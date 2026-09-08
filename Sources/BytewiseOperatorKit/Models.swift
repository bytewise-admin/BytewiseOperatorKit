import Foundation

// The PUBLIC model surface — hand-written, stable structs mapped from the internal generated
// transport models (Components.Schemas.*). Generated shapes churn with contract regeneration;
// these do not. Names mirror the contract schemas 1:1 so the mapping is trivially auditable.
// Optional arrays in the contract are coalesced to empty for ergonomics (an accompanying
// `available`/`stale` flag carries the "no data" signal where it matters).

// MARK: Dashboard / Overview

public struct DashboardSummaryProjectRef: Sendable, Hashable {
    public let name: String
    public let slug: String
    init(_ g: Components.Schemas.DashboardSummaryProjectRef) { name = g.name; slug = g.slug }
}

public struct Tile: Sendable, Hashable {
    public let key: String
    public let label: String
    public let module: String
    public let moduleName: String
    public let tone: String
    public let value: Int64
    init(_ g: Components.Schemas.Tile) {
        key = g.key; label = g.label; module = g.module; moduleName = g.moduleName; tone = g.tone; value = g.value
    }
}

/// `partial` + `failedModules` ⇒ a stat contributor failed, so `stats` is INCOMPLETE rather than
/// silently short — the same honesty contract `InboxListResponse` carries for its own fan-out. Without
/// these the app renders a degraded dashboard identically to a healthy one (round-4 R4-4, plumbed to the
/// kits in round-5).
public struct DashboardSummaryResponse: Sendable, Hashable {
    public let project: DashboardSummaryProjectRef
    public let stats: [Tile]
    public let statsModuleCount: Int32
    public let partial: Bool
    public let failedModules: [String]
    init(_ g: Components.Schemas.DashboardSummaryResponse) {
        project = .init(g.project); stats = g.stats.map(Tile.init); statsModuleCount = g.statsModuleCount
        partial = g.partial; failedModules = g.failedModules
    }
}

public struct PortfolioProjectRef: Sendable, Hashable {
    public let name: String
    public let platforms: [String]
    public let role: String
    public let slug: String
    init(_ g: Components.Schemas.PortfolioProjectRef) {
        name = g.name; platforms = g.platforms; role = g.role; slug = g.slug
    }
}

/// `partial` + `failedModules` as on `DashboardSummaryResponse` — see its note.
public struct PortfolioCard: Sendable, Hashable {
    public let project: PortfolioProjectRef
    public let stats: [Tile]
    public let statsModuleCount: Int32
    public let partial: Bool
    public let failedModules: [String]
    init(_ g: Components.Schemas.PortfolioCard) {
        project = .init(g.project); stats = g.stats.map(Tile.init); statsModuleCount = g.statsModuleCount
        partial = g.partial; failedModules = g.failedModules
    }
}

public struct PortfolioResponse: Sendable, Hashable {
    public let projects: [PortfolioCard]
    init(_ g: Components.Schemas.PortfolioResponse) { projects = g.projects.map(PortfolioCard.init) }
}

public struct AnalyticsPublicConfig: Sendable, Hashable {
    public let sentryDsn: String?
    public let postHogKey: String?
    public let postHogHost: String?
    init(_ g: Components.Schemas.AnalyticsPublicConfig) {
        sentryDsn = g.sentryDsn; postHogKey = g.postHogKey; postHogHost = g.postHogHost
    }
}

public struct NavEntryResponse: Sendable, Hashable {
    public let icon: String
    public let label: String
    public let module: String
    public let route: String
    init(_ g: Components.Schemas.NavEntryResponse) {
        icon = g.icon; label = g.label; module = g.module; route = g.route
    }
}

public struct OperatorMeResponse: Sendable, Hashable {
    public let id: Int32
    public let email: String?
    public let displayName: String?
    public let isSystemAdmin: Bool
    public let twoFactorEnabled: Bool
    init(_ g: Components.Schemas.OperatorMeResponse) {
        id = g.id; email = g.email; displayName = g.displayName
        isSystemAdmin = g.isSystemAdmin; twoFactorEnabled = g.twoFactorEnabled
    }
}

public struct BootstrapProject: Sendable, Hashable {
    public let id: Int32
    public let slug: String
    public let name: String
    public let platforms: Int32
    public let role: String
    public let enabledModules: [String]
    /// The caller's EFFECTIVE permission keys for this project (e.g. `analytics.triage`, `feedback.manage`,
    /// `stores.revenue`). Gate capability-specific actions off THIS set — `enabledModules` mirrors `/nav` and
    /// only proves `project.read` + ≥1 module permission, never a specific capability.
    public let permissions: [String]
    public let publishableAnalytics: AnalyticsPublicConfig
    init(_ g: Components.Schemas.BootstrapProject) {
        id = g.id; slug = g.slug; name = g.name; platforms = g.platforms; role = g.role
        enabledModules = g.enabledModules; permissions = g.permissions
        publishableAnalytics = .init(g.publishableAnalytics)
    }
}

/// Result of revoking the calling mobile-companion token (logout teardown).
public struct MobileSelfRevokeResponse: Sendable, Hashable {
    public let tokenId: String
    public let revoked: Bool
    init(_ g: Components.Schemas.MobileSelfRevokeResponse) { tokenId = g.tokenId; revoked = g.revoked }
}

public struct BootstrapResponse: Sendable, Hashable {
    public let me: OperatorMeResponse
    public let projects: [BootstrapProject]
    init(_ g: Components.Schemas.BootstrapResponse) {
        me = .init(g.me); projects = g.projects.map(BootstrapProject.init)
    }
}

// MARK: Account

public struct MyProjectResponse: Sendable, Hashable {
    public let id: Int32
    public let slug: String
    public let name: String
    public let platforms: Int32
    public let role: String
    init(_ g: Components.Schemas.MyProjectResponse) {
        id = g.id; slug = g.slug; name = g.name; platforms = g.platforms; role = g.role
    }
}

public struct PushDeviceListItemResponse: Sendable, Hashable {
    public let id: Int32
    public let platform: String
    public let bundleId: String?
    public let tokenPrefix: String
    public let enabled: Bool
    public let createdAt: Date
    public let lastSeenAt: Date
    init(_ g: Components.Schemas.PushDeviceListItemResponse) {
        id = g.id; platform = g.platform; bundleId = g.bundleId; tokenPrefix = g.tokenPrefix
        enabled = g.enabled; createdAt = g.createdAt; lastSeenAt = g.lastSeenAt
    }
}

public struct PushDeviceRegisterResponse: Sendable, Hashable {
    public let id: Int32
    public let platform: String
    public let refreshed: Bool
    init(_ g: Components.Schemas.PushDeviceRegisterResponse) {
        id = g.id; platform = g.platform; refreshed = g.refreshed
    }
}

public struct PushDeviceRemoveResponse: Sendable, Hashable {
    public let id: Int32
    public let removed: Bool
    init(_ g: Components.Schemas.PushDeviceRemoveResponse) { id = g.id; removed = g.removed }
}

// MARK: Crashes / Analytics

public struct AnalyticsIssueItem: Sendable, Hashable {
    public let id: String
    public let title: String
    public let level: String
    public let count: Int64
    public let userCount: Int32
    public let firstSeen: Date?
    public let lastSeen: Date?
    public let severity: String?
    public let internalStatus: String?
    public let notes: String?
    public let customerId: Int32?
    public let customerLabel: String?
    public let licenseId: Int32?
    public let aiSummary: String?
    public let aiSuggestedSeverity: String?
    public let aiGeneratedAt: Date?
    public let syncStatus: String?
    public let syncError: String?
    public let lastSyncedAt: Date?
    /// Where the effective severity came from (plan M-C): the manual value if an operator set one,
    /// else the crash-alert detector's coarse claim, else the AI suggestion. `severityOrigin` names
    /// which — a severity that cannot say its source is not a fact the operator can act on.
    public let detectorSeverity: String?
    public let effectiveSeverity: String?
    public let severityOrigin: String?
    init(_ g: Components.Schemas.AnalyticsIssueItem) {
        id = g.id; title = g.title; level = g.level; count = g.count; userCount = g.userCount
        firstSeen = g.firstSeen; lastSeen = g.lastSeen; severity = g.severity
        internalStatus = g.internalStatus; notes = g.notes; customerId = g.customerId
        customerLabel = g.customerLabel; licenseId = g.licenseId; aiSummary = g.aiSummary
        aiSuggestedSeverity = g.aiSuggestedSeverity; aiGeneratedAt = g.aiGeneratedAt
        syncStatus = g.syncStatus; syncError = g.syncError; lastSyncedAt = g.lastSyncedAt
        detectorSeverity = g.detectorSeverity; effectiveSeverity = g.effectiveSeverity
        severityOrigin = g.severityOrigin
    }
}

