"""Running H3 in less memory: a 4-bit text encoder, and letting it go early.

The MLX port holds Qwen3-VL-32B in bfloat16 — about 34 GB for the 50 layers H3
reads — for the whole render, beside the transformer. It is used once, at the
very start, to turn the prompt into conditioning, and never again. Two things
follow, and this module does both:

**A 4-bit encoder.** mlx-serve publishes the same 50-layer stack quantized to
MLX affine 4-bit, group size 64 (`ddalcu/MiniMax-H3-FL2VA-MLX-Serve-4bit`,
`text_encoder.safetensors`, 15.8 GB). Its layout is mlx-serve's, not the
upstream release's — keys are `model.layers.N…` rather than
`model.language_model.layers.N…`, the file carries no Qwen3-VL config, and
there is no vision tower at all — so the port cannot load it as it stands.
`QuantizedTextEncoder` is the port's own encoder class with only its loading
replaced: the same mlx-vlm modules, the same truncated forward, the same
request presentation, so everything after loading is the port's code running
unchanged. Without a vision tower it takes text only; keyframe modes still need
the full encoder, and the app says so before a render starts.

**Releasing it after use.** `release_after_encode` replaces the pipeline's
reference with a stub once the prompt is encoded, and returns the memory to the
system. The port reads `pipeline.text_encoder` in one place, the first line of a
render, so nothing later misses it. Each render is its own process, so the
next one loads a fresh encoder anyway and this costs nothing.

The port itself is not edited: it is cloned from upstream and replaced
whenever the runtime is repaired.
"""

from __future__ import annotations

import gc
import json
from pathlib import Path
from typing import Callable, Optional

#: Qwen3-VL-32B's own config, copied from the upstream release's
#: `FL2VA/text_encoder/config.json`. The 4-bit pack does not carry one, and a
#: Mac small enough to need the pack is one without the 67 GB upstream encoder
#: to borrow it from.
_BUNDLED_CONFIG = Path(__file__).with_name("qwen3vl_32b_config.json")


def is_quantized_pack(path: Optional[str]) -> bool:
    """Whether `path` is an mlx-serve pack rather than the upstream encoder."""
    if not path:
        return False
    root = Path(path)
    try:
        config = json.loads((root / "config.json").read_text())
    except (OSError, ValueError):
        return False
    return config.get("model_type") == "minimax_h3" and (root / "text_encoder.safetensors").exists()


def _encoder_class():
    from minimax_h3_mlx.packing import TEXT_ENCODER_LAYER
    from minimax_h3_mlx.text_encoder import MiniMaxH3TextEncoder

    class QuantizedTextEncoder(MiniMaxH3TextEncoder):
        """The port's encoder, loaded from mlx-serve's 4-bit file."""

        def __init__(self, pack_dir: str | Path, tokenizer_dir: Optional[Path] = None,
                     verbose: bool = False):
            # Mirrors the base class's construction, minus the vision tower and
            # with the config read from the bundled copy; `_load_weights` is
            # the part that actually differs. Not calling super().__init__,
            # because that reads `<dir>/config.json` as a Qwen3-VL config, and
            # the pack's is mlx-serve's own.
            import mlx.core as mx
            from mlx_vlm.models.qwen3_vl.config import ModelConfig, TextConfig, VisionConfig
            from mlx_vlm.models.qwen3_vl.language import Qwen3VLModel

            pack_dir = Path(pack_dir)
            raw = json.loads(_BUNDLED_CONFIG.read_text())
            num_layers = TEXT_ENCODER_LAYER

            self.num_layers = num_layers
            self.full_layers = raw["text_config"]["num_hidden_layers"]
            self.dtype = mx.bfloat16

            text_raw = dict(raw["text_config"])
            text_raw["num_hidden_layers"] = num_layers
            self.text_config = TextConfig.from_dict(text_raw)
            self.vision_config = VisionConfig.from_dict(raw["vision_config"])
            self.model_config = ModelConfig.from_dict({
                **raw, "text_config": text_raw, "vision_config": raw["vision_config"],
                "model_type": raw.get("model_type", "qwen3_vl"),
            })
            self.model_config.text_config = self.text_config
            self.model_config.vision_config = self.vision_config

            self.language = Qwen3VLModel(self.text_config)
            self.vision = None  # the pack has none
            self._load_pack(pack_dir, verbose)

            self.image_token_id = raw["image_token_id"]
            self.vision_start_token_id = raw["vision_start_token_id"]
            self.vision_end_token_id = raw["vision_end_token_id"]
            self.merge_size = self.vision_config.spatial_merge_size

            self._tokenizer = None
            self._processor = None
            # The upstream tokenizer when it is installed (the support download
            # carries it), else the pack's byte-identical copy.
            self._model_dir = pack_dir
            self._tokenizer_dir = tokenizer_dir if tokenizer_dir and tokenizer_dir.exists() else pack_dir

        @property
        def tokenizer(self):
            if self._tokenizer is None:
                from transformers import AutoTokenizer

                self._tokenizer = AutoTokenizer.from_pretrained(str(self._tokenizer_dir))
            return self._tokenizer

        def _load_pack(self, pack_dir: Path, verbose: bool) -> None:
            import mlx.core as mx
            import mlx.nn as nn
            from mlx.utils import tree_flatten, tree_unflatten

            quant = json.loads((pack_dir / "config.json").read_text()).get("quantization", {})
            group_size = int(quant.get("group_size", 64))
            bits = int(quant.get("bits", 4))

            weights = {}
            skipped = 0
            for key, tensor in mx.load(str(pack_dir / "text_encoder.safetensors")).items():
                if not key.startswith("model."):
                    skipped += 1
                    continue
                rest = key[len("model."):]
                if rest.startswith("layers.") and int(rest.split(".")[1]) >= self.num_layers:
                    skipped += 1
                    continue
                weights[rest] = tensor

            # Quantize exactly the layers the file stores quantized, so the
            # module tree matches it however mlx-serve chose: a layer carrying
            # `scales` is a QuantizedLinear, anything else stays dense.
            quantized = {key[: -len(".scales")] for key in weights if key.endswith(".scales")}
            nn.quantize(self.language, group_size=group_size, bits=bits,
                        class_predicate=lambda path, _module: path in quantized)

            expected = {key for key, _ in tree_flatten(self.language.parameters())}
            # The final norm is never applied — H3 reads the state before it —
            # so a pack without it is complete for this purpose.
            missing = sorted(expected - weights.keys() - {"norm.weight"})
            if missing:
                raise KeyError(f"4-bit text encoder is missing {len(missing)} tensors, e.g. {missing[:4]}.")
            kept = [(key, value) for key, value in weights.items() if key in expected]
            skipped += len(weights) - len(kept)
            self.language.update(tree_unflatten(kept))
            mx.eval(self.language.parameters())
            self.skipped_tensors = skipped
            if verbose:
                print(f"  text_encoder.safetensors: kept {len(kept)} (4-bit, {len(quantized)} quantized layers)")

    return QuantizedTextEncoder


