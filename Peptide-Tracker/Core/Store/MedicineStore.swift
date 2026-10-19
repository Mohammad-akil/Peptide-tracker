import Foundation
import Observation

/// App-scoped store for medicines, dose logs and refills — created once at
/// the app root and read from the environment by every tab, the same shape
/// as Plates' feature stores. Every mutation persists and re-plans
/// notifications, so views never have to remember to.
@MainActor
@Observable
final class MedicineStore {
    private(set) var medicines: [Medicine]
    private(set) var doseLogs: [DoseLog]
    private(set) var refills: [RefillEvent]
    /// Doctors, carers and clinics, A–Z.
    private(set) var contacts: [HealthContact]
    /// One per day the user checked in, oldest first.
    private(set) var checkIns: [DailyCheckIn]
    var settings: AppSettings {
        didSet { didChange() }
    }

    private var lastCountdownDay: Date?
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
        settings = snapshot.settings
        lastCountdownDay = snapshot.lastCountdownDay
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
        let logs = Dictionary(
            doseLogs.filter { $0.day == day }.map { ("\($0.medicineID)-\($0.time.minutesSinceMidnight)", $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return medicines
            .filter { $0.createdAt.startOfDay <= day }
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

    /// Where the next injection should go: the site after the last one in
    /// the rotation, across every injection medicine, so two pens don't
    /// share a spot.
    func suggestedSite() -> InjectionSite {
        let last = doseLogs
            .filter { $0.site != nil && $0.takenAt != nil }
            .max { $0.takenAt! < $1.takenAt! }?
            .site
        guard let last, let index = InjectionSite.rotation.firstIndex(of: last) else {
            return InjectionSite.rotation[0]
        }
        return InjectionSite.rotation[(index + 1) % InjectionSite.rotation.count]
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

    // MARK: - Data management

    func loadSampleData(now: Date = .now) {
        let sample = SampleData.snapshot(now: now, settings: settings)
        medicines = sample.medicines
        doseLogs = sample.doseLogs
        refills = sample.refills
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
        lastCountdownDay = nil
        didChange()
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
        repository.save(MedicineSnapshot(
            medicines: medicines,
            doseLogs: doseLogs,
            refills: refills,
            settings: settings,
            lastCountdownDay: lastCountdownDay,
            contacts: contacts,
            checkIns: checkIns
        ))
    }

    private var rescheduleTask: Task<Void, Never>?

    /// "Refresh reminder times": re-plans every notification now, without
    /// the usual short wait.
    func refreshReminders() async {
        rescheduleTask?.cancel()
        await scheduler.reschedule(medicines: medicines, settings: settings)
    }

    /// Coalesces bursts of changes (e.g. "Take all 3") into one re-plan.
    func rescheduleReminders() {
        rescheduleTask?.cancel()
        let medicines = medicines
        let settings = settings
        rescheduleTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await scheduler.reschedule(medicines: medicines, settings: settings)
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
