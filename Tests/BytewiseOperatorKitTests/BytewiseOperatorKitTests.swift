import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession
import XCTest
@testable import BytewiseOperatorKit

/// Canned JSON response builder (free function so it is safe to reference from `@Sendable` stub
/// responders without capturing the test case).
private func stubJSON(_ status: Int, _ body: String,
                      headers: [String: String] = [:]) -> BytewiseOperatorKitTests.Stub {
    // The generated client requires application/json on 2xx bodies; the undocumented error path
    // decodes ProblemDetails regardless of content type, so one type serves both.
    var h = headers; h["Content-Type"] = "application/json"
    return .init(status: status, headers: h, body: Data(body.utf8))
}

/// The wrapper's contract, over a URLProtocol stub (no network): the PAT rides as `Authorization:
/// Bearer` on every call; `X-Requested-With` rides only on unsafe methods; typed success bodies map
/// to the stable public models; failures map to the single error taxonomy (incl. Retry-After); the
/// pairing exchange returns the minted token. The GENERATED transport is exercised transitively —
/// these facts drive real swift-openapi decoding against canned wire payloads.
final class BytewiseOperatorKitTests: XCTestCase {

    // MARK: URLProtocol stub

    struct Stub: Sendable {
        let status: Int; let headers: [String: String]; let body: Data
        /// When set, the load FAILS with this error instead of returning a response — simulates a
        /// disconnect/timeout so a mutation's single-attempt (no-auto-retry) discipline is testable.
        var failure: URLError? = nil
    }

    final class StubURLProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var responder: (@Sendable (URLRequest) -> Stub)?
        nonisolated(unsafe) static var recorded: [URLRequest] = []
        static let lock = NSLock()