public struct AnalyticsResolvedIssueItem: Sendable, Hashable {
    public let id: String
    public let title: String
    public let level: String
    public let count: Int64
    public let userCount: Int32
    public let firstSeen: Date?
    public let lastSeen: Date?
    public let internalStatus: String?
    public let syncStatus: String?
    public let lastSyncedAt: Date?
    init(_ g: Components.Schemas.AnalyticsResolvedIssueItem) {
        id = g.id; title = g.title; level = g.level; count = g.count; userCount = g.userCount
        firstSeen = g.firstSeen; lastSeen = g.lastSeen; internalStatus = g.internalStatus
        syncStatus = g.syncStatus; lastSyncedAt = g.lastSyncedAt
    }
}

public struct AnalyticsIssueSyncItem: Sendable, Hashable {
    public let externalId: String
    public let internalStatus: String
    public let syncStatus: String
    public let syncError: String?
    public let updatedAt: Date
    init(_ g: Components.Schemas.AnalyticsIssueSyncItem) {
        externalId = g.externalId; internalStatus = g.internalStatus; syncStatus = g.syncStatus
        syncError = g.syncError; updatedAt = g.updatedAt
    }
}

public struct AnalyticsIssuesResponse: Sendable, Hashable {
    public let available: Bool
    public let reason: String?
    public let issues: [AnalyticsIssueItem]
    public let resolved: [AnalyticsResolvedIssueItem]
    public let sync: [AnalyticsIssueSyncItem]
    /// Which lane actually served this response — `provider` or `own` (plan M-C/C2). The two lanes
    /// detect differently, so a number without its lane is not comparable.
    public let routing: String?
    init(_ g: Components.Schemas.AnalyticsIssuesResponse) {
        available = g.available; reason = g.reason; routing = g.routing
        issues = (g.issues ?? []).map(AnalyticsIssueItem.init)
        resolved = (g.resolved ?? []).map(AnalyticsResolvedIssueItem.init)
        sync = (g.sync ?? []).map(AnalyticsIssueSyncItem.init)
    }
}

/// One uploaded symbol artifact as read back from the tenant-scoped inventory. `contentHash` is the
/// lowercase SHA-256 of the stored bytes; storage paths and container topology are intentionally absent.
public struct AnalyticsSymbolArtifactItem: Sendable, Hashable {
    public let id: Int64
    public let kind: String
    public let debugId: String
    public let architecture: String
    public let imageName: String
    public let fileSize: Int64
    public let contentHash: String
    public let status: String
    public let createdAt: Date
    init(_ g: Components.Schemas.AnalyticsSymbolArtifactItem) {
        id = g.id; kind = g.kind; debugId = g.debugId; architecture = g.architecture
        imageName = g.imageName; fileSize = g.fileSize; contentHash = g.contentHash
        status = g.status; createdAt = g.createdAt
    }
}

public struct AnalyticsSymbolArtifactsResponse: Sendable, Hashable {
    public let artifacts: [AnalyticsSymbolArtifactItem]
    init(_ g: Components.Schemas.AnalyticsSymbolArtifactsResponse) {
        artifacts = g.artifacts.map(AnalyticsSymbolArtifactItem.init)
    }
}

public struct AnalyticsIssueBreadcrumb: Sendable, Hashable {
    public let timestamp: Date?
    public let category: String?
    public let level: String
    public let message: String?
    init(_ g: Components.Schemas.AnalyticsIssueBreadcrumb) {
        timestamp = g.timestamp; category = g.category; level = g.level; message = g.message
    }
}

public struct AnalyticsIssueFrame: Sendable, Hashable {
    public let filename: String?
    public let function: String?
    public let lineno: Int32?
    public let inApp: Bool
    init(_ g: Components.Schemas.AnalyticsIssueFrame) {
        filename = g.filename; function = g.function; lineno = g.lineno; inApp = g.inApp
    }
}

public struct AnalyticsIssueDetailItem: Sendable, Hashable {
    public let id: String
    public let title: String
    public let level: String
    public let status: String
    public let count: Int64
    public let userCount: Int32
    public let culprit: String?
    public let firstSeen: Date?
    public let lastSeen: Date?
    public let exceptionType: String?
    public let exceptionValue: String?
    public let exceptionModule: String?
    public let severity: String?
    public let internalStatus: String?
    public let notes: String?
    public let customerId: Int32?
    public let customerLabel: String?
    public let licenseId: Int32?
    public let aiSummary: String?
    public let aiSuggestedSeverity: String?
    public let aiGeneratedAt: Date?
    public let syncStatus: String?
    public let syncError: String?
    public let lastSyncedAt: Date?
    /// Where the effective severity came from (plan M-C): the manual value if an operator set one,
    /// else the crash-alert detector's coarse claim, else the AI suggestion. `severityOrigin` names
    /// which — a severity that cannot say its source is not a fact the operator can act on.
    public let detectorSeverity: String?
    public let effectiveSeverity: String?
    public let severityOrigin: String?
    /// The app the issue was seen in, and the exact session that produced it (plan M-B). Populated on
    /// the own-store read; null on the provider path, where neither key travels with the issue.
    public let appId: String?
    public let sessionId: String?
    public let breadcrumbs: [AnalyticsIssueBreadcrumb]
    public let frames: [AnalyticsIssueFrame]
    /// Server-side event tags (schema `tags` container of free-form string properties).
    public let tags: [String: String]
    init(_ g: Components.Schemas.AnalyticsIssueDetailItem) {
        id = g.id; title = g.title; level = g.level; status = g.status; count = g.count
        userCount = g.userCount; culprit = g.culprit; firstSeen = g.firstSeen; lastSeen = g.lastSeen
        exceptionType = g.exceptionType; exceptionValue = g.exceptionValue; exceptionModule = g.exceptionModule
        severity = g.severity; internalStatus = g.internalStatus; notes = g.notes
        customerId = g.customerId; customerLabel = g.customerLabel; licenseId = g.licenseId
        aiSummary = g.aiSummary; aiSuggestedSeverity = g.aiSuggestedSeverity; aiGeneratedAt = g.aiGeneratedAt
        syncStatus = g.syncStatus; syncError = g.syncError; lastSyncedAt = g.lastSyncedAt
        detectorSeverity = g.detectorSeverity; effectiveSeverity = g.effectiveSeverity
        severityOrigin = g.severityOrigin
        appId = g.appId; sessionId = g.sessionId
        breadcrumbs = (g.breadcrumbs ?? []).map(AnalyticsIssueBreadcrumb.init)
        frames = (g.frames ?? []).map(AnalyticsIssueFrame.init)
        tags = g.tags?.additionalProperties ?? [:]
    }
}

public struct AnalyticsIssueDetailResponse: Sendable, Hashable {
    public let available: Bool
    public let partial: Bool
    public let reason: String?
    public let detailReason: String?
    public let issue: AnalyticsIssueDetailItem?
    /// Which lane actually served this response — `provider` or `own` (plan M-C/C2). The two lanes
    /// detect differently, so a number without its lane is not comparable.
    public let routing: String?
    init(_ g: Components.Schemas.AnalyticsIssueDetailResponse) {
        available = g.available; partial = g.partial; reason = g.reason; routing = g.routing
        detailReason = g.detailReason; issue = g.issue.map(AnalyticsIssueDetailItem.init)
    }
}

public struct AnalyticsReleaseChangelogRef: Sendable, Hashable {
    public let version: String
    init(_ g: Components.Schemas.AnalyticsReleaseChangelogRef) { version = g.version }
}

public struct AnalyticsReleaseItem: Sendable, Hashable {
    public let version: String
    public let sessions: Int64
    public let crashFreeRate: Double?
    public let hasChangelogEntry: Bool
    public let changelog: AnalyticsReleaseChangelogRef?
    init(_ g: Components.Schemas.AnalyticsReleaseItem) {
        version = g.version; sessions = g.sessions; crashFreeRate = g.crashFreeRate
        hasChangelogEntry = g.hasChangelogEntry; changelog = g.changelog.map(AnalyticsReleaseChangelogRef.init)
    }
}

