# Verified facts about MiniMax H3

Everything here was checked against a primary source — the Hugging Face API, the
MLX port's source, or the running app. Each entry says how it was verified so a
later agent can re-check it rather than trust it blindly.

**These facts cost more to establish than the code did. Read before assuming.**

## Corrections to plausible-but-wrong assumptions

These were all believed at some point during development and turned out to be
false. If you find yourself about to act on one of them, stop.

| Assumption | Reality |
|---|---|
| "2K output works locally" | **No.** `H3-Regenerate-2K` is explicitly *not* open-sourced — MiniMax run it as a cloud API. The README says so. Any resolution above 768 px short edge in this app is a plain resample and is labelled as such. |
| "Ref2VA works via the MLX port" | **No.** The pipeline takes keyframes only. Verified by reading the installed signature. See below. |
| "There's a guidance scale / negative prompt" | **No.** The released weights are CFG-distilled — one forward pass per step. Both controls would be inert, so neither is exposed. |
| "The text encoder is ~48 GB" | **67 GB.** It is Qwen3-VL-32B in bf16. Measured from the HF file manifest. |
| "The MLX repo is pip-installable" | **No.** It ships no `pyproject.toml` or `setup.py`. It must be cloned and put on `PYTHONPATH`. |
| "The MLX repos contain the whole model" | **Transformer only.** VAEs and text encoder come from the upstream release. |
| "Duration is freely choosable" | Snapped to a `17n + 5` frame grid. Only 8 s is exact between 5 and 15. |

## The MLX pipeline's real API

Read directly from the installed package (`minimax_h3_mlx.pipeline`):

```python
MiniMaxH3Pipeline.from_pretrained(checkpoint_dir, transformer_dir=None,
                                  dtype=mx.bfloat16, load_vision=False, verbose=True)

MiniMaxH3Pipeline.__call__(prompt, duration_seconds=5.0, aspect=(16, 9),
                           num_inference_steps=16, seed=0, images=None,
                           keyframe_anchors=(), height=None, width=None,
                           drop_adaln=True, verbose=True) -> GenerationResult
```

Consequences the app depends on:

- **`checkpoint_dir` is a task directory** (`FL2VA/` or `Ref2VA/`), not the repo
  root. It supplies `text_encoder/`, `video_vae/`, `audio_vae/`, `processor/`,
  `tokenizer/` and `model_index.json` together.
- **`transformer_dir` overrides the DiT**, which is how a published MLX quant is
  used — the quant repo holds only the transformer.
- **No reference conditioning.** No `reference_images`, `reference_videos` or
  `reference_audios` parameter exists. This is why Ref2VA is blocked.
- **No callback parameter.** Progress is only available by parsing the
  pipeline's own stdout, which prints `  step <done>/<total>`. The sidecar tees
  stdout to do this.
- **Returns arrays, not a file.** `GenerationResult.video` is
  `(frames, h, w, 3) uint8`; `.audio` is `(2, samples) float32`. The sidecar
  writes the file itself using `minimax_h3_mlx.media.save_mp4` / `save_wav`,
  which pipe raw frames into `ffmpeg` — so **ffmpeg must be on PATH**.

## Runtime dependencies the port does not declare

`requirements.txt` in the port lists `mlx`, `numpy`, `safetensors` and
`huggingface_hub`. It is incomplete: `text_encoder.py` imports

```python
from mlx_vlm.models.qwen3_vl.config import ModelConfig, TextConfig, VisionConfig
```

so **`mlx-vlm` is required** and must be installed separately.

`from_pretrained` also does not propagate `verbose` to the weight loaders, so
per-shard load prints are off by default. The sidecar patches
`load.load_dit` and `text_encoder.MiniMaxH3TextEncoder` to default it on — the
only way to get progress during the multi-minute load of a 67 GB encoder.

## Canvas and timing

`resolve_canvas_size` starts from a 768 px short edge, caps area at 768 × 1344,
and rounds both axes to a multiple of 32. Mirrored in Swift as
`AspectRatio.resolveCanvas`. The area cap is why 21:9 comes out below 768 on its
short edge.

