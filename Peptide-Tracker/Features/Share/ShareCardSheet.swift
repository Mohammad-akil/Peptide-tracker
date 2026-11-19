import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The share sheet (same design as Plates): a swipeable carousel of cards,
/// a Story/Post switch in the top bar, theme swatches, and Save / Share
/// buttons that export the selected card as a 1080px-wide image.
struct ShareCardSheet: View {
    var title = "Share progress"
    var variants: [ShareCardVariant]
    /// The card to open on, if it's in `variants`.
    var initialID: String?
    var caption: String? = "Staying on track with Doseday."

    @Environment(\.dismiss) private var dismiss
    @AppStorage("shareCardFormat") private var formatRaw = ShareCardFormat.story.rawValue
    @AppStorage("shareCardTheme") private var themeRaw = ShareCardTheme.brand.rawValue
    @State private var selectedID: String?
    @State private var renderedImage: UIImage?
    @State private var isRenderStale = true
    @State private var saveState: SaveState = .idle
    @State private var showsPhotosAlert = false

    private enum SaveState: Equatable { case idle, saving, saved, failed }

    private var format: ShareCardFormat { ShareCardFormat(rawValue: formatRaw) ?? .story }
    private var theme: ShareCardTheme { ShareCardTheme(rawValue: themeRaw) ?? .brand }
    private var selectedVariant: ShareCardVariant? { variants.first { $0.id == selectedID } ?? variants.first }
    private var selectedIndex: Int { variants.firstIndex { $0.id == selectedVariant?.id } ?? 0 }
    private var renderKey: String { "\(selectedVariant?.id ?? "")-\(formatRaw)-\(themeRaw)" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                carousel
                    .frame(maxHeight: .infinity)
                    .animation(.smooth(duration: 0.3), value: formatRaw)

                VStack(spacing: 8) {
                    if let selectedVariant {
                        Label(selectedVariant.name, systemImage: selectedVariant.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 0.3), value: selectedVariant.id)
                    }
                    if variants.count > 1 { pageDots }
                }

