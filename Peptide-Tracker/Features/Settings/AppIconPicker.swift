import SwiftUI
import UIKit

/// The home-screen icons the user can pick. Classic is the primary icon;
/// the rest are alternate icon sets in the asset catalog ("AppIcon-Mint"…),
/// with small previews in Assets → IconPreviews.
enum AppIconOption: String, CaseIterable, Identifiable {
    case classic, midnight, daylight, lavender, mint, ocean, sunset, gold, mono, injection
    case aurora, roseGold, graphite, neon, emerald, sapphire

    var id: String { rawValue }

    var title: String { self == .roseGold ? "Rose Gold" : rawValue.capitalized }

    /// The name used in the asset catalog ("RoseGold").
    private var assetName: String { self == .roseGold ? "RoseGold" : rawValue.capitalized }

    /// The alternate icon's name, or nil for the primary icon.
    var iconName: String? { self == .classic ? nil : "AppIcon-\(assetName)" }

    var preview: Image { Image("IconPreview-\(assetName)") }

    /// How the picker groups them.
    enum Group: String, CaseIterable {
        case free = "Classic"
        case colors = "Colours"
        case premium = "Premium finishes"
    }

    var group: Group {
        switch self {
        case .classic, .midnight, .daylight: .free
        case .aurora, .roseGold, .graphite, .neon, .emerald, .sapphire: .premium
        default: .colors
        }
    }

    static var current: Self {
        guard let name = UIApplication.shared.alternateIconName else { return .classic }
        return allCases.first { $0.iconName == name } ?? .classic
    }
}

/// Settings → App icon: every icon as it looks on the home screen, with
/// the current one ringed. Picking one asks iOS to switch (iOS confirms
/// with its own alert).
struct AppIconPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection = AppIconOption.current
    @State private var errorMessage: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick how \(Bundle.main.appName) looks on your Home Screen.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(AppIconOption.Group.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                .padding(.leading, 4)
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(AppIconOption.allCases.filter { $0.group == group }) { option in
                                    tile(option)
                                }
                            }
                            .padding(16)
                            .groupedCard()
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.top, 8)
                .padding(.bottom, AppTheme.Spacing.large)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle("App icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CompatToolbarRoleButton(role: .close) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
            }
            .alert("Couldn’t change the icon", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.large])
    }

    private func tile(_ option: AppIconOption) -> some View {
        let isSelected = selection == option
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return Button { choose(option) } label: {
            VStack(spacing: 8) {
                option.preview
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(.black.opacity(0.06), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(AppTheme.ColorToken.accent, lineWidth: 3)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white, AppTheme.ColorToken.accent)
                                .offset(x: 4, y: -4)
                        }
                    }
                Text(option.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(.snappy, value: isSelected)
    }

    private func choose(_ option: AppIconOption) {
        HapticFeedback.selection()
        guard option != selection else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "This device doesn’t support changing the app icon."
            return
        }
        let previous = selection
        selection = option
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(option.iconName)
            } catch {
                selection = previous
                errorMessage = error.localizedDescription
            }
        }
    }
}