Frame grid: the video VAE only encodes `17n + 5` frame counts, at a fixed 24 fps.
A requested duration is rounded **up** to the next grid point.

| Request | Frames | Actual |
|---|---|---|
| 5 s | 124 | 5.167 s |
| 8 s | 192 | **8.000 s** (the only exact one in range) |
| 15 s | 362 | 15.083 s |

## Repository layout and sizes

From the Hugging Face file manifest.

`MiniMaxAI/MiniMax-H3` publishes its components **twice**: once at the top level
in diffusers layout, and again mirrored inside `FL2VA/` and `Ref2VA/`. The MLX
pipeline needs the task folders, because top-level `vae/` lacks the `source/`
subfolder that `load_video_vae` expects.

| Component | Size |
|---|---|
| `FL2VA/transformer` (bf16) | 66.3 GB |
| `FL2VA/text_encoder` (Qwen3-VL-32B bf16) | 66.7 GB |
| `FL2VA/video_vae` | 10.4 GB |
| `FL2VA/audio_vae` | 0.6 GB |

MLX transformer-only builds (`pipenetwork/MiniMax-H3-MLX-*`), flat layout:
4-bit 25.3 GB · 6-bit ~31 GB · 8-bit 35.3 GB · bf16 66.3 GB.

**Recommended install ≈ 105 GB**, most of it the text encoder.

Repos that do **not** exist, despite being plausible names — do not add them back:
`pipenetwork/MiniMax-H3-TextEncoder-MLX-8bit`, `MiniMaxAI/MiniMax-H3-Regenerate-2K`.

## Performance

Published by the port's authors for an **M3 Ultra**, which has roughly 1.5× the
memory bandwidth of an M4 Max:

- bf16, 5 s, 8 steps ≈ **1.2 h**; at 50 steps ≈ 7.3 h
- 4-bit is ~1.4× faster than bf16
- resident memory: bf16 40.3 GB · 8-bit 21.5 GB · 4-bit 11.5 GB

A community report ran H3 through **ComfyUI** on an M4 Pro / 64 GB: 5 s at
608×352, 10 steps ≈ 18 min — note the reduced resolution.

The app's estimates scale these figures by a bandwidth factor. They are an order
of magnitude, not a promise; the live ETA comes from measured seconds-per-step.

## Format compatibility on Apple silicon

| Format | Runs here? |
|---|---|
| MLX 4/6/8-bit, bf16 | Yes |
| NVFP4 | No — NVIDIA Blackwell, no Metal path |
| GGUF | No — ComfyUI/llama.cpp loaders, not MLX |
| INT8 ConvRot | No — PyTorch scheme, no Metal kernel |

The last one matters: the uncensored community text encoders
(e.g. `linjian257/qwen3vl_32b_..._uncensored`) are INT8 ConvRot, so they target
the PyTorch path and cannot be loaded by MLX. Listed in the catalog for
reference with `blockedReason` set.

## Output codecs

Neither backend writes HEVC:

- the MLX port's `media.save_mp4` hardcodes `libx264` at crf 18;
- ComfyUI's `SaveVideo` offers `auto`, `h264` and `av1` only.

So H.264 is what the model produces, and the app delivers it unchanged. Asking
for HEVC previously *looked* like it worked — the recorded codec said so — but
the passthrough shortcut tested the requested format rather than the source's,
copied the H.264 file and mislabelled it. Anything not in the backends' own list
costs a second encode.

This Mac has `hevc_videotoolbox` and `h264_videotoolbox` but **no** AV1 encoder,
so AV1 is software-only via libsvtav1/libaom.

## Licence

MiniMax H3 Community License. Restricts local use in the **USA, EU, UK and South
Korea**; requires authorisation above ~US$20M revenue; prohibits training other
models on H3 output; prohibits unlawful and pornographic output regardless of
territory. There is no server-side filter on a local run.

The MLX port's own code is Apache-2.0. The app surfaces the licence on first run.

## Interface language and right-to-left layout

Two separate mechanisms, and only the second one mirrors the window. Both were
measured on macOS 27, not assumed.

