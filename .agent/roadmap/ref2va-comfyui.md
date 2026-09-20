# Ref2VA via a ComfyUI backend — implementation plan

Status: **not started.** Written at the end of the session that built the MLX
path, so the next session does not have to re-derive any of this.

## Why this is needed

The MLX port cannot do Ref2VA. This is verified, not assumed — the installed
pipeline's signature was read directly:

```
MiniMaxH3Pipeline.__call__(prompt, duration_seconds, aspect,
                           num_inference_steps, seed, images,
                           keyframe_anchors, height, width,
                           drop_adaln, verbose)
```

`images` + `keyframe_anchors` are keyframes only. There is no reference-image,
reference-video or reference-audio parameter, and no Ref2VA MLX conversion has
been published. The app currently blocks reference mode with that explanation
(`GenerationSpec.validate`, and `blockedReason` on the Ref2VA catalog entry).

ComfyUI is the realistic second path: native H3 support landed the day the
weights did, and it runs on Apple silicon via PyTorch MPS.

## What is already verified

- Upstream repo `MiniMaxAI/MiniMax-H3` has `Ref2VA/` beside `FL2VA/`, same
  internal layout (`transformer/`, `text_encoder/`, `video_vae/`, `audio_vae/`,
  `processor/`, `tokenizer/`, `model_index.json`). Ref2VA transformer ≈ 66 GB bf16.
- Ref2VA limits: ≤9 reference images, ≤3 reference videos (2–15 s each),
  ≤3 reference audio clips, 12 files total. Already modelled in `ReferenceAsset`.
- A community report ran H3 in ComfyUI on an **M4 Pro / 64 GB**: 5 s at
  608×352, 10 steps ≈ **18 minutes**, using PyTorch nightly, the
  `ComfyUI-AppleSilicon-FP8` custom nodes, and:
  ```
  export PYTORCH_ENABLE_MPS_FALLBACK=1
  export ASFP8_INT8_EXT=off
  ```
  Note that is a *reduced* resolution. Expect the 768 px canvas to cost
  considerably more.
- `Comfy-Org/MiniMax-H3` exists on Hugging Face — the repackaged weights in the
  layout ComfyUI expects. Check this before reusing the upstream layout; they
  may differ enough to matter.

## Open questions — ANSWERED

All four were settled before any Swift was written. Verified against a real
ComfyUI 0.36.0 install and the Hugging Face manifests.

**1. Does ComfyUI expose Ref2VA? — Yes.** `MiniMaxH3ReferenceToVideo` is a core
node (`comfy_extras/nodes_minimax_h3.py`), alongside `MiniMaxH3ImageToVideo`,
`MiniMaxH3AddGuide`, `MiniMaxH3SigmaShift` and `MiniMaxH3FunControlNetApply`.
Confirmed registered at runtime on MPS.

Its contract, which the workflow graph must satisfy:

```
inputs : clip, vae?, audio_vae?, prompt, width=1344, height=768,
         length=124 (min 5, max 3600, step 17 — the 17n+5 grid),
         ref_image_size ∈ {match, max},
         ref_images 0–9, ref_videos 0–3, ref_video_audios 0–3, ref_audios 0–3
outputs: positive conditioning, latent
```

Two details that matter for the UI:

- **References are addressed from the prompt** as `<Picture i>`, `<Video k>`,
  `<Audio j>`, 1-based per type. A reference the prompt never names contributes
  far less. The app must make this obvious, and should offer to insert the tags.
- `ref_image_size: "max"` uses a 2048 px short edge for identity fidelity and is
  **"several times slower"**, because reference tokens ride through every
  sampling step. Default to `match`.

**2. Can it reuse the MLX cache? — No.** ComfyUI wants single-file repackaged
safetensors from `Comfy-Org/MiniMax-H3` in a flat layout
(`diffusion_models/`, `text_encoders/`, `vae/`, `loras/`). Entirely separate from
the upstream diffusers tree the MLX port loads. Budget a second download.

**3. Quantization on MPS — the open risk.** `comfy/quant_ops.py` disables its
CUDA kernel registry when `torch.version.cuda is None`, so on Metal the INT8
ConvRot path falls back to whatever generic implementation exists. Whether that
is correct and usable is the one thing still to prove.

**4. Memory.** ComfyUI reports **137.4 GB** available on this machine and manages
its own offload. The INT8 set is ~48 GB resident, which is comfortable; the bf16
set would be ~91 GB and much less so.

## There is a 4-step Ref2VA turbo LoRA

`loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors`, 1.96 GB.
ComfyUI has a LoRA loader, which the MLX port does not. This is the difference
between Ref2VA being an overnight job and a usable one, and is the strongest
argument for the ComfyUI backend existing at all.

## Chosen configuration

