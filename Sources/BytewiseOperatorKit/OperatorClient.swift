import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// The official Swift client for the Bytewise Solutions operator-companion mobile API
/// (`v1-operator-mobile`). Bearer-only: authenticate with a mobile-companion PAT (`bws_pat_…`)
/// obtained via the pairing exchange.
///
/// ```swift
/// let client = OperatorClient(
///     baseURL: URL(string: "https://api.example.com")!,
///     credential: StaticOperatorCredential(pat))
/// let overview = try await client.dashboard.summary(project: "acme")
/// ```
///
/// The generated swift-openapi-generator transport under `Generated/` is `internal`; this wrapper
/// (client, façades, error taxonomy) is the ONLY public surface and the package's stability
/// boundary — generated request/response shapes churn with route refactors; these façades do not.
public final class OperatorClient: Sendable {
    let generated: any APIProtocol
    /// The read-cache seam (in-memory by default). Apps use it for the timestamped
    /// last-successful-response / stale-banner offline model.
    public let cache: any OperatorReadCache

    /// Production initializer. Requests go out over `URLSession` (`.shared` by default); the PAT is
    /// injected by the credential provider, and `X-Requested-With` is added to every unsafe method.
    ///
    /// No transport-level auto-retry is possible or needed here (the M6.4 flag-kill single-attempt guarantee):
    /// `URLSession` does not replay a discrete completed request on a connection failure the way OkHttp's
    /// default-on `retryOnConnectionFailure` does — so there is no equivalent toggle to disable. The mobile
    /// kill/unkill POSTs carry an EMPTY body, so there is no body stream `URLSession` could ask to re-provide
    /// (`urlSession(_:task:needNewBodyStream:)`) mid-recovery either. A kill therefore cannot fire twice from
    /// one `flags.kill(...)` call; `testKillIsSingleWireAttemptUnderDisconnect` pins one wire request per call.
    public init(
        baseURL: URL,
        credential: OperatorCredentialProvider?,
        session: URLSession = .shared,
        cache: any OperatorReadCache = InMemoryOperatorReadCache()
    ) {
        let transport = URLSessionTransport(configuration: .init(session: session))
        self.generated = Client(
            serverURL: baseURL,
            configuration: .init(dateTranscoder: BytewiseDateTranscoder()),
            transport: transport,
            middlewares: [OperatorAuthMiddleware(credential: credential)]
        )
        self.cache = cache
    }

    /// Test/advanced seam: inject a custom `ClientTransport` (e.g. a `URLSessionTransport` backed by
    /// a `URLProtocol` stub) so every façade is exercisable offline. The auth middleware is still
    /// installed, so Bearer + `X-Requested-With` injection is covered by these tests.
    public init(
        baseURL: URL,
        credential: OperatorCredentialProvider?,
        transport: any ClientTransport,
        cache: any OperatorReadCache = InMemoryOperatorReadCache()
    ) {
        self.generated = Client(
            serverURL: baseURL,
            configuration: .init(dateTranscoder: BytewiseDateTranscoder()),
            transport: transport,
            middlewares: [OperatorAuthMiddleware(credential: credential)]
        )
        self.cache = cache
    }

    // MARK: Façades (the only public API surface)

    /// Overview tab: dashboard summary, cross-project portfolio, cold-start bootstrap, and `/nav`.
    public var dashboard: DashboardFacade { DashboardFacade(client: self) }
    /// Crashes tab: analytics issues (list/detail), human triage, releases, and alert settings.
    public var crashes: CrashesFacade { CrashesFacade(client: self) }
    /// Feedback tab: list, human triage-set, resolve/reopen, and replies.
    public var feedback: FeedbackFacade { FeedbackFacade(client: self) }
    /// Revenue tab: commerce revenue, store revenue, and store vitals.
    public var revenue: RevenueFacade { RevenueFacade(client: self) }
    /// Account: identity, projects, and push-device registration lifecycle.
    public var account: AccountFacade { AccountFacade(client: self) }
    /// Feature-request management: list, quarantine queue, status change, lock, release, reject.
    public var featureBoard: FeatureBoardFacade { FeatureBoardFacade(client: self) }
    /// Onboarding: exchange a pairing code for a freshly minted mobile PAT (anonymous).
    public var pairing: PairingFacade { PairingFacade(client: self) }
    /// Operator-app chrome strings (localized; fallback-language chain honored server-side).
    public var localization: LocalizationFacade { LocalizationFacade(client: self) }
    /// Mobile Action Inbox (M5.1): the merged, prioritized cross-project operator-intervention list.
    public var inbox: InboxFacade { InboxFacade(client: self) }

    public var tasks: TasksFacade { TasksFacade(client: self) }
    /// License-abuse signals (read-only; conjunctive abuse.read + licenses.view + both modules gate).
    public var abuse: AbuseFacade { AbuseFacade(client: self) }
    /// Store reviews (read-only; stores.view + module stores). Summary list + by-id detail (M5.3).
    public var storesReviews: StoresReviewsFacade { StoresReviewsFacade(client: self) }
    /// Service status overview — the "Rendszermonitor" read (read-only; status.read + module status, M6.3).
    public var status: StatusFacade { StatusFacade(client: self) }
    /// Customer lookup for support (read-only; commerce.view + module commerce). Search + folded detail + activity (M6.5).
    public var customers: CustomersFacade { CustomersFacade(client: self) }
    /// Changelog review + publish/unpublish (changelog.read to review, changelog.write to publish; module changelog, M6.6a).
    public var changelog: ChangelogFacade { ChangelogFacade(client: self) }
    /// Roadmap board + review + narrow triage (roadmap.view to review, roadmap.curate to triage; module roadmap, M6.6b).
    public var roadmap: RoadmapFacade { RoadmapFacade(client: self) }
    /// Feature-flag kill-switch: list (flags.view) + kill/unkill (flags.manage) with If-Match; module flags, M6.4.
    public var flags: FlagsFacade { FlagsFacade(client: self) }
    /// Curated per-project external-links directory (read-only; links.view + module links). Category-grouped list (F5-09).
    public var links: LinksFacade { LinksFacade(client: self) }
}

/// Runs a generated-client operation, normalizing any THROWN error into the taxonomy. Undocumented
/// HTTP responses are returned (not thrown) and are mapped at the call site.
@inline(__always)
func run<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch {
        throw BytewiseOperatorError.normalize(error)
    }
}

/// Lenient ISO-8601 date handling. The .NET backend emits timestamps with or without fractional
/// seconds and with a `Z` or numeric offset; the runtime's default transcoder is stricter, so this
/// accepts both to avoid decode failures on live payloads. Encoding always uses fractional-second
/// UTC (`…Z`).
///
/// Uses the value-type `Date.ISO8601FormatStyle` (Sendable) rather than a shared
/// `ISO8601DateFormatter`, so there is no shared mutable state to reason about — the format-style
/// values are created locally per call and are cheap.
struct BytewiseDateTranscoder: DateTranscoder {
    func encode(_ date: Date) throws -> String {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(date)
    }

    func decode(_ string: String) throws -> Date {
        // The fractional-seconds style also parses non-fractional inputs (and both `Z` and numeric
        // offsets); the non-fractional style is a defensive fallback.
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string) { return date }
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(string) { return date }
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "Expected ISO-8601 date, got '\(string)'."))
    }
}
