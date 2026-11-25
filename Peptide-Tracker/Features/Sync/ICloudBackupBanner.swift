import SwiftUI

/// Settings' one-time "Back up to iCloud" banner. iCloud sync starts off;
/// this offers it once. "Turn on" opens the iCloud popup, which explains
/// what's stored before anything is uploaded. The ✕ hides the banner for
/// good, and it also goes away once iCloud sync is on. The iCloud sync page
/// in Settings can still turn it on later.
struct ICloudBackupBanner: View {
    private var sync: CloudSync { .shared }
    @AppStorage(Self.dismissedKey) private var isDismissed = false
    @State private var asksForConsent = false

    static let dismissedKey = "icloud.bannerDismissed"

    var body: some View {
        Group {
            if !isDismissed && !sync.isEnabled {
                banner
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.snappy, value: isDismissed)
        .animation(.snappy, value: sync.isEnabled)
        .iCloudConsentPopup(isPresented: $asksForConsent)
    }

    private var banner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: 0x32ADE6), in: .rect(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Back up to iCloud")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.trailing, 28)
                Text("Keep your medicines and history safe if you lose or change your phone.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Turn on") {
                    HapticFeedback.selection()
                    asksForConsent = true
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(AppTheme.ColorToken.accentSoft, in: .capsule)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button {
                HapticFeedback.selection()
                isDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .frame(width: 26, height: 26)
                    .background(AppTheme.ColorToken.controlFill, in: .circle)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(2)
            .accessibilityLabel("Close")
        }
    }
}

#Preview {
    ICloudBackupBanner()
        .padding()
        .background(AppTheme.ColorToken.background)
}