public struct AnalyticsReleasesResponse: Sendable, Hashable {
    public let available: Bool
    public let stale: Bool
    public let reason: String?
    public let computedAt: Date?
    public let releases: [AnalyticsReleaseItem]
    init(_ g: Components.Schemas.AnalyticsReleasesResponse) {
        available = g.available; stale = g.stale; reason = g.reason; computedAt = g.computedAt
        releases = (g.releases ?? []).map(AnalyticsReleaseItem.init)
    }
}

public struct AnalyticsTriageResponse: Sendable, Hashable {
    public let externalId: String
    public let internalStatus: String
    public let syncStatus: String
    public let severity: String?
    init(_ g: Components.Schemas.AnalyticsTriageResponse) {
        externalId = g.externalId; internalStatus = g.internalStatus
        syncStatus = g.syncStatus; severity = g.severity
    }
}

public struct AnalyticsAlertsResponse: Sendable, Hashable {
    public let enabled: Bool
    public let crashReArmDays: Int32?
    init(_ g: Components.Schemas.AnalyticsAlertsResponse) { enabled = g.enabled; crashReArmDays = g.crashReArmDays }
}

public struct AnalyticsAlertsToggleResponse: Sendable, Hashable {
    public let enabled: Bool
    init(_ g: Components.Schemas.AnalyticsAlertsToggleResponse) { enabled = g.enabled }
}

// MARK: Feedback

public struct FeedbackAttachmentMetaResponse: Sendable, Hashable {
    public let id: Int32
    public let fileName: String
    public let contentType: String
    public let sizeBytes: Int64
    init(_ g: Components.Schemas.FeedbackAttachmentMetaResponse) {
        id = g.id; fileName = g.fileName; contentType = g.contentType; sizeBytes = g.sizeBytes
    }
}

/// One manual tag from the project's vocabulary (F-E).
public struct TagRef: Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    init(_ g: Components.Schemas.TagRef) { self.id = Int(g.id); self.name = g.name }
}

/// The manual tags of ONE listed item. Tags ride BESIDE the rows rather than inside them so the row
/// shape stays what every other reader of this list already expects.
public struct ItemTags: Sendable, Hashable {
    public let itemId: Int
    public let tags: [TagRef]
    init(_ g: Components.Schemas.ItemTags) { self.itemId = Int(g.itemId); self.tags = g.tags.map(TagRef.init) }
}

/// A keyset page of the operator feedback list (F-A5). `nextCursor` is nil when the page exhausted
/// the filtered stream — that, not an item count, is how you know to stop asking. Feed it back as
/// `cursor` to get the next page; treat it as opaque, its shape is not part of the contract.
public struct FeedbackPage: Sendable, Hashable {
    public let items: [FeedbackListItemResponse]
    public let nextCursor: String?
    public let tags: [ItemTags]

    init(_ g: Components.Schemas.FeedbackSearchResponse) {
        self.items = g.items.map(FeedbackListItemResponse.init)
        self.nextCursor = g.nextCursor
        self.tags = g.tags.map(ItemTags.init)
    }
}

/// A keyset page of the operator feature board (F-A5), ordered by votes. Same cursor contract as
/// ``FeedbackPage``.
public struct FeatureBoardPage: Sendable, Hashable {
    public let items: [FeatureBoardOperatorItem]
    public let nextCursor: String?
    public let tags: [ItemTags]

    init(_ g: Components.Schemas.FeatureBoardOperatorPage) {
        self.items = g.items.map(FeatureBoardOperatorItem.init)
        self.nextCursor = g.nextCursor
        self.tags = g.tags.map(ItemTags.init)
    }
}

public struct FeedbackListItemResponse: Sendable, Hashable {
    public let id: Int32
    public let message: String
    public let email: String?
    public let status: String
    public let category: String?
    public let suggestedCategory: String?
    public let appVersion: String?
    public let osVersion: String?
    public let createdAt: Date
    public let isResolved: Bool
    public let resolvedAt: Date?
    public let assignedUserId: Int32?
    public let adminNotes: String?
    public let aiSummary: String?
    public let aiUrgency: String?
    public let aiTriagedAt: Date?
    public let isQuarantined: Bool
    public let quarantineReason: String?
    public let quarantinedAt: Date?
    public let attachments: [FeedbackAttachmentMetaResponse]
    init(_ g: Components.Schemas.FeedbackListItemResponse) {
        id = g.id; message = g.message; email = g.email; status = g.status; category = g.category
        suggestedCategory = g.suggestedCategory; appVersion = g.appVersion; osVersion = g.osVersion
        createdAt = g.createdAt; isResolved = g.isResolved; resolvedAt = g.resolvedAt
        assignedUserId = g.assignedUserId; adminNotes = g.adminNotes; aiSummary = g.aiSummary
        aiUrgency = g.aiUrgency; aiTriagedAt = g.aiTriagedAt; isQuarantined = g.isQuarantined
        quarantineReason = g.quarantineReason; quarantinedAt = g.quarantinedAt
        attachments = g.attachments.map(FeedbackAttachmentMetaResponse.init)
    }
}

public struct FeedbackReplyListItemResponse: Sendable, Hashable {
    public let id: Int32
    public let body: String
    public let repliedByUserId: Int32
    public let deliveryStatus: String
    public let attemptCount: Int32
    public let createdAt: Date
    public let sentAt: Date?
    init(_ g: Components.Schemas.FeedbackReplyListItemResponse) {
        id = g.id; body = g.body; repliedByUserId = g.repliedByUserId; deliveryStatus = g.deliveryStatus
        attemptCount = g.attemptCount; createdAt = g.createdAt; sentAt = g.sentAt
    }
}

public struct FeedbackReplySendResponse: Sendable, Hashable {
    public let id: Int32
    public let deliveryStatus: String
    public let sentAt: Date?
    init(_ g: Components.Schemas.FeedbackReplySendResponse) {
        id = g.id; deliveryStatus = g.deliveryStatus; sentAt = g.sentAt
    }
}

public struct FeedbackStateResponse: Sendable, Hashable {
    public let id: Int32
    public let status: String
    public let isResolved: Bool
    init(_ g: Components.Schemas.FeedbackStateResponse) { id = g.id; status = g.status; isResolved = g.isResolved }
}

public struct FeedbackTriageStateResponse: Sendable, Hashable {
    public let id: Int32
    public let status: String
    public let isResolved: Bool
    public let category: String?
    public let assignedUserId: Int32?
    public let adminNotes: String?
    init(_ g: Components.Schemas.FeedbackTriageStateResponse) {
        id = g.id; status = g.status; isResolved = g.isResolved; category = g.category
        assignedUserId = g.assignedUserId; adminNotes = g.adminNotes
    }
}

// MARK: Revenue

public struct CommerceRevenueCounts: Sendable, Hashable {
    public let active: Int32
    public let completed: Int32
    public let defaulted: Int32
    public let pendingPayment: Int32
    public let refunded: Int32
    init(_ g: Components.Schemas.CommerceRevenueCounts) {
        active = g.active; completed = g.completed; defaulted = g.defaulted
        pendingPayment = g.pendingPayment; refunded = g.refunded
    }
}

public struct CommerceRevenueMonth: Sendable, Hashable {
    public let month: String
    public let collectedCents: Int64
    /// Chargebacks LOST in this month, dated to when the dispute closed. Reported separately from
    /// `collectedCents`, never netted into it — a chargeback is not a refund.
    public let disputedLostCents: Int64
    init(_ g: Components.Schemas.CommerceRevenueMonth) {
        month = g.month; collectedCents = g.collectedCents; disputedLostCents = g.disputedLostCents
    }
}

public struct CommerceRevenueOrigin: Sendable, Hashable {
    public let origin: String
    public let collectedCents: Int64
    init(_ g: Components.Schemas.CommerceRevenueOrigin) { origin = g.origin; collectedCents = g.collectedCents }
}

public struct CommerceRevenueCurrencyBlock: Sendable, Hashable {
    public let currency: String
    public let collected30dCents: Int64
    public let prior30dCents: Int64
    public let outstandingPendingCents: Int64
    public let outstandingOverdueCents: Int64
    public let monthly: [CommerceRevenueMonth]
    public let origins: [CommerceRevenueOrigin]
    /// Chargebacks lost in the last 30 days / across the 12-month window. A DEDUCTION reported beside the
    /// collected figures: subtract it yourself to get what was kept, and note that the purchase's status
    /// deliberately does not move, so refund reporting keeps meaning refunds.
    public let disputedLost30dCents: Int64
    public let disputedLost12mCents: Int64
    init(_ g: Components.Schemas.CommerceRevenueCurrencyBlock) {
        currency = g.currency; collected30dCents = g.collected30dCents; prior30dCents = g.prior30dCents
        outstandingPendingCents = g.outstandingPendingCents; outstandingOverdueCents = g.outstandingOverdueCents
        monthly = g.monthly.map(CommerceRevenueMonth.init); origins = g.origins.map(CommerceRevenueOrigin.init)
        disputedLost30dCents = g.disputedLost30dCents; disputedLost12mCents = g.disputedLost12mCents
    }
}