                themePicker
                actionButtons
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .background(AppTheme.ColorToken.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CompatToolbarRoleButton(role: .close) { dismiss() }
                        .tint(AppTheme.ColorToken.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) { formatButton }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if selectedID == nil {
                selectedID = variants.first { $0.id == initialID }?.id ?? variants.first?.id
            }
        }
        .task(id: renderKey) {
            // Render once the swipe settles, so paging stays smooth.
            isRenderStale = true
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            renderedImage = render()
            isRenderStale = false
        }
        .onChange(of: renderKey) { _, _ in if saveState != .idle { saveState = .idle } }
        .alert("Allow Photos access", isPresented: $showsPhotosAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Doseday needs permission to add the card to your Photos.")
        }
    }

    // MARK: Controls

    /// Story (9:16) ↔ Post (4:5). The icon is the current canvas shape.
    private var formatButton: some View {
        let next: ShareCardFormat = format.isStory ? .post : .story
        return Button {
            HapticFeedback.selection()
            formatRaw = next.rawValue
        } label: {
            Label("Switch to \(next.label)", systemImage: format.isStory ? "rectangle.portrait" : "square")
                .contentTransition(.symbolEffect(.replace))
        }
        .labelStyle(.iconOnly)
        .tint(AppTheme.ColorToken.primaryText)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(variants.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex ? AppTheme.ColorToken.primaryText : AppTheme.ColorToken.uncheckedRing)
                    .frame(width: index == selectedIndex ? 18 : 6, height: 6)
            }
        }
        .animation(.snappy, value: selectedIndex)
    }

    private var themePicker: some View {
        HStack(spacing: 18) {
            ForEach(ShareCardTheme.allCases) { option in
                let isSelected = option == theme
                Button {
                    HapticFeedback.selection()
                    withAnimation(.easeInOut(duration: 0.25)) { themeRaw = option.rawValue }
                } label: {
                    VStack(spacing: 6) {
                        option.swatch
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                            .overlay { Circle().stroke(AppTheme.ColorToken.separator, lineWidth: 1) }
                            .padding(3)
                            .overlay { Circle().stroke(isSelected ? AppTheme.ColorToken.accent : .clear, lineWidth: 2.5) }
                        Text(option.label)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? AppTheme.ColorToken.primaryText : AppTheme.ColorToken.secondaryText)
                            .fixedSize()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task { await saveToPhotos() }
            } label: {
                Label(saveLabel, systemImage: saveIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(.capsule)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.3), value: saveState)
            }
            .buttonStyle(.plain)
            .compatGlass(interactive: true, in: .capsule)
            .allowsHitTesting(saveState != .saving)

            Group {
                if let renderedImage {
                    ShareLink(
                        item: ShareCardPNG(image: renderedImage),
                        message: caption.map { Text($0) },
                        preview: SharePreview(selectedVariant?.name ?? title, image: Image(uiImage: renderedImage))
                    ) { shareLabel }
                    .simultaneousGesture(TapGesture().onEnded { HapticFeedback.impact() })
                } else {
                    shareLabel
                }
            }
            .buttonStyle(.plain)
            .compatGlass(tint: AppTheme.ColorToken.accent, interactive: true, in: .capsule)
            .allowsHitTesting(renderedImage != nil && !isRenderStale)
        }
    }

    private var shareLabel: some View {
        Label("Share", systemImage: "square.and.arrow.up")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(.capsule)
    }

    private var saveLabel: String {
        switch saveState {
        case .saved: "Saved"
        case .failed: "Try again"
        case .idle, .saving: "Save"
        }
    }

    private var saveIcon: String {
        switch saveState {
        case .saved: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle"
        case .idle, .saving: "arrow.down.to.line"
        }
    }

    // MARK: Carousel

    /// Neighbouring cards peek in and shrink/fade as they move off centre.
    private var carousel: some View {
        GeometryReader { proxy in
            let peek: CGFloat = 40
            let item = CGSize(width: max(proxy.size.width - peek * 2, 1), height: max(proxy.size.height - 16, 1))
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(variants) { variant in
                        preview(variant, in: item)
                            .frame(width: item.width, height: proxy.size.height)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(1 - abs(phase.value) * 0.12)
                                    .opacity(1 - abs(phase.value) * 0.45)
                            }
                            .id(Optional(variant.id))
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $selectedID, anchor: .center)
            .safeAreaPadding(.horizontal, peek)
            .scrollClipDisabled()
        }
        .sensoryFeedback(.selection, trigger: selectedID) { old, _ in old != nil }
    }

    /// The real card at its export size, scaled to fit.
    private func preview(_ variant: ShareCardVariant, in available: CGSize) -> some View {
        let size = format.size
        let scale = max(min(available.width / size.width, available.height / size.height), 0.1)
        return variant.card(format, theme)
            .frame(width: size.width, height: size.height)
            .background {
                if theme == .clear {
                    ShareCardCheckerboard(cell: 10, base: Color(white: 0.16), check: Color(white: 0.24))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22 / scale, style: .continuous))
            .scaleEffect(scale)
            .frame(width: size.width * scale, height: size.height * scale)
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Export

    private func render() -> UIImage? {
        guard let variant = selectedVariant else { return nil }
        let size = format.size
        let renderer = ImageRenderer(content: variant.card(format, theme).frame(width: size.width, height: size.height))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }

    private func saveToPhotos() async {
        guard let image = isRenderStale || renderedImage == nil ? render() : renderedImage,
              let data = image.pngData() else { return }
        saveState = .saving
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            HapticFeedback.notification(.error)
            saveState = .idle
            showsPhotosAlert = true
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            HapticFeedback.notification(.success)
            withAnimation { saveState = .saved }
            ReviewPrompter.happyMoment(.shareCardSaved)
        } catch {
            HapticFeedback.notification(.error)
            saveState = .failed
        }
    }
}

/// The card handed to the share sheet as PNG, so a Clear card stays
/// see-through in Instagram and Snapchat.
private struct ShareCardPNG: Transferable {
    var image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.image.pngData() ?? Data() }
    }
}

/// Opens the share sheet with all of today's moments, starting on `start`.
struct ShareMomentsButton: ViewModifier {
    @Environment(MedicineStore.self) private var store
    @Binding var isPresented: Bool
    var start: ShareMoment.Kind?

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            ShareCardSheet(variants: ShareMoment(store: store).variants, initialID: start?.rawValue)
        }
    }
}

extension View {
    func shareMoments(isPresented: Binding<Bool>, start: ShareMoment.Kind? = nil) -> some View {
        modifier(ShareMomentsButton(isPresented: isPresented, start: start))
    }
}