**Our own strings** come from an explicitly loaded `.lproj` in the SwiftPM
resource bundle (`Localization.activeBundle`), so picking a language re-reads
every string immediately — no relaunch, and `.id(localization.generation)` on
the scene rebuilds the tree so nothing stale survives.

**AppKit's own chrome** — the menu bar, standard button titles, writing
direction — is fixed once, at launch, from defaults:

| `AppleLanguages` | `AppleTextDirection` | result |
|---|---|---|
| `["ar"]` | absent | Arabic menu bar, **window not mirrored** |
| `["ar"]` | `NO` | Arabic menu bar, not mirrored |
| `["en"]` | `YES` | English, not mirrored |
| `["ar"]` | `YES` | Arabic, **mirrored** |

The two conditions are **ANDed, not XORed**: mirroring needs a right-to-left
language *and* the flag. So choosing Arabic on an already-Arabic system cannot
double-flip back to left-to-right — a reasonable worry, and measurably not a
real one.

`AppleTextDirection` is the key Xcode sets for its right-to-left
pseudolanguage. Both keys must be *persisted* defaults; passed as launch
arguments they had no effect.

`Localization.set(_:)` therefore writes `AppleTextDirection` explicitly in
**both** directions rather than clearing it for left-to-right languages.
Clearing it would let an English interface inherit an Arabic system's
mirroring — English text in a mirrored window. Writing `false` pins the
direction to the chosen language whatever the machine is set to. Only
`.system` clears both keys, so that preference inherits the machine wholesale.

That last case — an actual right-to-left *system* — is reasoned from the table
rather than observed, since testing it means changing the machine's own
language.

`Locale.preferredLanguages` answers with the **app-domain** `AppleLanguages`
as soon as one is written, not with the system's. So anything that needs to know
what the *system* asks for — resolving a `.system` preference, or labelling the
"Follow system (…)" option — must read `AppleLanguages` out of
`UserDefaults.globalDomain` instead. Going through `Locale` made that option
rename itself to whatever the user had just chosen: on an English Mac, picking
Chinese relabelled it "跟随系统（简体中文）". `Localization.systemPreferredLanguages`
is the single place that reads it.

For the app bundle to count as localized at all, `make_app.sh` copies each
`.lproj` (with its `.strings`, not an empty folder) into `Contents/Resources`.
`CFBundleLocalizations` is deliberately *not* listed as well: with real `.lproj`
folders present it only duplicates every entry in `Bundle.main.localizations`.

Do **not** force `\.layoutDirection` from the scene. Overriding only the SwiftUI
half while AppKit stayed left-to-right made `NSToolbar` collapse its entire
contents into a single "more toolbar items" overflow button at every window
width. Direction now comes from the process, so both halves always agree.

### Measuring the running UI

`System Events`' `count of windows` silently returns 0 for **every** application
once window-level accessibility is gated, which reads exactly like "the app
launched with no window". Menu bars stay readable, which makes the failure easy
to misdiagnose. Check a known-good app before trusting a window count; to
inspect the real tree, talk to `AXUIElement` directly from a small compiled
helper (`AXUIElementCreateApplication(pid)`), which is unaffected.

### The Settings tab bar's focus ring

With full keyboard access on (`AppleKeyboardUIMode = 3`), AppKit draws a blue
focus ring on whichever Settings tab **has keyboard focus**, which is not the
same as the selected one. On an unselected tab it reads as a second selection;
on the selected tab it doubles up with the blue tint already there.

Neither `.focusEffectDisabled()` on the `TabView` nor migrating `.tabItem` to
the `Tab` API removes it — both were built and photographed, and the ring
survived both. The tabs are `NSToolbar` items and sit outside SwiftUI's focus
system entirely.

What works is clearing `focusRingType` on the window's chrome, which
`TabBarFocusRingSuppressor` in `SettingsView.swift` does. The walk stops at
`contentView`, so controls inside a panel keep their own focus rings. Focus
itself is untouched: Tab still moves through the tabs, Space still selects.

### Looking at the UI

`screencapture` works in this environment, including `-R x,y,w,h` against a
window rect from the accessibility probe. It is the only way to settle a
question about a ring, a tint or spacing — the accessibility tree reports none
of them. Capturing the same strip after each keystroke and comparing checksums
finds the frame that differs without reading every image.

