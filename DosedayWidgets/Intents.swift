import AppIntents
import WidgetKit

/// The tick button on a dose in the Today widgets. Runs in the widget,
/// writes straight to the shared data, and the widget redraws at once.
struct ToggleDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Tick off a dose"
    static let isDiscoverable = false

    @Parameter(title: "Medicine") var medicineID: String
    @Parameter(title: "Minutes after midnight") var minutes: Int

    init() {}

    init(medicineID: String, minutes: Int) {
        self.medicineID = medicineID
        self.minutes = minutes
    }

    func perform() async throws -> some IntentResult {
        try SharedData.toggleDose(medicineID: medicineID, minutes: minutes)
        return .result()
    }
}

/// A face on the Mood widget: logs today's mood.
struct LogMoodIntent: AppIntent {
    static let title: LocalizedStringResource = "Log today's mood"
    static let isDiscoverable = false

    @Parameter(title: "Mood") var mood: Int

    init() {}

    init(mood: Int) {
        self.mood = mood
    }

    func perform() async throws -> some IntentResult {
        try SharedData.logMood(mood)
        return .result()
    }
}
