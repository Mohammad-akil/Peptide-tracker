import SwiftUI

/// Common questions, each opening in place, and a way to reach support.
struct HelpSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var openQuestion: String?

    private struct Topic {
        let title: String
        let questions: [(question: String, answer: String)]
    }

    private let topics: [Topic] = [
        Topic(title: String(localized: "Reminders"), questions: [
            (String(localized: "How do refill reminders work?"),
             String(localized: "We work out when each medicine runs out from what you have and how much you take a day. The heads-up comes a few days before, at your reminder time. Change the default in Settings → Reminders, or one medicine’s from its page.")),
            (String(localized: "Why am I not getting notifications?"),
             String(localized: "Check that Notifications is on in Settings → Reminders, and that notifications are allowed for this app in the iPhone’s Settings. Focus modes can hold them back too. If times look wrong after travelling, use Refresh reminder times in Settings → Notifications.")),
            (String(localized: "How do I stop reminders while a refill is on its way?"),
             String(localized: "Open the medicine and tap Ordered. Reminders pause until you tap Refilled when you pick it up.")),
        ]),
        Topic(title: String(localized: "Doses and supply"), questions: [
            (String(localized: "Why did my count go down when I didn’t tick a dose?"),
             String(localized: "So your supply stays right even on days you forget to tick. At the end of each day, any dose left unticked is counted as used. Turn off Track doses in Settings → Doses to count down from your schedule alone.")),
            (String(localized: "How do I fix my pill count?"),
             String(localized: "Open the medicine, tap ••• and choose Correct count. Enter what you have now; it doesn’t log a refill.")),
            (String(localized: "How does injection site rotation work?"),
             String(localized: "When you tick off an injection, pick where it went on the body map. We suggest the next site in turn, alternating sides, and grey out sites used in the last three days so each one rests.")),
        ]),
        Topic(title: String(localized: "Your data"), questions: [
            (String(localized: "Where is my data kept?"),
             String(localized: "On this iPhone and, with iCloud sync on, in your private iCloud. There’s no account and nothing is sent to us. Deleting the app removes it from this iPhone; your iCloud copy stays until you delete it.")),
            (String(localized: "How do I share my medicines with my doctor?"),
             String(localized: "Settings → Export medicine list makes a PDF of every medicine and its schedule. Settings → Report shares how you’ve been doing with your doses.")),
            (String(localized: "Can I track medicines for someone else?"),
             String(localized: "Yes. In Settings → Tracking for, choose someone you care for and add their name. Reminders then say whose medicine it is.")),
        ]),
        Topic(title: String(localized: "Pro"), questions: [
            (String(localized: "What does Pro include?"),
             String(localized: "Doseday is a subscription app. Pro unlocks everything: dose reminders and tracking, injection sites, weight and goal progress, side effects, reports and PDF exports, with as many medicines as you take.")),
            (String(localized: "How do I restore a purchase?"),
             String(localized: "On the subscription screen that opens with the app, tap Restore. Use the same Apple Account you subscribed with.")),
            (String(localized: "How do I cancel?"),
             String(localized: "In the iPhone’s Settings app, tap your name, then Subscriptions, then Doseday. You keep Pro until the end of the period you paid for.")),
        ]),
    ]

    var body: some View {
        SettingsPageScaffold(page: .help) {
            ForEach(topics, id: \.title) { topic in
                GroupedSection(title: topic.title) {
                    ForEach(Array(topic.questions.enumerated()), id: \.element.question) { index, item in
                        QuestionRow(
                            question: item.question,
                            answer: item.answer,
                            isOpen: openQuestion == item.question,
                            showsDivider: index < topic.questions.count - 1
                        ) {
                            HapticFeedback.selection()
                            withAnimation(.snappy) {
                                openQuestion = openQuestion == item.question ? nil : item.question
                            }
                        }
                    }
                }
            }

            GroupedSection(title: String(localized: "Still need help?")) {
                Button { openURL(AppLinks.support) } label: {
                    SettingsRowLabel(symbol: "lifepreserver.fill", tint: Color(hex: 0xFF375F), title: String(localized: "Contact support"), showsChevron: true)
                }
                .buttonStyle(RowPressStyle())
            }
        }
    }
}

/// A question that opens to show its answer, with the chevron turning down.
private struct QuestionRow: View {
    let question: String
    let answer: String
    let isOpen: Bool
    let showsDivider: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Text(question)
                        .font(.system(size: 17, weight: isOpen ? .semibold : .regular))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    DisclosureMark(isOpen: isOpen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(.rect)
            }
            .buttonStyle(RowPressStyle())
            .accessibilityAddTraits(isOpen ? .isSelected : [])

            if isOpen {
                Text(answer)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
        .rowDivider(showsDivider)
    }
}

#Preview {
    NavigationStack { HelpSettingsView() }
}
