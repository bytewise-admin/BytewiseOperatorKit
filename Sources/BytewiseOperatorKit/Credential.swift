import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Supplies the operator PAT (`bws_pat_…`) for the `Authorization: Bearer` header. Async so a real
/// app can read it from the Keychain off the hot path. Return `nil` to send an unauthenticated
/// request — the pairing exchange is the only endpoint that runs without a credential.
///
/// Implementations MUST be thread-safe; the provider is invoked once per request, possibly
/// concurrently.
public protocol OperatorCredentialProvider: Sendable {
    func currentToken() async -> String?
}

/// A fixed PAT credential — the common case once an installation is paired.
public struct StaticOperatorCredential: OperatorCredentialProvider {
    private let token: String?
    public init(_ token: String?) { self.token = token }
    public func currentToken() async -> String? { token }
}

/// Central request decoration for every operator call:
/// - injects `Authorization: Bearer <pat>` when the credential provider yields a token;
/// - guarantees `X-Requested-With` on every UNSAFE method (POST/PUT/PATCH/DELETE) even for Bearer
///   auth — the server's CSRF filter (`RequireCsrfHeader`) demands it regardless of scheme, and
///   this is the single place that can never be forgotten.
///
/// `X-Project-Slug` is NOT set here: it is inherently per-call (a different project per request),
/// so the project-scoped façades set it on the typed request instead.
struct OperatorAuthMiddleware: ClientMiddleware {
    let credential: OperatorCredentialProvider?

    private static let requestedWithName = HTTPField.Name("X-Requested-With")!
    static let requestedWithValue = "BytewiseOperatorKit"

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request

        if let token = await credential?.currentToken(), !token.isEmpty {
            request.headerFields[.authorization] = "Bearer \(token)"
        }

        if Self.isUnsafe(request.method), request.headerFields[Self.requestedWithName] == nil {
            request.headerFields[Self.requestedWithName] = Self.requestedWithValue
        }

        return try await next(request, body, baseURL)
    }

    static func isUnsafe(_ method: HTTPRequest.Method) -> Bool {
        switch method {
        case .post, .put, .patch, .delete: return true
        default: return false
        }
    }
}
