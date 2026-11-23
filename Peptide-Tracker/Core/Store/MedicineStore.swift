import Foundation
import Observation
import WidgetKit

/// App-scoped store for medicines, dose logs and refills — created once at
/// the app root and read from the environment by every tab, the same shape
/// as Plates' feature stores. Every mutation persists and re-plans
/// notifications, so views never have to remember to.
@MainActor
@Observable
final class MedicineStore {
    /// The app's one store. Siri, Shortcuts and Live Activity buttons act on
    /// this same instance as the screens, so nothing writes the file twice.
    static let shared = MedicineStore()

    private(set) var medicines: [Medicine] {
        didSet { dosesByDay.removeAll(keepingCapacity: true) }
    }
    private(set) var doseLogs: [DoseLog] {
        didSet { dosesByDay.removeAll(keepingCapacity: true) }
    }
    /// `doses(on:)` per day, so Today, the week strip and the check-in card
    /// don't each re-scan every log on every redraw. Cleared whenever
    /// medicines or logs change.
    @ObservationIgnored private var dosesByDay: [Date: [ScheduledDose]] = [:]
    private(set) var refills: [RefillEvent]
    /// Doctors, carers and clinics, A–Z.
    private(set) var contacts: [HealthContact]
    /// One per day the user checked in, oldest first.
    private(set) var checkIns: [DailyCheckIn]
    /// Weigh-ins, oldest first, one per day.
    private(set) var weights: [WeightEntry]
    /// Saved calculator answers, oldest first.
    private(set) var calculatorResults: [CalculatorResult]
    /// Logged side effects, oldest first.
    private(set) var sideEffects: [SideEffectEntry]
    var settings: AppSettings {
        didSet { didChange() }
    }

    private var lastCountdownDay: Date?
    /// The last snapshot written, to tell which data changed on each save
    /// and invalidate only the queries that depend on it.
    @ObservationIgnored private var lastSaved: MedicineSnapshot?
    private let repository: MedicineRepository
    let scheduler: ReminderScheduler

    init(repository: MedicineRepository = FileMedicineRepository(), scheduler: ReminderScheduler = ReminderScheduler()) {
        self.repository = repository
        self.scheduler = scheduler
        let snapshot = repository.load()
        medicines = snapshot.medicines
        doseLogs = snapshot.doseLogs
        refills = snapshot.refills
        contacts = snapshot.contacts
        checkIns = snapshot.checkIns
        weights = snapshot.weights.sorted { $0.day < $1.day }
        calculatorResults = snapshot.calculatorResults.sorted { $0.day < $1.day }
        sideEffects = snapshot.sideEffects.sorted { $0.date < $1.date }
        settings = snapshot.settings
        lastCountdownDay = snapshot.lastCountdownDay
        lastSaved = snapshot
        refreshTodayUsage()
    }

    // MARK: - Medicines

    func medicine(id: UUID) -> Medicine? {
        medicines.first { $0.id == id }
    }

    /// Soonest to run out first.
    var medicinesByUrgency: [Medicine] {
        medicines.sorted { ($0.daysLeft, $0.name) < ($1.daysLeft, $1.name) }
    }

    func add(_ medicine: Medicine) {
        var medicine = medicine
        medicine.capacity = max(medicine.capacity, medicine.stock)
        medicines.append(medicine)
        didChange()
    }

    func update(_ medicine: Medicine) {
        guard let index = medicines.firstIndex(where: { $0.id == medicine.id }) else { return }
        var medicine = medicine
        medicine.capacity = max(medicine.capacity, medicine.stock)
        medicines[index] = medicine
        didChange()
    }

    /// Removes the medicine with its dose and refill history.
    func delete(id: UUID) {
        medicines.removeAll { $0.id == id }
        doseLogs.removeAll { $0.medicineID == id }
        refills.removeAll { $0.medicineID == id }
        didChange()
    }

    func setRemindersPaused(_ paused: Bool, for id: UUID) {
        mutate(id) { $0.remindersPaused = paused }
    }

    /// "Correct pill count" — sets what's on hand after missed or extra
    /// doses, without logging a refill.
    func correctStock(_ id: UUID, to count: Int) {
        mutate(id) {
            $0.stock = max(0, count)
            $0.capacity = max($0.capacity, $0.stock)
        }
    }

