#!/usr/bin/env python3
"""Sidecar for the VideoGen Mac app.

Subcommands
  doctor    Report the runtime's health as a single JSON object.
  probe     Report the installed H3 port's callable surface.
  download  Fetch model repositories into the shared HF cache, with progress.
  generate  Run one render described by a JSON job file.

Every subcommand writes NDJSON to stdout; see protocol.py.
"""
from __future__ import annotations

import argparse
import contextlib
import json
import os
import platform
import random
import re
import shutil
import subprocess
import sys
import threading
import traceback
from pathlib import Path
from typing import Any, Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))

import protocol  # noqa: E402
import h3_adapter  # noqa: E402


# ── doctor ──────────────────────────────────────────────────────────────────────

def cmd_doctor(_: argparse.Namespace) -> int:
    report: Dict[str, Any] = {
        "python": sys.version.split()[0],
        "executable": sys.executable,
        "platform": platform.platform(),
        "machine": platform.machine(),
        "hf_home": os.environ.get("HF_HOME"),
        "packages": {},
        "problems": [],
    }

    # mlx_vlm is needed by the text encoder but missing from the port's own
    # requirements, so it is checked here rather than discovered mid-render.
    for name in ("mlx", "mlx_vlm", "numpy", "huggingface_hub", "PIL", "safetensors"):
        try:
            module = __import__(name)
            report["packages"][name] = getattr(module, "__version__", "present")
        except Exception as exc:
            report["packages"][name] = None
            report["problems"].append(f"{name} is not importable: {exc}")

    if platform.machine() != "arm64":
        report["problems"].append(
            "This build of Python is not arm64. MLX needs an Apple-silicon interpreter.")

    try:
        import mlx.core as mx
        a = mx.ones((256, 256))
        mx.eval(a @ a)
        report["mlx_metal_ok"] = True
    except Exception as exc:
        report["mlx_metal_ok"] = False
        report["problems"].append(f"MLX could not run a Metal kernel: {exc}")

    report["ffmpeg"] = h3_adapter.ffmpeg_path()
    if not report["ffmpeg"]:
        report["problems"].append(
            "ffmpeg was not found. Reference videos and WAV sidecars need it.")

    caps = h3_adapter.detect()
    report["h3"] = caps.as_dict()
    if caps.error:
        report["problems"].append(caps.error)
    elif caps.missing_kwargs:
        report["problems"].append(
            "The installed port's pipeline is missing: " + ", ".join(caps.missing_kwargs))
    if caps.pipeline_class and not caps.has_media_writers:
        report["problems"].append(
            "minimax_h3_mlx.media has no save_mp4/save_wav; rendered clips cannot be written.")

    report["healthy"] = not report["problems"]
    protocol.emit(type="doctor", **report)
    protocol.done()
    return 0


def cmd_probe(_: argparse.Namespace) -> int:
    protocol.emit(type="probe", **h3_adapter.detect().as_dict())
    protocol.done()
    return 0


# ── download ────────────────────────────────────────────────────────────────────

