import Foundation
import Observation

/// What a cached query depends on. When data with a tag changes, every
/// query carrying that tag goes stale — the same idea as React Query's
/// `invalidateQueries({ queryKey })`, but by what the data *is*.
enum QueryTag: Hashable, CaseIterable {
    case medicines, doses, refills, moods, weights, calculators, settings, contacts
    /// Anything that depends on what "today" is; invalidated at midnight.
    case day
}

/// A small React Query–style cache for the app's derived data: the
/// calendar's year of day summaries, the adherence reports, the medicine
/// catalogue. Raw data lives in `MedicineStore` (already in memory); what
/// this saves is *recomputing* results from it on every redraw.
///
/// - `query(_:tags:staleTime:_:)` returns the cached value while it's fresh,
///   otherwise runs the fetcher and caches the result (`useQuery`).
/// - `prefetch(_:tags:_:)` fills the cache ahead of time — at launch, during
///   the splash (`queryClient.prefetchQuery`).
/// - `invalidate(_:)` marks every query with those tags stale and bumps
///   `revision`, so any screen showing one redraws and refetches it
///   (`invalidateQueries`). `MedicineStore` calls it after every save, with
///   exactly the tags whose data changed.
/// - Unused entries are dropped after `gcTime`, oldest first past `maxEntries`.
@MainActor
@Observable
final class QueryClient {
    static let shared = QueryClient()

    /// Read by every query, so a view that shows cached data redraws when
    /// any of it is invalidated.
    private(set) var revision = 0

    @ObservationIgnored private var entries: [String: Entry] = [:]
    @ObservationIgnored private let gcTime: TimeInterval = 10 * 60
    @ObservationIgnored private let maxEntries = 64

    private struct Entry {
        var value: Any
        var tags: Set<QueryTag>
        var fetchedAt: Date
        var lastUsed: Date
        var isStale = false
    }

    // MARK: Reading

    /// The cached value for `key`, fetched again if it's missing, stale, or
    /// older than `staleTime` (nil: fresh until invalidated).
    func query<Value>(
        _ key: String,
        tags: Set<QueryTag>,
        staleTime: TimeInterval? = nil,
        _ fetch: () -> Value
    ) -> Value {
        _ = revision
        let now = Date.now
        if var entry = entries[key], !entry.isStale, let value = entry.value as? Value,
           staleTime.map({ now.timeIntervalSince(entry.fetchedAt) < $0 }) ?? true {
            entry.lastUsed = now
            entries[key] = entry
            return value
        }
        let value = fetch()
        entries[key] = Entry(value: value, tags: tags, fetchedAt: now, lastUsed: now)
        collectGarbage(now: now)
        return value
    }

    /// Fills the cache before anything asks, e.g. during the splash.
    func prefetch<Value>(_ key: String, tags: Set<QueryTag>, _ fetch: () -> Value) {
        if let entry = entries[key], !entry.isStale { return }
        let now = Date.now
        entries[key] = Entry(value: fetch(), tags: tags, fetchedAt: now, lastUsed: now)
    }

    // MARK: Invalidating

    /// Marks every query that depends on any of `tags` stale; screens
    /// showing them redraw and refetch.
    func invalidate(_ tags: Set<QueryTag>) {
        guard !tags.isEmpty else { return }
        var changed = false
        for (key, entry) in entries where !entry.isStale && !entry.tags.isDisjoint(with: tags) {
            entries[key]?.isStale = true
            changed = true
        }
        if changed { revision &+= 1 }
    }

    func invalidate(_ tag: QueryTag) { invalidate([tag]) }

    /// Everything — after loading data written elsewhere, or a reset.
    func invalidateAll() {
        for key in entries.keys { entries[key]?.isStale = true }
        revision &+= 1
    }

    /// Drops everything (Delete all data).
    func clear() {
        entries.removeAll()
        revision &+= 1
    }

    // MARK: Housekeeping

    private func collectGarbage(now: Date) {
        entries = entries.filter { now.timeIntervalSince($0.value.lastUsed) < gcTime }
        guard entries.count > maxEntries else { return }
        let oldest = entries.sorted { $0.value.lastUsed < $1.value.lastUsed }.prefix(entries.count - maxEntries)
        for (key, _) in oldest { entries.removeValue(forKey: key) }
    }
}