    // MARK: - Ordering

    /// A refill is on its way: reminders pause until it's marked refilled.
    func markOrdered(_ id: UUID, at date: Date = .now) {
        mutate(id) { $0.orderedAt = date }
    }

    func cancelOrder(_ id: UUID) {
        mutate(id) { $0.orderedAt = nil }
    }

    // MARK: - Refills

    func refill(_ id: UUID, adding amount: Int, at date: Date = .now) {
        guard amount > 0, let medicine = medicine(id: id) else { return }
        mutate(id, save: false) {
            $0.stock += amount
            $0.capacity = max($0.capacity, $0.stock)
            $0.orderedAt = nil
        }
        refills.append(RefillEvent(
            medicineID: id,
            medicineName: medicine.name,
            date: date,
            amount: amount,
            lastsDays: medicine.perDay > 0 ? amount / medicine.perDay : 0
        ))
        didChange()
    }

    /// The amount last added — a sensible default for one-tap refills.
    func suggestedRefillAmount(for medicine: Medicine) -> Int {
        refills.last { $0.medicineID == medicine.id }?.amount
            ?? medicine.type.commonPackSizes.first { $0 >= medicine.perDay * 28 }
            ?? medicine.type.commonPackSizes[0]
    }

    func refills(for id: UUID) -> [RefillEvent] {
        refills.filter { $0.medicineID == id }.sorted { $0.date > $1.date }
    }

    // MARK: - Doses

    /// Every dose scheduled on `day`, in time order, resolved against logs.
    func doses(on day: Date) -> [ScheduledDose] {
        let day = day.startOfDay
        // Read both arrays even on a cache hit, so the calling view still
        // redraws when either changes.
        let medicines = medicines, doseLogs = doseLogs
        if let cached = dosesByDay[day] { return cached }
        let doses = computeDoses(on: day, medicines: medicines, doseLogs: doseLogs)
        dosesByDay[day] = doses
        return doses
    }

