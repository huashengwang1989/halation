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

## Open questions to settle first

1. Does ComfyUI's H3 implementation expose Ref2VA conditioning as nodes, or only
   FL2VA? Confirm before any code is written — this is the whole premise.
2. Does it accept the upstream `Ref2VA/` folder directly, or require
   `Comfy-Org/MiniMax-H3`? Decides whether we can reuse the shared cache.
3. Quantization on MPS: INT8 ConvRot needs `ComfyUI-AppleSilicon-FP8`. Is there
   a GGUF path (`unsloth/MiniMax-H3-GGUF`, `Abiray/MiniMax-H3-Pruned-GGUF`) that
   is better behaved on Metal?
4. Memory: 66 GB transformer + 67 GB encoder on 128 GB unified, under PyTorch
   rather than MLX. Sequential offload will likely be mandatory.

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
~/Library/Application Support/VideoGen/
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
