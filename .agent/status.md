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

- **No clip has ever been generated.** Everything up to the generation call is
  verified, but a real render needs ~105 GB of weights and 1–2 hours of compute.
  This is the single most valuable next test.
- **`VideoPostProcessor`** — the HEVC/AVFoundation encode path has never run on
  real model output, because there has been none. Frame-rate conforming and the
  WAV sidecar are untested.
- **Library** — recording, reconstruction from sidecar JSON, and deletion are
  untested end to end.
- **Escape closing the onboarding sheet** — scripted keys cannot reach it, so it
  needs a human. Wired via both `.cancelAction` and `.onExitCommand`.
- **Tab traversal** after enabling `AppleKeyboardUIMode=3` — reported working by
  the user, not confirmed by tooling.

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
