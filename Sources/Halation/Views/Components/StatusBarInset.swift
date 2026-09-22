import SwiftUI

/// The status bar's measured height, published from `StatusBar` up to `RootView`.
struct StatusBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension EnvironmentValues {
    /// How much of the window's bottom edge the status bar covers.
    @Entry var statusBarHeight: CGFloat = 0
}

extension View {
    /// Keeps a scrollable's content clear of the status bar.
    ///
    /// Necessary because `.safeAreaInset(edge: .bottom)` on a
    /// `NavigationSplitView` does not inset the detail at all — the bar is drawn
    /// *over* the content, and the detail's own `safeAreaInsets.bottom` stays at
    /// zero however tall the bar gets. Measured in a reduction of this window:
    ///
    /// ```
    /// bar height 25 -> detail safeAreaInsets.bottom = 0.0, last row overlapped by 25
    /// bar height 55 -> detail safeAreaInsets.bottom = 0.0, last row overlapped by 55
    /// ```
    ///
    /// So the overlap is not a stale inset that fails to grow: there is no inset
    /// at any size. It goes unnoticed while the bar is one line only because a
    /// card's own bottom padding happens to be deeper than the bar is tall. As
    /// soon as a render starts and the bar takes a second line — or a language
    /// with taller metrics does the same — the last line of content disappears
    /// underneath it.
    ///
    /// Supplying the margin here puts the number under our control, and the same
    /// reduction confirms it lands exactly: overlap +0.0 at both heights.
    func statusBarInset() -> some View {
        modifier(StatusBarInset())
    }
}

private struct StatusBarInset: ViewModifier {
    @Environment(\.statusBarHeight) private var height

    func body(content: Content) -> some View {
        content.contentMargins(.bottom, height, for: .scrollContent)
    }
}
