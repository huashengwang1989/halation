# Conventions

## Build, run, lint

```bash
make app     # build dist/Halation.app (release)
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
- **Exercise the sidecar standalone.** `python halation_sidecar.py doctor`
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

## User-facing strings

Every string the user reads goes through `loc("some.key")`. Nothing is added to
a `.strings` file by hand: `Scripts/translations.py` is the single source of
truth and `Scripts/build_strings.py` generates all five `.lproj` files from it.
Add the key to `translations.py` with all five languages, regenerate, then use
it. `build_strings.py` warns about anything missing.

Keys are semantic, not English text — `compose.generate.button`, not `Generate`.
That is what lets the same English word be translated differently where context
demands it: a **Rate** button that scores something is `打分`, never `率`.

Leave technical terms in English: `bfloat16`, `ComfyUI`, `MLX`, `LoRA`, `VAE`,
`ffmpeg`, and every model and repository name. Translating them makes the app
harder to use, not easier, because the surrounding ecosystem is English.

Anything persisted keeps its untranslated form and carries a key alongside it —
see `GenerationPreset.nameKey` / `displayName`. Storing translated text freezes
whichever language was current when the file was written.

German is carried mainly to catch layout that breaks on long words, and Arabic
to catch anything that assumes left-to-right. Check both after any chrome
change; see `verified-facts.md` for how right-to-left is actually switched on.

The language controls themselves are the exception to translating everything:
"Language" and "Interface Language" carry their English names in every
language — `语言 (Language)`, `لغة الواجهة ⁨(Interface Language)⁩`. Someone who
lands in a script they cannot read has to be able to find the way back. In
Arabic the Latin fragment is wrapped in U+2068/U+2069 isolates so the
parentheses do not migrate.

Where two messages differ only by a condition the user can perceive, write two
keys rather than one that covers both: `settings.language.restart` and
`settings.language.restart.direction`. Explaining mirroring to someone moving
between two left-to-right languages invents a worry instead of answering one.

## Segmented controls

Use `SegmentedPicker`, not `.pickerStyle(.segmented)`. The system style draws
its selection as a fully rounded pill inset in the track, which reads as an
object sitting on top of the control rather than one of its positions, and
SwiftUI exposes no way to change that shape. `SegmentedPicker` rounds only where
a segment meets the end of the track and squares every edge between.

Its radii are leading/trailing, not left/right, so right-to-left mirrors for
free — verified in Arabic: the first option rounds on the right. Any shape with
asymmetric corners should be built the same way; reach for
`UnevenRoundedRectangle`'s leading/trailing arguments rather than composing a
path by hand.

Keep a control's label outside its track. Inside, it inherits the track
background and reads as one more segment that can never be selected.

To find strings that were missed, scan for literals rather than reading screens:

```bash
grep -rnE '(Text|Label|Button)\("[A-Z]' Sources/Halation/Views/
grep -rnE 'return "[A-Z]|message: "[A-Z]' Sources/Halation/Models/
```

The second one matters more. Most of what was missed was not in a view at all
but in a model — `displayName`, `unloadableReason`, a validation message — where
it reads as ordinary code rather than as interface text.

## Naming a file in a message

Wrap it in backticks and render with `CodeSpanText`, which sets backticked spans
in a monospaced face. `minimax_h3_fl2va_pruned_int8_convrot.safetensors` loses
its underscores in a proportional face and blurs into the sentence around it.
Keep the backticks in every translation.

## Sliders whose range does not start at zero

Label both ends with `minimumValueLabel` / `maximumValueLabel`. Duration starts
at 5 s and steps at 4, so the knob sits hard left at the minimum and reads as
zero — as though nothing would be generated. The range was always enforced; what
was missing was the scale saying so. Add `.labelsHidden()` when a
`LabeledContent` already names the control, or the name appears twice.

## Counting things in a sentence

Put the count in a parenthetical — "(%@ so far)" — rather than in a phrase that
has to agree with it. Plural rules differ per language and Arabic alone has six
forms, none of which a `.strings` file can express. A parenthetical is
grammatical at any count in every language we ship.

## Colour

Take colours from the system so they adapt to both appearances: `.purple` for
the weights file name, `Color(nsColor: .linkColor)` for a link. Never a
hand-picked hex tuned against whichever appearance happened to be on screen.

A repository id that is also a URL carries its own link rather than sitting
beside a separate one — the model card's URL *is* the id appended to
huggingface.co, so two controls said the same thing. Links open on click, never
on hover: a page that opened because the pointer crossed a row is a surprise,
not a shortcut. A `Link` cannot be text-selected, so where the string is worth
copying (a repository id is what you paste into a download command) give it a
copy item in its context menu.

## Describing a catalogue entry

Use `ModelCard`. It is the whole description of an entry — name, tags,
repository link, weights file, blurb, sizes — and both the Models list and the
Compose summary render it, so an entry looks the same wherever it appears.

The two contexts differ only in what surrounds it: a status icon and action
buttons on one side, a heading on the other. Pass `showsDescription: false`
where space is tight, `isInUse:` to add the pill, and use the `footer` slot for
anything the context wants to say about the entry — it lands after the blurb and
before the sizes, where it will be read.

Do not rebuild a row out of the pieces. That is how the Compose side ended up
showing a bare format name while the Models page showed a full identity, for
entries where several share a format.

Strings assembled by concatenation hide from the usual greps. Watch for `+ " of "`
and similar joins, and for text built only for VoiceOver — `accessibilityValue`,
`accessibilityLabel`, and the `spoken…` helpers. It is read aloud, so it is
interface text, and it was the last English left in the app.

## What carries over between launches

Compose remembers the mode, the engine, the sampling settings and the output
settings — four switches in Settings, each on by default. What is never carried
over is the prompt, the seed and any attached files: those belong to one render
and always start clear.

The seed is the one that needs saying out loud, because it lives inside
`SamplingSettings` and so would ride along for free. It is stripped before the
group is stored, for the same reason `savePreset` strips it — a seed is one
particular clip, not a way of working, and a fixed seed quietly surviving a
relaunch would produce identical renders with no visible cause.

`AppState.draft` has a `didSet` that writes them, rather than the views calling
a save method — a view that forgets to call it is a bug waiting to happen, and
the draft changes from several places (a preset, a library item, the mode
picker). Property observers do not run during `init`, so restoring in the
initialiser does not write straight back.

## The staged sidecar goes stale

The app copies `Sources/Halation/Resources/sidecar` into
`Application Support/Halation/sidecar` at launch. Testing against that staged
copy tests whatever was current the last time the app started, not what is in
the repo — which reads as a puzzling failure when the change under test is a
rename. Run the repo's own file, or relaunch the app first.

The stager copies over the top and does not remove files, so a renamed script
leaves its predecessor behind until it is deleted by hand.