        static func reset(_ responder: @escaping @Sendable (URLRequest) -> Stub) {
            lock.lock(); recorded = []; self.responder = responder; lock.unlock()
        }
        static func requests() -> [URLRequest] { lock.lock(); defer { lock.unlock() }; return recorded }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            Self.lock.lock()
            Self.recorded.append(request)
            let responder = Self.responder
            Self.lock.unlock()
            let stub = responder?(request) ?? Stub(status: 404, headers: [:], body: Data())
            if let failure = stub.failure {
                client?.urlProtocol(self, didFailWithError: failure)
                return
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: stub.status,
                                           httpVersion: "HTTP/1.1", headerFields: stub.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !stub.body.isEmpty { client?.urlProtocol(self, didLoad: stub.body) }
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func makeClient(token: String? = "bws_pat_test.secret",
                            responder: @escaping @Sendable (URLRequest) -> Stub) -> OperatorClient {
        StubURLProtocol.reset(responder)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        let transport = URLSessionTransport(configuration: .init(session: session))
        return OperatorClient(baseURL: URL(string: "https://api.example.test")!,
                              credential: StaticOperatorCredential(token),
                              transport: transport)
    }

    private func header(_ requests: [URLRequest], _ name: String) -> String? {
        requests.last?.value(forHTTPHeaderField: name)
    }

    // MARK: Auth-header injection

    func testBearerRidesEveryCall_andRequestedWithOnlyOnUnsafeMethods() async throws {
        // A GET: Authorization present, X-Requested-With ABSENT.
        let getClient = makeClient { _ in
            stubJSON(200, #"{"project":{"name":"Acme","slug":"acme"},"stats":[],"statsModuleCount":0,"partial":false,"failedModules":[]}"#)
        }
        _ = try await getClient.dashboard.summary(project: "acme")
        var reqs = StubURLProtocol.requests()
        XCTAssertEqual(header(reqs, "Authorization"), "Bearer bws_pat_test.secret")
        XCTAssertNil(header(reqs, "X-Requested-With"), "GET must not carry the CSRF header")
        XCTAssertEqual(header(reqs, "X-Project-Slug"), "acme")

        // A POST (unsafe): Authorization AND X-Requested-With both present.
        let postClient = makeClient { _ in
            stubJSON(200, #"{"id":7,"status":"resolved","isResolved":true}"#)
        }
        _ = try await postClient.feedback.resolve(project: "acme", id: 7)
        reqs = StubURLProtocol.requests()
        XCTAssertEqual(header(reqs, "Authorization"), "Bearer bws_pat_test.secret")
        XCTAssertEqual(header(reqs, "X-Requested-With"), "BytewiseOperatorKit")
        XCTAssertEqual(header(reqs, "X-Project-Slug"), "acme")
    }

    /// The middleware in isolation: it adds `X-Requested-With` on POST but never on GET, and injects
    /// the Bearer token from the provider.
    func testMiddleware_addsRequestedWithOnlyForUnsafeMethods() async throws {
        let middleware = OperatorAuthMiddleware(credential: StaticOperatorCredential("tok-123"))

        func run(_ method: HTTPRequest.Method) async throws -> HTTPRequest {
            final class Box: @unchecked Sendable { var request: HTTPRequest? }
            let box = Box()
            _ = try await middleware.intercept(
                HTTPRequest(method: method, scheme: "https", authority: "api.example.test", path: "/x"),
                body: nil, baseURL: URL(string: "https://api.example.test")!, operationID: "op"
            ) { request, _, _ in
                box.request = request
                return (HTTPResponse(status: .ok), nil)
            }
            return box.request!
        }

        let get = try await run(.get)
        XCTAssertEqual(get.headerFields[.authorization], "Bearer tok-123")
        XCTAssertNil(get.headerFields[HTTPField.Name("X-Requested-With")!])

        let post = try await run(.post)
        XCTAssertEqual(post.headerFields[.authorization], "Bearer tok-123")
        XCTAssertEqual(post.headerFields[HTTPField.Name("X-Requested-With")!], "BytewiseOperatorKit")
    }

    // MARK: Decode-per-façade-family

    func testDashboardSummaryAndBootstrapDecode() async throws {
        let summaryClient = makeClient { _ in
            stubJSON(200, #"""
            {"project":{"name":"Acme","slug":"acme"},
             "stats":[{"key":"crashes","label":"Crashes","module":"analytics","moduleName":"Analytics","tone":"warn","value":12}],
             "statsModuleCount":3,"partial":true,"failedModules":["commerce"]}
            """#)
        }
        let summary = try await summaryClient.dashboard.summary(project: "acme")
        XCTAssertEqual(summary.project.slug, "acme")
        XCTAssertEqual(summary.statsModuleCount, 3)
        XCTAssertEqual(summary.stats.first?.value, 12)
        // The fail-soft contract (round-4 R4-4), which is the REASON these two fields exist: a dashboard
        // missing a contributor's tiles must be distinguishable from a healthy one that simply has fewer.
        // Decoding them is not enough — a kit that dropped them would still decode; this asserts they arrive.
        XCTAssertTrue(summary.partial)
        XCTAssertEqual(summary.failedModules, ["commerce"])

        let bootstrapClient = makeClient { _ in
            stubJSON(200, #"""
            {"me":{"id":1,"email":"op@x.test","displayName":"Op","isSystemAdmin":false,"twoFactorEnabled":true,"tokenKind":"mobileCompanion","tokenId":"AbCdEfGhIjKlMnOpQrStUv","scopes":null},
             "projects":[{"id":9,"slug":"acme","name":"Acme","platforms":3,"role":"owner",
                          "enabledModules":["analytics","feedback"],
                          "permissions":["analytics.triage","analytics.view","feedback.manage","feedback.read","project.read"],
                          "publishableAnalytics":{"sentryDsn":"https://dsn","postHogKey":"ph","postHogHost":null}}]}
            """#)
        }
        let bootstrap = try await bootstrapClient.dashboard.bootstrap()
        XCTAssertEqual(bootstrap.me.email, "op@x.test")
        XCTAssertTrue(bootstrap.me.twoFactorEnabled)
        // F1a credential introspection survives the public mirror: the kind as its wire string, the public
        // id, and a null scope ceiling (the mobile companion acts as owner).
        XCTAssertEqual(bootstrap.me.tokenKind, "mobileCompanion")
        XCTAssertEqual(bootstrap.me.tokenId, "AbCdEfGhIjKlMnOpQrStUv")
        XCTAssertNil(bootstrap.me.scopes)
        XCTAssertEqual(bootstrap.projects.count, 1)
        XCTAssertEqual(bootstrap.projects[0].enabledModules, ["analytics", "feedback"])
        XCTAssertEqual(bootstrap.projects[0].permissions, // gates capability actions, not just tab visibility
                       ["analytics.triage", "analytics.view", "feedback.manage", "feedback.read", "project.read"])
        XCTAssertEqual(bootstrap.projects[0].publishableAnalytics.sentryDsn, "https://dsn")
        XCTAssertNil(bootstrap.projects[0].publishableAnalytics.postHogHost)
    }

    func testAnalyticsIssuesDecode() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"available":true,
             "issues":[{"id":"EV-1","title":"NPE","level":"error","count":42,"userCount":7,"severity":"high"}]}
            """#)
        }
        let issues = try await client.crashes.issues(project: "acme")
        XCTAssertTrue(issues.available)
        XCTAssertEqual(issues.issues.count, 1)
        XCTAssertEqual(issues.issues[0].id, "EV-1")
        XCTAssertEqual(issues.issues[0].count, 42)
        XCTAssertEqual(issues.issues[0].severity, "high")
        XCTAssertTrue(issues.resolved.isEmpty)  // absent optional array coalesces to []
    }

    func testSymbolInventorySendsIdentityFilters_andMapsSHA256Readback() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"artifacts":[{"id":9223372036854770000,"kind":"so-symbols","debugId":"4f3c2a1b",
              "architecture":"arm64","imageName":"libbwtk.so","fileSize":4294967296,
              "contentHash":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
              "status":"ready","createdAt":"2026-09-01T08:09:10Z"}]}
            """#)
        }

        let response = try await client.crashes.symbols(
            project: "acme", appId: "android-prod", kind: "so-symbols", limit: 17,
            debugId: "4f3c2a1b", architecture: "arm64", imageName: "libbwtk.so",
            verifyStoredBytes: true)

        let artifact = try XCTUnwrap(response.artifacts.first)
        XCTAssertEqual(artifact.id, 9_223_372_036_854_770_000)
        XCTAssertEqual(artifact.fileSize, 4_294_967_296)
        XCTAssertEqual(artifact.debugId, "4f3c2a1b")
        XCTAssertEqual(artifact.architecture, "arm64")
        XCTAssertEqual(artifact.imageName, "libbwtk.so")
        XCTAssertEqual(artifact.contentHash,
                       "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        XCTAssertEqual(artifact.status, "ready")

        let req = try XCTUnwrap(StubURLProtocol.requests().last)
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.url?.path, "/api/v1/analytics/apps/android-prod/symbols")
        XCTAssertEqual(header([req], "X-Project-Slug"), "acme")
        XCTAssertNil(header([req], "X-Requested-With"))
        let url = try XCTUnwrap(req.url)
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(query.queryItems?.first(where: { $0.name == "kind" })?.value, "so-symbols")
        XCTAssertEqual(query.queryItems?.first(where: { $0.name == "limit" })?.value, "17")
        XCTAssertEqual(query.queryItems?.first(where: { $0.name == "debugId" })?.value, "4f3c2a1b")
        XCTAssertEqual(query.queryItems?.first(where: { $0.name == "architecture" })?.value, "arm64")
        XCTAssertEqual(query.queryItems?.first(where: { $0.name == "imageName" })?.value, "libbwtk.so")
        XCTAssertEqual(query.queryItems?.first(where: { $0.name == "verifyStoredBytes" })?.value, "true")
    }

    func testSymbolInventoryNotFoundUsesOperatorErrorTaxonomy() async throws {
        let client = makeClient { _ in
            stubJSON(404, #"{"title":"No active project matches the request.","status":404}"#)
        }
        await assertThrows(try await client.crashes.symbols(project: "nope", appId: "android-prod")) { error in
            guard case .notFound = error else { return XCTFail("expected .notFound, got \(error)") }
            XCTAssertEqual(error.statusCode, 404)
        }
    }

    func testFeedbackListDecode() async throws {
        // Every required (incl. required-nullable) key must be present in the wire body.
        let client = makeClient { _ in
            // F-A5 wire shape: the keyset ENVELOPE. A stub still answering with a bare array decodes to an
            // empty page, so every row assertion below would pass over nothing — hence the cursor is
            // asserted too: a façade that drops it silently ends a stream that has not ended.
            stubJSON(200, #"""
            {"items":[{"id":5,"message":"Great app","email":null,"status":"open","category":null,"suggestedCategory":null,
              "appVersion":null,"osVersion":null,"createdAt":"2026-07-01T00:00:00Z","isResolved":false,
              "resolvedAt":null,"assignedUserId":null,"adminNotes":null,"aiSummary":null,"aiUrgency":null,
              "aiTriagedAt":null,"isQuarantined":false,"quarantineReason":null,"quarantinedAt":null,
              "attachments":[{"id":1,"fileName":"log.txt","contentType":"text/plain","sizeBytes":1024}]}],
             "nextCursor":"Y3Vyc29y","tags":[{"itemId":5,"tags":[{"id":7,"name":"bug"}]}]}
            """#)
        }
        let page = try await client.feedback.list(project: "acme")
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items[0].id, 5)
        XCTAssertEqual(page.items[0].message, "Great app")
        XCTAssertFalse(page.items[0].isResolved)
        XCTAssertEqual(page.items[0].attachments.first?.sizeBytes, 1024)
        XCTAssertEqual(page.nextCursor, "Y3Vyc29y")
        XCTAssertEqual(page.tags.first?.tags.first?.name, "bug")
    }

    /// Round-5 `STORES-COVERAGE-REJECTEDROWS-NEM-LATSZIK`, and the Codex review of that change: the
    /// generated transport picked up the three `incomplete*` fields automatically, the HAND-WRITTEN public
    /// model did not — so an app reading this SDK would have seen a coverage row that looks flawless over a
    /// period known to be short. That is the same invisibility the fields were added to close, one layer
    /// down, which is why the public model owns them and this test pins the decode.
    func testStoresCoverageRowLossDecode() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"windowDays":90,"series":[],"topProducts":[],
             "coverage":[{"provider":"googleplay","reportKey":"play.earnings","through":"2026-07",
                          "lastRunAt":"2026-08-02T04:00:00Z","lastOutcome":"ok",
                          "incompletePeriod":"2026-06","incompleteRejectedRows":4,"incompleteRows":812,
                          "unclaimedPeriod":"2026-05","unclaimedRows":30,"unclaimedRemovedFacts":12}]}
            """#)
        }
        let revenue = try await client.revenue.stores(project: "acme")
        let coverage = try XCTUnwrap(revenue.coverage.first)
        XCTAssertEqual(coverage.lastOutcome, "ok") // the run did not stop…
        XCTAssertEqual(coverage.incompletePeriod, "2026-06") // …and one period still came up short
        XCTAssertEqual(coverage.incompleteRejectedRows, 4)
        XCTAssertEqual(coverage.incompleteRows, 812)
        // …and the same argument one item later (round-5 STORES-ERTEK-SZOTAR-ATNEVEZES).
        XCTAssertEqual(coverage.unclaimedPeriod, "2026-05")
        XCTAssertEqual(coverage.unclaimedRows, 30)
        XCTAssertEqual(coverage.unclaimedRemovedFacts, 12)
    }

    func testCommerceRevenueDecode() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"counts":{"active":4,"completed":10,"defaulted":1,"pendingPayment":2,"refunded":0},
             "currencies":[{"currency":"usd","collected30dCents":50000,"prior30dCents":40000,
                            "outstandingPendingCents":0,"outstandingOverdueCents":0,
                            "monthly":[{"month":"2026-06","collectedCents":50000,"disputedLostCents":1500}],
                            "origins":[{"origin":"stripe","collectedCents":50000}],
                            "disputedLost30dCents":1500,"disputedLost12mCents":9000}],
             "defaultSplit":{"dunning":1,"subscriptionDeleted":0,"unknown":0},
             "refunds90d":{"paidBase":10,"refunded":0},
             "trials":{"started90d":30,"matured90d":20,"maturedConverted90d":8}}
            """#)
        }
        let revenue = try await client.revenue.commerce(project: "acme")
        XCTAssertEqual(revenue.counts.completed, 10)
        XCTAssertEqual(revenue.currencies.first?.collected30dCents, 50000)
        XCTAssertEqual(revenue.currencies.first?.monthly.first?.month, "2026-06")
        // A DEDUCTION reported beside the collected figures: an app that reads `collected30dCents` alone
        // overstates what was kept, so the two chargeback fields have to survive the decode.
        XCTAssertEqual(revenue.currencies.first?.disputedLost30dCents, 1500)
        XCTAssertEqual(revenue.currencies.first?.disputedLost12mCents, 9000)
        XCTAssertEqual(revenue.currencies.first?.monthly.first?.disputedLostCents, 1500) // per-month, same deduction
        XCTAssertEqual(revenue.trials?.maturedConverted90d, 8)
    }

    // MARK: FeatureBoard

    func testFeatureBoardListDecode_andQueryFilters() async throws {
        let client = makeClient { _ in
            // F-A5 wire shape: the keyset ENVELOPE (see the feedback decode test for why the cursor is
            // asserted rather than only the rows).
            stubJSON(200, #"""
            {"items":[{"id":3,"title":"Dark mode","description":"Please","status":"planned","voteCount":12,
              "isLocked":false,"isDeleted":false,"statusChangedAt":"2026-07-10T00:00:00Z",
              "createdAt":"2026-07-01T00:00:00Z","commentCount":4}],
             "nextCursor":null,"tags":[]}
            """#)
        }
        let page = try await client.featureBoard.list(project: "acme", status: "planned", search: "dark")
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items[0].id, 3)
        XCTAssertEqual(page.items[0].status, "planned")
        XCTAssertEqual(page.items[0].voteCount, 12)
        XCTAssertEqual(page.items[0].commentCount, 4) // the additive field must survive the wrapper mapping
        XCTAssertFalse(page.items[0].isLocked)
        XCTAssertNil(page.nextCursor) // a null cursor is the ONLY end-of-stream signal
        let reqs = StubURLProtocol.requests()
        XCTAssertNil(header(reqs, "X-Requested-With"), "GET must not carry the CSRF header")
        XCTAssertEqual(header(reqs, "X-Project-Slug"), "acme")
        let query = reqs.last?.url?.query ?? ""
        XCTAssertTrue(query.contains("status=planned"), "status filter must ride the query: \(query)")
        XCTAssertTrue(query.contains("search=dark"), "search filter must ride the query: \(query)")
    }

    func testFeatureBoardQuarantinedDecode() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            [{"id":9,"title":"spam","description":null,"quarantineReason":"link-flood",
              "quarantinedAt":"2026-07-12T00:00:00Z","createdAt":"2026-07-12T00:00:00Z"}]
            """#)
        }
        let items = try await client.featureBoard.quarantined(project: "acme")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, 9)
        XCTAssertEqual(items[0].quarantineReason, "link-flood")
        XCTAssertNil(items[0].description)
    }

    func testFeatureBoardMutationsCarryCsrfHeader_andDecodeResults() async throws {
        // status change
        let statusClient = makeClient { _ in stubJSON(200, #"{"id":3,"status":"shipped"}"#) }
        let statusResult = try await statusClient.featureBoard.changeStatus(project: "acme", id: 3, status: "shipped")
        XCTAssertEqual(statusResult.status, "shipped")
        var reqs = StubURLProtocol.requests()
        XCTAssertEqual(header(reqs, "X-Requested-With"), "BytewiseOperatorKit")
        XCTAssertEqual(header(reqs, "X-Project-Slug"), "acme")

        // lock
        let lockClient = makeClient { _ in stubJSON(200, #"{"id":3,"isLocked":true}"#) }
        let lockResult = try await lockClient.featureBoard.setLocked(project: "acme", id: 3, locked: true)
        XCTAssertTrue(lockResult.isLocked)
        reqs = StubURLProtocol.requests()
        XCTAssertEqual(header(reqs, "X-Requested-With"), "BytewiseOperatorKit")

        // quarantine release + reject
        let releaseClient = makeClient { _ in stubJSON(200, #"{"id":9,"isQuarantined":false}"#) }
        let releaseResult = try await releaseClient.featureBoard.release(project: "acme", id: 9)
        XCTAssertFalse(releaseResult.isQuarantined)
        reqs = StubURLProtocol.requests()
        XCTAssertEqual(header(reqs, "X-Requested-With"), "BytewiseOperatorKit") // release itself, not just reject
        XCTAssertEqual(header(reqs, "X-Project-Slug"), "acme")

        let rejectClient = makeClient { _ in stubJSON(200, #"{"id":9}"#) }
        let rejectResult = try await rejectClient.featureBoard.reject(project: "acme", id: 9)
        XCTAssertEqual(rejectResult.id, 9)
        reqs = StubURLProtocol.requests()
        XCTAssertEqual(header(reqs, "X-Requested-With"), "BytewiseOperatorKit")
    }

    func testFeatureBoardCommentStripDecode_readIsCsrfFree_writesCarryCsrf() async throws {
        // The triage READ: oldest-first, tombstoned rows included, paging on the query. GET → no CSRF header.
        let readClient = makeClient { _ in
            stubJSON(200, #"""
            {"total":2,"page":1,"pageSize":50,"items":[
              {"id":11,"body":"legit question","isOperator":false,"isDeleted":false,"createdAt":"2026-08-01T09:00:00+00:00"},
              {"id":12,"body":"hidden spam","isOperator":false,"isDeleted":true,"createdAt":"2026-08-01T09:05:00+00:00"}]}
            """#)
        }
        let page = try await readClient.featureBoard.comments(project: "acme", featureId: 7, page: 1, pageSize: 50)
        XCTAssertEqual(page.total, 2)
        XCTAssertEqual(page.items.count, 2)
        XCTAssertTrue(page.items[1].isDeleted) // the tombstone survives the mapping (the strip shows what was hidden)
        var reqs = StubURLProtocol.requests()
        XCTAssertNil(header(reqs, "X-Requested-With"), "the comment read is a GET — no CSRF header")
        XCTAssertEqual(header(reqs, "X-Project-Slug"), "acme")
        let query = reqs.last?.url?.query ?? ""
        XCTAssertTrue(query.contains("page=1"), "paging must ride the query: \(query)")
        XCTAssertTrue(query.contains("pageSize=50"), "paging must ride the query: \(query)")

        // Reply: the moderate-gated write carries CSRF and sends the body.
        let replyClient = makeClient { _ in stubJSON(200, #"{"id":13,"body":"Shipped in 2.1!","isOperator":true,"isDeleted":false,"createdAt":"2026-08-01T10:00:00+00:00"}"#) }
        let reply = try await replyClient.featureBoard.reply(project: "acme", featureId: 7, body: "Shipped in 2.1!")
        XCTAssertTrue(reply.isOperator)
        XCTAssertEqual(reply.id, 13)
        reqs = StubURLProtocol.requests()
        XCTAssertEqual(header(reqs, "X-Requested-With"), "BytewiseOperatorKit")

        // Hide / release / reject: each a moderate-gated write with CSRF.
        let hideClient = makeClient { _ in stubJSON(200, #"{"id":12,"isDeleted":true}"#) }
        let hidden = try await hideClient.featureBoard.hideComment(project: "acme", commentId: 12)
        XCTAssertTrue(hidden.isDeleted)
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Requested-With"), "BytewiseOperatorKit")

        // The comment quarantine queue read (moderate-gated, still a GET → no CSRF).
        let queueClient = makeClient { _ in
            stubJSON(200, #"""
            {"items":[{"id":21,"featureId":7,"featureTitle":"Dark mode","body":"buy cheap","quarantineReason":"link-flood",
              "quarantinedAt":"2026-08-02T00:00:00+00:00","createdAt":"2026-08-02T00:00:00+00:00"}],"truncated":true}
            """#)
        }
        let queue = try await queueClient.featureBoard.quarantinedComments(project: "acme")
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(queue.items[0].featureTitle, "Dark mode")
        XCTAssertTrue(queue.truncated) // the incompleteness signal must survive the mapping
        XCTAssertNil(header(StubURLProtocol.requests(), "X-Requested-With"))

        let relClient = makeClient { _ in stubJSON(200, #"{"id":21,"isQuarantined":false}"#) }
        let released = try await relClient.featureBoard.releaseComment(project: "acme", commentId: 21)
        XCTAssertFalse(released.isQuarantined)
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Requested-With"), "BytewiseOperatorKit")

        let rejClient = makeClient { _ in stubJSON(200, #"{"id":21}"#) }
        let rejected = try await rejClient.featureBoard.rejectComment(project: "acme", commentId: 21)
        XCTAssertEqual(rejected.id, 21)
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Requested-With"), "BytewiseOperatorKit")
    }

    func testFeatureBoardForbiddenMapsTaxonomy() async throws {
        // featureboard.moderate missing → 403 must map to the shared taxonomy like every façade.
        let client = makeClient { _ in stubJSON(403, #"{"title":"Forbidden"}"#) }
        await assertThrows(try await client.featureBoard.quarantined(project: "acme")) { error in
            guard case .forbidden = error else { return XCTFail("expected .forbidden, got \(error)") }
        }
    }

    // MARK: Service status (M6.3)

    /// The status overview decodes end-to-end through the generated transport: the publication state, the
    /// rolled-up banner, a component with its day strip (incl. a `known == 0` no-coverage day and a `null`
    /// `uptimePercent`, which must stay `nil` — NOT 0), and an incident with its updates. The read is
    /// project-scoped, so `X-Project-Slug` must ride the request.
    func testStatusOverviewDecode_andProjectScoping() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"published":true,"publishedAt":"2026-07-01T10:00:00Z","systemAdmin":false,"banner":"degraded",
             "components":[
               {"id":1,"key":"api","name":"API","nameKey":"push.status.component","scope":"platform",
                "state":"degraded","reason":"backlog:slow","publicVisible":true,"archived":false,"sortOrder":0,
                "uptimePercent":99.5,
                "days":[{"day":"2026-07-18","uptime":1.0,"known":1.0,"worst":"operational"},
                        {"day":"2026-07-19","uptime":0.0,"known":0.0,"worst":"unknown"}]},
               {"id":2,"key":"jobs","name":"Jobs","nameKey":null,"scope":"project","state":"unknown",
                "reason":null,"publicVisible":false,"archived":true,"sortOrder":1,"uptimePercent":null,"days":[]}],
             "incidents":[
               {"id":9,"title":"Elevated errors","scope":"project","impact":"major","lifecycle":"monitoring",
                "startedAt":"2026-07-19T08:00:00Z","resolvedAt":null,"rowVersion":"AAAAAAAAB9E=",
                "componentIds":[1],
                "updates":[{"lifecycle":"monitoring","message":"Recovering.","postedAt":"2026-07-19T09:00:00Z"},
                           {"lifecycle":"investigating","message":"Looking into it.","postedAt":"2026-07-19T08:05:00Z"}]}]}
            """#)
        }
        let overview = try await client.status.overview(project: "acme")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme",
                       "the status read is project-scoped — the slug header is required by the contract")
        XCTAssertTrue(overview.published)
        XCTAssertNotNil(overview.publishedAt)
        XCTAssertFalse(overview.systemAdmin)
        XCTAssertEqual(overview.banner, "degraded")

        XCTAssertEqual(overview.components.count, 2)
        let api = overview.components[0]
        XCTAssertEqual(api.key, "api")
        XCTAssertEqual(api.nameKey, "push.status.component")
        XCTAssertEqual(api.reason, "backlog:slow")
        XCTAssertEqual(api.uptimePercent, 99.5)
        XCTAssertEqual(api.days.count, 2)
        XCTAssertEqual(api.days[1].known, 0.0, "a no-coverage day must survive decoding as known == 0")
        XCTAssertEqual(api.days[1].worst, "unknown")

        let jobs = overview.components[1]
        XCTAssertNil(jobs.nameKey)
        XCTAssertNil(jobs.uptimePercent, "an unobserved window is nil — never 0%")
        XCTAssertTrue(jobs.archived)
        XCTAssertFalse(jobs.publicVisible)
        XCTAssertTrue(jobs.days.isEmpty)

        XCTAssertEqual(overview.incidents.count, 1)
        let incident = overview.incidents[0]
        XCTAssertEqual(incident.lifecycle, "monitoring")
        XCTAssertNil(incident.resolvedAt)
        XCTAssertEqual(incident.rowVersion, "AAAAAAAAB9E=")
        XCTAssertEqual(incident.componentIds, [1])
        // Server order (postedAt desc) is preserved verbatim by the mapper.
        XCTAssertEqual(incident.updates.map(\.lifecycle), ["monitoring", "investigating"])
    }

    /// Missing `status.read` (or the module disabled) → 403 must map to the shared taxonomy like every façade.
    func testStatusForbiddenMapsTaxonomy() async throws {
        let client = makeClient { _ in stubJSON(403, #"{"title":"Forbidden","detail":"status.read required"}"#) }
        await assertThrows(try await client.status.overview(project: "acme")) { error in
            guard case let .forbidden(problem) = error else { return XCTFail("expected .forbidden, got \(error)") }
            XCTAssertEqual(problem?.detail, "status.read required")
        }
    }

    // MARK: Store vitals app selector (M6.1)

    /// The selector decodes end-to-end and rides the project slug. The server has ALREADY filtered to
    /// vitals-eligible (Play + enabled) apps and applied the cap, so the façade must pass rows through
    /// verbatim — in server order, with `truncated` preserved (the picker has to say so, or capped-out apps
    /// are silently unreachable).
    func testVitalsAppsDecode_preservesServerOrderAndTruncation() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"{"apps":[{"id":4,"displayName":"Aardvark"},{"id":9,"displayName":"Zebra"}],"truncated":true}"#)
        }
        let apps = try await client.revenue.vitalsApps(project: "acme")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertEqual(apps.apps.map(\.id), [4, 9], "server order (display name, then id) is passed through verbatim")
        XCTAssertEqual(apps.apps.map(\.displayName), ["Aardvark", "Zebra"])
        XCTAssertTrue(apps.truncated)
        // Data minimization is a CONTRACT property, not a client choice: the model has nothing but id + name
        // (no bundle/package id, no external store app id, no provider token).
        XCTAssertEqual(Mirror(reflecting: apps.apps[0]).children.compactMap(\.label).sorted(),
                       ["displayName", "id"])
    }

    /// Zero eligible apps is an ordinary 200 with an empty list — never an error. The screen turns this into a
    /// localized empty state.
    func testVitalsAppsEmptyIsNotAnError() async throws {
        let client = makeClient { _ in stubJSON(200, #"{"apps":[],"truncated":false}"#) }
        let apps = try await client.revenue.vitalsApps(project: "acme")
        XCTAssertTrue(apps.apps.isEmpty)
        XCTAssertFalse(apps.truncated)
    }

    /// Missing `stores.view` (or the module disabled) → 403 maps to the shared taxonomy, exactly as
    /// `vitals(project:appId:)` does — the two share one gate.
    func testVitalsAppsForbiddenMapsTaxonomy() async throws {
        let client = makeClient { _ in stubJSON(403, #"{"title":"Forbidden","detail":"stores.view required"}"#) }
        await assertThrows(try await client.revenue.vitalsApps(project: "acme")) { error in
            guard case let .forbidden(problem) = error else { return XCTFail("expected .forbidden, got \(error)") }
            XCTAssertEqual(problem?.detail, "stores.view required")
        }
    }

    // MARK: Error mapping

    func testUnauthorizedMapsWithProblemDetail() async throws {
        let client = makeClient { _ in
            stubJSON(401, #"{"title":"Unauthorized","detail":"Token expired","status":401}"#)
        }
        await assertThrows(try await client.account.me()) { error in
            guard case let .unauthorized(problem) = error else { return XCTFail("expected .unauthorized, got \(error)") }
            XCTAssertEqual(problem?.title, "Unauthorized")
            XCTAssertEqual(problem?.detail, "Token expired")
            XCTAssertEqual(error.statusCode, 401)
            XCTAssertFalse(error.isRetryable)
        }
    }

    func testForbiddenMaps() async throws {
        let client = makeClient { _ in stubJSON(403, #"{"title":"Forbidden"}"#) }
        await assertThrows(try await client.crashes.issues(project: "acme")) { error in
            guard case .forbidden = error else { return XCTFail("expected .forbidden, got \(error)") }
        }
    }

    /// A 4xx that isn't 401/403/404/429 preserves its REAL status (regression: it used to report 400).
    func testValidationPreservesRealStatusCode() async throws {
        let conflict = makeClient { _ in stubJSON(409, #"{"title":"Conflict","detail":"Already resolved"}"#) }
        await assertThrows(try await conflict.feedback.resolve(project: "acme", id: 1)) { error in
            guard case let .validation(status, problem) = error else { return XCTFail("expected .validation, got \(error)") }
            XCTAssertEqual(status, 409)
            XCTAssertEqual(error.statusCode, 409, "must not be misreported as 400")
            XCTAssertEqual(problem?.detail, "Already resolved")
        }

        let unprocessable = makeClient { _ in stubJSON(422, #"{"title":"Unprocessable"}"#) }
        await assertThrows(try await unprocessable.feedback.reply(project: "acme", id: 1, body: "hi")) { error in
            guard case let .validation(status, _) = error else { return XCTFail("expected .validation, got \(error)") }
            XCTAssertEqual(status, 422)
            XCTAssertEqual(error.statusCode, 422)
        }
    }

    func testRateLimitedSurfacesRetryAfter() async throws {
        let client = makeClient { _ in stubJSON(429, "{}", headers: ["Retry-After": "30"]) }
        await assertThrows(try await client.crashes.issues(project: "acme")) { error in
            guard case let .rateLimited(retryAfter, _) = error else { return XCTFail("expected .rateLimited, got \(error)") }
            XCTAssertEqual(retryAfter, .seconds(30))
            XCTAssertTrue(error.isRetryable)
        }
    }

    /// `Retry-After` as an HTTP-date (RFC 1123) → a positive delay from now.
    func testRateLimitedRetryAfterHttpDateForm() async throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let httpDate = formatter.string(from: Date().addingTimeInterval(120))
        let client = makeClient { _ in stubJSON(429, "{}", headers: ["Retry-After": httpDate]) }
        await assertThrows(try await client.crashes.issues(project: "acme")) { error in
            guard case let .rateLimited(retryAfter, _) = error else { return XCTFail("expected .rateLimited, got \(error)") }
            guard let retryAfter else { return XCTFail("expected a parsed Retry-After delay") }
            // ~120s in the future (RFC 1123 has 1s resolution; allow slack for test timing).
            XCTAssertGreaterThan(retryAfter, .seconds(100))
            XCTAssertLessThanOrEqual(retryAfter, .seconds(121))
        }
    }

    /// A negative delta-seconds `Retry-After` clamps to zero (never a negative delay).
    func testRateLimitedRetryAfterNegativeClampsToZero() async throws {
        let client = makeClient { _ in stubJSON(429, "{}", headers: ["Retry-After": "-5"]) }
        await assertThrows(try await client.crashes.issues(project: "acme")) { error in
            guard case let .rateLimited(retryAfter, _) = error else { return XCTFail("expected .rateLimited, got \(error)") }
            XCTAssertEqual(retryAfter, .seconds(0))
        }
    }

    func testServerErrorMaps() async throws {
        let client = makeClient { _ in stubJSON(503, #"{"title":"Service Unavailable"}"#) }
        await assertThrows(try await client.dashboard.portfolio()) { error in
            guard case let .server(status, problem) = error else { return XCTFail("expected .server, got \(error)") }
            XCTAssertEqual(status, 503)
            XCTAssertEqual(problem?.title, "Service Unavailable")
        }
    }

    // MARK: Pairing

    func testPairingExchangeReturnsToken() async throws {
        // Anonymous flow — construct the client with NO credential.
        let client = makeClient(token: nil) { _ in
            stubJSON(200, #"""
            {"token":"bws_pat_new.secret","tokenId":"tok-42","name":"Peter's iPhone",
             "createdAt":"2026-07-13T00:00:00Z","expiresAt":"2026-10-11T00:00:00Z"}
            """#)
        }
        let result = try await client.pairing.exchange(code: "bws_pair_abc")
        XCTAssertEqual(result.token, "bws_pat_new.secret")
        XCTAssertEqual(result.tokenId, "tok-42")
        XCTAssertEqual(result.name, "Peter's iPhone")
        // No credential configured → no Authorization header on the anonymous exchange.
        XCTAssertNil(header(StubURLProtocol.requests(), "Authorization"))
    }

    func testRevokeSelfLogoutTeardown() async throws {
        // DELETE /auth/mobile-pairing/self — carries Bearer + the CSRF header (unsafe method), returns the
        // idempotent revoked result.
        let client = makeClient { _ in
            stubJSON(200, #"{"tokenId":"tok-42","revoked":true}"#)
        }
        let result = try await client.account.revokeSelf()
        XCTAssertEqual(result.tokenId, "tok-42")
        XCTAssertTrue(result.revoked)
        let reqs = StubURLProtocol.requests()
        XCTAssertEqual(header(reqs, "Authorization"), "Bearer bws_pat_test.secret")
        XCTAssertEqual(header(reqs, "X-Requested-With"), "BytewiseOperatorKit") // DELETE is unsafe → CSRF header
    }

    // MARK: Read-cache seam

    func testInMemoryReadCacheStoresTimestampedValues() async throws {
        let cache = InMemoryOperatorReadCache()
        await cache.write(["a": "b"], forKey: "loc:en")
        let entry = await cache.read("loc:en", as: [String: String].self)
        XCTAssertEqual(entry?.value, ["a": "b"])
        XCTAssertLessThan(entry!.age(), 5)
        // A type mismatch is a miss, not a crash.
        let mismatch = await cache.read("loc:en", as: Int.self)
        XCTAssertNil(mismatch)
    }

    // MARK: Customers lookup (M6.5)

    func testCustomerSearchDecode_isProjectScoped_andPostsWithCsrf() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"customers":[{"id":7,"email":"ada@example.test","name":"Ada"},
                          {"id":8,"email":"grace@example.test","name":null}],
             "truncated":true}
            """#)
        }
        let page = try await client.customers.search(project: "acme", query: "a")
        // A POST search is project-scoped AND CSRF-guarded (the query rides the body, never the URL).
        let last = StubURLProtocol.requests().last
        XCTAssertEqual(last?.httpMethod, "POST")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertNotNil(header(StubURLProtocol.requests(), "X-Requested-With"))
        XCTAssertTrue(page.truncated)
        XCTAssertEqual(page.customers.map(\.id), [7, 8])
        XCTAssertEqual(page.customers[0].name, "Ada")
        XCTAssertNil(page.customers[1].name)
    }

    func testCustomerDetailDecode_liveStateWithTypedMetaAndMaskedLicense() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"id":7,"state":"live","email":"ada@example.test","name":"Ada",
             "createdAt":"2026-01-02T03:04:05Z","mergedIntoCustomerId":null,
             "entitlements":[{"feature":"pro.export","limit":5,"validUntil":null,"source":"license"}],
             "recentActivity":[
               {"occurredAt":"2026-07-01T10:00:00Z","kind":"licenseIssued",
                "meta":{"currency":null,"amountCents":null,"resolved":null,"maskedLicenseSuffix":"•••ABCD","trialVariant":null}},
               {"occurredAt":"2026-06-01T10:00:00Z","kind":"somethingNew","meta":null}],
             "activityTruncated":true,"nextCursor":"abc"}
            """#)
        }
        let detail = try await client.customers.detail(project: "acme", id: 7)
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertEqual(detail.state, "live")
        XCTAssertEqual(detail.email, "ada@example.test")
        XCTAssertNil(detail.mergedIntoCustomerId)
        XCTAssertEqual(detail.entitlements.first?.feature, "pro.export")
        XCTAssertNil(detail.entitlements.first?.validUntil, "null validUntil = non-expiring, never a fake date")
        XCTAssertEqual(detail.recentActivity[0].meta?.maskedLicenseSuffix, "•••ABCD")
        XCTAssertNil(detail.recentActivity[1].meta, "an unknown kind carries nil meta")
        XCTAssertTrue(detail.activityTruncated)
        XCTAssertEqual(detail.nextCursor, "abc")
    }

    func testCustomerDetailMergedState_hasNullIdentityAndSurvivorPointer() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"id":8,"state":"merged","email":null,"name":null,"createdAt":"2026-01-02T03:04:05Z",
             "mergedIntoCustomerId":7,"entitlements":[],"recentActivity":[],"activityTruncated":false,"nextCursor":null}
            """#)
        }
        let detail = try await client.customers.detail(project: "acme", id: 8)
        XCTAssertEqual(detail.state, "merged")
        XCTAssertNil(detail.email)
        XCTAssertEqual(detail.mergedIntoCustomerId, 7)
        XCTAssertTrue(detail.entitlements.isEmpty)
        XCTAssertTrue(detail.recentActivity.isEmpty)
    }

    func testCustomerActivityEmptyPageIsNotAnError() async throws {
        let client = makeClient { _ in stubJSON(200, #"{"items":[],"nextCursor":null}"#) }
        let page = try await client.customers.activity(project: "acme", id: 7, cursor: "c")
        XCTAssertTrue(page.items.isEmpty)
        XCTAssertNil(page.nextCursor)
    }

    /// Missing `commerce.view` (or the module disabled) → 403 must map to the shared taxonomy like every façade.
    func testCustomerSearchForbiddenMapsTaxonomy() async throws {
        let client = makeClient { _ in stubJSON(403, #"{"title":"Forbidden","detail":"commerce.view required"}"#) }
        await assertThrows(try await client.customers.search(project: "acme", query: "a")) { error in
            guard case let .forbidden(problem) = error else { return XCTFail("expected .forbidden, got \(error)") }
            XCTAssertEqual(problem?.detail, "commerce.view required")
        }
    }

    // MARK: My Tasks (M6.2)

    func testMyTasksDecode_isAccountLevel_withNoProjectSlug() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"tasks":[
               {"id":5,"projectSlug":"acme","projectName":"Acme","title":"ship it","status":"todo",
                "priority":"high","dueDate":"2026-08-01","createdAt":"2026-07-20T10:00:00Z",
                "canComplete":true,"context":{"kind":"review","id":"9876543210"}},
               {"id":6,"projectSlug":"beta","projectName":"Beta","title":"no due","status":"doing",
                "priority":"low","dueDate":null,"createdAt":"2026-07-19T10:00:00Z",
                "canComplete":false,"context":null}],
             "truncated":false,"partial":false,"failedProjects":[],"omittedProjects":0}
            """#)
        }
        let page = try await client.tasks.myTasks()
        // Account-level: a cross-project read carries NO X-Project-Slug (mirrors the inbox) and, being a GET,
        // no CSRF header.
        XCTAssertNil(header(StubURLProtocol.requests(), "X-Project-Slug"))
        XCTAssertNil(header(StubURLProtocol.requests(), "X-Requested-With"))
        XCTAssertEqual(header(StubURLProtocol.requests(), "Authorization"), "Bearer bws_pat_test.secret")
        XCTAssertEqual(page.tasks.map(\.id), [5, 6])
        // dueDate is a bare calendar date STRING (never an instant); context is the {kind,id} token or nil.
        XCTAssertEqual(page.tasks[0].dueDate, "2026-08-01")
        XCTAssertEqual(page.tasks[0].context?.kind, "review")
        XCTAssertEqual(page.tasks[0].context?.id, "9876543210")
        XCTAssertNil(page.tasks[1].dueDate)
        XCTAssertNil(page.tasks[1].context)
        XCTAssertEqual(page.tasks[0].rowKey, "acme:5") // composite row identity
    }

    func testCompleteIsProjectScoped_installsTheRowsSlugPerCall_andNeverSharesState() async throws {
        // The complete write is project-scoped transport: the slug is a PER-CALL argument, so two completions on
        // DIFFERENT projects each carry their OWN slug — there is no shared "selected project" the SDK mutates.
        let client = makeClient { _ in
            stubJSON(200, #"{"id":5,"status":"done","completedAt":"2026-07-21T09:00:00Z"}"#)
        }
        _ = try await client.tasks.complete(project: "acme", id: 5)
        var last = StubURLProtocol.requests().last
        XCTAssertEqual(last?.httpMethod, "POST")
        XCTAssertEqual(last?.url?.path, "/api/v1/todo/tasks/5/complete")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertNotNil(header(StubURLProtocol.requests(), "X-Requested-With")) // CSRF on the unsafe write

        // A second complete on a DIFFERENT project (through the SAME client) installs THAT slug — never "acme".
        _ = try await client.tasks.complete(project: "beta", id: 9)
        last = StubURLProtocol.requests().last
        XCTAssertEqual(last?.url?.path, "/api/v1/todo/tasks/9/complete")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "beta")
    }

    // MARK: Changelog review + publish/unpublish (M6.6a)

    func testChangelogListDecode_isProjectScoped_andReadCarriesNoCsrf() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"items":[
              {"id":7,"version":"1.2.3","title":"New","publishedAt":"2026-07-20T10:00:00+00:00",
               "updatedAt":"2026-07-20T11:00:00+00:00","hasTranslations":true},
              {"id":8,"version":"1.2.4","title":"Draft","publishedAt":null,
               "updatedAt":"2026-07-20T12:00:00+00:00","hasTranslations":false}],
             "truncated":false}
            """#)
        }
        let resp = try await client.changelog.list(project: "acme")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertNil(header(StubURLProtocol.requests(), "X-Requested-With"), "a GET must not carry the CSRF header")
        XCTAssertFalse(resp.truncated)
        XCTAssertEqual(resp.items.map(\.id), [7, 8])
        XCTAssertNotNil(resp.items[0].publishedAt)
        XCTAssertNil(resp.items[1].publishedAt, "a draft row has no publishedAt")
        XCTAssertTrue(resp.items[0].hasTranslations)
    }

    func testChangelogDetailDecode_includesTranslations_andOversizedFlag() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"id":7,"version":"1.2.3","title":"New","body":"Body text.",
             "publishedAt":null,"firstPublishedAt":null,"updatedAt":"2026-07-20T11:00:00+00:00",
             "publicId":"b519c1c7-817f-39b1-a7ad-53b75f2579c0",
             "translations":[{"lang":"de","title":"Titel","body":"Body DE"}],
             "oversizedWebOnly":false}
            """#)
        }
        let d = try await client.changelog.detail(project: "acme", id: 7)
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertEqual(d.body, "Body text.")
        XCTAssertEqual(d.publicId, "b519c1c7-817f-39b1-a7ad-53b75f2579c0")
        XCTAssertFalse(d.oversizedWebOnly)
        XCTAssertEqual(d.translations.map(\.lang), ["de"])
        XCTAssertEqual(d.translations[0].body, "Body DE")
    }

    func testChangelogPublish_carriesCsrf_andDecodesFirstPublish() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"{"id":7,"publishedAt":"2026-07-20T10:00:00+00:00","updatedAt":"2026-07-20T10:00:00+00:00","firstPublish":true}"#)
        }
        let r = try await client.changelog.publish(project: "acme", id: 7)
        let last = StubURLProtocol.requests().last
        XCTAssertEqual(last?.httpMethod, "POST")
        XCTAssertEqual(last?.url?.path, "/api/v1/changelog/mobile/7/publish")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Requested-With"), "BytewiseOperatorKit") // unsafe → CSRF
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertTrue(r.firstPublish)
    }

    func testChangelogPublishOversized400_mapsToValidation() async throws {
        let client = makeClient { _ in stubJSON(400, #"{"title":"too large","detail":"review on web"}"#) }
        await assertThrows(try await client.changelog.publish(project: "acme", id: 7)) { error in
            guard case let .validation(status, _) = error else { return XCTFail("expected .validation, got \(error)") }
            XCTAssertEqual(status, 400)
        }
    }

    func testChangelogUnpublish_carriesCsrf_andClearsPublishedAt() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"{"id":7,"publishedAt":null,"updatedAt":"2026-07-20T13:00:00+00:00"}"#)
        }
        let r = try await client.changelog.unpublish(project: "beta", id: 7)
        let last = StubURLProtocol.requests().last
        XCTAssertEqual(last?.url?.path, "/api/v1/changelog/mobile/7/unpublish")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Requested-With"), "BytewiseOperatorKit")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "beta")
        XCTAssertNil(r.publishedAt)
    }

    // MARK: Roadmap board + review + triage (M6.6b)

    func testRoadmapBoardDecode_isProjectScoped_lanesAndSortOrder() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"lanes":[
              {"lane":"consideration","items":[]},
              {"lane":"planned","items":[
                {"id":5,"title":"Dark mode","visibility":"public","sortOrder":0},
                {"id":6,"title":"Secret","visibility":"internal","sortOrder":1}]},
              {"lane":"inprogress","items":[]},
              {"lane":"done","items":[]}],
             "oversized":false}
            """#)
        }
        let board = try await client.roadmap.board(project: "acme")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertNil(header(StubURLProtocol.requests(), "X-Requested-With"), "a GET must not carry the CSRF header")
        XCTAssertFalse(board.oversized)
        XCTAssertEqual(board.lanes.map(\.lane), ["consideration", "planned", "inprogress", "done"])
        let planned = board.lanes.first { $0.lane == "planned" }!
        XCTAssertEqual(planned.items.map(\.id), [5, 6])
        XCTAssertEqual(planned.items[0].sortOrder, 0)
        XCTAssertEqual(planned.items[1].visibility, "internal") // operator view carries internal cards
    }

    func testRoadmapDetailDecode_platformsAndTranslations() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"""
            {"id":12,"title":"Dark mode","description":"Ship it.","lane":"planned","visibility":"public",
             "platforms":["web","ios"],
             "translations":[{"lang":"de","title":"Dunkelmodus","description":null}]}
            """#)
        }
        let d = try await client.roadmap.detail(project: "acme", id: 12)
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertEqual(d.platforms, ["web", "ios"])
        XCTAssertEqual(d.translations.map(\.lang), ["de"])
        XCTAssertNil(d.translations[0].description, "a null translation description decodes as nil")
    }

    func testRoadmapTriage_carriesCsrf_andDecodesCanonicalSortOrder() async throws {
        let client = makeClient { _ in
            stubJSON(200, #"{"id":12,"lane":"done","visibility":"public","sortOrder":4,"changed":true}"#)
        }
        let r = try await client.roadmap.triage(project: "acme", id: 12, lane: "done")
        let last = StubURLProtocol.requests().last
        XCTAssertEqual(last?.httpMethod, "POST")
        XCTAssertEqual(last?.url?.path, "/api/v1/roadmap/mobile/12/triage")
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Requested-With"), "BytewiseOperatorKit") // unsafe → CSRF
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
        XCTAssertTrue(r.changed)
        XCTAssertEqual(r.lane, "done")
        XCTAssertEqual(r.sortOrder, 4)
    }

    func testRoadmapTriageForbiddenMapsTaxonomy() async throws {
        let client = makeClient { _ in stubJSON(403, #"{"title":"Forbidden","detail":"roadmap.curate required"}"#) }
        await assertThrows(try await client.roadmap.triage(project: "acme", id: 12, visibility: "public")) { error in
            guard case let .forbidden(problem) = error else { return XCTFail("expected .forbidden, got \(error)") }
            XCTAssertEqual(problem?.detail, "roadmap.curate required")
        }
    }

    // MARK: Feature-flag kill-switch (M6.4)

    func testFlagListDecodes_andIsProjectScoped() async throws {
        let client = makeClient { _ in stubJSON(200, #"""
            {"flags":[
              {"key":"aa","name":"A","description":null,"flagType":"boolean","enabled":true,"killed":false,
               "killedAt":null,"rolloutBasisPoints":10000,"ruleCount":0,"updatedAt":"2026-07-21T10:00:00+00:00","rowVersion":"AAAAAAAAB9E="},
              {"key":"zz","name":"Z","description":"d","flagType":"variant","enabled":true,"killed":true,
               "killedAt":"2026-07-21T09:30:00+00:00","rolloutBasisPoints":5000,"ruleCount":2,"updatedAt":"2026-07-21T10:00:00+00:00","rowVersion":"AAAAAAAAB9I="}
            ],"truncated":false}
            """#) }
        let resp = try await client.flags.list(project: "acme")
        XCTAssertEqual(resp.flags.map(\.key), ["aa", "zz"])         // SERVER order preserved
        XCTAssertFalse(resp.truncated)
        XCTAssertEqual(resp.flags[1].ruleCount, 2)
        XCTAssertTrue(resp.flags[1].killed)
        XCTAssertNotNil(resp.flags[1].killedAt)
        XCTAssertEqual(header(StubURLProtocol.requests(), "X-Project-Slug"), "acme")
    }

    func testFlagKillStaleSurfacesTypedConflictNotValidation() async throws {
        // The mobile contract models only success bodies, so the 409 arrives undocumented; the flag-kill
        // mapping decodes it into the DISTINGUISHABLE `.conflict` carrying the server's CURRENT state.
        let client = makeClient { _ in stubJSON(409,
            #"{"key":"checkout","killed":true,"killedAt":"2026-07-21T09:30:00+00:00","rowVersion":"AAAAAAAAB9I="}"#) }
        await assertThrows(try await client.flags.kill(project: "acme", key: "checkout", ifMatch: "AAAAAAAAB9E=")) { error in
            guard case let .conflict(c) = error else { return XCTFail("expected .conflict, got \(error)") }
            XCTAssertEqual(c.key, "checkout")
            XCTAssertTrue(c.killed)                                 // the current state, so a reconcile is possible
            XCTAssertEqual(c.rowVersion, "AAAAAAAAB9I=")
            XCTAssertEqual(error.statusCode, 409)
        }
    }

    func testKillSendsQuotedIfMatchAndCsrf() async throws {
        // F5-09 drift-correction: the operator-mobile FlagKillResult schema had already gained the required
        // `diff` (before/after FlagServeState) + `projectId` on the committed contract, but the generated
        // transport was stale until regenerate.sh was re-run for the Links surface — so the success body now
        // carries those required fields.
        let client = makeClient { _ in stubJSON(200,
            #"{"key":"checkout","killed":true,"killedAt":"2026-07-21T09:30:00+00:00","rowVersion":"AAAAAAAAB9I=","projectId":7,"diff":{"flag":"checkout","killed":true,"projectId":7,"before":{"enabled":true,"killed":false,"rolloutBasisPoints":10000,"ruleCount":0,"servesOffToEveryone":false},"after":{"enabled":true,"killed":true,"rolloutBasisPoints":10000,"ruleCount":0,"servesOffToEveryone":true}}}"#) }
        let result = try await client.flags.kill(project: "acme", key: "checkout", ifMatch: "AAAAAAAAB9E=")
        XCTAssertTrue(result.killed)
        let reqs = StubURLProtocol.requests()
        // swift-openapi serializes the header value with RFC 6570 simple-style expansion, which percent-encodes
        // the reserved chars (`"`→%22, `=`→%3D); the server percent-decodes before trimming the quotes. Assert
        // the DECODED intent so the quoted-strong-validator contract is pinned regardless of the wire escaping.
        XCTAssertEqual(header(reqs, "If-Match")?.removingPercentEncoding, "\"AAAAAAAAB9E=\"")
        XCTAssertEqual(header(reqs, "X-Requested-With"), OperatorAuthMiddleware.requestedWithValue)
    }

    func testKillIsSingleWireAttemptUnderDisconnect() async throws {
        // One explicit kill() under a transport failure must produce AT MOST ONE wire request — the mutation
        // is single-attempt (no SDK/transport auto-retry that could fire a kill twice).
        let client = makeClient { _ in Stub(status: 0, headers: [:], body: Data(),
                                            failure: URLError(.networkConnectionLost)) }
        await assertThrows(try await client.flags.kill(project: "acme", key: "checkout", ifMatch: "AAAAAAAAB9E=")) { error in
            guard case .transport = error else { return XCTFail("expected .transport, got \(error)") }
        }
        XCTAssertEqual(StubURLProtocol.requests().count, 1, "a failed kill must not be auto-retried")
    }

    // MARK: helper

    private func assertThrows(_ expression: @autoclosure () async throws -> some Any,
                              _ verify: (BytewiseOperatorError) -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await expression()
            XCTFail("expected a BytewiseOperatorError to be thrown", file: file, line: line)
        } catch let error as BytewiseOperatorError {
            verify(error)
        } catch {
            XCTFail("expected BytewiseOperatorError, got \(error)", file: file, line: line)
        }
    }
}
