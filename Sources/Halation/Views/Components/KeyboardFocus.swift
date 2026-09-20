import AppKit
import SwiftUI

/// Lets Tab and Shift-Tab move focus out of a multi-line text view.
///
/// `TextEditor` wraps `NSTextView`, which treats Tab as a character to insert
/// rather than as a focus command. In a form that traps keyboard and VoiceOver
/// users: once focus lands in the prompt there is no way out without a mouse.
///
/// We intercept Tab and drive AppKit's own key-view loop, so focus goes exactly
/// where the window would otherwise have sent it. Option-Tab is left alone, so a
/// literal tab character is still reachable.
private struct TabMovesFocus: ViewModifier {
    func body(content: Content) -> some View {
        content.onKeyPress(.tab, phases: .down) { press in
            // Option-Tab keeps the original meaning: insert a tab.
            guard !press.modifiers.contains(.option) else { return .ignored }
            guard let window = NSApp.keyWindow else { return .ignored }
            if press.modifiers.contains(.shift) {
                window.selectPreviousKeyView(nil)
            } else {
                window.selectNextKeyView(nil)
            }
            return .handled
        }
    }
}

extension View {
    /// Apply to multi-line text views so they do not trap keyboard focus.
    func tabMovesFocus() -> some View { modifier(TabMovesFocus()) }
}