    private func computeDoses(on day: Date, medicines: [Medicine], doseLogs: [DoseLog]) -> [ScheduledDose] {
        let logs = Dictionary(
            doseLogs.filter { $0.day == day }.map { ("\($0.medicineID)-\($0.time.minutesSinceMidnight)", $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return medicines
            .filter { $0.createdAt.startOfDay <= day && $0.isScheduled(on: day) }
            .flatMap { medicine in
                medicine.intakeTimes.compactMap { time -> ScheduledDose? in
                    let log = logs["\(medicine.id)-\(time.minutesSinceMidnight)"]
                    // Doses due before the medicine was added were already
                    // taken (or not) before the stock was counted — leave
                    // them out so they aren't counted down or called missed.
                    if log == nil, time.on(day) < medicine.createdAt { return nil }
                    return ScheduledDose(medicine: medicine, day: day, time: time, takenAt: log?.takenAt, site: log?.site)
                }
            }
            .sorted { ($0.time, $0.medicine.name) < ($1.time, $1.medicine.name) }
    }

    func doses(on day: Date, for medicineID: UUID) -> [ScheduledDose] {
        doses(on: day).filter { $0.medicine.id == medicineID }
    }

    /// Ticks a dose off, or un-ticks it. Ticking today's dose takes units
    /// from stock; a past dose was already counted down at day's end, so
    /// ticking it later only records that it was taken. `site` is where an
    /// injection went, kept with the log when ticking.
    func toggle(_ dose: ScheduledDose, site: InjectionSite? = nil, now: Date = .now) {
        guard dose.day <= now.startOfDay else { return }
        let isToday = dose.day == now.startOfDay
        let units = dose.medicine.unitsPerIntake

        if let index = logIndex(for: dose) {
            if doseLogs[index].isTaken {
                if isToday {
                    doseLogs.remove(at: index)
                    mutate(dose.medicine.id, save: false) { $0.stock += units }
                } else {
                    doseLogs[index].takenAt = nil
                    doseLogs[index].site = nil
                }
            } else {
                doseLogs[index].takenAt = now
                doseLogs[index].site = site
            }
        } else {
            doseLogs.append(DoseLog(medicineID: dose.medicine.id, day: dose.day, time: dose.time, units: units, takenAt: now, site: site))
            mutate(dose.medicine.id, save: false) { $0.stock = max(0, $0.stock - units) }
        }
        HapticFeedback.impact()
        didChange()

        // Every dose of today taken: a moment to ask for a rating.
        if isToday, logIndex(for: dose).map({ doseLogs[$0].isTaken }) == true,
           doses(on: dose.day).allSatisfy(\.isTaken) {
            ReviewPrompter.dayCompleted(dose.day)
        }
    }

    /// "Take all 3" on a timeline slot.
    func markTaken(_ doses: [ScheduledDose], now: Date = .now) {
        for dose in doses where !dose.isTaken { toggle(dose, now: now) }
    }

    // MARK: - Injection sites

    /// Taken injections with a site, newest first.
    func injectionHistory(for medicineID: UUID) -> [DoseLog] {
        doseLogs
            .filter { $0.medicineID == medicineID && $0.site != nil && $0.takenAt != nil }
            .sorted { $0.takenAt! > $1.takenAt! }
    }

    /// Where the next injection should go, across every injection
    /// medicine so two pens don't share a spot: the site in an area the
    /// user injects that has rested longest (`InjectionSite.next`).
    func suggestedSite() -> InjectionSite {
        InjectionSite.next(lastUsed: lastUsed(), skipping: settings.skippedSiteAreas)
    }

    /// When each site was last used, for fading recent sites on the map.
    func lastUsed() -> [InjectionSite: Date] {
        var used: [InjectionSite: Date] = [:]
        for log in doseLogs {
            guard let site = log.site, let takenAt = log.takenAt else { continue }
            used[site] = max(used[site] ?? .distantPast, takenAt)
        }
        return used
    }

    private func logIndex(for dose: ScheduledDose) -> Int? {
        doseLogs.firstIndex {
            $0.medicineID == dose.medicine.id && $0.day == dose.day && $0.time == dose.time
        }
    }

    /// Counts down every dose left unticked on days that have ended, so the
    /// supply keeps falling even when the user forgets to tick. Runs on
    /// launch and whenever the app comes back to the foreground.
    func runDailyCountdown(now: Date = .now) {
        let yesterday = now.startOfDay.adding(days: -1)
        guard let last = lastCountdownDay else {
            lastCountdownDay = yesterday
            didChange()
            return
        }
        // Even with nothing to count down, a new day resets today's usage.
        guard last < yesterday else {
            didChange()
            return
        }

        var day = max(last.adding(days: 1), yesterday.adding(days: -60))
        while day <= yesterday {
            for dose in doses(on: day) where logIndex(for: dose) == nil {
                let units = dose.medicine.unitsPerIntake
                doseLogs.append(DoseLog(medicineID: dose.medicine.id, day: day, time: dose.time, units: units, takenAt: nil))
                mutate(dose.medicine.id, save: false) { $0.stock = max(0, $0.stock - units) }
            }
            day = day.adding(days: 1)
        }
        lastCountdownDay = yesterday
        didChange()
    }

    // MARK: - Reminders

    /// Medicines that need a refill now — out, under five days, or past
    /// their reminder date — soonest first. Drives the card on Today.
    func medicinesNeedingRefill(now: Date = .now) -> [Medicine] {
        medicinesByUrgency.filter { $0.urgency <= .critical || $0.reminderDate(now: now) <= now }
    }

    /// The next heads-up still to come.
    func nextReminder(now: Date = .now) -> (medicine: Medicine, date: Date)? {
        medicines
            .filter(\.wantsReminder)
            .map { ($0, $0.reminderDate(now: now)) }
            .filter { $0.1 > now }
            .min { $0.1 < $1.1 }
    }

    // MARK: - Health contacts

    /// Adds the contact, or updates it if it's already saved.
    func save(_ contact: HealthContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
        } else {
            contacts.append(contact)
        }
        contacts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persist()
    }

    func deleteContact(id: UUID) {
        contacts.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Daily check-in

    func checkIn(on day: Date) -> DailyCheckIn? {
        checkIns.last { $0.day == day.startOfDay }
    }

    /// Saves how the user feels today, replacing an earlier pick.
    func checkIn(_ mood: DailyCheckIn.Mood, now: Date = .now) {
        let today = now.startOfDay
        if let index = checkIns.firstIndex(where: { $0.day == today }) {
            checkIns[index].mood = mood
        } else {
            checkIns.append(DailyCheckIn(day: today, mood: mood))
        }
        HapticFeedback.selection()
        persist()
    }

    /// Days in a row with a check-in, back from today (or yesterday, while
    /// today's is still to do).
    func checkInStreak(now: Date = .now) -> Int {
        let days = Set(checkIns.map(\.day))
        var day = now.startOfDay
        if !days.contains(day) { day = day.adding(days: -1) }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = day.adding(days: -1)
        }
        return streak
    }

    // MARK: - Weight

    var latestWeight: WeightEntry? { weights.last }

    func weight(on day: Date) -> WeightEntry? {
        weights.last { $0.day == day.startOfDay }
    }

    /// Saves a weigh-in for `day`, replacing that day's earlier one.
    func logWeight(kilograms: Double, on day: Date = .now) {
        let day = day.startOfDay
        if let index = weights.firstIndex(where: { $0.day == day }) {
            weights[index].kilograms = kilograms
        } else {
            weights.append(WeightEntry(day: day, kilograms: kilograms))
            weights.sort { $0.day < $1.day }
        }
        persist()
    }

    func deleteWeight(id: UUID) {
        weights.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Calculator history

    func calculatorResults(for kind: HealthCalculator) -> [CalculatorResult] {
        calculatorResults.filter { $0.kind == kind }
    }

    /// Keeps a calculator answer for today, replacing today's earlier one.
    func saveCalculatorResult(_ result: CalculatorResult) {
        var result = result
        result.day = result.day.startOfDay
        if let index = calculatorResults.firstIndex(where: { $0.kind == result.kind && $0.day == result.day }) {
            result.id = calculatorResults[index].id
            calculatorResults[index] = result
        } else {
            calculatorResults.append(result)
            calculatorResults.sort { $0.day < $1.day }
        }
        persist()
    }

    func deleteCalculatorResult(id: UUID) {
        calculatorResults.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Side effects

    /// Adds the entry, or updates it if it's already saved.
    func save(_ entry: SideEffectEntry) {
        if let index = sideEffects.firstIndex(where: { $0.id == entry.id }) {
            sideEffects[index] = entry
        } else {
            sideEffects.append(entry)
        }
        sideEffects.sort { $0.date < $1.date }
        HapticFeedback.selection()
        persist()
    }

    func deleteSideEffect(id: UUID) {
        sideEffects.removeAll { $0.id == id }
        persist()
    }

    /// Side effects logged in the last `days` days, newest first.
    func sideEffects(lastDays days: Int, now: Date = .now) -> [SideEffectEntry] {
        let start = now.startOfDay.adding(days: -(days - 1))
        return sideEffects.filter { $0.day >= start && $0.date <= now }.reversed()
    }

    /// Patterns across every logged side effect.
    func sideEffectPatterns() -> [SideEffectPattern] {
        var doseDays: [UUID: [Date]] = [:]
        for log in doseLogs where log.isTaken {
            doseDays[log.medicineID, default: []].append(log.day)
        }
        doseDays = doseDays.mapValues { Array(Set($0)) }
        let names = Dictionary(uniqueKeysWithValues: medicines.map { ($0.id, $0.name) })
        return SideEffectPattern.patterns(entries: sideEffects, doseDays: doseDays, medicineNames: names)
    }

    // MARK: - Sharps container

    /// Injections ticked off since the container was last emptied.
    var sharpsUsed: Int {
        let since = settings.sharpsEmptiedAt ?? .distantPast
        let injections = Set(medicines.filter { $0.type == .injection }.map(\.id))
        return doseLogs.filter { log in
            guard let takenAt = log.takenAt else { return false }
            return takenAt >= since && injections.contains(log.medicineID)
        }.count
    }

    /// How full the container is, 0–1.
    var sharpsFraction: Double {
        min(1, Double(sharpsUsed) / Double(max(settings.sharpsCapacity, 1)))
    }

    func emptySharps(now: Date = .now) {
        settings.sharpsEmptiedAt = now
    }

    // MARK: - In-use life

    /// A new pen, vial or bottle was opened today.
    func markOpened(_ id: UUID, at date: Date = .now) {
        mutate(id) { $0.openedAt = date }
    }

    func setUsableDays(_ days: Int?, for id: UUID) {
        mutate(id) {
            $0.usableDaysAfterOpening = days
            if days != nil, $0.openedAt == nil { $0.openedAt = .now }
        }
    }

    func setPrepMinutes(_ minutes: Int?, for id: UUID) {
        mutate(id) { $0.prepMinutes = minutes }
    }

    /// Opened medicines past or near their in-use limit, soonest first.
    func medicinesNearDiscard(within days: Int = 2, now: Date = .now) -> [Medicine] {
        medicines
            .filter { ($0.daysUntilDiscard(now: now) ?? .max) <= days }
            .sorted { ($0.daysUntilDiscard(now: now) ?? 0) < ($1.daysUntilDiscard(now: now) ?? 0) }
    }

    // MARK: - Trip planner

    /// What to pack for a trip from `start` to `end` (inclusive): each
    /// scheduled medicine's doses and units, plus `spareDays` extra, and
    /// whether what's on hand by `start` covers it. Counting only.
    func tripSupply(from start: Date, to end: Date, spareDays: Int = 2, now: Date = .now) -> [TripSupplyLine] {
        let first = start.startOfDay
        let last = max(end.startOfDay, first)
        let tripDays = Calendar.current.days(from: first, to: last) + 1
        return medicines.compactMap { medicine in
            var doses = 0
            var day = first
            while day <= last.adding(days: spareDays) {
                if medicine.isScheduled(on: day) { doses += medicine.intakeTimes.count }
                day = day.adding(days: 1)
            }
            guard doses > 0 else { return nil }
            let units = doses * medicine.unitsPerIntake
            // Use between now and the trip comes out of what's on hand.
            var usedBefore = 0
            var d = now.startOfDay
            while d < first {
                if medicine.isScheduled(on: d) { usedBefore += medicine.perDay }
                d = d.adding(days: 1)
            }
            // Counted from this morning's supply, like days left.
            let onHandAtStart = max(0, medicine.stock + medicine.unitsTakenToday - usedBefore)
            return TripSupplyLine(medicine: medicine, tripDays: tripDays, doses: doses, units: units, onHandAtStart: onHandAtStart)
        }
        .sorted { ($0.isShort ? 0 : 1, $0.medicine.name) < ($1.isShort ? 0 : 1, $1.medicine.name) }
    }

    // MARK: - Data management

    func loadSampleData(now: Date = .now) {
        let sample = SampleData.snapshot(now: now, settings: settings)
        medicines = sample.medicines
        doseLogs = sample.doseLogs
        refills = sample.refills
        contacts = sample.contacts
        checkIns = sample.checkIns
        weights = sample.weights
        sideEffects = sample.sideEffects
        lastCountdownDay = sample.lastCountdownDay
        didChange()
    }

    /// Settings → Delete all data: everything, settings and profile photo
    /// included, as if the app were new.
    func eraseEverything() {
        ProfilePhoto.remove()
        settings = AppSettings()
        deleteAllData()
    }

    func deleteAllData() {
        medicines = []
        doseLogs = []
        refills = []
        contacts = []
        checkIns = []
        weights = []
        calculatorResults = []
        sideEffects = []
        lastCountdownDay = nil
        didChange()
    }

    /// "Taken" on a dose reminder: ticks that dose if it isn't already.
    func markTaken(medicineID: UUID, day: Date, minutes: Int) {
        guard let dose = doses(on: day).first(where: {
            $0.medicine.id == medicineID && $0.time.minutesSinceMidnight == minutes
        }), !dose.isTaken else { return }
        toggle(dose)
    }

    // MARK: - Shared with widgets

    /// Picks up doses and moods logged from a widget while the app was in
    /// the background. Runs whenever the app comes to the foreground.
    func reloadFromDisk() {
        let snapshot = repository.load()
        guard snapshot.doseLogs != doseLogs || snapshot.checkIns != checkIns || snapshot.medicines.map(\.stock) != medicines.map(\.stock) else { return }
        medicines = snapshot.medicines
        doseLogs = snapshot.doseLogs
        checkIns = snapshot.checkIns
        lastSaved = snapshot
        refreshTodayUsage()
        rescheduleReminders()
        DoseActivityController.refresh(store: self)
        QueryClient.shared.invalidate([.medicines, .doses, .moods])
    }

    // MARK: - Plumbing

    private func mutate(_ id: UUID, save: Bool = true, _ change: (inout Medicine) -> Void) {
        guard let index = medicines.firstIndex(where: { $0.id == id }) else { return }
        change(&medicines[index])
        if save { didChange() }
    }

    private func didChange() {
        refreshTodayUsage()
        persist()
        rescheduleReminders()
        DoseActivityController.refresh(store: self)
    }

    private func refreshTodayUsage(now: Date = .now) {
        let today = now.startOfDay
        var used: [UUID: Int] = [:]
        for log in doseLogs where log.day == today && log.isTaken {
            used[log.medicineID, default: 0] += log.units
        }
        for index in medicines.indices {
            let units = used[medicines[index].id, default: 0]
            if medicines[index].unitsTakenToday != units { medicines[index].unitsTakenToday = units }
        }
    }

    private func persist() {
        let snapshot = MedicineSnapshot(
            medicines: medicines,
            doseLogs: doseLogs,
            refills: refills,
            settings: settings,
            lastCountdownDay: lastCountdownDay,
            contacts: contacts,
            checkIns: checkIns,
            weights: weights,
            calculatorResults: calculatorResults,
            sideEffects: sideEffects
        )
        QueryClient.shared.invalidate(changedTags(from: lastSaved, to: snapshot))
        lastSaved = snapshot
        repository.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Which kinds of data differ between two saves.
    private func changedTags(from old: MedicineSnapshot?, to new: MedicineSnapshot) -> Set<QueryTag> {
        guard let old else { return Set(QueryTag.allCases) }
        var tags = Set<QueryTag>()
        if old.medicines != new.medicines { tags.insert(.medicines) }
        if old.doseLogs != new.doseLogs { tags.insert(.doses) }
        if old.refills != new.refills { tags.insert(.refills) }
        if old.settings != new.settings { tags.insert(.settings) }
        if old.contacts != new.contacts { tags.insert(.contacts) }
        if old.checkIns != new.checkIns { tags.insert(.moods) }
        if old.weights != new.weights { tags.insert(.weights) }
        if old.calculatorResults != new.calculatorResults { tags.insert(.calculators) }
        if old.sideEffects != new.sideEffects { tags.insert(.sideEffects) }
        return tags
    }

    private var rescheduleTask: Task<Void, Never>?

    /// "Refresh reminder times": re-plans every notification now, without
    /// the usual short wait.
    func refreshReminders() async {
        rescheduleTask?.cancel()
        await scheduler.reschedule(medicines: medicines, settings: settings, takenDoseIDs: takenDoseIDs, siteLastUsed: lastUsed())
    }

    /// Doses already ticked off from today on, so they get no reminder.
    var takenDoseIDs: Set<String> {
        let today = Date.now.startOfDay
        return Set(doseLogs.filter { $0.isTaken && $0.day >= today }.map {
            "\($0.medicineID)-\($0.day.timeIntervalSince1970)-\($0.time.minutesSinceMidnight)"
        })
    }

    /// Coalesces bursts of changes (e.g. "Take all 3") into one re-plan.
    func rescheduleReminders() {
        rescheduleTask?.cancel()
        let medicines = medicines
        let settings = settings
        let takenDoseIDs = takenDoseIDs
        let siteLastUsed = lastUsed()
        rescheduleTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await scheduler.reschedule(medicines: medicines, settings: settings, takenDoseIDs: takenDoseIDs, siteLastUsed: siteLastUsed)
        }
    }
}

// MARK: - Previews

extension MedicineStore {
    static func preview(sample: Bool = true) -> MedicineStore {
        let snapshot = sample ? SampleData.snapshot(now: .now, settings: AppSettings()) : MedicineSnapshot()
        return MedicineStore(repository: InMemoryMedicineRepository(snapshot))
    }
}
