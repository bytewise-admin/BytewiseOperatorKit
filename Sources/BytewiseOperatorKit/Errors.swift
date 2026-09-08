import Foundation
import HTTPTypes
import OpenAPIRuntime

/// RFC 9457 problem-details projection surfaced on a failed call (the operator API returns
/// `application/problem+json` with `title`/`detail`/`status`). Fields are best-effort — a non-JSON
/// or empty error body yields `nil`s.
public struct ProblemDetail: Sendable, Hashable, Codable {
    public let title: String?
    public let detail: String?
    public let status: Int?

    public init(title: String?, detail: String?, status: Int?) {
        self.title = title
        self.detail = detail
        self.status = status
    }

    private enum CodingKeys: String, CodingKey { case title, detail, status }
}

/// The single error every façade throws. Cases mirror the operator API's stable HTTP taxonomy;
/// each carries the server's `ProblemDetail` (title/detail) when one was returned. `transport`
/// wraps any failure that never produced an HTTP status — connection loss, timeout, or a response
/// body that could not be decoded.
public enum BytewiseOperatorError: Error, Sendable {
    /// 401 — missing/expired/revoked PAT, or a NULL-expiry mobile row failing closed.
    case unauthorized(ProblemDetail?)
    /// 403 — authenticated but not permitted (RBAC, or the mobile credential class denial matrix).
    case forbidden(ProblemDetail?)
    /// 404 — not found, INCLUDING "module not enabled / not a member" (no existence leak by design).
    case notFound(ProblemDetail?)
    /// Any 4xx that isn't 401/403/404/409/429 (400/402/413/422/…). Carries the REAL status so a
    /// live 422 is never misreported as 400.
    case validation(status: Int, ProblemDetail?)
    /// 409 — a flag kill/unkill lost the optimistic-concurrency race (M6.4). Carries the server's
    /// CURRENT flag state so the kill screen can reflect it and report *reconciled* when the current
    /// state already equals the intended target (do NOT re-POST). Distinct from `.validation` so the
    /// screen can pattern-match a real concurrency conflict; never auto-retried.
    case conflict(FlagKillConflict)
    /// 429 — rate limited. `retryAfter` is populated only when the server sent `Retry-After`
    /// (the bearer 30/min limiter emits a bare 429 today; `Retry-After` is a named M1.8 follow-up).
    case rateLimited(retryAfter: Duration?, ProblemDetail?)
    /// 5xx — server fault.
    case server(status: Int, ProblemDetail?)
    /// No HTTP status was obtained, or the response could not be processed (network, timeout, decode).
    case transport(any Error)

    /// The ProblemDetail carried by this error, when the server provided one.
    public var problem: ProblemDetail? {
        switch self {
        case let .unauthorized(p), let .forbidden(p), let .notFound(p),
             let .rateLimited(_, p):
            return p
        case let .validation(_, p):
            return p
        case let .server(_, p):
            return p
        case .conflict, .transport:
            return nil
        }
    }

    /// The HTTP status, when this error came from a server response.
    public var statusCode: Int? {
        switch self {
        case .unauthorized: return 401
        case .forbidden: return 403
        case .notFound: return 404
        case let .validation(status, _): return status
        case .conflict: return 409
        case .rateLimited: return 429
        case let .server(status, _): return status
        case .transport: return nil
        }
    }

    /// Whether a caller may reasonably retry (rate limits, server faults, transient transport).
    /// Mutations must NOT auto-retry (per the request-budget discipline) — this is advisory for reads.
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .server, .transport: return true
        case .unauthorized, .forbidden, .notFound, .validation, .conflict: return false
        }
    }
}