### The "write with Siri" button over the prompt

macOS 27 creates the Writing Tools affordance in **its own window**, as soon as
a text view appears — not when one is focused — and does not take it down when
that view goes away. So it ends up floating over the Queue or the Library.

Measured, in this order: it is present on a fresh launch before the prompt has
ever been clicked; `makeFirstResponder(nil)` on section change does not remove
it (the premise that it follows focus is simply wrong);
`.writingToolsBehavior(.limited)` does not remove it either.
`.writingToolsBehavior(.disabled)` on the prompt is the only lever that works,
and the cost is Writing Tools on that field.

Decided against: Writing Tools on the prompt is worth more than the stray
button, so the field keeps them and this waits for a macOS fix. Do not
"fix" it by disabling Writing Tools without asking.

### Driving the UI for verification

`System Events`' `click at {x, y}` resolves the element under the point but does
not reliably activate a SwiftUI button inside a `List` row, and those rows'
buttons are not exposed as `AXButton` at all, so `AXUIElementPerformAction`
cannot reach them either. A synthesised `CGEvent` — mouseMoved, then down, then
up, with a short pause — does work, and is what opens the per-job log sheet.

## What this app needs from the Mac it runs on

Nothing is tuned to the machine it was written on any more. Both numbers that
depend on the hardware are read from the hardware at runtime — see
`MachineProfile` and `RenderThroughput`.

### Memory is the binding constraint, and the text encoder is why

Apple Silicon shares one memory pool between CPU and GPU, and macOS caps what
the GPU may wire down at roughly three quarters of installed memory.
`MachineProfile.usableWeightBytes` is that budget. Going over does not fail
cleanly — it swaps — so both warnings are advisory, never blocking.

A run holds the transformer **and** the text encoder at once, and the encoder is
the larger of the two: Qwen3-VL-32B in bfloat16 is about 34 GB resident against
12 GB for the 4-bit transformer. Computed over the real catalogue figures:

| installed | usable | what fits |
|---|---|---|
| 48 GB and below | ≤36 GB | **nothing** |
| 64 GB | 48 GB | 4-bit and the INT8 ConvRot builds, all flagged "tight" (46 GB) |
| 96 GB | 72 GB | everything except bfloat16 |
| 128 GB and above | ≥96 GB | everything, bfloat16 included at 75 GB |

So **64 GB is the practical floor** and there is no quantization that changes
that — choosing a smaller transformer saves at most 29 GB against a 34 GB fixed
cost. Say this plainly in anything user-facing; it is the single most useful
fact for someone deciding whether to try the app.

### Render time is measured, not predicted

`RenderThroughput` reduces render time to one number: seconds per sampling step
per megapixel. Finished renders in the library supply it, per backend, as a
median — MLX and ComfyUI are not comparable, since ComfyUI runs a distilled LoRA
at four steps where MLX wants sixteen.

Only before the first render does it fall back to a prediction, scaled from the
MLX port's published M3 Ultra figure by memory bandwidth, taken from the chip
tier in `machdep.cpu.brand_string` rather than a table of exact figures per
model — a table would be wrong for every chip released after this was written.
The summary panel says which of the two it is showing.

This matters because the old constant was not merely machine-specific, it was
wrong: it predicted 2 h 31 min – 5 h 13 min for a 16-step render on the machine
it was tuned for, where measurement from that machine's own renders gives
1 h 15 min – 2 h 36 min.

## Catalogue entries name themselves

`CatalogEntry.nameKey` is written out per entry. It used to be derived from role
and format, which gave **nine** entries the name "bfloat16" — including a video
VAE that is really fp16 and an audio VAE that is fp32. `quantization` is a
required field, so entries where it means nothing had been given `.bf16` as
filler, and that filler was then displayed as fact.

The row title, the Compose summary and the delete button's accessibility label
all use `displayName`. Every name is unique: tag pills and the grey description
are context, not identity.

## Two bugs the naming was hiding

**Selection did not follow mode or engine.** `selectBestAvailableModels` re-picked
only when the current entry was not *installed*, so switching to reference mode
kept an installed FL2VA transformer, and switching engine kept weights the new
engine cannot read. It now also requires the entry's task and backend to match
what is selected, and it runs on an engine change as well as a mode change.

