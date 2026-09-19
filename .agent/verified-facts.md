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
