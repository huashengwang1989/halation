import SwiftUI

// Liquid Glass arrived in macOS 26, and everything this app takes from it is
// cosmetic: a material behind a card, a tint on the default button, a gap in a
// toolbar, a softened scroll edge. None of it carries meaning that would be
// lost, so on macOS 15 each one falls back to what the same control looked like
// before — the app looks its age there rather than not running at all.
//
// These wrappers are the only places `#available` appears. Call sites read the
// same on both systems, which is the point: a view should not have to know
// which OS it is drawing on.

extension View {

    /// A glass surface behind the content, or a material fill before macOS 26.
    ///
    /// `.regularMaterial` is the closest predecessor — it is what a card or a
    /// floating badge used, and it keeps the same "frosted over the content
    /// behind" reading that glass gives.
    @ViewBuilder
    func glassSurface(in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
    }

    /// The default action's style: glass-prominent, or bordered-prominent.
    ///
    /// Both are the accent-tinted, filled treatment their system reserves for
    /// the one button a sheet or a toolbar most expects to be pressed.
    @ViewBuilder
    func prominentButtonStyle() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// An ordinary raised control: glass, or bordered.
    @ViewBuilder
    func raisedButtonStyle() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Softens the fade where content meets the top of a scroll view.
    ///
    /// There is no equivalent before macOS 26; the content simply meets the
    /// edge, which is what every app did until then.
    @ViewBuilder
    func softScrollEdge(for edges: Edge.Set = .top) -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: edges)
        } else {
            self
        }
    }
}

/// A fixed gap between toolbar groups, where the system draws them as separate
/// clusters. Before macOS 26 a toolbar had no such concept, so the items simply
/// sit next to each other.
@ToolbarContentBuilder
func toolbarGap(_ placement: ToolbarItemPlacement = .automatic) -> some ToolbarContent {
    if #available(macOS 26, *) {
        ToolbarSpacer(.fixed, placement: placement)
    }
}
