# Image generation — brainstorming and plan

Status: **not started.** Written from a session that only investigated, so the
next session does not have to re-derive any of it. Everything under "verified"
was checked against the installed ComfyUI or the Hugging Face API on
2026-09-20; everything under "judgement" is an opinion that may not survive
contact with the work.

Wanted: text to image, image expansion (outpainting), images as reference,
editing an existing image. Plus uncensored variants, and the ability to pick a
previously generated image as a reference alongside uploaded ones.

## H3 cannot do any of it

Verified, not assumed:

- The frame grid is `17n + 5` with a minimum of five frames
  (`FrameGrid.alignedFrameCount`). There is no single-frame output to coax out
  of it.
- The model is a video architecture: video VAE and audio VAE, no image path.
- The MLX port has no image code at all — `dit.py`, `video_vae.py`,
  `audio_vae.py`, `text_encoder.py` and nothing else.

So this needs new weights. Nothing already on disk carries over either: the
text encoders are Qwen3-VL-32B builds tuned for H3, and the VAEs are video and
audio.

## The engine is already installed and already capable

The ComfyUI at `~/Library/Application Support/Halation/comfyui` is **0.36.0**
and knows **103 model families**, among them `Flux`, `Flux2`, `FluxInpaint`,
`FluxSchnell`, `QwenImage`, `HiDream`, `Chroma`, `ChromaRadiance`, `Omnigen2`,
`SDXL`, `SD3`, `SD15_instructpix2pix`, `SDXL_instructpix2pix`, `Lumina2`,
`HunyuanImage21`.

Every node the four capabilities need already ships — no custom nodes:

| capability | nodes |
|---|---|
| text to image | the ordinary sampler path |
| expansion | `ImagePadForOutpaint`, `InpaintModelConditioning`, `VAEEncodeForInpaint`, `SetLatentNoiseMask` |
| images as reference | `ReferenceLatent`, `FluxKontextMultiReferenceLatentMethod` |
| editing | `TextEncodeQwenImageEdit`, `TextEncodeQwenImageEditPlus`, `nodes_edit_model.py`, the FluxKontext nodes |

**This is weights plus a workflow graph, not a new backend.** MLX cannot
participate, so image modes are ComfyUI-only — the same shape as Ref2VA today,
and the engine picker already handles a mode with one engine.

## Candidate models

All public, ungated, and published in the ComfyUI split-file layout the
downloader already understands. Sizes are from the Hub's own metadata.

| model | covers | DiT | notes |
|---|---|---|---|
| **Chroma1-HD** | text to image | 17.8 GB | **Apache-2.0.** De-distilled Flux Schnell derivative, no content filter. `class Chroma` at `supported_models.py:1763`. |
| **Flux Kontext dev** | editing **and** reference, in one file | 11.9 GB fp8 | Cheapest way to three of the four capabilities. Flux dev licence is non-commercial. |
| **Qwen-Image / Qwen-Image-Edit** | text to image, editing | 20.5 GB fp8mixed, 40.9 GB bf16 | Needs Qwen2.5-VL-7B (9.4 GB fp8) and its own VAE (0.25 GB). |

A whole image setup is roughly **18–30 GB**, against H3's measured floor of
64 GB of unified memory. Image generation will run on machines that cannot run
this app's video path at all, which matters for anyone else picking it up.

### Uncensored

Generation is solved: **Chroma1-HD** is Apache-2.0, ungated and unfiltered, and
is supported natively. That licence is worth noticing — Flux dev is
non-commercial, and H3's own licence restricts territory *and* prohibits
pornographic output regardless of territory (see `verified-facts.md`).

Editing is the awkward one. The community edit models are GGUF-first —
`ChrisColeTech/qwen-image-edit-uncensored-GGUF` is five GGUF files to one
safetensors, licence stated as "unknown". The app already tells users *"GGUF
needs a ComfyUI custom node this app does not install."* Supporting those means
either taking on ComfyUI-GGUF as a dependency, or restricting to safetensors
releases such as `darknight9121/FLUX.2-klein-base-9B-bucket-uncensored`
(safetensors, licence "other", far less proven).