Decided with the user, on a machine with ~101 GB free at the time:

| | |
|---|---|
| ComfyUI | app-managed headless clone under Application Support, leaving the user's own v0.8.2 install untouched |
| Runtime | own venv, Python 3.12, torch 2.14 with MPS |
| Transformer | `minimax_h3_ref2va_pruned_int8_convrot` — 21.0 GB |
| Text encoder | `qwen3vl_32b_minimax_h3_int8_convrot` — 27.1 GB |
| Video VAE | `minimax_h3_video_vae_fp16` — 5.2 GB (fp16 over INT8: small, and decode quality shows) |
| Audio VAE | `minimax_h3_audio_vae_fp32` — 0.6 GB |
| LoRA | `minimax_h3_ref2v_turbo_4step` — 2.0 GB |
| **Total** | **~56 GB** |

Weights live in `~/Documents/AI Models/comfyui/`, wired up by an
`extra_model_paths.yaml` in the ComfyUI checkout — so they sit beside the MLX
weights in the same shared folder.

## Design

### Engine abstraction

Introduce a protocol both backends satisfy, then make `RenderEngine` pick one
per job from `spec.task`:

```swift
protocol RenderBackend: Sendable {
    var id: BackendID { get }
    func supports(_ mode: GenerationMode) -> Bool
    func run(job: RenderJob, into scratch: URL,
             events: @Sendable (SidecarEvent) -> Void) async throws -> URL
}
```

`MLXBackend` wraps today's sidecar `generate`. `ComfyUIBackend` is new. Keep
`SidecarEvent` as the shared vocabulary — the queue, progress, ETA and library
all already speak it, so nothing above the backend needs to change.

Route on task: FL2VA → MLX (fast, native), Ref2VA → ComfyUI. Let the user
override in Settings once both work.

### Runtime

A **second, separate** environment under Application Support — do not reuse the
MLX venv, the dependency sets conflict (PyTorch nightly vs MLX):

```
~/Library/Application Support/Halation/
  runtime/          existing MLX venv
  comfyui/          git checkout + its own venv
  comfyui-extra-model-paths.yaml
```

`extra_model_paths.yaml` must point ComfyUI at `~/Documents/AI Models` so the
shared cache is honoured and nothing is downloaded twice. This is the single
most important integration detail — getting it wrong means a second 100 GB.

### Protocol

ComfyUI is an HTTP + websocket server, not a one-shot process:

1. Start `python main.py --listen 127.0.0.1 --port <free>` as a managed child.
2. Wait for `/system_stats` to answer.
3. `POST /prompt` with the workflow graph; keep the returned `prompt_id`.
4. Subscribe to `ws://127.0.0.1:<port>/ws?clientId=…`; translate
   `progress` → `.step`, `executing` → `.stage`, `executed` → `.artifact`.
5. Fetch the output via `/view`, then hand the file to `VideoPostProcessor`
   exactly as the MLX path does.

Reuse `ProcessRunner` for the server's lifetime; its SIGTERM-then-SIGKILL
teardown is what stops an orphaned server holding 60 GB.

### Workflow graph

Store a Ref2VA template as JSON in `Resources/comfyui/ref2va.json` with
placeholder node ids, and patch prompt/seed/steps/duration/aspect and the
reference file lists at submit time. Do **not** build the graph in Swift by
hand — the template must be exportable from ComfyUI itself so it can be
re-captured when the nodes change.

### UI

- `GenerationSpec.validate` — drop the Ref2VA blocking problem once the backend
  reports ready; keep an advisory about the much longer render time.
- Models — the Ref2VA catalog entry loses its `blockedReason`; add ComfyUI's
  own requirements as install targets.
- Settings — a ComfyUI pane mirroring the Runtime pane: install, repair,
  doctor output, port, and a "reveal checkout" button.

## Staging

1. Research the four open questions. **Do not write code until Q1 is answered** —
   if ComfyUI has no Ref2VA nodes either, the honest answer is that Ref2VA needs
   CUDA and this plan should be abandoned rather than half-built.
2. `RenderBackend` protocol + move today's path behind `MLXBackend`. No
   behaviour change; verify the FL2VA path still renders.
3. ComfyUI runtime install + doctor.
4. Workflow submission and websocket progress, against a trivial graph first.
5. The real Ref2VA graph.
6. UI unblocking.

Steps 2 and 3 are independently useful and low-risk; 4–6 depend on Q1.

## Watch list

Two things would change the picture significantly if they land:

- **A Ref2VA MLX conversion.** Would make this whole plan unnecessary.
- **LoRA support in the MLX port.** `lightx2v/Minimax-h3-Turbo` is a 4-step
  distillation LoRA — minutes instead of hours. Currently listed in the Models
  tab as blocked because the port has no LoRA loader.
