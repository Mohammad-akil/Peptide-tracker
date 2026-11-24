import SwiftUI

/// The pill in the corner of Get started: the current language's flag and
/// code. Opens `LanguagePickerSheet`.
struct LanguageChip: View {
    var action: () -> Void
    @AppStorage(AppLanguage.storageKey) private var languageRaw = ""

    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .deviceDefault }

    var body: some View {
        Button {
            HapticFeedback.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: language.flag)
                Text(verbatim: language.shortCode)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.ColorToken.primaryText)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .compatGlass(interactive: true, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Language"))
        .accessibilityValue(Text(verbatim: language.nativeName))
    }
}

/// Every language Doseday ships. Tapping a row selects it; the check in the
/// toolbar closes the sheet and then switches the app.
struct LanguagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MedicineStore.self) private var store
    @AppStorage(AppLanguage.storageKey) private var languageRaw = ""

    @State private var pending: AppLanguage?

    private var current: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .deviceDefault }
    private var selected: AppLanguage { pending ?? current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, language in
                        row(language, showsDivider: index < AppLanguage.allCases.count - 1)
                    }
                }
                .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .tint(AppTheme.ColorToken.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply", systemImage: "checkmark") { confirm() }
                        .labelStyle(.iconOnly)
                        .tint(AppTheme.ColorToken.accent)
                }
            }
        }
        .presentationDetents([.large])
    }

    /// Closes the sheet first, then switches, so the redraw doesn't happen
    /// under the dismissal. Reminders are rescheduled in the new language.
    private func confirm() {
        let chosen = selected
        dismiss()
        guard chosen != current || languageRaw.isEmpty else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            AppLanguage.apply(chosen)
            languageRaw = chosen.rawValue
            store.rescheduleReminders()
        }
    }

    private func row(_ language: AppLanguage, showsDivider: Bool) -> some View {
        Button {
            HapticFeedback.selection()
            pending = language
        } label: {
            HStack(spacing: 14) {
                Text(verbatim: language.flag)
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: language.nativeName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                    if language.localizedName != language.nativeName {
                        Text(verbatim: language.localizedName)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: language == selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(language == selected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryText.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .contentShape(.rect)
            .rowDivider(showsDivider, inset: 56)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityAddTraits(language == selected ? .isSelected : [])
    }
}