def cmd_download(args: argparse.Namespace) -> int:
    """Download one repo (optionally a subset) into the shared HF cache.

    Progress is measured by watching the cache directory grow rather than by
    hooking tqdm: huggingface_hub nests several progress bars whose meanings have
    changed between versions, and summing them double-counts.

    Resume and de-duplication are the hub's own; pointing HF_HOME at the shared
    folder is what lets a second project reuse these bytes.
    """
    try:
        from huggingface_hub import snapshot_download
    except Exception as exc:
        protocol.error(f"huggingface_hub is not available: {exc}")
        return 1

    repo_id: str = args.repo
    patterns: Optional[List[str]] = json.loads(args.patterns) if args.patterns else None

    # A single named file, fetched as a plain file rather than into the HF cache.
    # ComfyUI reads real files from its own folder layout; it cannot use the
    # symlinked cache tree the MLX path relies on.
    if args.file:
        return _download_single(repo_id, args.file, args.dest)

    protocol.stage("preparing")
    protocol.log(f"Resolving {repo_id}…")

    total_bytes = 0
    try:
        from huggingface_hub import HfApi
        info = HfApi().model_info(repo_id, files_metadata=True)
        for sibling in info.siblings or []:
            if patterns and not _matches(sibling.rfilename, patterns):
                continue
            total_bytes += getattr(sibling, "size", None) or 0
    except Exception as exc:
        protocol.log(f"Could not read the file manifest ({exc}). Progress will be coarse.")

    cache_dir = _repo_cache_dir(repo_id)
    watcher = _SizeWatcher(repo_id, cache_dir, total_bytes)
    protocol.download(repo_id, 0, total_bytes)

    protocol.stage("generating")  # reuse the UI's "active" styling
    watcher.start()
    try:
        path = snapshot_download(
            repo_id=repo_id,
            allow_patterns=patterns,
            max_workers=args.workers,
        )
    except Exception as exc:
        watcher.stop()
        protocol.error(f"Download of {repo_id} failed: {exc}")
        return 1
    watcher.stop()

    final = watcher.downloaded()
    protocol.download(repo_id, total_bytes or final, total_bytes or final)
    protocol.log(f"{repo_id} is in place at {path}")
    protocol.done()
    return 0


def _prune_empty(start: Path, stop_at: Path) -> None:
    """Remove `start` and its empty parents, stopping before `stop_at`."""
    current = start
    while current != stop_at and current.is_dir():
        try:
            current.rmdir()
        except OSError:
            return
        current = current.parent


def _prune_empty_children(directory: Path) -> None:
    """Remove empty folders directly under `directory`, deepest first."""
    if not directory.is_dir():
        return
    for path in sorted(directory.rglob("*"), key=lambda p: -len(p.parts)):
        if path.is_dir() and path.name != ".cache":
            try:
                path.rmdir()
            except OSError:
                pass


def _download_single(repo_id: str, filename: str, dest_dir: str) -> int:
    """Fetch one file into `dest_dir`, reporting progress from its size on disk."""
    from huggingface_hub import hf_hub_download, HfApi

    destination = Path(dest_dir)
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / Path(filename).name

    total = 0
    try:
        info = HfApi().model_info(repo_id, files_metadata=True)
        for sibling in info.siblings or []:
            if sibling.rfilename == filename:
                total = getattr(sibling, "size", None) or 0
                break
    except Exception as exc:
        protocol.log(f"Could not read the manifest ({exc}). Progress will be coarse.")

    if target.exists() and total and target.stat().st_size >= total * 0.99:
        protocol.log(f"{target.name} is already present.")
        protocol.download(repo_id, total, total)
        protocol.done()
        return 0

    # A transfer that was cancelled leaves the repository's folder shape behind.
    _prune_empty_children(destination)

    protocol.stage("preparing")
    protocol.download(repo_id, 0, total)
    protocol.stage("generating")

    watcher = _SizeWatcher(repo_id, destination, total)
    watcher.start()
    try:
        # local_dir gives real files rather than symlinks into the cache. It is
        # the destination folder itself: `hf_hub_download` recreates the file's
        # repository path underneath, which is not the layout ComfyUI wants, so
        # the result is moved up to `dest_dir/<name>` below. Passing a parent
        # instead used to scatter files into folders of the repository's choosing.
        fetched = Path(hf_hub_download(repo_id=repo_id, filename=filename,
                                       local_dir=str(destination)))
    except Exception as exc:
        watcher.stop()
        protocol.error(f"Download of {filename} failed: {exc}")
        return 1
    watcher.stop()

    if fetched.resolve() != target.resolve():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(fetched), str(target))
        # Leave no empty scaffolding from the repository's own layout. Also swept
        # on the way in, because a cancelled transfer never reaches this point and
        # its empty folders would otherwise accumulate.
        _prune_empty(fetched.parent, stop_at=destination)

    protocol.download(repo_id, total or watcher.downloaded(), total or watcher.downloaded())
    protocol.log(f"{filename} is in place.")
    protocol.done()
    return 0


