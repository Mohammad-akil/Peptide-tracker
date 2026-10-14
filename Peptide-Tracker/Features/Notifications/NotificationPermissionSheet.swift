import SwiftUI

/// "Get a heads-up before you run out" — explains the one notification we
/// send before the system permission prompt.
struct NotificationPermissionSheet: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            IllustrationView(.notifications)
                .padding(.top, 22)

            Text("Get a heads-up before you run out")
                .font(.system(size: 24, weight: .bold))
                .kerning(-0.3)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.bottom, 8)
            Text("One reminder a few days before each medicine runs out, at the time you picked. Nothing else.")
                .font(.system(size: 16))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 22)

            Button("Turn on reminders") {
                Task {
                    let granted = await store.scheduler.requestAuthorization()
                    store.settings.notificationsEnabled = granted
                    dismiss()
                }
            }
            .buttonStyle(.primary)

            Button("Not now") {
                // Keeps Settings honest; it can be turned on from there later.
                store.settings.notificationsEnabled = false
                dismiss()
            }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(height: 50)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }
}

/// A lock-screen style notification, for showing what a reminder looks like.
struct NotificationPreview: View {
    let title: String
    let time: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Icon(.pill, size: 21)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(AppTheme.ColorToken.accent, in: .rect(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Spacer(minLength: 8)
                    Text(time).font(.system(size: 13)).foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Text("Tap to refill.").font(.system(size: 15))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example notification: \(title). Tap to refill.")
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        NotificationPermissionSheet()
            .presentationDetents([.medium])
    }
    .environment(MedicineStore.preview())
}
