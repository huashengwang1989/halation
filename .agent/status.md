# Status

Last updated: end of the session that built the MLX path.

## Working and verified

- **Runtime bootstrap**, end to end: `uv` fetched, venv created, MLX installed
  and confirmed running a Metal kernel, port cloned, pipeline imported, its
  signature checked against what the app calls.
- **Download path**: a real transfer into `~/Documents/AI Models/huggingface`,
  correct cache layout, progress measured from disk (tqdm double-counts under
  `huggingface_hub` 1.x, so it is not used).
- **Model scanning**: HF cache layout and hand-placed folders, with per-entry
  marker paths so a partial download is not reported as installed.
- **App runs** with no crash; layout, sidebar auto-collapse with hysteresis, and
  toolbar order all driven and checked through the accessibility API.
- **Keyboard**: Return advances onboarding, ⌘L ticks the licence checkbox — both
  confirmed in the running app.
- **Build quality**: 0 compiler warnings, 0 lint violations.

## Gotchas that cost real debugging time

- **SwiftPM autolinking misses AVKit.** Using SwiftUI's `VideoPlayer` links the
  `_AVKit_SwiftUI` overlay but not `AVKit.framework`, whose classes the overlay
  subclasses. The app aborted in `getSuperclassMetadata` the moment a player was
  instantiated. `Package.swift` now links AVKit explicitly. Check `otool -L` when
  a system framework's types crash on first use.
- **`mlx_vlm` is a hidden dependency.** The port's `text_encoder.py` imports
  `mlx_vlm.models.qwen3_vl` unconditionally, but its own `requirements.txt` lists
  only `mlx`. Without it every render dies at the first load step, after the
  weights have already been downloaded. It is now in the sidecar's requirements
  and checked by `doctor`.
- **Never let `protocol.emit` write through a redirected stdout.** Generation runs
  inside `contextlib.redirect_stdout(tee)` so the pipeline's prints can be parsed.
  Because `emit` used `sys.stdout`, every event it produced during a render was
  fed back into that parser instead of reaching the app — silently swallowing all
  step and stage progress. `protocol` now holds the real stream, captured at
  import.

- **`huggingface_hub` 1.x uses Xet storage.** Per-repo `blobs/` entries are
  symlinks into a shared, chunk-deduplicated tree under `huggingface/xet/`.
  Anything that measures size must follow symlinks, or a 78 GB install reads as
  a few megabytes. `du -sh` on the repo folder also understates badly.
- **The upstream snapshot root holds only `FL2VA/` and `Ref2VA/`.** A marker-file
  test that looks only at the root concludes the repo is not a model at all. This
  made a complete download appear uninstalled, which then cascaded into a missing
  `support_path` and a failed render.
- **A failing sidecar exits non-zero *after* reporting why.** The process error is
  always the generic "exited with code 1", so it must never be allowed to
  override the `error` event the sidecar already sent.
- **The staged sidecar is a copy.** It lives in Application Support and is now
  re-staged on every launch; previously only on install, so shipped fixes to the
  Python side silently did nothing.
- **Progress hitting 100% is not the end of a download.** The hub still verifies
  checksums and materialises symlinks, which takes minutes on a large repo.
- **Catalog entries can share a repository**, so a per-repo byte count is not a
  per-entry byte count. Progress must be measured from a baseline.

## Built but NOT verified

Be honest about these; do not imply otherwise.

- **A render completed end to end.** One clip has been generated, encoded and
  written to `~/Movies/VideoGen` with its thumbnail and recipe JSON, and plays
  back in the Library. The core path is proven.
- **Still untested:** first-frame and first-and-last-frame modes; the non-native
  frame rates (30/60 conforming); ProRes and H.264 output; the WAV sidecar
  option; and the upscale tiers.
- **Library** — recording and playback are verified. Reconstruction from sidecar
  JSON after losing the index, and deletion to Trash, are not.
- **Escape closing the onboarding sheet** — scripted keys cannot reach it, so it
  needs a human. Wired via both `.cancelAction` and `.onExitCommand`.
- **Tab traversal** after enabling `AppleKeyboardUIMode=3` — reported working by
  the user, not confirmed by tooling.

## Ref2VA via ComfyUI — working

A second backend, used for reference mode, which the MLX port cannot do.

- `RenderBackend` protocol with `MLXBackend` and `ComfyUIBackend`. `RenderEngine`
  routes by mode: reference goes to ComfyUI, everything else stays on MLX.
- `ComfyUIRuntime` installs and supervises a private headless ComfyUI under
  Application Support, on a free port, with `extra_model_paths.yaml` pointing at
  `~/Documents/AI Models/comfyui`. The user's own ComfyUI is untouched.
- Graph built in `ComfyUIWorkflow`, derived from ComfyUI's own
  `video_minimax_h3_r2v.json` template.
- Progress over the websocket, with history polling as a fallback so a dropped
  socket cannot stall a render silently.

**Measured:** 1344×768, 124 frames, 4 steps with the turbo LoRA, **26m47s**.
Compare the MLX path at 5 steps: 24 min. So ComfyUI is not the slow option — it
is roughly par, and it is the only one with reference conditioning or LoRAs.

Still to verify: progress reporting through a full app-driven render, and that
cancel reaches ComfyUI's queue.

## Multilingual interface

Five languages: English, 繁體中文 (TW phrasing), 简体中文, Deutsch, العربية.
~329 keys in `Scripts/translations.py`, generated into `.lproj` bundles.

Default follows the system, matched by Foundation, so `en-GB` lands on English,
`zh-Hant-HK` on Traditional Chinese, and anything unsupported (`fr`, `ja`) on
English. Settings offers an explicit override plus a Relaunch button.

**Verified in the running app** via a direct `AXUIElement` probe — every toolbar
item translated, none truncated or collapsed, in all five languages; the Arabic
window fully mirrored (sidebar and its toggle on the right, Generate on the
left). German is the longest ("Schnelle Vorschau", 153 pt vs English 123 pt) and
still fits.

`verified-facts.md` records how right-to-left is actually switched on — it is
not what the obvious reading of `AppleLanguages` suggests.

## Next

1. **Run a real render.** Install the recommended bundle, generate a 5 s clip at
   low steps, and confirm the file, audio, thumbnail and recipe JSON all appear.
   Expect 1–2 hours.
2. `roadmap/ref2va-comfyui.md` — Ref2VA via a ComfyUI backend. Starts with a
   research question that may kill the plan; read it first.

## Watch list

Either of these would change the project more than any planned work:

- **A Ref2VA MLX conversion** would make the ComfyUI plan unnecessary.
- **LoRA support in the MLX port** would unlock the 4-step turbo LoRA — minutes
  per clip instead of hours.

Both are already in `ModelCatalog` with `blockedReason` set, so they are visible
in the Models tab.