def _repo_cache_dir(repo_id: str) -> Path:
    """Where huggingface_hub keeps this repo's blobs under the active HF_HOME."""
    home = os.environ.get("HF_HOME")
    hub = Path(home) / "hub" if home else Path.home() / ".cache" / "huggingface" / "hub"
    return hub / ("models--" + repo_id.replace("/", "--"))


class _SizeWatcher:
    """Reports download progress by sampling the cache directory's size.

    Two subtleties this has to handle.

    Several catalog entries share one repository — the upstream release supplies
    the VAEs and the 67 GB text encoder as separate subsets — so the cache
    directory already holds bytes that are not part of *this* transfer. Progress
    is therefore measured from a baseline taken at the start, not from zero, or a
    12 GB download reports 155 GB of 11 GB.

    And reaching 100% of the byte count is not the end: the hub still has to
    verify checksums and materialise the snapshot symlinks, which on a large repo
    takes minutes with nothing else to show. We say so rather than leaving a full
    bar sitting there looking stuck.
    """

    def __init__(self, repo_id: str, directory: Path, total: int, interval: float = 1.0):
        self.repo_id = repo_id
        self.directory = directory
        self.total = total
        self.interval = interval
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._baseline = 0
        self._announced_finalising = False

    def current_bytes(self) -> int:
        """Bytes under the cache directory. Follows symlinks, because
        huggingface_hub 1.x points per-repo blobs at a shared Xet store."""
        total = 0
        for root, _, files in os.walk(self.directory, onerror=lambda _: None):
            for name in files:
                try:
                    total += os.stat(os.path.join(root, name)).st_size
                except OSError:
                    continue
        return total

    def downloaded(self) -> int:
        """Bytes attributable to this transfer, clamped to its own total."""
        seen = max(self.current_bytes() - self._baseline, 0)
        return min(seen, self.total) if self.total else seen

    def _run(self) -> None:
        while not self._stop.wait(self.interval):
            seen = self.downloaded()
            note = None
            if self.total and seen >= self.total:
                note = "Verifying checksums and linking files — this can take a while"
                if not self._announced_finalising:
                    self._announced_finalising = True
                    protocol.log("Transfer complete. " + note)
            protocol.download(self.repo_id, seen, self.total or seen, note)

    def start(self) -> None:
        self._baseline = self.current_bytes()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=3)


def _matches(name: str, patterns: List[str]) -> bool:
    from fnmatch import fnmatch
    return any(fnmatch(name, pattern) for pattern in patterns)


# ── generate ────────────────────────────────────────────────────────────────────