public struct CommerceRevenueDefaultSplit: Sendable, Hashable {
    public let dunning: Int32
    public let subscriptionDeleted: Int32
    public let unknown: Int32
    init(_ g: Components.Schemas.CommerceRevenueDefaultSplit) {
        dunning = g.dunning; subscriptionDeleted = g.subscriptionDeleted; unknown = g.unknown
    }
}

public struct CommerceRevenueRefunds90d: Sendable, Hashable {
    public let paidBase: Int32
    public let refunded: Int32
    init(_ g: Components.Schemas.CommerceRevenueRefunds90d) { paidBase = g.paidBase; refunded = g.refunded }
}

public struct CommerceRevenueTrialsSection: Sendable, Hashable {
    public let started90d: Int32
    public let matured90d: Int32
    public let maturedConverted90d: Int32
    init(_ g: Components.Schemas.CommerceRevenueTrialsSection) {
        started90d = g.started90d; matured90d = g.matured90d; maturedConverted90d = g.maturedConverted90d
    }
}

public struct CommerceRevenueResponse: Sendable, Hashable {
    public let counts: CommerceRevenueCounts
    public let currencies: [CommerceRevenueCurrencyBlock]
    public let defaultSplit: CommerceRevenueDefaultSplit
    public let refunds90d: CommerceRevenueRefunds90d
    public let trials: CommerceRevenueTrialsSection?
    init(_ g: Components.Schemas.CommerceRevenueResponse) {
        counts = .init(g.counts); currencies = g.currencies.map(CommerceRevenueCurrencyBlock.init)
        defaultSplit = .init(g.defaultSplit); refunds90d = .init(g.refunds90d)
        trials = g.trials.map(CommerceRevenueTrialsSection.init)
    }
}

/// One report pipeline's ingest coverage. `incompletePeriod` and its two counts are the row-loss notice
/// (round-5 `STORES-COVERAGE-REJECTEDROWS-NEM-LATSZIK`): the oldest period this pipeline ingested while
/// dropping rows it could not read, and which has not been read cleanly since. Surfaced here rather than
/// left in the generated transport — a public model that silently drops a field the server serves is the
/// same invisibility this field exists to close, one layer down.
///
/// The `unclaimed*` trio is the value-dictionary notice (round-5 `STORES-ERTEK-SZOTAR-ATNEVEZES`): the
/// oldest period whose report carried rows of which the parser recognised no VALUE.
/// `unclaimedRemovedFacts` grades it — stored rows the replace removed for that period, as a high-water
/// mark — without settling it: a legitimate restatement produces the same number, and on `play.earnings` a
/// miss does not empty the period at all (the amounts still sum; only the unit counts fall to zero), so
/// "replaced by nothing" is NOT what a positive count means.
public struct StoresReportCoverage: Sendable, Hashable {
    public let provider: String
    public let reportKey: String
    public let lastRunAt: Date?
    public let lastOutcome: String?
    public let through: String?
    public let incompletePeriod: String?
    public let incompleteRejectedRows: Int
    public let incompleteRows: Int
    public let unclaimedPeriod: String?
    public let unclaimedRows: Int
    public let unclaimedRemovedFacts: Int
    init(_ g: Components.Schemas.StoresReportCoverage) {
        provider = g.provider; reportKey = g.reportKey; lastRunAt = g.lastRunAt
        lastOutcome = g.lastOutcome; through = g.through
        incompletePeriod = g.incompletePeriod
        incompleteRejectedRows = Int(g.incompleteRejectedRows); incompleteRows = Int(g.incompleteRows)
        unclaimedPeriod = g.unclaimedPeriod
        unclaimedRows = Int(g.unclaimedRows); unclaimedRemovedFacts = Int(g.unclaimedRemovedFacts)
    }
}

public struct StoresRevenuePoint: Sendable, Hashable {
    public let provider: String
    public let date: String
    public let basis: String
    public let currency: String
    public let gross: Double?
    public let net: Double?
    public let units: Int64
    public let isAccountingGrade: Bool
    init(_ g: Components.Schemas.StoresRevenuePoint) {
        provider = g.provider; date = g.date; basis = g.basis; currency = g.currency
        gross = g.gross; net = g.net; units = g.units; isAccountingGrade = g.isAccountingGrade
    }
}

public struct StoresRevenueProduct: Sendable, Hashable {
    public let provider: String
    public let productId: String
    public let currency: String
    public let net: Double?
    public let units: Int64
    init(_ g: Components.Schemas.StoresRevenueProduct) {
        provider = g.provider; productId = g.productId; currency = g.currency; net = g.net; units = g.units
    }
}

public struct StoresRevenueResponse: Sendable, Hashable {
    public let windowDays: Int32
    public let coverage: [StoresReportCoverage]
    public let series: [StoresRevenuePoint]
    public let topProducts: [StoresRevenueProduct]
    init(_ g: Components.Schemas.StoresRevenueResponse) {
        windowDays = g.windowDays; coverage = g.coverage.map(StoresReportCoverage.init)
        series = g.series.map(StoresRevenuePoint.init); topProducts = g.topProducts.map(StoresRevenueProduct.init)
    }
}

public struct StoresVitalsDay: Sendable, Hashable {
    public let date: String
    public let crashRate: Double?
    public let anrRate: Double?
    public let distinctUsers: Int64?
    init(_ g: Components.Schemas.StoresVitalsDay) {
        date = g.date; crashRate = g.crashRate; anrRate = g.anrRate; distinctUsers = g.distinctUsers
    }
}

public struct StoresVitalsResponse: Sendable, Hashable {
    public let available: Bool
    public let stale: Bool
    public let reason: String?
    public let computedAt: Date?
    public let days: [StoresVitalsDay]
    init(_ g: Components.Schemas.StoresVitalsResponse) {
        available = g.available; stale = g.stale; reason = g.reason; computedAt = g.computedAt
        days = (g.days ?? []).map(StoresVitalsDay.init)
    }
}

/// One selectable Google Play app for the vitals screen. Deliberately minimal — the server projects id +
/// display name only (no bundle/package id, no external store app id, no provider token).
public struct StoresVitalsApp: Sendable, Hashable {
    public let id: Int32
    public let displayName: String
    init(_ g: Components.Schemas.StoresVitalsApp) {
        id = g.id; displayName = g.displayName
    }
}

/// The vitals app selector. `apps` is already filtered to vitals-eligible (Play + enabled) listings and is in
/// server order (display name, then id). `truncated` is true when more eligible apps exist than the server cap.
public struct StoresVitalsAppsResponse: Sendable, Hashable {
    public let apps: [StoresVitalsApp]
    public let truncated: Bool
    init(_ g: Components.Schemas.StoresVitalsAppsResponse) {
        apps = g.apps.map(StoresVitalsApp.init); truncated = g.truncated
    }
}

// MARK: Pairing

public struct MobilePairingExchangeResponse: Sendable, Hashable {
    /// The freshly minted mobile-companion PAT (`bws_pat_…`). Shown to the app ONCE — persist it in
    /// the Keychain; it is never retrievable again.
    public let token: String
    public let tokenId: String
    public let name: String
    public let createdAt: Date
    public let expiresAt: Date
    init(_ g: Components.Schemas.MobilePairingExchangeResponse) {
        token = g.token; tokenId = g.tokenId; name = g.name; createdAt = g.createdAt; expiresAt = g.expiresAt
    }
}

// MARK: FeatureBoard

public struct FeatureBoardOperatorItem: Sendable, Hashable {
    public let id: Int32
    public let title: String
    public let description: String?
    public let status: String
    public let voteCount: Int32
    public let isLocked: Bool
    public let isDeleted: Bool
    public let statusChangedAt: Date?
    public let createdAt: Date
    /// Publicly visible comments on the request — the cue that it has discussion worth opening.
    public let commentCount: Int32
    init(_ g: Components.Schemas.FeatureBoardOperatorItem) {
        id = g.id; title = g.title; description = g.description; status = g.status
        voteCount = g.voteCount; isLocked = g.isLocked; isDeleted = g.isDeleted
        statusChangedAt = g.statusChangedAt; createdAt = g.createdAt; commentCount = g.commentCount
    }
}

