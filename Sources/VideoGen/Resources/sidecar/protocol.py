"""NDJSON event protocol shared by every sidecar subcommand.

Everything the Swift app learns about a running job arrives as one JSON object per
line on stdout. Anything written to stderr is treated as diagnostic noise and only
surfaced if the process exits non-zero.
"""
from __future__ import annotations

import json
import sys
import time
from typing import Any, Optional


# The real stdout, captured at import time.
#
# Generation runs inside `contextlib.redirect_stdout(...)` so the pipeline's own
# prints can be parsed for progress. Writing events through `sys.stdout` would
# therefore feed them straight back into that parser instead of to the app —
# which silently swallowed every step and stage event for the whole render.
_EVENT_STREAM = sys.stdout


def emit(**payload: Any) -> None:
    """Write one event. Flushed immediately so the UI stays live during long runs."""
    _EVENT_STREAM.write(json.dumps(payload, default=str) + "\n")
    _EVENT_STREAM.flush()


def log(message: str) -> None:
    emit(type="log", message=str(message))


def stage(name: str) -> None:
    """`name` must match a case of Swift's RenderJob.State."""
    emit(type="stage", stage=name)


def error(message: str) -> None:
    emit(type="error", message=str(message))


def done() -> None:
    emit(type="done")


def seed(value: int) -> None:
    emit(type="seed", seed=int(value))


def artifact(video: Optional[str] = None, audio: Optional[str] = None) -> None:
    emit(type="artifact", video=video, audio=audio)


def memory(num_bytes: int) -> None:
    emit(type="memory", bytes=int(num_bytes))


def substage(label: str, completed: int, total: int, detail: Optional[str] = None) -> None:
    """Progress *within* a stage — model loading, mainly.

    Loading the 67 GB text encoder and the transformer takes many minutes, during
    which the diffusion loop has not started and there is no step count to show.
    Without this the UI sits at "Loading model" with a motionless bar.
    """
    emit(type="substage", label=label, completed=int(completed),
         total=int(total), detail=detail)


def tokens(total: int, text: int) -> None:
    """How long the sequence handed to the text encoder actually is.

    Not a running cost — H3 is a diffusion model and generates nothing token by
    token. This is one forward pass over one sequence, reported because a
    keyframe or reference render carries a block of vision tokens per image that
    dwarfs the words, and there is otherwise no way to see that.
    """
    emit(type="tokens", total=int(total), text=int(text))


def download(repo_id: str, completed: int, total: int, file: Optional[str] = None) -> None:
    emit(type="download", repo_id=repo_id, completed=int(completed),
         total=int(total), file=file)


class StepReporter:
    """Reports diffusion progress and keeps a rolling seconds-per-step average.

    The app derives its ETA from this rather than from a static estimate, because
    step time varies by several hundred percent with resolution and reference count.
    """

    def __init__(self, total: int, throttle: float = 1.0) -> None:
        self.total = max(1, int(total))
        self.completed = 0
        self.throttle = throttle
        self._start = time.monotonic()
        self._last_emit = 0.0
        # When the previous step landed, and how long it took. The average hides
        # the shape of a run: steps get slower as the sequence grows, and the
        # first is slower still because caches are cold.
        self._last_advance = self._start
        self._recent: Optional[float] = None

    def advance(self, completed: Optional[int] = None) -> None:
        now = time.monotonic()
        previous = self.completed
        self.completed = self.completed + 1 if completed is None else int(completed)
        # Divided by the number of steps that landed, not assumed to be one: a
        # throttled report can cover several.
        stepped = max(1, self.completed - previous)
        self._recent = (now - self._last_advance) / stepped
        self._last_advance = now

        is_last = self.completed >= self.total
        if not is_last and (now - self._last_emit) < self.throttle:
            return
        self._last_emit = now
        elapsed = now - self._start
        per_step = elapsed / self.completed if self.completed > 0 else None
        emit(type="step", completed=self.completed, total=self.total,
             seconds_per_step=per_step, seconds_recent=self._recent)

    def report_memory(self) -> None:
        """Best-effort peak-memory reading from MLX, if it is loaded."""
        try:
            import mlx.core as mx
            getter = getattr(mx, "get_peak_memory", None) or getattr(
                getattr(mx, "metal", None), "get_peak_memory", None)
            if getter is not None:
                memory(getter())
        except Exception:
            pass
