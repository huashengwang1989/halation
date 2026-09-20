import Foundation

/// Whether the developer menu is shown.
///
/// This reads the same switch AppKit uses for its own Debug menu, rather than
/// inventing a second one, so the two can never disagree — turn on
///
///     defaults write -g _NS_4445425547 -bool true
///
/// and both appear together. The key name is hex for "DEBUG". It is private to
/// AppKit, which is acceptable for gating a developer menu and nothing else: if
/// Apple ever renames it, our menu quietly disappears alongside AppKit's, which
/// is the correct failure. Nothing a user relies on should be behind it.
///
/// UserDefaults searches the global domain, so no per-app setting is needed.
/// Both narrower scopes still work if you want them, and the argument domain
/// outranks everything, which makes a single run easy to flip either way:
///
///     defaults write com.local.halation _NS_4445425547 -bool true   # this app
///     open -a Halation --args -_NS_4445425547 NO                    # one run
enum AppDebug {
    static let defaultsKey = "_NS_4445425547"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }
}