def load_quantized_encoder(pack_dir: str, tokenizer_dir: Optional[Path] = None):
    return _encoder_class()(pack_dir, tokenizer_dir=tokenizer_dir, verbose=True)


def build_pipeline(pipeline_class, checkpoint: str, transformer_dir: Optional[str],
                   text_encoder_dir: str):
    """`from_pretrained`, with the 4-bit encoder in place of the upstream one.

    Same components in the same order, printing the same "  <label>: <s>s"
    lines, so the app's load progress reads it exactly as it reads the port's.
    """
    import time

    from minimax_h3_mlx.load import load_audio_vae, load_dit, load_video_vae
    from minimax_h3_mlx.pipeline import PipelineConfig

    root = Path(checkpoint)
    dit_path = Path(transformer_dir) if transformer_dir else root / "transformer"
    config = PipelineConfig.from_model_index(root / "model_index.json")

    def step(label: str, fn: Callable):
        started = time.perf_counter()
        out = fn()
        print(f"  {label}: {time.perf_counter() - started:.1f}s")
        return out

    print(f"loading MiniMax-H3 from {root} with the 4-bit text encoder")
    text_encoder = step("text encoder",
                        lambda: load_quantized_encoder(text_encoder_dir, root / "tokenizer"))
    dit = step(f"transformer ({dit_path.name})", lambda: load_dit(dit_path))
    video_vae = step("video vae", lambda: load_video_vae(root / "video_vae"))
    audio_vae = step("audio vae", lambda: load_audio_vae(root / "audio_vae"))
    return pipeline_class(dit, text_encoder, video_vae, audio_vae, config)


class _Released:
    """Stands in for the encoder once it is gone, and says so if anything asks."""

    def __getattr__(self, name):
        raise RuntimeError("The text encoder was released after encoding the prompt.")


def release_after_encode(pipeline, on_release: Optional[Callable[[int], None]] = None) -> None:
    """Drop the encoder from memory as soon as it has encoded the prompt.

    `on_release` is told how many bytes MLX reports free afterwards, for the
    log: the figure is the evidence that this did anything.
    """
    import mlx.core as mx

    encoder = pipeline.text_encoder
    original = encoder.encode

    def encode_then_release(*args, **kwargs):
        result = original(*args, **kwargs)
        mx.eval(result[0])
        before = _active_bytes(mx)
        pipeline.text_encoder = _Released()
        # Break every remaining reference: this closure's, the bound method's.
        encoder.__dict__.clear()
        gc.collect()
        mx.clear_cache()
        if on_release is not None:
            on_release(max(before - _active_bytes(mx), 0))
        return result

    encoder.encode = encode_then_release


def _active_bytes(mx) -> int:
    for owner in (mx, getattr(mx, "metal", None)):
        fn = getattr(owner, "get_active_memory", None)
        if fn is not None:
            try:
                return int(fn())
            except Exception:
                continue
    return 0