public struct QuarantinedFeature: Sendable, Hashable {
    public let id: Int32
    public let title: String
    public let description: String?
    public let quarantineReason: String?
    public let quarantinedAt: Date?
    public let createdAt: Date
    init(_ g: Components.Schemas.QuarantinedFeature) {
        id = g.id; title = g.title; description = g.description
        quarantineReason = g.quarantineReason; quarantinedAt = g.quarantinedAt; createdAt = g.createdAt
    }
}

public struct FeatureBoardStatusResult: Sendable, Hashable {
    public let id: Int32
    public let status: String
    init(_ g: Components.Schemas.FeatureBoardStatusResult) { id = g.id; status = g.status }
}

public struct FeatureBoardLockResult: Sendable, Hashable {
    public let id: Int32
    public let isLocked: Bool
    init(_ g: Components.Schemas.FeatureBoardLockResult) { id = g.id; isLocked = g.isLocked }
}

public struct FeatureBoardReleaseResult: Sendable, Hashable {
    public let id: Int32
    public let isQuarantined: Bool
    init(_ g: Components.Schemas.FeatureBoardReleaseResult) { id = g.id; isQuarantined = g.isQuarantined }
}

public struct FeatureBoardRejectResult: Sendable, Hashable {
    public let id: Int32
    init(_ g: Components.Schemas.FeatureBoardRejectResult) { id = g.id }
}

// MARK: FeatureBoard comment moderation (the mobile comment strip, F5-10)

/// One comment on the OPERATOR triage thread. Includes tombstoned rows (`isDeleted`) so the strip can show
/// what was hidden; `isOperator` marks the team's own reply. `createdAt` carries an offset on the wire.
public struct FeatureBoardOperatorComment: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let body: String
    public let isOperator: Bool
    public let isDeleted: Bool
    public let createdAt: Date
    init(_ g: Components.Schemas.FeatureBoardOperatorComment) {
        id = g.id; body = g.body; isOperator = g.isOperator; isDeleted = g.isDeleted; createdAt = g.createdAt
    }
}

/// A page of the operator triage thread, oldest-first.
public struct FeatureBoardOperatorCommentPage: Sendable, Hashable {
    public let total: Int32
    public let page: Int32
    public let pageSize: Int32
    public let items: [FeatureBoardOperatorComment]
    init(_ g: Components.Schemas.FeatureBoardOperatorCommentPage) {
        total = g.total; page = g.page; pageSize = g.pageSize
        items = g.items.map(FeatureBoardOperatorComment.init)
    }
}

/// Hide result: the comment id and its (now true) tombstone state.
public struct FeatureBoardCommentHideResult: Sendable, Hashable {
    public let id: Int32
    public let isDeleted: Bool
    init(_ g: Components.Schemas.FeatureBoardCommentHideResult) { id = g.id; isDeleted = g.isDeleted }
}

/// One held comment in the review queue: its parent request for context + the AI's bounded reason.
public struct QuarantinedComment: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let featureId: Int32
    public let featureTitle: String
    public let body: String
    public let quarantineReason: String?
    public let quarantinedAt: Date?
    public let createdAt: Date
    init(_ g: Components.Schemas.QuarantinedComment) {
        id = g.id; featureId = g.featureId; featureTitle = g.featureTitle; body = g.body
        quarantineReason = g.quarantineReason; quarantinedAt = g.quarantinedAt; createdAt = g.createdAt
    }
}

/// The comment review queue: newest-first held comments. `truncated` ⇒ more exist than the returned window
/// (sustained ingress stays visible — surface it).
public struct FeatureBoardQuarantinedComments: Sendable, Hashable {
    public let items: [QuarantinedComment]
    public let truncated: Bool
    init(_ g: Components.Schemas.FeatureBoardQuarantinedComments) {
        items = g.items.map(QuarantinedComment.init); truncated = g.truncated
    }
}

/// Comment release result: the comment id and its (now false) quarantine state.
public struct FeatureBoardCommentReleaseResult: Sendable, Hashable {
    public let id: Int32
    public let isQuarantined: Bool
    init(_ g: Components.Schemas.FeatureBoardCommentReleaseResult) { id = g.id; isQuarantined = g.isQuarantined }
}

/// Comment reject result: the (now tombstoned) comment id.
public struct FeatureBoardCommentRejectResult: Sendable, Hashable {
    public let id: Int32
    init(_ g: Components.Schemas.FeatureBoardCommentRejectResult) { id = g.id }
}

// MARK: Mobile Action Inbox (M5.1)

/// The client routing destination for an inbox row: a reserved token + the ids the target screen needs.
/// An unrecognized `kind` should route to a safe Overview (the sealed-router fallback discipline).
public struct InboxTargetDto: Sendable, Hashable {
    public let kind: String
    public let ids: [String: String]
    init(_ g: Components.Schemas.InboxTargetDto) {
        kind = g.kind
        ids = g.ids.additionalProperties
    }
}

/// One actionable inbox row. `id` is `{kind}:{sourceId}[:{discriminator}]` — use it as the local seen-set
/// key. `priority` is the lowercased severity token (critical|high|normal|low). The row carries only a
/// localization key + bounded machine args/badges + routing ids — never raw feedback/crash/review content.
public struct InboxRow: Sendable, Hashable {
    public let id: String
    public let kind: String
    public let projectSlug: String
    public let occurredAt: Date
    public let priority: String
    public let titleKey: String
    public let titleArgs: [String: String]
    public let badges: [String]
    public let target: InboxTargetDto
    init(_ g: Components.Schemas.InboxRow) {
        id = g.id; kind = g.kind; projectSlug = g.projectSlug; occurredAt = g.occurredAt
        priority = g.priority; titleKey = g.titleKey
        titleArgs = g.titleArgs.additionalProperties; badges = g.badges
        target = .init(g.target)
    }
}

/// The merged, prioritized, capped Action Inbox. `truncated` ⇒ the fairness/global cap dropped rows;
/// `partial` + `failedSources` ⇒ a source failed (the list is incomplete, NOT a silent-empty);
/// `omittedProjects` ⇒ projects beyond the fan-out ceiling.
public struct InboxListResponse: Sendable, Hashable {
    public let rows: [InboxRow]
    public let truncated: Bool
    public let partial: Bool
    public let failedSources: [String]
    public let omittedProjects: Int32
    init(_ g: Components.Schemas.InboxListResponse) {
        rows = g.rows.map(InboxRow.init)
        truncated = g.truncated; partial = g.partial
        failedSources = g.failedSources; omittedProjects = g.omittedProjects
    }
}

// MARK: Mobile My Tasks (M6.2)

/// A server-AUTHORIZED routing token for a task's originating context — `{kind, id}` ONLY, never a raw
/// SourceModule/SourceKey. v1 emits it exclusively for a store review the caller can reach (`kind == "review"`,
/// `id` = the numeric review id); every other/deferred/malformed source is nil.
public struct MyTaskContext: Sendable, Hashable {
    public let kind: String
    public let id: String
    init(_ g: Components.Schemas.MyTaskContext) {
        kind = g.kind
        id = g.id
    }
}

/// One cross-project "my task" row. `id` is the task id in its OWN project (`projectSlug`) — the complete write
/// is addressed to that slug. `dueDate` is a bare `YYYY-MM-DD` CALENDAR date (OpenAPI `date`, never an instant —
/// render it as a date, not a relative age). `canComplete` is a UX hint (the write stays authoritative).
public struct MyTaskRow: Sendable, Hashable {
    public let id: Int32
    public let projectSlug: String
    public let projectName: String
    public let title: String
    public let status: String
    public let priority: String
    public let dueDate: String?
    public let createdAt: Date
    public let canComplete: Bool
    public let context: MyTaskContext?
    init(_ g: Components.Schemas.MyTaskRow) {
        id = g.id; projectSlug = g.projectSlug; projectName = g.projectName; title = g.title
        status = g.status; priority = g.priority; dueDate = g.dueDate; createdAt = g.createdAt
        canComplete = g.canComplete
        context = g.context.map(MyTaskContext.init)
    }
    /// The client row identity is `(projectSlug, id)` — task ids repeat across projects, so use this composite
    /// (NOT the bare `id`) as the SwiftUI list key.
    public var rowKey: String { "\(projectSlug):\(id)" }
}

