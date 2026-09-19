# VideoGen

A native macOS app for generating video locally with **MiniMax H3**, on Apple silicon.

SwiftUI front end, MLX back end. Nothing leaves the machine: no account, no API key,
no upload.

---

## What this actually is

H3 has no Swift implementation, and it never will — it is a 33B diffusion
transformer. The app is therefore two halves:

| Half | Does |
|---|---|
| **SwiftUI app** (`Sources/VideoGen`) | Model library, render queue, format validation, H.265 encoding, video library |
| **Python sidecar** (`Sources/VideoGen/Resources/sidecar`) | Drives [`PipeNetwork/minimax-h3-mlx`](https://github.com/PipeNetwork/minimax-h3-mlx), the Apache-2.0 Apple-silicon port |

They talk over NDJSON on stdout — one JSON object per line, one event per line.
The app owns everything the user can see; the sidecar owns the tensors.

## Before you start: two honest numbers

**Renders take hours.** The MLX port's published figures are for an M3 Ultra, which
has roughly 1.5× the memory bandwidth of an M4 Max. On this machine expect **one to
two hours for a 5-second clip** at the default 16 steps, and an overnight job at 50.
The queue is designed around that: it survives quitting, and it shows a live
seconds-per-step ETA rather than a guess.

**Setup is about 105 GB.** Most of it is the Qwen3-VL-32B text encoder (67 GB), which
H3 conditions on. The 4-bit transformer is 26 GB and the VAEs 12 GB.

## Requirements

- Apple silicon Mac. 64 GB unified memory is the practical floor; 128 GB is comfortable.
- macOS 26 or later (the UI uses Liquid Glass).
- ~130 GB free disk.
- `ffmpeg` — `brew install ffmpeg`. The port pipes raw frames into it.
- Xcode 26+ toolchain to build.

## Build and run

```bash
make run
```

That builds `dist/VideoGen.app` and launches it. `make app` builds without launching;
`make debug` builds a debug bundle. Xcode can also open `Package.swift` directly.

On first launch the app walks through licence acknowledgement, runtime install and
model download. The runtime lives in `~/Library/Application Support/VideoGen` and can
be rebuilt from Settings › Runtime without touching downloaded weights.

## The shared models folder

Weights go in **`~/Documents/AI Models`**, created on first run. Inside it,
`huggingface/` is a standard Hugging Face cache and the app sets `HF_HOME` to it — so
any other project pointed at the same folder **reuses the same download instead of
fetching a second copy**. The app also scans for hand-placed `<org>/<model>` folders,
and lists models it does not recognise without touching them.

Change the location in Settings › General.

## What the model can and cannot do

These are properties of H3 and of the MLX port, not choices this app made. The UI
states each one where it is relevant rather than exposing a control that does nothing.

| | |
|---|---|
| Frame rate | **24 fps, fixed.** 30 and 60 fps are offered as conform-only, and labelled as frame duplication. |
| Resolution | **768 px short edge.** H3's real 2K mode (`H3-Regenerate-2K`) is *not* open-sourced — MiniMax run it as a cloud API — so 1080p/1440p here are plain resamples and say so. |
| Duration | 5–15 s, snapped to the video VAE's `17n + 5` frame grid. The UI shows the snapped value. |
| Aspect ratios | 21:9, 16:9, 4:3, 1:1, 3:4, 9:16, resolved with the port's own area-capped canvas rule. |
| Audio | Generated jointly, 32 kHz stereo. There is no faster silent mode. |
| Guidance / negative prompt | **Not available.** The released weights are CFG-distilled — one forward pass per step — so there is nothing for a guidance scale to do. |
| Ref2VA | **Not usable yet.** The MLX pipeline accepts keyframes only; it has no reference-conditioning path. A ComfyUI backend is planned — see [docs/ref2va-comfyui-plan.md](docs/ref2va-comfyui-plan.md). |
| Acceleration LoRAs | 4-step distillation LoRAs exist and would be transformative, but the port has no LoRA loader. Listed in Models as blocked, to watch. |

## Output

Finished clips go to `~/Movies/VideoGen` as **HEVC/H.265** by default (hardware
encoded), with AAC audio muxed in. H.264 and ProRes 422 are also available.

Every clip is written with a `.videogen.json` sidecar recording the prompt, seed,
steps, canvas and codec — so a render stays reproducible even without this app.
"Reproduce Exactly" in the Library re-queues a clip with its original seed.

Named presets are saved separately, in Settings' support folder.

## Licence

The **app code** here is yours to do as you like with.

The **weights** are under the [MiniMax H3 Community License](https://huggingface.co/MiniMaxAI/MiniMax-H3),
which restricts local use in the USA, the EU, the UK and South Korea, requires
authorisation above roughly US$20M revenue, and prohibits training other models on
H3 output. The app surfaces this on first run; complying with it is the user's
responsibility.

The **MLX port** is Apache-2.0.

## Layout

```
Sources/VideoGen/
  Models/        OutputFormat, ModelCatalog, GenerationSpec, RenderJob
  Services/      ModelStore, RuntimeManager, DownloadManager,
                 RenderEngine, VideoPostProcessor, LibraryStore, ProcessRunner
  Views/         Compose, Queue, Library, Models, Settings, Onboarding
  Resources/sidecar/
                 videogen_sidecar.py   doctor / probe / download / generate
                 h3_adapter.py         capability detection
                 protocol.py           NDJSON event protocol
```

The sidecar checks the installed pipeline's signature at launch (Settings › Runtime),
so a port update that changes the API is reported before a render starts rather than
three hours into one.