Decide the GGUF question before designing the catalogue entries, because it
changes whether `Quantization.gguf` stays permanently unloadable.

## What the app assumes about video

Measured, so the estimate is not a guess. 9,720 lines of Swift; **13 files**
carry video assumptions:

```
Models/GenerationSpec.swift          Services/RenderThroughput.swift
Models/OutputFormat.swift            Services/VideoPostProcessor.swift
Services/ComfyUIWorkflow.swift       Services/VideoPostProcessor+Output.swift
Services/JobFileWriter.swift         Views/ComposeCards.swift
Services/LibraryStore.swift          Views/ComposeSummary.swift
Services/RenderEngine.swift          Views/LibraryView.swift
                                     Views/QueueView.swift
```

Call sites: `spec.format` ×45, `durationSeconds` ×20, `videoURL` ×19,
`frameRate` ×13, `FrameGrid` ×5.

The load-bearing pieces:

- **`GenerationSpec`** carries duration, frame rate, codec and audio — all
  meaningless for an image — and lacks what images need: free width and height,
  CFG, denoise strength, and a mask.
- **`LibraryItem.videoURL`** is not optional and `LibraryView` builds an
  `AVPlayer` from it directly.
- **`RenderBackend.run`** returns a video URL and everything downstream runs
  through `VideoPostProcessor` (ffmpeg, AVFoundation).
- **`RenderThroughput`** measures step · megapixel · *duration*.
- **`ModelTask`** is `fl2va`/`ref2va` only; `MachineProfile.fit` and
  `ComfyUIModelSet.required(for:)` are H3-shaped.

## Generated images as references

Nearly free. `ReferenceAsset` is `url` + `kind` + `slot` and nothing else, so a
generated image is already a valid reference — the data model needs no change.
What is missing is a picker that offers the Library beside "Choose files…".
`ReferencesCard` works only from `$spec` and would need `AppState`.

Worth doing for reference **videos** too, which Ref2VA already accepts and
which has no UI path today.

## Staging

1. **Text to image, Chroma only.** No masks, no editing. Forces the
   media-kind refactor everything else waits on, and ends with something
   usable.
2. **Library as a reference source.** Small, and independently useful.
3. **Editing and reference conditioning** via Flux Kontext — one model, two
   capabilities.
4. **Expansion.** Needs the mask editor, which is the only genuinely new
   interaction in the whole plan.
5. **Uncensored variants.** Catalogue entries; the machinery already exists.

## Effort — judgement, not measurement

| stage | size |
|---|---|
| 1. text to image end to end | comparable to the localisation batch: days, not hours |
| 2. library as reference source | half a day |
| 3. editing and reference | modest once (1) has landed |
| 4. expansion with a mask editor | the wildcard — new interaction design |
| 5. uncensored entries | hours |

The dominant cost in (1) is **not** the model or the graph.
`ComfyUIWorkflow.swift` is 200 lines of hand-built nodes, so a second graph is
about a day. The cost is that `LibraryItem.videoURL` and the video-shaped
`GenerationSpec` are load-bearing; making them media-kind-aware is the
structural change the rest of the plan waits on.

## Open questions

- **One spec or two?** Widening `GenerationSpec` with optional image fields
  keeps one queue and one library, but leaves every call site asking which half
  applies. A sibling `ImageSpec` behind a `MediaKind` enum is cleaner to read
  and worse to plumb. Decide before touching the 45 `spec.format` call sites.
- **Does the Library stay one list?** Mixed images and videos in one grid is
  simpler to build and may be right, since both are "things I made".
- **GGUF**: take on the custom node, or stay safetensors-only?
- **Aspect ratios.** `OutputFormat.AspectRatio` maps to H3's fixed canvases.
  Image models take arbitrary sizes rounded to 8 or 16.

## Watch list

- The hand-built graphs are pinned to ComfyUI's node names and break across its
  versions. One graph is maintainable; four is a standing cost, and there is no
  test that would catch a rename. `Scripts/check_catalog_urls.py` covers the
  weights; nothing covers the graphs.
- An MLX image path would change this plan the way an MLX Ref2VA conversion
  would have changed the other one. Worth a look before committing to
  ComfyUI-only, since it would keep the native fast path.
