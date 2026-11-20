import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Must match `Peptide-Tracker/Services/LiveActivity/DoseActivity.swift`
/// field for field: the app starts and updates the activity, this draws it.
nonisolated struct DoseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var medicineID: String?
        var minutes: Int
        var title: String
        var detail: String
        var dueAt: Date
        var symbol: String
        var taken: Int
        var total: Int
    }
}

/// The Live Activity's "Taken" button. Declared in the app too; as a Live
/// Activity intent the system runs the app's copy. This body is only a
/// fallback that ticks the dose straight in the shared file.
struct CompleteDoseActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark dose taken"
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

private let accent = Color(red: 0.42, green: 0.27, blue: 0.85)

/// Today's next dose on the Lock Screen and in the Dynamic Island: what,
/// when (counting down, then up once it's due), and a Taken button.
struct DoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseActivityAttributes.self) { context in
            LockScreenDoseView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
                .activitySystemActionForegroundColor(accent)
                .widgetURL(URL(string: "doseday://today"))
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: state.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if state.medicineID != nil {
                        DueText(date: state.dueAt)
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.title)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(state.detail)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        TakenButton(state: state)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: state.symbol)
                    .foregroundStyle(accent)
            } compactTrailing: {
                if state.medicineID != nil {
                    DueText(date: state.dueAt)
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .frame(maxWidth: 52)
                } else {
                    Image(systemName: "checkmark").foregroundStyle(.green)
                }
            } minimal: {
                Image(systemName: state.medicineID == nil ? "checkmark" : state.symbol)
                    .foregroundStyle(accent)
            }
            .widgetURL(URL(string: "doseday://today"))
        }
    }
}

private struct LockScreenDoseView: View {
    let state: DoseActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(accent, in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.medicineID == nil ? state.title : "Next: \(state.title)")
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                Text(state.detail)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(state.taken) of \(state.total) taken today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if state.medicineID != nil {
                VStack(alignment: .trailing, spacing: 6) {
                    DueText(date: state.dueAt)
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                    TakenButton(state: state)
                }
            }
        }
    }
}

/// Counts down to the dose, then up once it's due.
private struct DueText: View {
    let date: Date

    var body: some View {
        Text(date, style: .timer)
    }
}

private struct TakenButton: View {
    let state: DoseActivityAttributes.ContentState

    var body: some View {
        if let id = state.medicineID {
            Button(intent: CompleteDoseActivityIntent(medicineID: id, minutes: state.minutes)) {
                Label("Taken", systemImage: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
            }
            .tint(accent)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }
}

// MARK: - Control Center

/// Ticks off today's next dose from Control Center, the Lock Screen or the
/// Action button, without opening the app. The app picks it up next time
/// it comes to the foreground.
struct LogNextDoseControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Log next dose"
    static let description = IntentDescription("Ticks off your next dose due today.")

    func perform() async throws -> some IntentResult {
        try SharedData.toggleNextDose()
        return .result()
    }
}

struct LogNextDoseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.doseday.ios.logNextDose") {
            ControlWidgetButton(action: LogNextDoseControlIntent()) {
                Label("Log next dose", systemImage: "checkmark.circle.fill")
            }
        }
        .displayName("Log next dose")
        .description("Tick off your next dose without opening the app.")
    }
}
