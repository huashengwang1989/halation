# Project: Halation

A native macOS app that generates video locally with MiniMax H3 on Apple silicon.
Nothing leaves the machine — no account, no API key, no upload.

Target machine: Mac Studio M4 Max, 128 GB, macOS 26+. Xcode 26+ toolchain.

## Shape

H3 is a 33B diffusion transformer with no Swift implementation, so the app is two
halves joined by a line-delimited JSON protocol:

```
SwiftUI app  ──NDJSON over stdout──>  Python sidecar  ──>  minimax-h3-mlx
(everything                           (subprocess,          (cloned checkout,
 the user sees)                        one per job)          Apache-2.0)
```

The app owns all user-facing state; the sidecar owns the tensors. One JSON object
per line, one event per line. `SidecarEvent` in Swift and `protocol.py` in Python
are the two ends of that contract — **change them together**.

## Layout

```
Sources/Halation/
  Models/      OutputFormat, ModelCatalog, GenerationSpec, RenderJob, URL+Literal
  Services/    ModelStore, RuntimeManager, DownloadManager, RenderEngine,
               VideoPostProcessor(+Output), LibraryStore, ProcessRunner
  Views/       RootView, Compose(View/Cards), ReferencesCard, Queue, Library,
               Models, Settings, Onboarding, Components/
  Resources/sidecar/
               halation_sidecar.py   doctor | probe | download | generate
               h3_adapter.py         capability detection
               protocol.py           NDJSON event protocol
.agent/        these instructions
docs/          nothing agent-facing; see .agent/roadmap/
```

Runtime and weights live outside the repo:

- `~/Documents/AI Models` — **shared** model folder, deliberately not app-private.
  `HF_HOME` points into it so any other project aimed at the same folder reuses
  the downloads. Never delete anything there that the app did not create.
- `~/Library/Application Support/Halation/` — Python venv, cloned port, queue
  state, scratch. Disposable; rebuildable from Settings.
- `~/Movies/Halation` — finished clips plus a `.halation.json` recipe each.

## Invariants

Break these and the app starts lying to the user.

1. **Only offer combinations the model can produce.** 24 fps is fixed; 768 px
   short edge is fixed; 5–15 s snapped to a frame grid. Anything else is
   post-processing and must be labelled as such in the UI.
2. **Never expose a control that does nothing.** No guidance scale, no negative
   prompt — the weights are CFG-distilled. This is why those were removed.
3. **One render at a time.** A 33B transformer plus its encoder can hold 40 GB
   resident; two concurrent jobs swap and finish later than sequential ones.
4. **Renders take hours.** Every design decision follows from this: the queue is
   durable across quit, ETAs come from measured seconds-per-step, and jobs that
   were mid-flight return to `queued` rather than claiming false progress.
5. **The models folder is shared.** Dedupe via `HF_HOME`; scan and list models
   belonging to other projects without touching them.
6. **The sidecar adapts to the installed port.** `h3_adapter.detect()` reads the
   pipeline's real signature at launch and reports a mismatch before a
   multi-hour render, not during one.

## Capability gaps, and why

- **Ref2VA is blocked.** The MLX pipeline has no reference-conditioning path.
  See `roadmap/ref2va-comfyui.md`.
- **Turbo LoRAs are blocked.** `lightx2v/Minimax-h3-Turbo` is a 4-step
  distillation LoRA — minutes instead of hours — but the port has no LoRA
  loader. Listed in the Models tab with `blockedReason` so it is visible.
- **2K is impossible locally.** Not a gap in the app; the module is not open.

Both blocked entries carry `blockedReason` in `ModelCatalog`. When either
upstream limitation lifts, clearing the reason is most of the work.
