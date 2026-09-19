import SwiftUI
import UniformTypeIdentifiers

/// Keyframes for FL2VA, or the reference set for Ref2VA. Split into its own file
/// because it carries all the drag-and-drop and per-kind limit handling.
struct ReferencesCard: View {
    @Binding var spec: GenerationSpec
    @State private var isTargeted = false

    var body: some View {
        GlassCard(title: title, systemImage: "paperclip", footnote: footnote) {
            VStack(alignment: .leading, spacing: 12) {
                if spec.references.isEmpty {
                    DropWell(isTargeted: isTargeted, mode: spec.mode)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)],
                              spacing: 12) {
                        ForEach(spec.references) { asset in
                            ReferenceChip(asset: asset) { remove(asset) }
                        }
                    }
                }

                HStack {
                    Button("Add Files…", systemImage: "plus") { openPanel() }
                    if !spec.references.isEmpty {
                        Button("Remove All", role: .destructive) { spec.references = [] }
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dropDestination(for: URL.self) { urls, _ in
                add(urls)
                return true
            } isTargeted: { isTargeted = $0 }
        }
    }

    private var title: String {
        spec.mode == .reference ? "References" : "Keyframes"
    }

    private var footnote: String {
        switch spec.mode {
        case .firstFrame:
            "One image, used as the opening frame. The clip animates outward from it."
        case .firstAndLastFrame:
            "Two images. The first becomes frame one, the second the final frame, and H3 generates the motion between "
            + "them."
        case .reference:
            "Up to 9 images, 3 videos and 3 audio clips, 12 files in total. References define the subject, style or "
            + "voice"
            + "rather than an exact frame."
        case .textToVideo:
            ""
        }
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = spec.mode == .reference
        panel.canChooseDirectories = false
        panel.allowedContentTypes = spec.mode == .reference
            ? [.image, .movie, .audio]
            : [.image]
        panel.message = spec.mode == .reference
            ? "Choose reference images, videos or audio"
            : "Choose a keyframe image"
        if panel.runModal() == .OK { add(panel.urls) }
    }

    private func add(_ urls: [URL]) {
        for url in urls {
            guard let kind = Self.kind(of: url) else { continue }
            guard spec.mode == .reference || kind == .image else { continue }

            let slot: ReferenceAsset.Slot = switch spec.mode {
            case .firstFrame: .first
            case .firstAndLastFrame:
                spec.references.contains { $0.slot == .first } ? .last : .first
            default: .reference
            }

            // Respect the per-mode and per-kind ceilings instead of silently
            // accepting files the model will reject.
            let sameKind = spec.references.count { $0.kind == kind }
            if spec.mode == .reference {
                guard sameKind < kind.limit,
                      spec.references.count < ReferenceAsset.totalFileLimit else { continue }
            } else {
                guard spec.references.count < spec.mode.maxImages else { continue }
            }

            spec.references.append(ReferenceAsset(url: url, kind: kind, slot: slot))
        }
    }

    private func remove(_ asset: ReferenceAsset) {
        spec.references.removeAll { $0.id == asset.id }
        // Keep first/last consistent after a removal.
        if spec.mode == .firstAndLastFrame {
            for index in spec.references.indices {
                spec.references[index].slot = index == 0 ? .first : .last
            }
        }
    }

    private static func kind(of url: URL) -> ReferenceAsset.Kind? {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        return nil
    }
}

private struct DropWell: View {
    var isTargeted: Bool
    var mode: GenerationMode

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: mode.symbolName)
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Drop files here")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(isTargeted ? AnyShapeStyle(.tint.opacity(0.12))
                               : AnyShapeStyle(.quaternary.opacity(0.3)),
                    in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(isTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}

private struct ReferenceChip: View {
    var asset: ReferenceAsset
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.4))
                if asset.kind == .image, let image = NSImage(contentsOf: asset.url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: asset.kind.symbolName)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 74)
            .clipShape(.rect(cornerRadius: 8))

            Text(asset.slot == .reference ? asset.kind.label : asset.slot.label)
                .font(.caption2.weight(.medium))
            Text(asset.url.lastPathComponent)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .background(.quaternary.opacity(0.25), in: .rect(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Remove \(asset.url.lastPathComponent)")
        }
        .help(asset.url.path)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(asset.slot == .reference ? asset.kind.label : asset.slot.label): "
                            + "\(asset.url.lastPathComponent)")
    }
}
