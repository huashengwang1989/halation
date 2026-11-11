import Foundation

/// Carries settings across a change of bundle identifier.
///
/// `UserDefaults.standard` is keyed by the bundle identifier, so the move from
/// the unsigned builds' `com.local.halation` to a real identifier for Developer
/// ID signing would otherwise open on a blank slate: no models folder, the
/// licence unacknowledged, every remembered choice gone. The app is not
/// sandboxed, so the old domain is readable by name.
///
/// Runs once, before anything reads a setting — which means before `AppState`
/// builds its `ModelStore`, since that reads the models folder in its
/// initialiser. It only fills keys the new domain does not have, so it can
/// never overwrite a setting made after the move, and a marker stops it running
/// again even if the old domain is still there.
@MainActor
enum SettingsMigration {
    static let legacyDomain = "com.local.halation"
    private static let doneKey = "migratedFromLegacyDomain"

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard let current = Bundle.main.bundleIdentifier,
              current != legacyDomain,
              !defaults.bool(forKey: doneKey),
              let legacy = UserDefaults.standard.persistentDomain(forName: legacyDomain),
              !legacy.isEmpty
        else { return }

        var copied = 0
        for (key, value) in legacy where defaults.object(forKey: key) == nil {
            // Apple's own keys (window frames and the like) belong to the old
            // identity's windows; the system recreates them.
            if key.hasPrefix("NS") || key.hasPrefix("Apple") { continue }
            defaults.set(value, forKey: key)
            copied += 1
        }
        defaults.set(true, forKey: doneKey)
        InteractionLog.shared.record(.life, "settings.migrated", value: "\(copied)")
    }
}