**ComfyUI weights never counted as installed.** `installedEntryIDs` was built
from the Hugging Face cache alone, and ComfyUI weights are plain files in the
shared folder, so every ComfyUI checkpoint looked missing to selection, to
validation and to the recommended bundle. Only `isInstalled(_:)` checked the
file system. The two agree now.

These compounded: with ComfyUI entries invisible, the stale MLX selection was
what made reference mode pass validation at all, and the render worked only
because `ComfyUIBackend` resolves its own model set and ignores the spec's entry
ids entirely. Verified after the fix: text-to-video on MLX picks the bf16 pair,
reference mode picks the Ref2VA INT8 ConvRot pair, and text-to-video on ComfyUI
reports the FL2VA transformer as not selected — which is true, it is not
downloaded, and saying so is the point.

### Throughput samples must not require a recorded checkpoint

A reference render's spec carries no `transformerEntryID` — ComfyUI resolves its
own model set — so requiring one discarded every ComfyUI timing and sent that
engine's estimate back to a figure published for a different Mac. Unrecorded
runs now count, with bf16 assumed, which applies no speed-up correction and so
reads slightly slow rather than inventing one.

`GenerationSpec.resolvedBackend` exists for the same class of mistake: reference
specs carry `backend == nil`, so reading that field directly reports them as MLX
renders. It mirrors `RenderEngine.backend(for:)` — explicit choice wins,
reference is always ComfyUI, everything else MLX.

### Reading coordinates out of the accessibility tree

`AXPosition` is reported for rows that are scrolled out of view, in unclipped
coordinates, so an element can be given a position above the window's own top
edge. Intersect against the window rect before using a coordinate to capture or
to click — otherwise the point lands on whatever is behind, on another display,
and the screenshot looks like a real answer.

`screencapture -R` takes global points across all displays; `sips --cropOffset`
works in one image's pixels, which is not the same space when a second display
has a different backing scale. Prefer `-R` with the rect from `winlist`.

### A link and text selection cannot share a run

Measured both ways on the repository id in `EntryRow`:

- `AttributedString.link` — opens on click, pointing-hand cursor, hover styling
  can be driven from state. A double-click selects **nothing**.
- `.textSelection(.enabled)` instead — double-click selects a word, but an
  `onTapGesture` on the same text **never fires**, because selection consumes
  the click. Verified by window count and frontmost app: nothing opened.

Click to open won, because that is the job the id took over when the separate
"Model card" link was removed; without it the card is unreachable. Copying is
covered by the button beside it (full URL) and a context menu item (bare id).

Note for tests: a synthesised `CGEvent` drag does **not** produce a text
selection, even on plain selectable text — it looks like the feature is broken
when it is not. Use a double-click with `mouseEventClickState` set, which does.

### Required is not the same question as used

`EntryRow` keeps `isInUse` and `isRequired` apart, and the warning icon keys off
the second. A turbo LoRA is used when present and skipped when not, so its
absence is nothing to warn about — the first version treated every file matching
the engine and task as required and put a warning on an undownloaded LoRA.

`isRequired` asks `ComfyUIModelSet.required(for:)` rather than matching on the
catalogue's `task`, because reimplementing that rule got it wrong twice over in
opposite directions:

- the turbo LoRA is **not** on the required list, so it was warned about when it
  should have been ignored;
- the audio VAE **is** on it for *both* tasks, though the catalogue entry is
  tagged `.ref2va`, so it was reported as unused during an FL2VA render that
  genuinely loads it.

`isMissingRequirement` goes through `missing(in:for:)` rather than
`!isInstalled`, so someone running an alternate text encoder is not told the
stock one is missing — the engine accepts either, and the row has to agree with
the engine.

The rule: anything the UI says about what a render needs comes from the type the
engine itself consults. Restating it in a view is how the two drift.

## There are no tokens to meter

H3 is a diffusion model. Nothing is generated token by token, so there is no
token stream, no running token cost, and no tokens per second. The sidecar
protocol has never had a token event; `grep -i token` across it returned
nothing before `protocol.tokens` was added.

