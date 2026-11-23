import Foundation

/// Merges this device's data with the copy in iCloud, item by item.
///
/// Every record has a stable `id`, so a three-way merge against `base` (the
/// copy both sides agreed on at the last sync) tells an edit from an add and
/// a delete from "never had it":
/// - on both sides: whichever side changed it since `base` wins (this device
///   if both did);
/// - only here: kept if new, dropped if it was in `base` (deleted in iCloud);
/// - only in iCloud: kept if new, dropped if it was in `base` (deleted here).
///
/// With no `base` (the first sync on this device) everything from both sides
/// is kept, so restoring onto a new phone never loses anything.
enum SnapshotMerge {
    static func merge(base: MedicineSnapshot?, local: MedicineSnapshot, remote: MedicineSnapshot) -> MedicineSnapshot {
        var merged = MedicineSnapshot()
        merged.medicines = items(base: base?.medicines, local: local.medicines, remote: remote.medicines)
        merged.doseLogs = dedupedLogs(items(base: base?.doseLogs, local: local.doseLogs, remote: remote.doseLogs))
        merged.refills = items(base: base?.refills, local: local.refills, remote: remote.refills)
            .sorted { $0.date < $1.date }
        merged.contacts = items(base: base?.contacts, local: local.contacts, remote: remote.contacts)
        merged.checkIns = dedupedCheckIns(items(base: base?.checkIns, local: local.checkIns, remote: remote.checkIns))
        merged.weights = items(base: base?.weights, local: local.weights, remote: remote.weights)
            .sorted { $0.day < $1.day }
        merged.calculatorResults = items(base: base?.calculatorResults, local: local.calculatorResults, remote: remote.calculatorResults)
            .sorted { $0.day < $1.day }
        merged.sideEffects = items(base: base?.sideEffects, local: local.sideEffects, remote: remote.sideEffects)
            .sorted { $0.date < $1.date }
        merged.settings = settings(base: base?.settings, local: local.settings, remote: remote.settings)
        merged.lastCountdownDay = [local.lastCountdownDay, remote.lastCountdownDay].compactMap { $0 }.max()
        return merged
    }

    /// Three-way merge of one list, keeping this device's order and adding
    /// iCloud's new items after it.
    static func items<T: Identifiable & Equatable>(base: [T]?, local: [T], remote: [T]) -> [T] where T.ID: Hashable {
        let baseByID = base.map { Dictionary($0.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) }
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let localIDs = Set(local.map(\.id))

        var result: [T] = []
        for item in local {
            if let other = remoteByID[item.id] {
                // On both: this device's version unless only iCloud changed it.
                let localChanged = baseByID?[item.id].map { $0 != item } ?? true
                result.append(localChanged ? item : other)
            } else if baseByID?[item.id] == nil {
                result.append(item) // Added here since the last sync.
            }
            // Otherwise it was synced before and deleted on another device.
        }
        for item in remote where !localIDs.contains(item.id) {
            // New in iCloud, unless it was synced before and deleted here.
            if baseByID?[item.id] == nil { result.append(item) }
        }
        return result
    }

    private static func settings(base: AppSettings?, local: AppSettings, remote: AppSettings) -> AppSettings {
        guard let base else {
            // First sync: a fresh install restores what's in iCloud.
            return remote == AppSettings() ? local : remote
        }
        return local != base ? local : remote
    }

    /// The same dose ticked off on two phones before they synced: one log
    /// per medicine, day and time, preferring a taken one, so stock isn't
    /// counted down twice.
    private static func dedupedLogs(_ logs: [DoseLog]) -> [DoseLog] {
        var chosen: [String: Int] = [:]
        var result: [DoseLog] = []
        for log in logs {
            let key = "\(log.medicineID)-\(log.day.timeIntervalSince1970)-\(log.time.minutesSinceMidnight)"
            if let index = chosen[key] {
                if !result[index].isTaken, log.isTaken { result[index] = log }
            } else {
                chosen[key] = result.count
                result.append(log)
            }
        }
        return result
    }

    /// One check-in per day, the first (this device's) winning.
    private static func dedupedCheckIns(_ checkIns: [DailyCheckIn]) -> [DailyCheckIn] {
        var seen = Set<Date>()
        return checkIns.filter { seen.insert($0.day).inserted }.sorted { $0.day < $1.day }
    }
}