def cmd_generate(args: argparse.Namespace) -> int:
    """Run one render through `MiniMaxH3Pipeline`.

    The pipeline returns numpy arrays rather than a file, so the writing is ours to
    do — we use the port's own ffmpeg-backed writers to avoid a second dependency.
    """
    job: Dict[str, Any] = json.loads(Path(args.job).read_text())

    checkpoint = job.get("support_path")
    if not checkpoint:
        protocol.error("No checkpoint directory was resolved. Install the VAEs in Models.")
        return 1

    resolved_seed = job.get("seed")
    if resolved_seed is None:
        resolved_seed = random.getrandbits(31)
    protocol.seed(resolved_seed)

    try:
        from minimax_h3_mlx.pipeline import MiniMaxH3Pipeline
        from minimax_h3_mlx import media
    except Exception as exc:
        protocol.error(
            "The MiniMax-H3 MLX port could not be imported: "
            f"{exc}. Repair the runtime in Settings."
        )
        return 1

    steps = int(job["steps"])
    reporter = protocol.StepReporter(max(1, steps - 1))

    _enable_loader_verbosity()
    sizes = _component_file_sizes(checkpoint, job.get("transformer_path"))

    # The pipeline prints "  step done/total" as it denoises and takes no callback,
    # so we tee stdout through a parser instead of losing the progress entirely.
    tee = _StepTee(reporter, file_sizes=sizes)

    protocol.stage("preparing")
    total_gb = sum(sizes.values()) / 1e9
    protocol.substage("Loading model", 0, sum(sizes.values()) or len(_LOAD_STEPS),
                      f"{_LOAD_STEPS[0]} first · {total_gb:.0f} GB of weights")
    try:
        with contextlib.redirect_stdout(tee):
            pipeline = MiniMaxH3Pipeline.from_pretrained(
                checkpoint_dir=checkpoint,
                transformer_dir=job.get("transformer_path"),
                verbose=True,
            )

        images, anchors = _keyframes(job)
        _report_prompt_tokens(pipeline, job["prompt"], images)

        protocol.stage("generating")
        with contextlib.redirect_stdout(tee):
            result = pipeline(
                prompt=job["prompt"],
                duration_seconds=float(job["duration_seconds"]),
                aspect=(int(job["aspect_width"]), int(job["aspect_height"])),
                num_inference_steps=steps,
                seed=int(resolved_seed),
                images=images or None,
                keyframe_anchors=tuple(anchors),
                verbose=True,
            )
    except Exception as exc:
        protocol.error(f"Generation failed: {exc}")
        protocol.log(traceback.format_exc(limit=14))
        return 1

    reporter.report_memory()
    protocol.stage("decoding")

    output = Path(job["raw_output_path"])
    output.parent.mkdir(parents=True, exist_ok=True)
    wav_path = output.with_suffix(".wav")

    try:
        media.save_wav(wav_path, result.audio, result.sample_rate)
        _encode_video(output, result.video, result.fps, wav_path, job.get("codec", "h264"))
    except Exception as exc:
        protocol.error(f"Could not write the video: {exc}")
        protocol.log(traceback.format_exc(limit=8))
        return 1

    if not output.exists():
        protocol.error(f"The pipeline finished but no file appeared at {output}.")
        return 1

    protocol.log(
        f"Rendered in {getattr(result, 'total_seconds', 0):.0f}s "
        f"({getattr(result, 'seconds_per_step', 0):.1f}s per step)"
    )
    protocol.artifact(video=str(output),
                      audio=str(wav_path) if wav_path.exists() else None)
    protocol.done()
    return 0


# ffmpeg encoders per codec. SVT-AV1 rather than libaom: on this class of machine
# it encodes a 5-second 768p clip in about a second, where libaom takes minutes
# for the same thing.
_ENCODERS = {
    "h264": ["-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p"],
    "av1": ["-c:v", "libsvtav1", "-crf", "30", "-preset", "8", "-pix_fmt", "yuv420p"],
}


def _report_prompt_tokens(pipeline, prompt: str, images) -> None:
    """Count the tokens the text encoder will actually be handed.

    Built through the encoder's own `build_request`, so the figure is the real
    sequence length rather than a guess: with keyframes or references each image
    contributes a block of vision tokens that is far larger than the prompt, and
    only the encoder knows how large.

    Never fatal. This is a statistic, and a render must not fail for want of one.
    """
    try:
        encoder = pipeline.text_encoder
        text_only = len(encoder.tokenizer(prompt, add_special_tokens=False)["input_ids"])
        try:
            input_ids, _, _ = encoder.build_request(prompt, images or None)
            total = int(input_ids.shape[-1])
        except Exception:
            # Fall back to the text alone rather than reporting nothing.
            total = text_only
        protocol.tokens(total=total, text=text_only)
    except Exception as exc:  # noqa: BLE001 - deliberately swallowed
        protocol.log(f"Could not count prompt tokens: {exc}")