What does exist is the **length of the one sequence the text encoder reads**,
once, before denoising starts. `protocol.tokens` reports it, built through the
encoder's own `build_request` so the figure is real rather than inferred. Only
part of it is the prompt: measured against the shipped tokenizer, a short prompt
is 3 tokens, a long cinematic one 47. Each reference image adds a block of
vision tokens — roughly 729 for a 768px image at patch 14 with merge 2 — so a
nine-image Ref2VA render is thousands of tokens of picture and a few dozen of
words. That contrast is the only reason the number is worth showing.

It is MLX-only. ComfyUI resolves its own graph and reports no such figure.

The real throughput unit is **seconds per step**, not steps per second: a step
takes minutes, so the reciprocal would be a fraction with no useful digits.
`StepReporter` now emits both `seconds_per_step` (cumulative average, what the
ETA rests on) and `seconds_recent` (the latest step, divided by however many
steps a throttled report covers). ComfyUI has no per-step duration either, so
`ComfyUIBackend.timed(_:)` derives it from the gap between progress reports.

### A SwiftUI `Menu` cannot be opened in code

There is no programmatic presentation API for `Menu`, and the preset control is
not an `NSPopUpButton` that could be sent `performClick` — accessibility reports
it as a *menu button*, not a *pop up button*, unlike the genuine `NSPopUpButton`
in Settings.

So `highlightPresets()` rings the control instead, paired with a status-bar note
naming the preset. That answers the question the request was really asking —
where did my preset go — and a menu that opened by itself would have to be
dismissed again anyway.

One quirk this exposed: `PresetMenu.currentPresetName` matches on sampling and
format and takes the *first* hit, so a preset saved with settings identical to a
built-in leaves the control showing the built-in's name. The ring and the note
still point at the right control; only the label is ambiguous.

### An alert's message is fixed once it is presented

Its buttons are not: `.disabled(...)` on an alert button updates live as state
changes, measured through `AXEnabled` flipping while typing. But the `message:`
text is handed to AppKit when the alert appears and never updated, so a reason
that depends on what has been typed can never be shown there.

That is why naming a preset is a sheet (`PresetNamer`) rather than an alert. A
Save button that is merely dim does not say why it is dim, and the objection —
that the name is already taken — is exactly the part that has to change as the
user types.

## A repository's layout is not the layout ComfyUI wants

`CatalogEntry.ComfyUIFile.folder` says where a file belongs under
`<models>/comfyui/`. It does **not** say where the file lives inside its
repository, and the app used to send `folder/filename` as the path to fetch.

That holds for `Comfy-Org/MiniMax-H3`, which happens to store its files under
`text_encoders/`, `vae/`, `loras/` and `diffusion_models/`. It does not hold for
a community repository. The uncensored encoder sits at its repository's root:

```
GET …/resolve/main/text_encoders/<name>.safetensors  ->  404   (what the app asked for)
GET …/resolve/main/<name>.safetensors                ->  302   (where the file is)
```

`ComfyUIFile.repoPath` now carries the in-repository path when it differs, and
`remotePath` is what the downloader sends.

The failure surfaced only as huggingface_hub's routine warning about
unauthenticated requests, which is **not** an error: the repository is public
and ungated, and an anonymous ranged GET returns 206. Nothing here needs a
token.

`_download_single` also passed `local_dir=destination.parent.parent`, which
scattered files into `<models>/<repo layout>` rather than the folder asked for —
it left an empty `<models>/text_encoders/` and a stray `<models>/.cache/`. It now
downloads into the destination folder and moves the result up to
`dest_dir/<name>`, so the local layout no longer depends on the repository's.

### Xet names its partial file by content hash

A Xet transfer does write an `.incomplete` file into
`<dest>/.cache/huggingface/download/`, and `_SizeWatcher` measures it correctly —
the app reported "13.82 GB of 25.77 GB" mid-transfer. But the file is named for
the chunk hash, not the file being fetched:

```
Bne6F93c5pJarKXPfRrucTs-WwQ=.e385249a….8f9f95a5.incomplete
```

