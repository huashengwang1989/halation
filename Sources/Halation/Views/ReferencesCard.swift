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
                    Button(loc("refs.addFiles"), systemImage: "plus") { openPanel() }
                    if !spec.references.isEmpty {
                        Button(loc("refs.removeAll"), role: .destructive) { spec.references = [] }
                    }
                    if spec.mode == .reference, !missingTags.isEmpty {
                        Button(missingTags.count == 1 ? loc("refs.insertTag") : loc("refs.insertTags"),
                               systemImage: "text.badge.plus") { insertMissingTags() }
                            .help(loc("refs.insertTags.help", missingTags.joined(separator: ", ")))
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
        spec.mode == .reference ? loc("refs.title.references") : loc("refs.title.keyframes")
    }

    private var footnote: String {
        switch spec.mode {
        case .firstFrame: loc("refs.footnote.first")
        case .firstAndLastFrame: loc("refs.footnote.firstlast")
        case .reference: loc("refs.footnote.reference")
        case .textToVideo: ""
        }
    }

    /// Reference tags the prompt has not used yet. H3 conditions on references
    /// through these, so an untagged reference is largely wasted.
    private var missingTags: [String] {
        guard spec.mode == .reference else { return [] }
        let images = spec.references.filter { $0.kind == .image }
        return images.indices
            .map { "<Picture \($0 + 1)>" }
            .filter { !spec.prompt.contains($0) }
    }

    private func insertMissingTags() {
        let tags = missingTags.joined(separator: " ")
        guard !tags.isEmpty else { return }
        let trimmed = spec.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        spec.prompt = trimmed.isEmpty ? tags : trimmed + " " + tags
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = spec.mode == .reference
        panel.canChooseDirectories = false
        panel.allowedContentTypes = spec.mode == .reference
            ? [.image, .movie, .audio]
            : [.image]
        panel.message = spec.mode == .reference
            ? loc("refs.choose.any")
            : loc("refs.choose.image")
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
            Text(loc("refs.drop"))
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
            .accessibilityLabel(loc("refs.remove", asset.url.lastPathComponent))
        }
        .help(asset.url.path)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(asset.slot == .reference ? asset.kind.label : asset.slot.label): "
                            + "\(asset.url.lastPathComponent)")
    }
}