def _encode_video(path: Path, video, fps: int, audio_path: Path, codec: str) -> None:
    """Encode raw frames straight to the requested codec.

    The port's own `media.save_mp4` hardcodes libx264, so this replaces it rather
    than encoding twice. Either way it is a single encode from the model's raw
    output — the point is to avoid a transcode, not to prefer one codec.
    """
    ffmpeg = h3_adapter.ffmpeg_path()
    if ffmpeg is None:
        raise RuntimeError("ffmpeg not found on PATH.")

    settings = _ENCODERS.get(codec)
    if settings is None:
        protocol.log(f"Unknown codec {codec!r}; writing H.264.")
        settings = _ENCODERS["h264"]

    frames, height, width, _ = video.shape
    command = [
        ffmpeg, "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24",
        "-s", f"{width}x{height}", "-r", str(fps), "-i", "pipe:0",
    ]
    if audio_path is not None and Path(audio_path).exists():
        command += ["-i", str(audio_path), "-c:a", "aac", "-b:a", "192k", "-shortest"]
    command += settings + [str(path)]

    protocol.log(f"Encoding {frames} frames as {codec}…")
    import numpy as np
    raw = np.ascontiguousarray(video, dtype=np.uint8).tobytes()
    process = subprocess.run(command, input=raw, capture_output=True)
    if process.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {process.stderr.decode()[:500]}")


def _keyframes(job: Dict[str, Any]):
    """Keyframe images paired with their anchors, in the order the model packs them."""
    try:
        from PIL import Image
    except Exception:
        Image = None

    images: List[Any] = []
    anchors: List[str] = []
    for key, anchor in (("first_frame", "first"), ("last_frame", "last")):
        path = job.get(key)
        if not path:
            continue
        if Image is None:
            protocol.log(f"Pillow is unavailable; ignoring the {anchor} keyframe.")
            continue
        images.append(Image.open(path).convert("RGB"))
        anchors.append(anchor)
    return images, anchors


# The four components `from_pretrained` loads, in the order it loads them. It
# prints "  <label>: <seconds>s" as each finishes.
_LOAD_STEPS = ("text encoder", "transformer", "video vae", "audio vae")


def _enable_loader_verbosity() -> bool:
    """Make the weight loaders announce each shard.

    `from_pretrained` does not pass `verbose` down, so by default the only load
    signal is four milestone lines — and the first covers the 67 GB text encoder,
    which means many minutes at zero. The loaders are imported inside
    `from_pretrained`, so patching their modules beforehand takes effect.

    Entirely best-effort: a port whose signatures differ just keeps the coarse
    milestones.
    """
    patched = False
    try:
        import minimax_h3_mlx.load as load_mod
        original = load_mod.load_dit

        def verbose_load_dit(*args, **kwargs):
            kwargs.setdefault("verbose", True)
            return original(*args, **kwargs)

        load_mod.load_dit = verbose_load_dit
        patched = True
    except Exception as exc:
        protocol.log(f"Could not enable transformer load detail: {exc}")

    try:
        import minimax_h3_mlx.text_encoder as te_mod
        original_te = te_mod.MiniMaxH3TextEncoder

        class VerboseTextEncoder(original_te):  # type: ignore[misc,valid-type]
            def __init__(self, *args, **kwargs):
                kwargs.setdefault("verbose", True)
                super().__init__(*args, **kwargs)

        te_mod.MiniMaxH3TextEncoder = VerboseTextEncoder
        patched = True
    except Exception as exc:
        protocol.log(f"Could not enable text-encoder load detail: {exc}")

    return patched


def _component_file_sizes(checkpoint: str, transformer: Optional[str]) -> Dict[str, int]:
    """Map weight-file name -> size, across every component that will be loaded.

    Used to weight load progress by bytes rather than by component count, so the
    text encoder's fourteen shards advance the bar proportionally to their size.
    Symlinks are followed: huggingface_hub stores content in a shared Xet tree.
    """
    sizes: Dict[str, int] = {}
    roots = [os.path.join(checkpoint, name)
             for name in ("text_encoder", "video_vae", "audio_vae")]
    roots.append(transformer or os.path.join(checkpoint, "transformer"))

    for root in roots:
        for directory, _, files in os.walk(root, onerror=lambda _: None):
            for name in files:
                if not name.endswith((".safetensors", ".bin", ".gguf")):
                    continue
                try:
                    sizes[name] = os.stat(os.path.join(directory, name)).st_size
                except OSError:
                    continue
    return sizes