Looking for `*<filename>*.incomplete` therefore finds nothing and makes a
working download look stalled. Match on `*.incomplete` alone.

What is real is a **startup window of roughly half a minute** in which Xet
negotiates chunks and writes nothing at all, so the byte count sits at zero. The
download row shows an indeterminate bar until the first bytes arrive, the same
way the queue does while a model loads.

A cancelled transfer leaves the repository's own folder scaffolding behind —
`hf_hub_download` recreates the repo path under `local_dir`, and the move up to
`dest_dir/<name>` only happens once the download finishes. An interrupted one
therefore leaves an empty nested folder and a partial in `.cache`. Both are
harmless and the partial is what lets a retry resume.

### The catalogue's repository paths need checking, not assuming

Two entries shipped pointing at files that were not there, and both surfaced to
the user only as huggingface_hub's unrelated token warning:

- the uncensored text encoder sits at its repository's **root**, not under
  `text_encoders/`;
- the FL2VA turbo LoRA is published by **lightx2v** at v1.2, while the
  Comfy-Org mirror carries only v1.0 — so `loras/…v1.2…` was a 404 there.

`Scripts/check_catalog_urls.py` now HEADs every ComfyUI entry's resolved URL and
reports anything that is not a 200 or 302. Run it after touching the catalogue;
it needs no token, because every repository here is public.

### A file appearing on disk is not observable

`ModelStore.isInstalled` tests ComfyUI weights with `fileExists`, because they
are plain files and never enter `installed`. `@Observable` cannot see that, so a
row that asked "is this installed" kept its old answer after a download — stale
icon, stale Download button — until something else forced a redraw.

`ModelStore.revision` is bumped by every `scan()`, unconditionally, and both
`isInstalled` and `installedEntryIDs` read it. That is what makes the dependency
visible to SwiftUI. Anything else that answers a question from the file system
rather than from stored state has to do the same.

### A finished transfer used to block its own retry

`enqueue` left an existing transfer alone unless it had failed or been
cancelled, so once a download finished, pressing Download for that entry did
nothing for the rest of the session — even after the file was deleted. Reaching
that branch already means the file is *not* installed, so any transfer that is
no longer running is stale by definition; all terminal states now restart.

## What the app needs from macOS

Measured by lowering `platforms:` in `Package.swift` and reading the compiler's
availability errors, which is authoritative in a way that reading the source is
not.

**Nothing requires macOS 27.** The package declares `.macOS(.v26)` and builds
clean; Swift's availability checking would reject a 27-only API against that
deployment target, so the clean build *is* the proof.

**Exactly five APIs require macOS 26**, at 20 call sites across 12 view files,
and every one of them is cosmetic:

| API | sites | where |
|---|---|---|
| `.buttonStyle(.glassProminent)` | 9 | Compose, Library, Models, Onboarding, PresetNamer, QueueLogSheet, Queue |
| `.scrollEdgeEffectStyle(_:for:)` | 4 | ComposeSummary, Compose, Library, Models |
| `.glassEffect(_:in:)` | 3 | GlassCard, Library, Queue |
| `ToolbarSpacer` | 3 | Compose, Models, Root |
| `.buttonStyle(.glass)` | 1 | ComposeCards |

Nothing else in the codebase is newer than **macOS 15.0**. Set the deployment
target to `.v15` and the compiler reports those five and nothing else — no
15.1-or-later API, nothing in between. So Sequoia is the true floor once they
are shimmed, and the work is five `@available` helpers plus a mechanical
substitution, not an architectural change:

```swift
extension View {
    @ViewBuilder func glassy(in shape: some Shape) -> some View {
        if #available(macOS 26, *) { glassEffect(.regular, in: shape) }
        else { background(.regularMaterial, in: shape) }
    }
}
```

`LSMinimumSystemVersion` in `Scripts/make_app.sh` and `platforms:` in
`Package.swift` both have to move together; they are the two places the floor is
stated.

Caveat: this is a compile-time result. It says the code *builds* for Sequoia,
not that it *behaves* there. `TabBarFocusRingSuppressor` walks the window's
chrome, and the right-to-left switch depends on `AppleTextDirection` — neither
is verifiable without a machine running it.

### Method

