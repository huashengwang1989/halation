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

    for name in ("mlx", "numpy", "huggingface_hub", "PIL", "safetensors"):
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
    protocol.download(repo_id, watcher.current_bytes(), total_bytes)

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

    final = watcher.current_bytes()
    protocol.download(repo_id, total_bytes or final, total_bytes or final)
    protocol.log(f"{repo_id} is in place at {path}")
    protocol.done()
    return 0


def _repo_cache_dir(repo_id: str) -> Path:
    """Where huggingface_hub keeps this repo's blobs under the active HF_HOME."""
    home = os.environ.get("HF_HOME")
    hub = Path(home) / "hub" if home else Path.home() / ".cache" / "huggingface" / "hub"
    return hub / ("models--" + repo_id.replace("/", "--"))


class _SizeWatcher:
    """Reports download progress by sampling the cache directory's size."""

    def __init__(self, repo_id: str, directory: Path, total: int, interval: float = 1.0):
        self.repo_id = repo_id
        self.directory = directory
        self.total = total
        self.interval = interval
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._baseline = 0

    def current_bytes(self) -> int:
        total = 0
        for root, _, files in os.walk(self.directory, onerror=lambda _: None):
            for name in files:
                try:
                    total += os.stat(os.path.join(root, name)).st_size
                except OSError:
                    continue
        return total

    def _run(self) -> None:
        while not self._stop.wait(self.interval):
            seen = self.current_bytes()
            # Incomplete files land in the cache too, so cap at the known total
            # rather than reporting more than 100%.
            if self.total:
                seen = min(seen, self.total)
            protocol.download(self.repo_id, seen, self.total or seen)

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

    # The pipeline prints "  step done/total" as it denoises and takes no callback,
    # so we tee stdout through a parser instead of losing the progress entirely.
    tee = _StepTee(reporter)

    protocol.stage("preparing")
    try:
        with contextlib.redirect_stdout(tee):
            pipeline = MiniMaxH3Pipeline.from_pretrained(
                checkpoint_dir=checkpoint,
                transformer_dir=job.get("transformer_path"),
                verbose=True,
            )

        images, anchors = _keyframes(job)

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
        media.save_mp4(output, result.video, fps=result.fps, audio_path=str(wav_path))
    except TypeError:
        # Older signatures take the audio array directly, or no audio at all.
        try:
            media.save_mp4(output, result.video, result.fps)
        except Exception as exc:
            protocol.error(f"Could not write the video: {exc}")
            return 1
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


class _StepTee:
    """Forwards the pipeline's own stdout into protocol events.

    `MiniMaxH3Pipeline` writes progress with `print`, so this is the only place
    step counts are available. Anything that is not a step line becomes a log entry.
    """

    def __init__(self, reporter: "protocol.StepReporter") -> None:
        self.reporter = reporter
        self._buffer = ""

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
        protocol.log(stripped)

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
