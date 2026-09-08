import Foundation

/// A cached value with the wall-clock time it was stored — the app renders it with a "stale as of
/// <age>" banner and decides its own refresh policy. No ETag/conditional-GET: the mobile reads have
/// no server-side conditional support in M1 (a named M1.8 follow-up), so this is a pure
/// timestamped last-successful-response cache.
public struct CacheEntry<Value: Sendable>: Sendable {
    public let value: Value
    public let storedAt: Date

    public init(value: Value, storedAt: Date) {
        self.value = value
        self.storedAt = storedAt
    }

    /// Age relative to `now` (defaults to the current time).
    public func age(now: Date = Date()) -> TimeInterval { now.timeIntervalSince(storedAt) }
}

/// The read-cache seam. The SDK ships an in-memory default (`InMemoryOperatorReadCache`); an app
/// that needs disk persistence across launches supplies its own conforming type. Deliberately
/// minimal — staleness/eviction policy lives with the caller, not here.
public protocol OperatorReadCache: Sendable {
    func read<Value: Sendable>(_ key: String, as type: Value.Type) async -> CacheEntry<Value>?
    func write<Value: Sendable>(_ value: Value, forKey key: String) async
    func remove(_ key: String) async
}

/// Process-lifetime, in-memory read cache. Values are type-erased under `any Sendable` and cast back
/// on read, so no `Codable` conformance is required of the public models.
public actor InMemoryOperatorReadCache: OperatorReadCache {
    private var storage: [String: (value: any Sendable, storedAt: Date)] = [:]

    public init() {}

    public func read<Value: Sendable>(_ key: String, as type: Value.Type) async -> CacheEntry<Value>? {
        guard let entry = storage[key], let typed = entry.value as? Value else { return nil }
        return CacheEntry(value: typed, storedAt: entry.storedAt)
    }

    public func write<Value: Sendable>(_ value: Value, forKey key: String) async {
        storage[key] = (value, Date())
    }

    public func remove(_ key: String) async {
        storage[key] = nil
    }
}
