import SwiftUI

/// Help ▸ Licenses.
///
/// The text is English only, deliberately. A licence summary that drifts from
/// what it summarises is worse than no summary, and five translations are five
/// chances to drift; the authoritative documents are LICENSE and NOTICE in the
/// repository, both in English. Only the window's chrome is localized.
struct LicensesView: View {
    private struct Entry: Identifiable {
        let id = UUID()
        let name: String
        let licence: String
        let detail: String
        var url: String?
    }

    /// Kept in step with NOTICE by hand. There are six of them and they change
    /// about once a year, so generating this from the file would cost more than
    /// it saves.
    private let thirdParty: [Entry] = [
        .init(name: "minimax-h3-mlx", licence: "Apache License 2.0",
              detail: "The Apple-silicon port of MiniMax H3, imported by the Python sidecar.",
              url: "https://github.com/PipeNetwork/minimax-h3-mlx"),
        .init(name: "ComfyUI", licence: "GNU General Public License v3.0",
              detail: "Cloned into Application Support and run as a separate process, driven "
                    + "over HTTP. It is not linked into Halation and is not redistributed by it.",
              url: "https://github.com/comfyanonymous/ComfyUI"),
        .init(name: "ComfyUI workflow templates", licence: "MIT License",
              detail: "The render graph is derived from this project's own H3 template."),
        .init(name: "ffmpeg", licence: "LGPL-2.1+ or GPL-2.0+, depending on your build",
              detail: "Found on PATH if present and invoked as an external tool."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("Halation") {
                    Text("Copyright © 2026 Huasheng")
                    Text("GNU Affero General Public License v3.0")
                        .fontWeight(.medium)
                    Text("Halation is free software. You may redistribute and modify it under "
                       + "the terms of the AGPL, version 3 or later. It comes with no warranty. "
                       + "If you run a modified version over a network, the AGPL requires you to "
                       + "offer its source to the people using it.")
                    link("Read the full licence", "https://www.gnu.org/licenses/agpl-3.0.html")
                }

                Divider()

                section("Model weights are not part of this program") {
                    Text("Halation downloads weights from Hugging Face at your request. It does "
                       + "not contain or redistribute any of them. Each is licensed by whoever "
                       + "published it, and that agreement is between you and them.")
                    Text("MiniMax H3 in particular restricts where it may be used, and prohibits "
                       + "unlawful and pornographic output in every territory. A local run has no "
                       + "server-side filter, so complying is your responsibility.")
                        .foregroundStyle(.secondary)
                }

                Divider()

                section("Third-party software") {
                    Text("None of this is bundled. Each is fetched at runtime into your own "
                       + "Application Support folder and run from there.")
                        .foregroundStyle(.secondary)
                    ForEach(thirdParty) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.name).fontWeight(.medium)
                            Text(entry.licence).font(.callout).foregroundStyle(.secondary)
                            Text(entry.detail).font(.callout)
                            if let url = entry.url { link(url, url) }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .textSelection(.enabled)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 520, height: 560)
    }

    @ViewBuilder
    private func section(_ title: String,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func link(_ label: String, _ target: String) -> some View {
        Link(label, destination: URL(string: target)!)
            .font(.callout)
    }
}