/// The cross-project "my tasks" list. `truncated` ⇒ a per-project or global cap dropped a row; `partial` +
/// `failedProjects` ⇒ a project's query failed (the list is incomplete, NOT a silent-empty); `omittedProjects`
/// ⇒ projects beyond the fan-out ceiling.
public struct MyTasksResponse: Sendable, Hashable {
    public let tasks: [MyTaskRow]
    public let truncated: Bool
    public let partial: Bool
    public let failedProjects: [String]
    public let omittedProjects: Int32
    init(_ g: Components.Schemas.MyTasksResponse) {
        tasks = g.tasks.map(MyTaskRow.init)
        truncated = g.truncated; partial = g.partial
        failedProjects = g.failedProjects; omittedProjects = g.omittedProjects
    }
}

/// The quick-complete result: the id, the lowercased status token (`done` on success/idempotent), and the
/// completion instant.
public struct TodoCompleteResponse: Sendable, Hashable {
    public let id: Int32
    public let status: String
    public let completedAt: Date?
    init(_ g: Components.Schemas.TodoCompleteResponse) {
        id = g.id; status = g.status; completedAt = g.completedAt
    }
}

/// One row in the read-only mobile abuse signal list (M5.4). `type`, `priority` and `status` are OPEN
/// string tokens (the client maps known tokens to localized labels, falling back for anything unknown).
/// Carries NO subject key and NO resolver id — the server never projects those columns onto the wire.
public struct AbuseSignalItem: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let type: String
    public let severity: Int32
    public let priority: String
    public let status: String
    public let isLive: Bool
    public let firstSeen: Date
    public let lastSeen: Date
    public let resolvedAt: Date?
    init(_ g: Components.Schemas.AbuseSignalItem) {
        id = g.id; type = g._type; severity = g.severity; priority = g.priority
        status = g.status; isLive = g.isLive
        firstSeen = g.firstSeen; lastSeen = g.lastSeen; resolvedAt = g.resolvedAt
    }
}

/// The read-only mobile abuse signal list (M5.4). `truncated` ⇒ more signals exist than the server cap;
/// rows render in SERVER order (severity, then recency, then id) and must not be re-sorted.
public struct AbuseSignalListResponse: Sendable, Hashable {
    public let items: [AbuseSignalItem]
    public let truncated: Bool
    init(_ g: Components.Schemas.AbuseSignalListResponse) {
        items = g.items.map(AbuseSignalItem.init)
        truncated = g.truncated
    }
}

// MARK: Store reviews (read-only mobile surface, M5.3)

/// One row in the read-only mobile review list (M5.3). `provider` and `replyState` are OPEN string tokens
/// (the client maps known tokens to localized labels, falling back for anything unknown). `effectiveReviewTime`
/// = ReviewEditedAt ?? ReviewCreatedAt (matches the inbox ordering). Carries NO body / reply text / external id.
public struct StoreReviewSummary: Sendable, Hashable, Identifiable {
    public let id: Int64
    public let storeAppId: Int32
    public let appName: String?
    public let provider: String
    public let rating: Int32
    public let title: String?
    public let effectiveReviewTime: Date
    public let replyState: String
    init(_ g: Components.Schemas.StoreReviewSummary) {
        id = g.id; storeAppId = g.storeAppId; appName = g.appName; provider = g.provider
        rating = g.rating; title = g.title; effectiveReviewTime = g.effectiveReviewTime; replyState = g.replyState
    }
}

/// The bounded, PII-safe review SUMMARY list (M5.3). `truncated` ⇒ more reviews exist than the server cap;
/// rows render in SERVER order (effective review time desc) and must not be re-sorted.
public struct StoreReviewSummaryResponse: Sendable, Hashable {
    public let items: [StoreReviewSummary]
    public let truncated: Bool
    init(_ g: Components.Schemas.StoreReviewSummaryResponse) {
        items = g.items.map(StoreReviewSummary.init)
        truncated = g.truncated
    }
}

/// The honest full review DETAIL by id (M5.3). The public review body lives here. The reply state is surfaced
/// READ-ONLY (`replyState` / `replyText` / `replyError`); `replyError` is a machine reason token, and both it
/// and `replyState` are OPEN string tokens the client maps to localized labels with a fallback.
public struct StoreReviewDetailResponse: Sendable, Hashable, Identifiable {
    public let id: Int64
    public let storeAppId: Int32
    public let appName: String?
    public let provider: String
    public let rating: Int32
    public let title: String?
    public let body: String?
    public let territoryOrLanguage: String?
    public let appVersion: String?
    public let reviewCreatedAt: Date
    public let reviewEditedAt: Date?
    public let providerReplyText: String?
    public let providerRepliedAt: Date?
    public let replyState: String
    public let replyText: String?
    public let replySubmittedAt: Date?
    public let replyError: String?
    init(_ g: Components.Schemas.StoreReviewDetailResponse) {
        id = g.id; storeAppId = g.storeAppId; appName = g.appName; provider = g.provider; rating = g.rating
        title = g.title; body = g.body; territoryOrLanguage = g.territoryOrLanguage; appVersion = g.appVersion
        reviewCreatedAt = g.reviewCreatedAt; reviewEditedAt = g.reviewEditedAt
        providerReplyText = g.providerReplyText; providerRepliedAt = g.providerRepliedAt
        replyState = g.replyState; replyText = g.replyText; replySubmittedAt = g.replySubmittedAt; replyError = g.replyError
    }
}

// MARK: Changelog — the operator review + publish/unpublish surface (Wave M / M6.6a)

/// One changelog LIST row — a body-free picker entry. `publishedAt` nil ⇒ a draft. `hasTranslations` hints
/// that publishing will also expose localized variants.
public struct ChangelogMobileListItem: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let version: String
    public let title: String
    public let publishedAt: Date?
    public let updatedAt: Date
    public let hasTranslations: Bool
    init(_ g: Components.Schemas.ChangelogMobileListItem) {
        id = g.id; version = g.version; title = g.title
        publishedAt = g.publishedAt; updatedAt = g.updatedAt; hasTranslations = g.hasTranslations
    }
}

/// The changelog LIST response — server order (CreatedAt DESC), `truncated` when more exist beyond the cap.
public struct ChangelogMobileListResponse: Sendable, Hashable {
    public let items: [ChangelogMobileListItem]
    public let truncated: Bool
    init(_ g: Components.Schemas.ChangelogMobileListResponse) {
        items = g.items.map(ChangelogMobileListItem.init); truncated = g.truncated
    }
}

/// One per-language override reviewed before publishing (the localized title/body that goes public).
public struct ChangelogMobileTranslation: Sendable, Hashable {
    public let lang: String
    public let title: String
    public let body: String
    init(_ g: Components.Schemas.ChangelogMobileTranslation) { lang = g.lang; title = g.title; body = g.body }
}

/// The changelog DETAIL — the REVIEW read: base title/body PLUS the translation variants publishing exposes.
/// `oversizedWebOnly` ⇒ the base body or a translation body exceeds the mobile review ceiling; the oversized
/// body/bodies come back BLANK and the publish is refused (review + publish it on web).
public struct ChangelogMobileDetail: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let version: String
    public let title: String
    public let body: String
    public let publishedAt: Date?
    public let firstPublishedAt: Date?
    public let updatedAt: Date
    public let publicId: String
    public let translations: [ChangelogMobileTranslation]
    public let oversizedWebOnly: Bool
    init(_ g: Components.Schemas.ChangelogMobileDetail) {
        id = g.id; version = g.version; title = g.title; body = g.body
        publishedAt = g.publishedAt; firstPublishedAt = g.firstPublishedAt; updatedAt = g.updatedAt
        publicId = g.publicId; translations = g.translations.map(ChangelogMobileTranslation.init)
        oversizedWebOnly = g.oversizedWebOnly
    }
}

/// The PUBLISH result. `firstPublish` true ⇒ this publish fired the `changelog.published` webhook + drafted
/// the newsletter (once, ever); a republish leaves those untouched. `updatedAt` lets the detail refresh in place.
public struct ChangelogPublishResult: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let publishedAt: Date
    public let updatedAt: Date
    public let firstPublish: Bool
    init(_ g: Components.Schemas.ChangelogPublishResult) {
        id = g.id; publishedAt = g.publishedAt; updatedAt = g.updatedAt; firstPublish = g.firstPublish
    }
}