_LOAD_DONE = re.compile(
    r"^(text encoder|transformer[^:]*|video vae|audio vae):\s*[\d.]+s$", re.I)
_SHARD = re.compile(r"^(\S+\.safetensors):", re.I)


class _StepTee:
    """Forwards the pipeline's own stdout into protocol events.

    `MiniMaxH3Pipeline` writes progress with `print` and takes no callback, so
    parsing its output is the only way to report anything. Three things are
    recognised: the diffusion step counter, the four load milestones, and the
    per-shard lines that give finer detail while a component is loading.
    Everything else becomes a log line.
    """

    def __init__(self, reporter: "protocol.StepReporter",
                 file_sizes: Optional[Dict[str, int]] = None) -> None:
        self.reporter = reporter
        self._buffer = ""
        self._loaded = 0
        self._sizes = file_sizes or {}
        self._total_bytes = sum(self._sizes.values())
        self._loaded_bytes = 0
        self._seen_shards: set = set()

    def write(self, text: str) -> int:
        self._buffer += text
        while "\n" in self._buffer:
            line, self._buffer = self._buffer.split("\n", 1)
            self._handle(line)
        return len(text)

    def _handle(self, line: str) -> None:
        stripped = line.strip()
        if not stripped:
            return

        match = re.match(r"step\s+(\d+)\s*/\s*(\d+)", stripped)
        if match:
            completed, total = int(match.group(1)), int(match.group(2))
            if total > 0 and self.reporter.total != total:
                self.reporter.total = total
            self.reporter.advance(completed)
            return

        if _LOAD_DONE.match(stripped):
            self._loaded = min(self._loaded + 1, len(_LOAD_STEPS))
            nxt = (_LOAD_STEPS[self._loaded]
                   if self._loaded < len(_LOAD_STEPS) else "finishing")
            self._report_load(f"loaded {stripped.split(':')[0]} · next: {nxt}")
            protocol.log(stripped)
            return

        shard = _SHARD.match(stripped)
        if shard:
            name = shard.group(1)
            if name not in self._seen_shards:
                self._seen_shards.add(name)
                self._loaded_bytes += self._sizes.get(name, 0)
            current = (_LOAD_STEPS[self._loaded]
                       if self._loaded < len(_LOAD_STEPS) else "model")
            self._report_load(f"{current} · {name}")
            return

        protocol.log(stripped)

    def _report_load(self, detail: str) -> None:
        """Byte-weighted where we know the sizes, component-counted otherwise."""
        if self._total_bytes > 0:
            done = min(self._loaded_bytes, self._total_bytes)
            protocol.substage("Loading model", done, self._total_bytes, detail)
        else:
            protocol.substage("Loading model", self._loaded, len(_LOAD_STEPS), detail)

    def flush(self) -> None:
        if self._buffer.strip():
            self._handle(self._buffer)
            self._buffer = ""


# ── entry point ─────────────────────────────────────────────────────────────────

def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="videogen_sidecar")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("doctor").set_defaults(func=cmd_doctor)
    subparsers.add_parser("probe").set_defaults(func=cmd_probe)

    download = subparsers.add_parser("download")
    download.add_argument("--repo", required=True)
    download.add_argument("--patterns", default=None,
                          help="JSON array of glob patterns to restrict the download.")
    download.add_argument("--workers", type=int, default=8)
    download.add_argument("--file", default=None,
                          help="Fetch this single repo file instead of a snapshot.")
    download.add_argument("--dest", default=None,
                          help="Destination folder for --file.")
    download.set_defaults(func=cmd_download)

    generate = subparsers.add_parser("generate")
    generate.add_argument("--job", required=True, help="Path to the job JSON file.")
    generate.set_defaults(func=cmd_generate)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except KeyboardInterrupt:
        protocol.error("Cancelled.")
        return 130
    except SystemExit as exc:
        return int(exc.code or 0)
    except Exception as exc:
        protocol.error(str(exc))
        protocol.log(traceback.format_exc(limit=12))
        return 1


if __name__ == "__main__":
    sys.exit(main())
