import Foundation
import OpenAPIRuntime

// The per-domain façades — the only public API for making calls. Each maps the internal generated
// transport types to the stable public models and the single error taxonomy. `X-Project-Slug` is
// set here on project-scoped ops; `X-Requested-With` on unsafe methods is set both here (the
// generated header is required) and defensively by the auth middleware; `Authorization: Bearer` is
// injected centrally by the middleware.

private let requestedWith = OperatorAuthMiddleware.requestedWithValue

/// Overview tab.
public struct DashboardFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /dashboard/summary` — the project's stat tiles.
    public func summary(project: String) async throws -> DashboardSummaryResponse {
        let out = try await run { try await api.dashboardSummary(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /dashboard/portfolio` — cross-project cards (account-level).
    public func portfolio() async throws -> PortfolioResponse {
        let out = try await run { try await api.dashboardPortfolio(.init()) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /bootstrap` — the single cold-start read (me + projects + per-project modules/analytics).
    public func bootstrap() async throws -> BootstrapResponse {
        let out = try await run { try await api.operatorBootstrap(.init()) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /nav` — permission-filtered navigation entries for a project.
    public func nav(project: String) async throws -> [NavEntryResponse] {
        let out = try await run { try await api.navGet(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return p.map(NavEntryResponse.init) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Crashes tab (analytics issues, human triage, releases, alert settings).
public struct CrashesFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /analytics/issues`.
    public func issues(project: String) async throws -> AnalyticsIssuesResponse {
        let out = try await run { try await api.analyticsIssueList(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /analytics/issues/{externalId}/detail`.
    public func issueDetail(project: String, externalId: String) async throws -> AnalyticsIssueDetailResponse {
        let out = try await run {
            try await api.analyticsIssueDetail(.init(path: .init(externalId: externalId),
                                                     headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /analytics/issues/{externalId}/triage` — HUMAN triage (status/severity/notes). The AI
    /// triage path (`ai.use`) is deliberately out of the mobile contract.
    public func triageIssue(project: String, externalId: String,
                            status: String? = nil, severity: String? = nil, notes: String? = nil)
        async throws -> AnalyticsTriageResponse {
        let out = try await run {
            try await api.analyticsIssueTriage(.init(
                path: .init(externalId: externalId),
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(notes: notes, severity: severity, status: status))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /analytics/releases`.
    public func releases(project: String) async throws -> AnalyticsReleasesResponse {
        let out = try await run { try await api.analyticsReleaseList(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /analytics/apps/{appId}/symbols` — exact stored-artifact read-back. This GET is deliberately
    /// `analytics.configure`-gated; `verifyStoredBytes` requires the complete identity filters and makes
    /// the server re-read and hash the selected blob before returning success.
    public func symbols(project: String, appId: String,
                        kind: String? = nil, limit: Int32? = nil,
                        debugId: String? = nil, architecture: String? = nil,
                        imageName: String? = nil, verifyStoredBytes: Bool? = nil)
        async throws -> AnalyticsSymbolArtifactsResponse {
        let out = try await run {
            try await api.analyticsSymbolArtifactList(.init(
                path: .init(appId: appId),
                query: .init(architecture: architecture, debugId: debugId, imageName: imageName,
                             kind: kind, limit: limit, verifyStoredBytes: verifyStoredBytes),
                headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /analytics/alerts` — the crash-alert digest setting.
    public func alerts(project: String) async throws -> AnalyticsAlertsResponse {
        let out = try await run { try await api.analyticsAlertsGet(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /analytics/alerts` — enable/disable the crash-alert digest.
    public func setAlerts(project: String, enabled: Bool) async throws -> AnalyticsAlertsToggleResponse {
        let out = try await run {
            try await api.analyticsAlertsSet(.init(
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(enabled: enabled))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /analytics/alerts/rearm` — re-arm the crash alert (optionally set the re-arm window).
    public func rearmAlerts(project: String, crashReArmDays: Int32? = nil) async throws -> AnalyticsAlertsResponse {
        let out = try await run {
            try await api.analyticsAlertsRearm(.init(
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(crashReArmDays: crashReArmDays))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Feedback tab.
public struct FeedbackFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /feedback` — filterable list.
    /// F-A5: a keyset PAGE, not the whole list. Pass `cursor` from the previous page's `nextCursor`
    /// to continue; a nil `nextCursor` means the stream is exhausted. Before F-A5 this returned the
    /// newest 500 rows as a bare array and cut there silently, so a project with more feedback than
    /// that could not reach its own data from the app.
    public func list(project: String, assignedTo: Int32? = nil, category: String? = nil,
                     state: String? = nil, status: String? = nil,
                     cursor: String? = nil, take: Int32? = nil) async throws -> FeedbackPage {
        let out = try await run {
            try await api.feedbackList(.init(
                query: .init(assignedTo: assignedTo, category: category, cursor: cursor,
                             state: state, status: status, take: take),
                headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /feedback/{id}/triage-set` — HUMAN triage (status/category/assignment/notes).
    public func triageSet(project: String, id: Int32, status: String? = nil, category: String? = nil,
                          assignedUserId: Int32? = nil, adminNotes: String? = nil)
        async throws -> FeedbackTriageStateResponse {
        let out = try await run {
            try await api.feedbackTriageSet(.init(
                path: .init(id: id),
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(adminNotes: adminNotes, assignedUserId: assignedUserId,
                                  category: category, status: status))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /feedback/{id}/resolve`.
    public func resolve(project: String, id: Int32) async throws -> FeedbackStateResponse {
        let out = try await run {
            try await api.feedbackResolve(.init(path: .init(id: id),
                                                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /feedback/{id}/reopen`.
    public func reopen(project: String, id: Int32) async throws -> FeedbackStateResponse {
        let out = try await run {
            try await api.feedbackReopen(.init(path: .init(id: id),
                                               headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /feedback/{id}/replies`.
    public func replies(project: String, id: Int32) async throws -> [FeedbackReplyListItemResponse] {
        let out = try await run {
            try await api.feedbackReplyList(.init(path: .init(id: id), headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return p.map(FeedbackReplyListItemResponse.init) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /feedback/{id}/reply` — send an operator reply.
    public func reply(project: String, id: Int32, body: String) async throws -> FeedbackReplySendResponse {
        let out = try await run {
            try await api.feedbackReplySend(.init(
                path: .init(id: id),
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(body: body))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Revenue tab.
public struct RevenueFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /commerce/revenue`.
    public func commerce(project: String) async throws -> CommerceRevenueResponse {
        let out = try await run { try await api.commerceRevenue(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /stores/revenue` — optional `days` window.
    public func stores(project: String, days: Int32? = nil) async throws -> StoresRevenueResponse {
        let out = try await run {
            try await api.storesRevenue(.init(query: .init(days: days), headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /stores/vitals` — crash/ANR vitals for a specific store `appId`.
    public func vitals(project: String, appId: Int32) async throws -> StoresVitalsResponse {
        let out = try await run {
            try await api.storesVitals(.init(query: .init(appId: appId), headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /stores/vitals/apps` — the bounded selector that supplies `vitals(project:appId:)`'s required
    /// `appId`. Only vitals-ELIGIBLE apps are listed (Google Play + enabled), filtered server-side, so the
    /// caller must not re-filter by provider. `truncated` means more eligible apps exist than the server cap —
    /// surface it, or those apps are silently unreachable.
    public func vitalsApps(project: String) async throws -> StoresVitalsAppsResponse {
        let out = try await run { try await api.storesVitalsApps(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Account: identity, projects, push devices.
public struct AccountFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /auth/me`.
    public func me() async throws -> OperatorMeResponse {
        let out = try await run { try await api.authMe(.init()) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /projects/mine`.
    public func projects() async throws -> [MyProjectResponse] {
        let out = try await run { try await api.projectsMine(.init()) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return p.map(MyProjectResponse.init) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /account/push-devices` — this operator's registered devices.
    public func pushDevices() async throws -> [PushDeviceListItemResponse] {
        let out = try await run { try await api.pushListDevices(.init()) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return p.map(PushDeviceListItemResponse.init) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /account/push-devices` — register (or refresh) this installation's APNs/FCM token.
    public func registerPushDevice(token: String, platform: String, bundleId: String? = nil)
        async throws -> PushDeviceRegisterResponse {
        let out = try await run {
            try await api.pushRegisterDevice(.init(
                headers: .init(xRequestedWith: requestedWith),
                body: .json(.init(bundleId: bundleId, platform: platform, token: token))))
        }
        // Register returns 200 (refreshed existing) or 201 (new) — both carry the same payload.
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .created(let created): switch created.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `DELETE /account/push-devices/{id}` — unregister on logout/rotation (tolerate offline failure).
    public func removePushDevice(id: Int32) async throws -> PushDeviceRemoveResponse {
        let out = try await run {
            try await api.pushUnregisterDevice(.init(path: .init(id: id),
                                                     headers: .init(xRequestedWith: requestedWith)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `DELETE /auth/mobile-pairing/self` — revoke the CALLING mobile-companion token on logout, so a
    /// discarded credential does not linger for its ≤90-day lifetime. Best-effort: the app MUST still wipe
    /// local credential state even if this call fails offline (the token then lapses at its mandatory expiry).
    public func revokeSelf() async throws -> MobileSelfRevokeResponse {
        let out = try await run {
            try await api.mobilePairingRevokeSelf(.init(headers: .init(xRequestedWith: requestedWith)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Onboarding: exchange a pairing code for a mobile PAT. Runs WITHOUT a credential.
public struct PairingFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `POST /auth/mobile-pairing/exchange` — anonymous; returns the minted PAT ONCE.
    public func exchange(code: String) async throws -> MobilePairingExchangeResponse {
        let out = try await run { try await api.mobilePairingExchange(.init(body: .json(.init(code: code)))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Feature-request management (FeatureBoard): list + moderation actions. The list requires
/// `featureboard.view`; every other operation requires `featureboard.moderate`.
public struct FeatureBoardFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /featureboard` — operator list, optionally filtered by status/search (and soft-deleted rows).
    ///
    /// F-A5: a keyset PAGE ordered by votes, not the whole board. Pass `cursor` from the previous
    /// page's `nextCursor` to continue; a nil `nextCursor` means the stream is exhausted. Before
    /// F-A5 this took the top 500 by votes as a bare array and cut there silently.
    public func list(project: String, status: String? = nil, search: String? = nil,
                     includeDeleted: Bool? = nil,
                     cursor: String? = nil, take: Int32? = nil) async throws -> FeatureBoardPage {
        let out = try await run {
            try await api.featureBoardOperatorList(.init(
                query: .init(cursor: cursor, includeDeleted: includeDeleted,
                             search: search, status: status, take: take),
                headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /featureboard/features/quarantined` — the spam-quarantine queue (`featureboard.moderate`).
    public func quarantined(project: String) async throws -> [QuarantinedFeature] {
        let out = try await run { try await api.featureBoardQuarantined(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return p.map(QuarantinedFeature.init) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /featureboard/features/{id}/status` — change a feature's workflow status.
    public func changeStatus(project: String, id: Int32, status: String) async throws -> FeatureBoardStatusResult {
        let out = try await run {
            try await api.featureBoardChangeStatus(.init(
                path: .init(id: id),
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(status: status))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /featureboard/features/{id}/lock` — lock (or unlock) voting/commenting on a feature.
    public func setLocked(project: String, id: Int32, locked: Bool) async throws -> FeatureBoardLockResult {
        let out = try await run {
            try await api.featureBoardLock(.init(
                path: .init(id: id),
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(locked: locked))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /featureboard/features/{id}/release` — release a quarantined feature onto the board.
    public func release(project: String, id: Int32) async throws -> FeatureBoardReleaseResult {
        let out = try await run {
            try await api.featureBoardRelease(.init(path: .init(id: id),
                                                    headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /featureboard/features/{id}/reject` — reject (delete) a quarantined feature. Irreversible;
    /// gate behind an explicit confirm in the UI.
    public func reject(project: String, id: Int32) async throws -> FeatureBoardRejectResult {
        let out = try await run {
            try await api.featureBoardReject(.init(path: .init(id: id),
                                                   headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    // ── comment moderation (the mobile comment strip, F5-10) ──────────────────────────────────────────
    // The triage READ needs `featureboard.view`; every write (reply/hide/release/reject) + the comment
    // quarantine queue need `featureboard.moderate`. Gate the write actions in the UI on the operator's
    // Moderate permission — the server enforces it regardless, but a viewer must not be offered them.

    /// `GET /featureboard/features/{id}/comments/all` — the operator triage thread for one feature, oldest-first,
    /// INCLUDING tombstoned rows (so the strip can show what was hidden). Held rows never appear here — they live
    /// in `quarantinedComments`. Requires `featureboard.view`.
    public func comments(project: String, featureId: Int32, page: Int32? = nil,
                         pageSize: Int32? = nil) async throws -> FeatureBoardOperatorCommentPage {
        let out = try await run {
            try await api.featureBoardOperatorComments(.init(
                path: .init(id: featureId),
                query: .init(page: page, pageSize: pageSize),
                headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /featureboard/features/{id}/reply` — post the team's public reply on a feature's thread. Requires
    /// `featureboard.moderate`.
    public func reply(project: String, featureId: Int32, body: String) async throws -> FeatureBoardOperatorComment {
        let out = try await run {
            try await api.featureBoardOperatorReply(.init(
                path: .init(id: featureId),
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(body: body))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /featureboard/comments/{id}/hide` — tombstone a published comment. Idempotent. Requires
    /// `featureboard.moderate`.
    public func hideComment(project: String, commentId: Int32) async throws -> FeatureBoardCommentHideResult {
        let out = try await run {
            try await api.featureBoardCommentHide(.init(path: .init(id: commentId),
                                                        headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /featureboard/comments/quarantined` — the held-comment review queue, newest-first, with each row's
    /// parent request + the AI's reason. Requires `featureboard.moderate`.
    public func quarantinedComments(project: String) async throws -> FeatureBoardQuarantinedComments {
        let out = try await run { try await api.featureBoardQuarantinedComments(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /featureboard/comments/{id}/release` — publish a held comment. Idempotent. Requires
    /// `featureboard.moderate`.
    public func releaseComment(project: String, commentId: Int32) async throws -> FeatureBoardCommentReleaseResult {
        let out = try await run {
            try await api.featureBoardCommentRelease(.init(path: .init(id: commentId),
                                                           headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /featureboard/comments/{id}/reject` — reject a held comment as spam (tombstone it). Idempotent;
    /// gate behind an explicit confirm in the UI. Requires `featureboard.moderate`.
    public func rejectComment(project: String, commentId: Int32) async throws -> FeatureBoardCommentRejectResult {
        let out = try await run {
            try await api.featureBoardCommentReject(.init(path: .init(id: commentId),
                                                          headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// License-abuse signals (read-only on the companion app). The list requires `abuse.read` AND
/// `licenses.view` with both the abuse and licenses modules enabled — the same conjunctive cross-module gate
/// the web abuse surface enforces. Read-only in v1: no triage/remediate.
public struct AbuseFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /abuse/signals-mobile` — the bounded, SubjectKey-free persisted-signal list for a project
    /// (`truncated` ⇒ more signals exist than the server cap; rows are in server order).
    public func list(project: String) async throws -> AbuseSignalListResponse {
        let out = try await run { try await api.abuseSignalList(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Store reviews (read-only on the companion app; M5.3). Both reads require `stores.view` with the stores
/// module enabled. Read-only in v1: the reply/retry/draft writes are DEFERRED and are NOT exposed here.
public struct StoresReviewsFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /stores/reviews-mobile` — the bounded, PII-safe review SUMMARY list (optional `appId` filter).
    /// `truncated` ⇒ more reviews exist than the server cap; rows are in server order (effective time desc).
    /// The summary carries NO body / reply text / external id — those live in `detail`.
    public func list(project: String, appId: Int32? = nil) async throws -> StoreReviewSummaryResponse {
        let out = try await run {
            try await api.storesReviewList(.init(query: .init(appId: appId), headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /stores/reviews-mobile/{id}` — the honest full review DETAIL by id (always reachable, even for a
    /// review outside the capped summary list). A 404 surfaces as `BytewiseOperatorError.notFound`.
    public func detail(project: String, id: Int64) async throws -> StoreReviewDetailResponse {
        let out = try await run {
            try await api.storesReviewDetail(.init(path: .init(id: id), headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Changelog review + publish/unpublish (Wave M / M6.6a). Reads require `changelog.read`; publish/unpublish
/// require `changelog.write`, with the changelog module enabled. Publishing is CUSTOMER-FACING (it exposes the
/// entry on the public page + Atom feed + embed + mobile public read), so the detail is the full review picture
/// and an oversized entry is web-only (its publish 400s). All four ops take the project slug per call.
public struct ChangelogFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /changelog/mobile` — the body-free LIST picker in server order (CreatedAt DESC). `truncated` ⇒
    /// more entries exist than the server cap.
    public func list(project: String) async throws -> ChangelogMobileListResponse {
        let out = try await run {
            try await api.changelogMobileList(.init(headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /changelog/mobile/{id}` — the REVIEW read: base title/body PLUS the translation variants publishing
    /// exposes. `oversizedWebOnly` ⇒ the body/bodies came back blank and publish will be refused. 404 ⇒ `.notFound`.
    public func detail(project: String, id: Int32) async throws -> ChangelogMobileDetail {
        let out = try await run {
            try await api.changelogMobileDetail(.init(path: .init(id: id), headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /changelog/mobile/{id}/publish` — the customer-facing publish. `firstPublish` distinguishes the
    /// first publish (webhook + newsletter fire once) from a republish. An oversized entry 400s (surfaces as
    /// `BytewiseOperatorError.validation`); it is idempotent, so never blind-retry — refresh + resend.
    public func publish(project: String, id: Int32) async throws -> ChangelogPublishResult {
        let out = try await run {
            try await api.changelogMobilePublish(.init(
                path: .init(id: id), headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /changelog/mobile/{id}/unpublish` — hide the entry (reversible visibility; external copies may
    /// persist). Idempotent.
    public func unpublish(project: String, id: Int32) async throws -> ChangelogUnpublishResult {
        let out = try await run {
            try await api.changelogMobileUnpublish(.init(
                path: .init(id: id), headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Roadmap board + review + narrow triage (Wave M / M6.6b). The reads require `roadmap.view`; triage
/// (lane-change + visibility toggle) requires `roadmap.curate` (Owner/Admin only), with the roadmap module
/// enabled. Triage is CUSTOMER-FACING when it makes an item Public (or moves an already-Public item), so the
/// UI reviews the detail (what becomes public) before writing. Item title/description/platforms editing and
/// drag-REORDER stay web. All three ops take the project slug per call.
public struct RoadmapFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /roadmap/mobile` — the lane-grouped BOARD (both Internal + Public cards, the operator view).
    /// `oversized` ⇒ the board exceeds the per-project ceiling and is not complete / not reorder-ready.
    public func board(project: String) async throws -> RoadmapMobileBoard {
        let out = try await run { try await api.roadmapMobileBoard(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /roadmap/mobile/{id}` — the "review what becomes public" DETAIL: base title/description, resolved
    /// platforms, lane + visibility, and the localized variants. A 404 surfaces as `BytewiseOperatorError.notFound`.
    public func detail(project: String, id: Int32) async throws -> RoadmapMobileDetail {
        let out = try await run {
            try await api.roadmapMobileDetail(.init(path: .init(id: id), headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /roadmap/mobile/{id}/triage` — the narrow lane/visibility write (at least one of `lane`/`visibility`;
    /// NEVER title/description/platforms). Returns the canonical `sortOrder` to place the card in place; `changed`
    /// false ⇒ an idempotent no-op. Idempotent, so never blind-retry — re-read before any resend.
    public func triage(project: String, id: Int32, lane: String? = nil, visibility: String? = nil)
        async throws -> RoadmapTriageResult {
        let out = try await run {
            try await api.roadmapMobileTriage(.init(
                path: .init(id: id),
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(lane: lane, visibility: visibility))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Curated per-project links directory (F5-09): the operator browsing a project's external tool links
/// (Stripe/SendGrid/Cloudflare dashboards, …) from their phone. READ-ONLY — create/edit/delete stay on
/// the web manage surface. Project-scoped; the list requires `links.view`.
public struct LinksFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /links/mobile` — the category-grouped directory (categories alphabetical; links in SortOrder).
    /// `truncated` ⇒ the project exceeds the per-project item ceiling: the directory is NOT complete
    /// (surface it — the client renders what arrived and says so).
    public func list(project: String) async throws -> LinksMobileDirectory {
        let out = try await run { try await api.linksMobileList(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Read-only customer lookup for support (M6.5): a PII-safe POST search, a folded detail with an explicit
/// live/merged/erased state model, and cursor-paged older activity. Project-scoped; `commerce.view`.
public struct CustomersFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `POST /commerce/customers-mobile/search` — substring search on email OR name. The query rides the
    /// request BODY (never the URL) so customer PII is not logged in a query string. A blank/nil query returns
    /// the most-recent N; `truncated` ⇒ more matches than the server cap exist.
    public func search(project: String, query: String? = nil) async throws -> CustomerSearchResponse {
        let out = try await run {
            try await api.commerceCustomerSearch(.init(
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project),
                body: .json(.init(query: query))))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /commerce/customers-mobile/{id}` — the folded detail; `state` is `live` | `merged` | `erased`
    /// (identity is nil for a merged loser + an erased row). A 404 surfaces as `BytewiseOperatorError.notFound`.
    public func detail(project: String, id: Int32) async throws -> CustomerDetailResponse {
        let out = try await run {
            try await api.commerceCustomerDetail(.init(path: .init(id: id), headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `GET /commerce/customers-mobile/{id}/activity?cursor=` — older activity beyond the detail's newest-N
    /// page (called only on "load more"). Pass the previous page's `nextCursor`.
    public func activity(project: String, id: Int32, cursor: String? = nil) async throws -> CustomerActivityPage {
        let out = try await run {
            try await api.commerceCustomerActivity(.init(
                path: .init(id: id), query: .init(cursor: cursor), headers: .init(xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Service status — the operator "Rendszermonitor" overview (read-only on the companion app; M6.3). The read
/// requires `status.read` with the status module enabled (conjunctive), and is PROJECT-SCOPED
/// (`X-Project-Slug` is required by the contract). Read-only in v1: publish/unpublish, component CRUD and
/// incident create/update are DEFERRED and are NOT exposed here.
public struct StatusFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /status` — the full operator overview for a project: publication state, the rolled-up banner,
    /// every component (incl. internal + archived) with its 90-day rollup strip, and the incident list
    /// (`startedAt` desc, active + recently resolved).
    ///
    /// The SDK preserves SERVER order verbatim (components, incidents, incident updates `postedAt` desc, day
    /// buckets oldest-first) and never re-sorts. A CALLER may reorder deliberately: the mobile apps apply one
    /// documented stable partition (active incidents before resolved, server order kept within each group)
    /// because the server's single `startedAt`-desc list can rank a just-resolved incident above an older
    /// live one. Component order is authoritative and must not be reordered by anyone.
    public func overview(project: String) async throws -> StatusOverview {
        let out = try await run { try await api.statusOverview(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Operator-app chrome strings (localized).
public struct LocalizationFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /localization` — flat string map for the given culture (server resolves the
    /// fallback-language chain). Returns `nil` on a `304 Not Modified` (unused today — the SDK
    /// sends no `If-None-Match`).
    public func bundle(culture: String? = nil) async throws -> [String: String]? {
        let out = try await run { try await api.localizationBundle(.init(query: .init(culture: culture))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return p.additionalProperties }
        case .notModified: return nil
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Mobile Action Inbox (M5.1): the merged, prioritized cross-project operator-intervention list.
public struct InboxFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /mobile/inbox` — the single account-level Action Inbox read (fans out across the caller's own
    /// projects; account-level, so no `X-Project-Slug`). Response is `no-store`; "seen" is client-local.
    public func list() async throws -> InboxListResponse {
        let out = try await run { try await api.inboxList(.init()) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Cross-project "My Tasks" (M6.2). The LIST is ACCOUNT-LEVEL (a cross-project fan-out — no `X-Project-Slug`,
/// mirrors the inbox); the quick-complete WRITE is PROJECT-SCOPED transport addressed to the row's OWN slug, so
/// completing a task never mutates any shared "selected project" state — the slug is a per-call argument.
public struct TasksFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /mobile/my-tasks` — the caller's outstanding tasks across their projects (account-level, so NO
    /// `X-Project-Slug`). Server-ordered (DueDate asc nulls-last, then priority, then id) — do NOT re-sort.
    /// Response is `no-store`.
    public func myTasks() async throws -> MyTasksResponse {
        let out = try await run { try await api.mobileMyTasks(.init()) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /todo/tasks/{id}/complete` — the project-scoped quick-complete. `project` MUST be the ROW's own
    /// `projectSlug`; `id` its `MyTaskRow.id`. Atomic + assignee-bound server-side: a 404 means the task is no
    /// longer yours / present (refresh the list); a 403 means todo.edit was lost (drop the affordance). NEVER
    /// blind-auto-retry — re-read before any resend.
    public func complete(project: String, id: Int32) async throws -> TodoCompleteResponse {
        let out = try await run {
            try await api.todoCompleteTask(.init(
                path: .init(id: id),
                headers: .init(xRequestedWith: requestedWith, xProjectSlug: project)))
        }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }
}

/// Feature-flag KILL-SWITCH (Wave M / M6.4) — the highest-risk mobile surface. Scope is view (list) + kill +
/// unkill only (no create/edit/delete/targeting/variants — those stay web). Listing requires `flags.view`;
/// kill/unkill require the REUSED `flags.manage` (Owner/Admin), with the flags module enabled. Killing flips
/// the DISTINCT kill switch so the flag serves OFF on each device's next successful evaluation, overriding
/// rules/rollout/enabled while PRESERVING the saved config; un-kill makes that config eligible again. Kill and
/// unkill are optimistic-concurrency guarded: pass the row's `rowVersion` as `ifMatch` (sent as a quoted strong
/// validator); a stale value throws `BytewiseOperatorError.conflict` carrying the server's CURRENT state.
/// Mutations are single-attempt — never auto-retried. All three ops take the project slug per call.
public struct FlagsFacade: Sendable {
    let client: OperatorClient
    private var api: any APIProtocol { client.generated }

    /// `GET /flags/mobile` — every valid flag in Key order. `truncated` ⇒ corrupt over-cap data (rare, never
    /// a normal paging signal). Response is `no-store`.
    public func list(project: String) async throws -> FlagsMobileListResponse {
        let out = try await run { try await api.flagsMobileList(.init(headers: .init(xProjectSlug: project))) }
        switch out {
        case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
        case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromUndocumented(code, payload)
        }
    }

    /// `POST /flags/mobile/{key}/kill` — flip the kill switch ON. `ifMatch` is the flag's current `rowVersion`;
    /// a stale value throws `BytewiseOperatorError.conflict` (the CURRENT state); idempotent when already
    /// killed. NEVER blind-retry — re-fetch first (the mutation is single-attempt).
    public func kill(project: String, key: String, ifMatch: String) async throws -> FlagKillResult {
        try await setKilled(project: project, key: key, ifMatch: ifMatch, kill: true)
    }

    /// `POST /flags/mobile/{key}/unkill` — clear the kill switch (the saved config becomes eligible again on
    /// later successful evaluations). Same If-Match + no-auto-retry discipline as `kill`.
    public func unkill(project: String, key: String, ifMatch: String) async throws -> FlagKillResult {
        try await setKilled(project: project, key: key, ifMatch: ifMatch, kill: false)
    }

    private func setKilled(project: String, key: String, ifMatch: String, kill: Bool) async throws -> FlagKillResult {
        let validator = quoteValidator(ifMatch)
        let out: Operations.FlagsMobileKill.Output
        let outUnkill: Operations.FlagsMobileUnkill.Output
        if kill {
            out = try await run {
                try await api.flagsMobileKill(.init(
                    path: .init(key: key),
                    headers: .init(xRequestedWith: requestedWith, xProjectSlug: project, ifMatch: validator)))
            }
            switch out {
            case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
            // The mobile contract models only success bodies, so a 409 arrives as `.undocumented`; the flag-kill
            // mapping decodes it into the distinguishable `.conflict` (never the generic `.validation`).
            case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromFlagKillUndocumented(code, payload)
            }
        } else {
            outUnkill = try await run {
                try await api.flagsMobileUnkill(.init(
                    path: .init(key: key),
                    headers: .init(xRequestedWith: requestedWith, xProjectSlug: project, ifMatch: validator)))
            }
            switch outUnkill {
            case .ok(let ok): switch ok.body { case .json(let p): return .init(p) }
            case .undocumented(let code, let payload): throw await BytewiseOperatorError.fromFlagKillUndocumented(code, payload)
            }
        }
    }

    /// Quote the base64 rowVersion as a STRONG ETag validator (matching the web client); the server trims the
    /// quotes. Never double-quote an already-quoted value.
    private func quoteValidator(_ rowVersion: String) -> String {
        (rowVersion.hasPrefix("\"") && rowVersion.hasSuffix("\"")) ? rowVersion : "\"\(rowVersion)\""
    }
}