/// The UNPUBLISH result — `publishedAt` is nil after a successful unpublish (or an already-hidden no-op).
public struct ChangelogUnpublishResult: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let publishedAt: Date?
    public let updatedAt: Date
    init(_ g: Components.Schemas.ChangelogUnpublishResult) {
        id = g.id; publishedAt = g.publishedAt; updatedAt = g.updatedAt
    }
}

// MARK: Roadmap — the operator board + review + narrow triage surface (Wave M / M6.6b)

/// One board card — id + base title + Internal/Public visibility + the canonical `sortOrder` (carried so a
/// future drag-reorder builds its full-set payload with no read-model change; the board never re-sorts).
public struct RoadmapMobileCard: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let title: String
    public let visibility: String
    public let sortOrder: Int32
    init(_ g: Components.Schemas.RoadmapMobileCard) {
        id = g.id; title = g.title; visibility = g.visibility; sortOrder = g.sortOrder
    }
}

/// One board lane: the lowercased lane token and its cards in `sortOrder` order (server order — never re-sort).
public struct RoadmapMobileLane: Sendable, Hashable, Identifiable {
    public let lane: String
    public let items: [RoadmapMobileCard]
    public var id: String { lane }
    init(_ g: Components.Schemas.RoadmapMobileLane) {
        lane = g.lane; items = g.items.map(RoadmapMobileCard.init)
    }
}

/// The roadmap BOARD — lanes in enum order (consideration→planned→inprogress→done). `oversized` ⇒ the project
/// exceeds the per-project item ceiling: the board is NOT complete and NOT reorder-ready (surface it).
public struct RoadmapMobileBoard: Sendable, Hashable {
    public let lanes: [RoadmapMobileLane]
    public let oversized: Bool
    init(_ g: Components.Schemas.RoadmapMobileBoard) {
        lanes = g.lanes.map(RoadmapMobileLane.init); oversized = g.oversized
    }
}

/// One per-language override reviewed before making an item Public (the localized title/description that goes
/// public). `description` nil ⇒ the base description is used for that language.
public struct RoadmapMobileTranslation: Sendable, Hashable {
    public let lang: String
    public let title: String
    public let description: String?
    init(_ g: Components.Schemas.RoadmapMobileTranslation) {
        lang = g.lang; title = g.title; description = g.description
    }
}

/// The roadmap DETAIL — the "review what becomes public" read: base title/description, the resolved `platforms`
/// token list (`["all"]` when unspecified), lane + visibility tokens, and the localized variants. Plain text.
public struct RoadmapMobileDetail: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let title: String
    public let description: String?
    public let lane: String
    public let visibility: String
    public let platforms: [String]
    public let translations: [RoadmapMobileTranslation]
    init(_ g: Components.Schemas.RoadmapMobileDetail) {
        id = g.id; title = g.title; description = g.description
        lane = g.lane; visibility = g.visibility; platforms = g.platforms
        translations = g.translations.map(RoadmapMobileTranslation.init)
    }
}

/// The TRIAGE result — the item's canonical lane + visibility after the write, its canonical `sortOrder` (so
/// the client places the card without a re-read), and `changed` (false ⇒ an idempotent no-op).
public struct RoadmapTriageResult: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let lane: String
    public let visibility: String
    public let sortOrder: Int32
    public let changed: Bool
    init(_ g: Components.Schemas.RoadmapTriageResult) {
        id = g.id; lane = g.lane; visibility = g.visibility; sortOrder = g.sortOrder; changed = g.changed
    }
}

// MARK: Links — the curated per-project external-links directory (read-only mobile surface, F5-09)

/// One curated external link (Stripe/SendGrid/… dashboard), grouped under a free-text `category`. `createdAt`
/// carries an offset on the wire (server widens it to UTC), decoded to a `Date`.
public struct LinkMobileEntry: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let name: String
    public let url: String
    public let description: String?
    public let category: String
    public let sortOrder: Int32
    public let createdAt: Date
    init(_ g: Components.Schemas.LinkMobileEntry) {
        id = g.id; name = g.name; url = g.url; description = g.description
        category = g.category; sortOrder = g.sortOrder; createdAt = g.createdAt
    }
}

/// Links grouped under one free-text `category` (links ordered by SortOrder then id). `id` is the category
/// so the group is `Identifiable` for a SwiftUI list.
public struct LinkMobileGroup: Sendable, Hashable, Identifiable {
    public var id: String { category }
    public let category: String
    public let links: [LinkMobileEntry]
    init(_ g: Components.Schemas.LinkMobileGroup) {
        category = g.category; links = g.links.map(LinkMobileEntry.init)
    }
}

/// The Links directory — category-ordered `groups`. `truncated` ⇒ the project exceeds the per-project item
/// ceiling: the directory is NOT complete (surface it).
public struct LinksMobileDirectory: Sendable, Hashable {
    public let groups: [LinkMobileGroup]
    public let truncated: Bool
    init(_ g: Components.Schemas.LinksMobileDirectory) {
        groups = g.groups.map(LinkMobileGroup.init); truncated = g.truncated
    }
}

// MARK: Service status — the operator "Rendszermonitor" overview (read-only mobile surface, M6.3)

/// One day bucket of a component's uptime strip (M6.3). `uptime` and `known` are FRACTIONS (0…1) of the
/// day's evaluated time: `known` is how much of that day was actually OBSERVED, so a day with a tiny
/// `known` carries an `uptime` figure resting on almost no evidence — a renderer must not present it as a
/// confident healthy day. `worst` is an OPEN state token (`operational` / `degraded` / `partialoutage` /
/// `majoroutage` / `unknown`); `unknown` sits OUTSIDE the severity order and is neither green nor red.
public struct StatusPublicDay: Sendable, Hashable, Identifiable {
    /// `yyyy-MM-dd` (invariant culture, UTC day).
    public let day: String
    public let uptime: Double
    public let known: Double
    public let worst: String
    public var id: String { day }
    init(_ g: Components.Schemas.StatusPublicDay) {
        day = g.day; uptime = g.uptime; known = g.known; worst = g.worst
    }
}

/// One status component in the operator overview (M6.3). `scope` (`platform` / `project`), `state` and each
/// day's `worst` are OPEN string tokens. `nameKey` is a BEST-EFFORT localization key owned by whichever
/// module contributes the component — it is NOT part of the mobile string bundle, so a client must fall back
/// to `name` when the lookup does not resolve. `reason` is an operator-only machine code
/// (`healthcheck:…` / `backlog:stuck` / `low-volume` / …), never end-user text. `uptimePercent` is `nil`
/// when the window observed nothing — which is NOT the same as 0%.
public struct StatusOverviewComponent: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let key: String
    public let name: String
    public let nameKey: String?
    public let scope: String
    public let state: String
    public let reason: String?
    public let publicVisible: Bool
    public let archived: Bool
    public let sortOrder: Int32
    public let uptimePercent: Double?
    /// Up to 90 day buckets, oldest first (server order — never re-sort).
    public let days: [StatusPublicDay]
    init(_ g: Components.Schemas.StatusOverviewComponent) {
        id = g.id; key = g.key; name = g.name; nameKey = g.nameKey; scope = g.scope; state = g.state
        reason = g.reason; publicVisible = g.publicVisible; archived = g.archived; sortOrder = g.sortOrder
        uptimePercent = g.uptimePercent
        days = g.days.map(StatusPublicDay.init)
    }
}

/// One posted update on an incident (M6.3). `lifecycle` is an OPEN token; `message` is operator-authored
/// PLAIN TEXT and must be rendered as such (never as markdown/HTML).
public struct StatusOverviewIncidentUpdate: Sendable, Hashable {
    public let lifecycle: String
    public let message: String
    public let postedAt: Date
    init(_ g: Components.Schemas.StatusOverviewIncidentUpdate) {
        lifecycle = g.lifecycle; message = g.message; postedAt = g.postedAt
    }
}

/// One incident in the operator overview (M6.3). `scope`, `impact` (`minor` / `major` / `critical`) and
/// `lifecycle` (`investigating` / `identified` / `monitoring` / `resolved`) are OPEN tokens — only the
/// literal `resolved` means resolved, so an unknown/future token must never be classified as such.
/// `rowVersion` is the optimistic-concurrency token a future incident-update WRITE would send as `If-Match`;
/// a cached copy is always stale-capable, so any such write must refetch and handle a 409.
public struct StatusOverviewIncident: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let title: String
    public let scope: String
    public let impact: String
    public let lifecycle: String
    public let startedAt: Date
    public let resolvedAt: Date?
    public let rowVersion: String
    public let componentIds: [Int32]
    /// Updates in server order (`postedAt` desc) — never re-sort.
    public let updates: [StatusOverviewIncidentUpdate]
    init(_ g: Components.Schemas.StatusOverviewIncident) {
        id = g.id; title = g.title; scope = g.scope; impact = g.impact; lifecycle = g.lifecycle
        startedAt = g.startedAt; resolvedAt = g.resolvedAt; rowVersion = g.rowVersion
        componentIds = g.componentIds
        updates = g.updates.map(StatusOverviewIncidentUpdate.init)
    }
}

