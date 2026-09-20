"""Locates and describes the installed MiniMax-H3 MLX port.

The port is a checkout on ``PYTHONPATH`` rather than an installed distribution, and
it ships no ``__init__.py`` — so ``import minimax_h3_mlx`` succeeds as a namespace
package while exposing nothing. Everything real lives in ``minimax_h3_mlx.pipeline``.

This module reports what is present so the app can say precisely what is missing,
and checks the pipeline's signature so a fork with a changed API is detected before
a multi-hour render rather than during one.
"""
from __future__ import annotations

import importlib
import inspect
import os
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

import protocol

PIPELINE_MODULE = "minimax_h3_mlx.pipeline"
PIPELINE_CLASS = "MiniMaxH3Pipeline"

# Keyword arguments this app relies on. A fork that drops one of these would fail
# mid-render, so the absence is reported up front instead.
REQUIRED_CALL_KWARGS = ("prompt", "duration_seconds", "num_inference_steps", "seed")
OPTIONAL_CALL_KWARGS = ("aspect", "images", "keyframe_anchors", "height", "width")


@dataclass
class Capabilities:
    module: Optional[str] = None
    pipeline_class: Optional[str] = None
    call_kwargs: List[str] = field(default_factory=list)
    from_pretrained_kwargs: List[str] = field(default_factory=list)
    missing_kwargs: List[str] = field(default_factory=list)
    supports_keyframes: bool = False
    supports_references: bool = False
    has_media_writers: bool = False
    checkout_path: Optional[str] = None
    error: Optional[str] = None

    @property
    def is_usable(self) -> bool:
        return self.pipeline_class is not None and not self.missing_kwargs

    def as_dict(self) -> Dict[str, Any]:
        return {
            "module": self.module,
            "pipeline_class": self.pipeline_class,
            "call_kwargs": self.call_kwargs,
            "from_pretrained_kwargs": self.from_pretrained_kwargs,
            "missing_kwargs": self.missing_kwargs,
            "supports_keyframes": self.supports_keyframes,
            "supports_references": self.supports_references,
            "has_media_writers": self.has_media_writers,
            "checkout_path": self.checkout_path,
            "error": self.error,
            "usable": self.is_usable,
        }


def _signature_kwargs(func) -> List[str]:
    try:
        parameters = inspect.signature(func).parameters
    except (TypeError, ValueError):
        return []
    return [
        name for name, p in parameters.items()
        if name != "self" and p.kind in (p.POSITIONAL_OR_KEYWORD, p.KEYWORD_ONLY)
    ]


def detect() -> Capabilities:
    caps = Capabilities(checkout_path=os.environ.get("HALATION_H3_REPO"))

    try:
        module = importlib.import_module(PIPELINE_MODULE)
    except Exception as exc:
        caps.error = f"{PIPELINE_MODULE} could not be imported: {exc}"
        return caps

    caps.module = PIPELINE_MODULE
    pipeline = getattr(module, PIPELINE_CLASS, None)
    if pipeline is None:
        caps.error = f"{PIPELINE_MODULE} has no {PIPELINE_CLASS}."
        return caps

    caps.pipeline_class = PIPELINE_CLASS
    caps.call_kwargs = _signature_kwargs(getattr(pipeline, "__call__"))
    caps.from_pretrained_kwargs = _signature_kwargs(
        getattr(pipeline, "from_pretrained", None) or (lambda: None))

    present = set(caps.call_kwargs)
    caps.missing_kwargs = [name for name in REQUIRED_CALL_KWARGS if name not in present]
    caps.supports_keyframes = "images" in present and "keyframe_anchors" in present
    # No released version of the port packs reference images, videos or audio.
    caps.supports_references = any(
        name in present for name in
        ("reference_images", "ref_images", "references", "reference_videos"))

    try:
        media = importlib.import_module("minimax_h3_mlx.media")
        caps.has_media_writers = hasattr(media, "save_mp4") and hasattr(media, "save_wav")
    except Exception:
        caps.has_media_writers = False

    return caps


def ffmpeg_path() -> Optional[str]:
    """The port pipes raw frames into ffmpeg, so it must be on PATH to write video."""
    override = os.environ.get("HALATION_FFMPEG")
    if override and Path(override).is_file():
        return override
    for candidate in ("ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"):
        found = shutil.which(candidate) if not os.path.isabs(candidate) else (
            candidate if Path(candidate).is_file() else None)
        if found:
            return found
    return None