```bash
sed -i '' 's/\.macOS(\.v26)/.macOS(.v15)/' Package.swift
swift build -c debug --scratch-path /tmp/b15 -Xswiftc -continue-building-after-errors
```

A separate scratch path and `-continue-building-after-errors` both matter: the
ordinary build stops at the first failing file and reports a fraction of the
truth. Per-file `swiftc -typecheck` is worse — it aborts on the unresolved
cross-file references before it reaches the view bodies.

### Reaching back to Sequoia costs Liquid Glass everywhere

The five macOS 26 APIs are now behind `Views/Components/LiquidGlass.swift`, so
lowering the deployment target is a one-line change rather than a port. But the
deployment target is also what opts an app into the new design language, and
that is decided by the **`minos` in the binary's `LC_BUILD_VERSION`** — not by
`LSMinimumSystemVersion`, and not by which branch the `#available` checks take.

Measured on macOS 27, photographing the same toolbar four times:

| shims | `minos` | plist | result |
|---|---|---|---|
| none (committed baseline) | 26.0 | 26.0 | full Liquid Glass |
| all | 26.0 | 26.0 | **pixel-identical to baseline** |
| all | 15.0 | 15.0 | legacy appearance throughout |
| all | 15.0 | **26.0** | legacy appearance throughout |

The last row is the one that settles it: the Info.plist string is irrelevant to
the appearance, so there is no combination that gets both. An app that can
launch on Sequoia renders pre-26 on every system, including 27.

So the shims are correct — row two proves they change nothing on a modern
system — and the version is a build-time choice the packager makes, not a
compromise baked into the source. `UIDesignRequiresCompatibility` does not help;
it opts *out* of the new design, and there is no opt-*in* for a lower target.

While isolating this, note that the whole toolbar lost its glass, not just the
styled controls. That is the giveaway that the cause is app-wide rather than a
bad wrapper: a broken `buttonStyle` shim could not have un-glassed a toolbar
item it never touched.

## The `.icon` format, as actool actually accepts it

Icon Composer's `.icon` package is a directory holding `icon.json` and
`Assets/`, compiled into `Assets.car` by `actool`. The schema is not documented
anywhere, so every key in `Scripts/make_icon.sh` was bisected against `actool`
one at a time. What it rejects is most of what you would guess.

**Groups run front to back.** The first entry in `groups` is the *topmost*
layer. This is the opposite of `CALayer`, of `CGContext`, and of the order you
would draw them in yourself, and getting it wrong is silent — the icon builds
and installs, it just shows the back layer tinting everything in front of it.
Half a day went into "why is the white core coming out dull orange" before the
answer turned out to be that the bloom was on top of it the whole time.

Other findings, each verified by a build that failed without it:

- `groups` is mandatory, and each group needs `layers`. A top-level `layers`
  array is rejected.
- A colour is the string `"<space>:r,g,b,a"`, e.g. `"srgb:0.09,0.10,0.16,1.0"`.
- `linear-gradient` takes a **bare array** of those strings.
  `{"colors": [...]}` is rejected. `"automatic"` and `{"automatic-gradient":
  "..."}` are both accepted as a `fill`.
- There is no way to say "no shadow". `"kind": "none"`, `false` and
  `"opacity": 0` are all rejected. **Omitting the `shadow` key is the only
  accepted way**, which is why the bloom group has none.

## The layered renderer lights layers by their alpha silhouette

This is the constraint that shapes the artwork, and it is worth knowing before
drawing anything. macOS 26 derives a group's lighting, shadow and `specular`
rim from the alpha of its layers. That works for shapes with edges and fails
for soft glows: a glow crosses any alpha threshold at exactly one radius, so it
comes back with a thin circle etched around it that no amount of blurring
removes. Three separate attempts to blur, re-stop and re-reach the gradient all
failed, because the problem was never the gradient.

The fix is to give the renderer no silhouette to find. `renderBloom` draws the
ground gradient first and fills the canvas edge to edge, so the backmost layer
is fully opaque. Costs nothing — there is nothing behind it — and the circle is
gone. For the same reason the core carries no `specular` and no hand-painted
highlight: both were soft radial spots, and both got traced.
