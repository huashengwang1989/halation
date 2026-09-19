# Conventions

## Build, run, lint

```bash
make app     # build dist/VideoGen.app (release)
make debug   # debug bundle
make run     # build and launch
make lint    # SwiftLint with the project config
make clean
```

SwiftPM cannot emit an app bundle, so `Scripts/make_app.sh` wraps the executable
and ad-hoc signs it. Xcode can open `Package.swift` directly.

**Both must be clean before finishing: 0 compiler warnings, 0 lint violations.**

## Code

- Swift 6 language mode, strict concurrency. `@MainActor @Observable` for stores,
  `actor` for process handling, `Sendable` structs for data crossing boundaries.
- When a non-`Sendable` platform type must cross a boundary, wrap it in a small
  `@unchecked Sendable` type that *documents the invariant making it safe* —
  see `VideoPumpChannel`. Do not scatter unexplained suppressions.
- Comments explain **why**, not what. Density should match the surrounding file.
- User-facing strings state limits plainly rather than implying capability the
  model lacks. "24 fps — native" vs "30 fps — conformed" is the house style.
- Layout uses leading/trailing, never left/right, so RTL mirrors correctly.

## Lint policy

`.swiftlint.yml` is project-local and documents a reason for every relaxed rule.

- Relaxing a rule requires a comment saying why it does not fit *this* code.
  Loosening a threshold to avoid wrapping a few lines is not a reason.
- 18 opt-in rules are enabled because they catch mistakes rather than enforce
  taste. `force_unwrapping` earned its place immediately.
- Per-line escape is `// swiftlint:disable:next rule_name`.
- **Swift has no per-line suppression for compiler warnings.** Those always
  require a real fix.

## Verification

Claims about behaviour should be checked, not asserted. What has worked here:

- **Run the app and drive it.** `osascript` + System Events can resize windows,
  read the toolbar, and send keys. Window count is a reliable signal for sheet
  presented/dismissed.
- **Measure layout headlessly.** An `NSHostingView` harness can read a scroll
  view's `documentView.frame` to prove a sizing fix. This caught a bug where
  `Text` stopped wrapping inside a horizontal `ScrollView`.
- **Query Hugging Face directly.** `/api/models/<id>?blobs=true` gives real file
  lists and sizes. Several catalog entries were wrong until checked this way.
- **Read the port's source.** Its actual signature is the contract, not the
  README.
- **Exercise the sidecar standalone.** `python videogen_sidecar.py doctor`
  reports runtime health as one JSON object.

### Known limits of that tooling

State these rather than implying coverage that does not exist:

- **Screenshots are unavailable** (no screen-recording permission). Visual
  results must be confirmed by the user.
- **SwiftUI's accessibility tree is shallow** to System Events. Toolbar items are
  visible; content views, list rows and `AXFocusedUIElement` generally are not.
- **Scripted key events do not reach a SwiftUI sheet** for all keys — Return and
  ⌘-shortcuts land, Escape did not, confirmed against a minimal reproduction.
- **`@FocusState` does not observe AppKit-driven focus** on plain buttons, so it
  is not a reliable probe for Tab traversal.

## Git

Commit messages explain the reasoning, not just the change — especially *why* a
fix was needed and what was ruled out. Include measurements where a claim is
quantitative. End with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

## Host environment notes

- `AppleKeyboardUIMode` governs Tab traversal system-wide. At `0`, Tab reaches
  only text fields and lists — no buttons, anywhere. It was set to `3` during
  development at the user's request. A dialog should still work without it, via
  Return for the default action and an explicit shortcut for anything gating it.
- `ffmpeg` must be on `PATH`; the port shells out to it by name.
