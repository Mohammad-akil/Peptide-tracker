import PhotosUI
import SwiftUI

/// The top of Settings: the user's photo in a circle with their Pro or Free
/// badge on its bottom edge, and their name under it. Tapping the photo
/// picks or removes one; tapping the name edits it; tapping Free opens Pro.
struct ProfileHeader: View {
    @Environment(MedicineStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(AppRouter.self) private var router
    @State private var photo: UIImage?
    @State private var pickedItem: PhotosPickerItem?
    @State private var showsPicker = false
    @State private var isEditingName = false
    @State private var nameDraft = ""

    private static let size: CGFloat = 104

    var body: some View {
        VStack(spacing: 18) {
            avatarMenu
                .overlay(alignment: .bottom) {
                    badge.offset(y: 11)
                }

            Button {
                nameDraft = store.settings.userName
                isEditingName = true
            } label: {
                Text(name.isEmpty ? "Add your name" : name)
                    .font(.system(size: 24, weight: .bold))
                    .kerning(-0.3)
                    .foregroundStyle(name.isEmpty ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit your name")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear { photo = ProfilePhoto.load() }
        .photosPicker(isPresented: $showsPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let saved = ProfilePhoto.save(data) {
                    withAnimation(.snappy) { photo = saved }
                }
                pickedItem = nil
            }
        }
        .alert("Your name", isPresented: $isEditingName) {
            TextField("Name", text: $nameDraft)
                .textInputAutocapitalization(.words)
                .textContentType(.name)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                withAnimation(.snappy) {
                    store.settings.userName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }

    private var name: String {
        store.settings.userName.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Photo

    /// With a photo: choose another or remove it. Without: straight to the picker.
    @ViewBuilder
    private var avatarMenu: some View {
        if photo != nil {
            Menu {
                Button("Choose photo", systemImage: "photo.on.rectangle") { showsPicker = true }
                Button("Remove photo", systemImage: "trash", role: .destructive) {
                    ProfilePhoto.remove()
                    withAnimation(.snappy) { photo = nil }
                }
            } label: {
                avatar
            }
            .accessibilityLabel("Profile photo")
        } else {
            Button { showsPicker = true } label: { avatar }
                .buttonStyle(.plain)
                .accessibilityLabel("Add profile photo")
        }
    }

    private var avatar: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                LinearGradient(colors: [Color(hex: 0x8A6CF0), AppTheme.ColorToken.accent], startPoint: .top, endPoint: .bottom)
                if let initials {
                    Text(initials)
                        .font(.system(size: Self.size * 0.38, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: Self.size * 0.42))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: Self.size, height: Self.size)
        .clipShape(.circle)
        // A white ring, so the badge and photo sit apart from the ground.
        .overlay { Circle().strokeBorder(AppTheme.ColorToken.cardBackground, lineWidth: 4) }
        .shadow(color: Color(hex: 0x28185A, opacity: 0.14), radius: 14, y: 8)
        .overlay(alignment: .topTrailing) {
            // A small camera mark until there's a photo.
            if photo == nil {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.ColorToken.cardBackground, in: .circle)
                    .shadow(color: Color(hex: 0x28185A, opacity: 0.12), radius: 6, y: 3)
                    .offset(x: 2, y: 2)
            }
        }
    }

    /// "AK" from "Mohammad Akil"; nil until there's a name.
    private var initials: String? {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? nil : String(letters).uppercased()
    }

    // MARK: Badge

    @ViewBuilder
    private var badge: some View {
        if purchases.isPro {
            Label("PRO", systemImage: "crown.fill")
                .font(.system(size: 12, weight: .heavy))
                .kerning(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    LinearGradient(colors: [Color(hex: 0xFFC94D), Color(hex: 0xF29A1F)], startPoint: .top, endPoint: .bottom),
                    in: .capsule
                )
                .overlay { Capsule().strokeBorder(AppTheme.ColorToken.cardBackground, lineWidth: 2.5) }
                .accessibilityLabel("Pro member")
        } else {
            Button { router.sheet = .paywall(reason: nil) } label: {
                Text("FREE")
                    .font(.system(size: 12, weight: .heavy))
                    .kerning(0.6)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 24)
                    .background(AppTheme.ColorToken.cardBackground, in: .capsule)
                    .overlay { Capsule().strokeBorder(AppTheme.ColorToken.separator, lineWidth: 1) }
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Free plan. Upgrade to Pro")
        }
    }
}

#Preview {
    ProfileHeader()
        .environment(MedicineStore.preview())
        .environment(PurchaseStore())
        .environment(AppRouter())
        .background(AppTheme.ColorToken.background)
}