/// The operator status overview (M6.3) — project-scoped, read-only on the companion app. `published`
/// reports whether the PUBLIC status page is live (an internally healthy overview says nothing about what
/// customers can see). `banner` is the rolled-up OPEN state token. `systemAdmin` is an advisory capability
/// flag for the web console's platform-component controls; every write stays server-authorized, so the
/// mobile surface does not act on it. Components and incidents are in SERVER order.
public struct StatusOverview: Sendable, Hashable {
    public let published: Bool
    public let publishedAt: Date?
    public let systemAdmin: Bool
    public let banner: String
    public let components: [StatusOverviewComponent]
    public let incidents: [StatusOverviewIncident]
    init(_ g: Components.Schemas.StatusOverview) {
        published = g.published; publishedAt = g.publishedAt; systemAdmin = g.systemAdmin; banner = g.banner
        // The contract makes both arrays REQUIRED (non-nullable) — map directly; no `?? []` coalescing.
        components = g.components.map(StatusOverviewComponent.init)
        incidents = g.incidents.map(StatusOverviewIncident.init)
    }
}

// ── Customers (M6.5): read-only lookup for support — PII-safe search + folded detail + activity paging ──

public struct CustomerSummary: Sendable, Hashable, Identifiable {
    public let id: Int32
    public let email: String
    public let name: String?
    init(_ g: Components.Schemas.CustomerSummary) {
        id = g.id; email = g.email; name = g.name
    }
}

public struct CustomerSearchResponse: Sendable, Hashable {
    public let customers: [CustomerSummary]
    public let truncated: Bool
    init(_ g: Components.Schemas.CustomerSearchResponse) {
        customers = g.customers.map(CustomerSummary.init)
        truncated = g.truncated
    }
}

public struct CustomerEntitlementRow: Sendable, Hashable {
    public let feature: String
    /// `nil` = unlimited (never render a fake number).
    public let limit: Int32?
    /// `nil` = non-expiring (never render a fake date).
    public let validUntil: Date?
    /// The dominant contributor: `"license"` or `"store"`.
    public let source: String
    init(_ g: Components.Schemas.CustomerEntitlementRow) {
        feature = g.feature; limit = g.limit; validUntil = g.validUntil; source = g.source
    }
}

/// Typed, allow-listed timeline metadata — the ONLY fields a timeline event may carry (never a raw dictionary).
public struct CustomerTimelineMeta: Sendable, Hashable {
    public let currency: String?
    public let amountCents: Int64?
    public let resolved: Bool?
    /// Last-4 license mask (e.g. `•••ABCD`), never the raw key.
    public let maskedLicenseSuffix: String?
    public let trialVariant: String?
    init(_ g: Components.Schemas.CustomerTimelineMeta) {
        currency = g.currency; amountCents = g.amountCents; resolved = g.resolved
        maskedLicenseSuffix = g.maskedLicenseSuffix; trialVariant = g.trialVariant
    }
}

public struct CustomerTimelineRow: Sendable, Hashable {
    public let occurredAt: Date
    public let kind: String
    /// `nil` for an unknown kind (a future producer can never leak through the typed allow-list).
    public let meta: CustomerTimelineMeta?
    init(_ g: Components.Schemas.CustomerTimelineRow) {
        occurredAt = g.occurredAt; kind = g.kind
        meta = g.meta.map(CustomerTimelineMeta.init)
    }
}

public struct CustomerDetailResponse: Sendable, Hashable, Identifiable {
    public let id: Int32
    /// `"live"` | `"merged"` | `"erased"`.
    public let state: String
    /// `nil` for a merged loser + an erased row (never a synthetic sentinel string).
    public let email: String?
    public let name: String?
    public let createdAt: Date
    /// Set ONLY when `state == "merged"` (the same-project survivor).
    public let mergedIntoCustomerId: Int32?
    /// Empty for merged/erased. An empty list means "no VISIBLE entitlements" (the caller may lack the
    /// license/entitlement read permission), not "none exist".
    public let entitlements: [CustomerEntitlementRow]
    /// Empty for merged; an erased row may retain financial activity.
    public let recentActivity: [CustomerTimelineRow]
    public let activityTruncated: Bool
    public let nextCursor: String?
    init(_ g: Components.Schemas.CustomerDetailResponse) {
        id = g.id; state = g.state; email = g.email; name = g.name
        createdAt = g.createdAt; mergedIntoCustomerId = g.mergedIntoCustomerId
        entitlements = g.entitlements.map(CustomerEntitlementRow.init)
        recentActivity = g.recentActivity.map(CustomerTimelineRow.init)
        activityTruncated = g.activityTruncated; nextCursor = g.nextCursor
    }
}

public struct CustomerActivityPage: Sendable, Hashable {
    public let items: [CustomerTimelineRow]
    public let nextCursor: String?
    init(_ g: Components.Schemas.CustomerActivityPage) {
        items = g.items.map(CustomerTimelineRow.init)
        nextCursor = g.nextCursor
    }
}

// MARK: Feature-flag kill-switch (M6.4)

/// One flag row in the kill-switch list. `killed`+`killedAt` is the DISTINCT kill state (an alarm, not
/// `enabled == false`). `rolloutBasisPoints` is the FALLBACK rollout (rules run first) — label it
/// "Fallback rollout", never "audience"/"impact". `ruleCount` is the parsed count of targeting rules.
/// `rowVersion` is the base64 strong validator the kill/unkill If-Match rests on.
public struct FlagMobileRow: Sendable, Hashable, Identifiable {
    public let key: String
    public let name: String
    public let description: String?
    public let flagType: String
    public let enabled: Bool
    public let killed: Bool
    public let killedAt: Date?
    public let rolloutBasisPoints: Int32
    public let ruleCount: Int32
    public let updatedAt: Date
    public let rowVersion: String
    public var id: String { key }
    init(_ g: Components.Schemas.FlagMobileRow) {
        key = g.key; name = g.name; description = g.description; flagType = g.flagType
        enabled = g.enabled; killed = g.killed; killedAt = g.killedAt
        rolloutBasisPoints = g.rolloutBasisPoints; ruleCount = g.ruleCount
        updatedAt = g.updatedAt; rowVersion = g.rowVersion
    }
}

/// The kill-switch list. `truncated` ⇒ corrupt/legacy over-cap data (rare) — NOT a normal paging signal.
public struct FlagsMobileListResponse: Sendable, Hashable {
    public let flags: [FlagMobileRow]
    public let truncated: Bool
    init(_ g: Components.Schemas.FlagsMobileListResponse) {
        flags = g.flags.map(FlagMobileRow.init); truncated = g.truncated
    }
}

/// The kill/unkill success result: the flag's kill state AFTER the write and the FRESH `rowVersion` to
/// stamp the next If-Match with.
public struct FlagKillResult: Sendable, Hashable, Identifiable {
    public let key: String
    public let killed: Bool
    public let killedAt: Date?
    public let rowVersion: String
    public var id: String { key }
    init(_ g: Components.Schemas.FlagKillResult) {
        key = g.key; killed = g.killed; killedAt = g.killedAt; rowVersion = g.rowVersion
    }
}

/// The server's CURRENT flag state when a kill/unkill lost the optimistic-concurrency race (409). Also
/// `Codable` so the error layer can decode it straight from the raw 409 body (the mobile contract models
/// only success bodies, so the 409 arrives as `.undocumented`).
public struct FlagKillConflict: Sendable, Hashable, Codable, Identifiable {
    public let key: String
    public let killed: Bool
    public let killedAt: Date?
    public let rowVersion: String
    public var id: String { key }
    init(_ g: Components.Schemas.FlagKillConflict) {
        key = g.key; killed = g.killed; killedAt = g.killedAt; rowVersion = g.rowVersion
    }
    public init(key: String, killed: Bool, killedAt: Date?, rowVersion: String) {
        self.key = key; self.killed = killed; self.killedAt = killedAt; self.rowVersion = rowVersion
    }
}
