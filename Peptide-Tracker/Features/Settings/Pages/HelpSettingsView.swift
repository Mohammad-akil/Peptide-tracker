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
        Topic(title: "Reminders", questions: [
            ("How do refill reminders work?",
             "We work out when each medicine runs out from what you have and how much you take a day. The heads-up comes a few days before, at your reminder time. Change the default in Settings → Reminders, or one medicine’s from its page."),
            ("Why am I not getting notifications?",
             "Check that Notifications is on in Settings → Reminders, and that notifications are allowed for this app in the iPhone’s Settings. Focus modes can hold them back too. If times look wrong after travelling, use Refresh reminder times in Settings → Notifications."),
            ("How do I stop reminders while a refill is on its way?",
             "Open the medicine and tap Ordered. Reminders pause until you tap Refilled when you pick it up."),
        ]),
        Topic(title: "Doses and supply", questions: [
            ("Why did my count go down when I didn’t tick a dose?",
             "So your supply stays right even on days you forget to tick. At the end of each day, any dose left unticked is counted as used. Turn off Track doses in Settings → Doses to count down from your schedule alone."),
            ("How do I fix my pill count?",
             "Open the medicine, tap ••• and choose Correct count. Enter what you have now; it doesn’t log a refill."),
            ("How does injection site rotation work?",
             "When you tick off an injection, pick where it went on the body map. We suggest the next site in turn, alternating sides, and grey out sites used in the last three days so each one rests."),
        ]),
        Topic(title: "Your data", questions: [
            ("Where is my data kept?",
             "Only on this iPhone. There’s no account and nothing is sent to us. Deleting the app deletes everything it saved, so export your medicine list first if you need it."),
            ("How do I share my medicines with my doctor?",
             "Settings → Export medicine list makes a PDF of every medicine and its schedule. Settings → Report shares how you’ve been doing with your doses."),
            ("Can I track medicines for someone else?",
             "Yes. In Settings → Tracking for, choose someone you care for and add their name. Reminders then say whose medicine it is."),
        ]),
        Topic(title: "Pro", questions: [
            ("What does Pro include?",
             "Pro tracks as many medicines as you take. The free plan covers \(PurchaseStore.freeMedicineLimit). Everything else works on both."),
            ("How do I restore a purchase?",
             "Open the Pro screen from Settings and tap Restore. Use the same Apple Account you bought Pro with."),
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

            GroupedSection(title: "Still need help?") {
                Button { openURL(AppLinks.support) } label: {
                    SettingsRowLabel(symbol: "lifepreserver.fill", tint: Color(hex: 0xFF375F), title: "Contact support", showsChevron: true)
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