extension BytewiseOperatorError {
    /// Map a documented HTTP status + parsed problem + Retry-After into a taxonomy case.
    static func map(status: Int, problem: ProblemDetail?, retryAfter: Duration?) -> BytewiseOperatorError {
        switch status {
        case 401: return .unauthorized(problem)
        case 403: return .forbidden(problem)
        case 404: return .notFound(problem)
        case 429: return .rateLimited(retryAfter: retryAfter, problem)
        case 400...499: return .validation(status: status, problem)  // preserves the REAL 4xx code
        default: return .server(status: status, problem)
        }
    }

    /// Build an error from an OpenAPIRuntime `.undocumented` response (the only shape non-2xx
    /// responses take, since the mobile contract documents only success bodies). Reads the problem
    /// body and `Retry-After` off the raw payload.
    static func fromUndocumented(_ status: Int, _ payload: UndocumentedPayload) async -> BytewiseOperatorError {
        let problem = await parseProblem(payload.body)
        let retry = retryAfter(payload.headerFields)
        return map(status: status, problem: problem, retryAfter: retry)
    }

    /// The flag kill/unkill error mapping (M6.4): a 409 whose body is a typed `FlagKillConflict` becomes
    /// the distinguishable `.conflict` (carrying the server's CURRENT state); any other status — or a 409
    /// without that shape — falls through to the shared taxonomy. Only the flags façade calls this, so a
    /// generic 409 elsewhere is never coerced into a fabricated conflict.
    static func fromFlagKillUndocumented(_ status: Int, _ payload: UndocumentedPayload) async -> BytewiseOperatorError {
        if status == 409, let conflict = await parseFlagKillConflict(payload.body) {
            return .conflict(conflict)
        }
        return await fromUndocumented(status, payload)
    }

    private static func parseFlagKillConflict(_ body: HTTPBody?) async -> FlagKillConflict? {
        guard let body else { return nil }
        guard let data = try? await Data(collecting: body, upTo: 64 * 1024), !data.isEmpty else { return nil }
        let decoder = JSONDecoder()
        // `killedAt` is an RFC 3339 offset timestamp that MAY carry fractional seconds (EF DateTime → UtcNow
        // ticks); accept both forms so a killed-state conflict decodes reliably.
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { d in
            let raw = try d.singleValueContainer().decode(String.self)
            if let date = withFraction.date(from: raw) ?? plain.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: try d.singleValueContainer(), debugDescription: "unparseable date \(raw)")
        }
        return try? decoder.decode(FlagKillConflict.self, from: data)
    }

    private static func parseProblem(_ body: HTTPBody?) async -> ProblemDetail? {
        guard let body else { return nil }
        guard let data = try? await Data(collecting: body, upTo: 64 * 1024), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(ProblemDetail.self, from: data)
    }

    /// Parse `Retry-After` in either RFC 9110 form: delta-seconds (a non-negative integer) or an
    /// HTTP-date (RFC 1123). Negative/at-or-before-now values clamp to zero (never a negative delay).
    static func retryAfter(_ fields: HTTPFields) -> Duration? {
        guard let raw = fields[.retryAfter]?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        // delta-seconds
        if let seconds = Int(raw) { return .seconds(max(0, seconds)) }
        // HTTP-date → delay from now
        if let date = httpDate(raw) { return .seconds(max(0, date.timeIntervalSinceNow)) }
        return nil
    }

    private static func httpDate(_ raw: String) -> Date? {
        // Local formatter (Retry-After is a rare 429-only path) — no shared mutable state.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"  // RFC 1123, e.g. "Wed, 21 Oct 2026 07:28:00 GMT"
        return formatter.date(from: raw)
    }

    /// Normalize a thrown error (from the generated client / transport) into the taxonomy.
    /// Undocumented HTTP responses never reach here — they are returned, not thrown — so anything
    /// caught is a genuine transport or decoding failure.
    static func normalize(_ error: any Error) -> BytewiseOperatorError {
        if let already = error as? BytewiseOperatorError { return already }
        if let clientError = error as? ClientError { return .transport(clientError.underlyingError) }
        return .transport(error)
    }
}
