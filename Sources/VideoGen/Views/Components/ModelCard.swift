import AppKit
import SwiftUI

/// The description of one catalogue entry: what it is, where it came from, which
/// file it is, and what it costs.
///
/// Shared by the Models list and the Compose summary, which differ only in what
/// they put around it — a status icon and action buttons on one side, a heading
/// on the other. Before this existed the Compose side showed a bare format name,
/// and several entries share a format, so the only way to find out what a render
/// would actually load was to leave Compose and go looking.
struct ModelCard<Footer: View>: View {
    var entry: CatalogEntry
    /// The blurb. Off where there is no room for it.
    var showsDescription: Bool = true
    /// Adds the "In use" pill. The caller decides, because what counts as in use
    /// depends on where the card is being shown.
    var isInUse: Bool = false
    /// Anything the surrounding context wants to say about this entry, placed
    /// where it will be read: after the description, before the sizes.
    @ViewBuilder var footer: () -> Footer

    @State private var isHoveringRepository = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.displayName).font(.callout.weight(.medium))
                // Which engine loads this. The two sets are not interchangeable,
                // and several entries exist only for one.
                TagPill(text: entry.backend.label,
                        tint: entry.backend == .comfyUI ? .purple : .blue)
                TagPill(text: entry.provenance.label)
                if !entry.isUsableHere {
                    TagPill(text: loc("models.notRunnable"), tint: .red)
                }
                if isInUse {
                    TagPill(text: loc("models.inUse"), tint: .accentColor)
                }
            }

            repositoryLine
            if let file = entry.comfyUIFile { fileLine(file) }

            if showsDescription {
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            footer()

            HStack(spacing: 10) {
                Label(Format.bytes(entry.approximateBytes), systemImage: "internaldrive")
                if let resident = entry.approximateResidentBytes {
                    Label(loc("models.inMemory", Format.bytes(resident)),
                          systemImage: "memorychip")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    /// The repository id *is* the model card — the card's URL is this string
    /// appended to huggingface.co — so it carries the link itself rather than
    /// sitting beside a separate one saying the same thing. Opening is on click,
    /// not on hover: a page that opened because the pointer crossed a row would be
    /// a surprise.
    private var repositoryLine: some View {
        HStack(spacing: 4) {
            Text(repositoryText)
                .onHover { isHoveringRepository = $0 }
                .help(entry.huggingFaceURL?.absoluteString ?? entry.repoID)
                .lineLimit(1)
                .truncationMode(.middle)
                // The bare id, for pasting into a download command; the button
                // beside it copies the full URL.
                .contextMenu {
                    Button(loc("models.copyRepoID")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.repoID, forType: .string)
                    }
                }
            if let card = entry.huggingFaceURL {
                CopyButton(value: card.absoluteString, help: loc("models.copyLink"))
            }
            Spacer(minLength: 0)
        }
        .font(.caption2)
    }

    /// For ComfyUI weights the repository is not enough to find the thing: one
    /// repository holds every file, and what matters is which one, and which
    /// folder it has to land in.
    private func fileLine(_ file: CatalogEntry.ComfyUIFile) -> some View {
        HStack(spacing: 4) {
            Text("\(file.folder)/\(file.filename)")
                // System purple, so it holds up in both appearances rather than
                // being a hand-picked shade tuned to one.
                .foregroundStyle(.purple)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            // The name alone, without the folder: that is what a download command
            // or a file dialog wants.
            CopyButton(value: file.filename, help: loc("models.copyFilename"))
            Spacer(minLength: 0)
        }
        .font(.caption2.monospaced())
    }

    /// Underlined and a shade stronger while the pointer is over it, the way a
    /// link behaves everywhere else.
    ///
    /// The link lives on the string rather than in a `Link` view so the hover
    /// styling can be driven from state. Text selection is deliberately not
    /// enabled alongside it: the two are mutually exclusive in SwiftUI, and both
    /// were measured — with the link a double-click selects nothing, and with
    /// `.textSelection` an `onTapGesture` never fires, because selection consumes
    /// the click. The copy button and the context menu cover wanting the text.
    private var repositoryText: AttributedString {
        var text = AttributedString(entry.repoID)
        text.link = entry.huggingFaceURL
        text.foregroundColor = Color(nsColor: .linkColor).opacity(isHoveringRepository ? 1 : 0.8)
        if isHoveringRepository { text.underlineStyle = .single }
        return text
    }
}

extension ModelCard where Footer == EmptyView {
    init(entry: CatalogEntry, showsDescription: Bool = true, isInUse: Bool = false) {
        self.init(entry: entry, showsDescription: showsDescription, isInUse: isInUse) {
            EmptyView()
        }
    }
}
