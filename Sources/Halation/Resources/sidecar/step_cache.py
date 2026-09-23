"""Reusing a denoising step's result instead of recomputing it, for the MLX port.

A port of the algorithm in ComfyUI's ``comfy_extras/nodes_easycache.py`` — the
same one the Compose page offers on the ComfyUI engine — so that both engines
mean the same thing by "step reuse" and a clip rendered either way is spoiled,
or not, in the same manner.

Not a MiniMax feature: H3's model card describes no caching mode. This is a
generic property of diffusion transformers. Consecutive steps produce very
similar outputs, so when a step's input has barely moved, the previous step's
*change* is added again instead of running the transformer.

It lives here rather than in ``minimax_h3_mlx`` because that package is cloned
from upstream and replaced whenever the runtime is repaired. A patch applied
there is a patch to reapply forever; installing from our own sidecar touches
nothing that upstream owns.

It intercepts the transformer's ``__call__`` on its class and leaves
``pipeline.dit`` as the genuine module. Substituting the object there instead
looks tidier and is wrong: the pipeline goes on to read ``dit.config``, to call
``dit.parameters()``, and — the one that matters — to hand ``dit`` to
``drop_adaln_weights``, which frees about 26 GB by discarding the projections
that depend only on the timestep. A stand-in object breaks all three, and the
last one silently costs more memory than any amount of step skipping saves.

The cache is deliberately blind to what it is wrapping. It only knows that the
call takes video and audio rows and returns predictions for both.
"""

from __future__ import annotations

import mlx.core as mx


class StepCache:
    """Wraps a pipeline's transformer, skipping calls whose result is predictable.

    The estimate is ComfyUI's. Track how far the input moved since the last
    step, scale it by the rate at which output movement has been tracking input
    movement, and accumulate that as an estimate of the error a skip would
    introduce. Recompute when the accumulated estimate crosses the threshold,
    and reset it.
    """

    def __init__(self, total_steps, reuse_threshold=0.2,
                 start_percent=0.15, end_percent=0.95, subsample=8, verbose=False):
        self.total_steps = max(1, int(total_steps))
        self.reuse_threshold = float(reuse_threshold)
        self.subsample = max(1, int(subsample))
        self.verbose = verbose

        # The first steps set the composition and the last ones set fine detail;
        # both are the wrong place to economise. The window is expressed in
        # percentages so it means the same thing at 16 steps and at 60.
        self.start_step = int(float(start_percent) * self.total_steps)
        self.end_step = int(float(end_percent) * self.total_steps)

        self.step = 0
        self.skipped = 0
        # What the cache itself costs, measured on the first step rather than
        # estimated. Reuse buys time by spending memory, which is the wrong
        # trade to make blind on a machine that is already close to its limit.
        self.cache_bytes = 0

        # What a skip replays: the change the transformer made last time it ran.
        self._diff_video = None
        self._diff_audio = None
        # Subsampled references for the indicators, and the scalars derived
        # from them. Subsampled because this is a similarity measure, not a
        # result: an eighth of the rows says the same thing for an eighth of
        # the bandwidth, and the measurement runs on every step.
        self._input_prev = None
        self._output_prev = None
        self._output_norm = None
        self._rate = None
        self._cumulative = 0.0

    # -- indicators ---------------------------------------------------------

    def _sub(self, x):
        """Every nth row. The rows are a packed token sequence rather than a
        spatial grid, so this strides the sequence where ComfyUI strides height
        and width; the quantity being estimated is the same."""
        return x[:, ::self.subsample]

    @staticmethod
    def _mean_abs(x):
        """Mean absolute value, as a Python float.

        ``.item()`` is what forces it. MLX builds a graph and evaluates only
        when a concrete value is demanded, so without this the comparison below
        would be adding lazy arrays to a condition rather than a number to a
        threshold — and nothing would ever be skipped, at the cost of building
        the graph anyway.
        """
        return mx.abs(x).mean().item()

    def _in_window(self):
        return self.start_step <= self.step < self.end_step

    # -- the wrapped call ---------------------------------------------------

    def run(self, compute, video, audio):
        """Either replay the last change, or call `compute()` and record it.

        `compute` is a thunk over the real transformer call, so this never holds
        the transformer, its arguments, or any opinion about their shape.
        """
        step = self.step
        self.step += 1

        input_change = None
        if self._input_prev is not None:
            # Measured on every step, not only inside the window, so the rate is
            # already warm when the window opens. ComfyUI measures it only
            # inside; doing it earlier costs one subsampled mean and makes the
            # first decision better informed than a guess.
            input_change = self._mean_abs(self._sub(video) - self._input_prev)

            if (self._in_window() and self._diff_video is not None
                    and self._rate is not None and self._output_norm):
                self._cumulative += (self._rate * input_change) / self._output_norm
                if self._cumulative < self.reuse_threshold:
                    self.skipped += 1
                    if self.verbose:
                        print(f"  step reuse: skipped step {step}, "
                              f"estimate {self._cumulative:.4f} "
                              f"< {self.reuse_threshold}", flush=True)
                    return video + self._diff_video, audio + self._diff_audio
                self._cumulative = 0.0

        out_video, out_audio = compute()

        output_sub = self._sub(out_video)
        if self._output_prev is not None and input_change:
            # How much output movement one unit of input movement has been
            # buying. Only meaningful once there is a previous output to
            # compare against, and only when the input actually moved.
            self._rate = self._mean_abs(output_sub - self._output_prev) / input_change

        self._output_prev = output_sub
        self._output_norm = self._mean_abs(out_video)
        self._input_prev = self._sub(video)
        self._diff_video = out_video - video
        self._diff_audio = out_audio - audio

        # Force the cached tensors now. They are kept across steps, and an
        # unevaluated MLX array is a graph holding every array it was built
        # from — so leaving them lazy would pin one step's entire working set
        # in memory for the whole render, which is the opposite of the point.
        mx.eval(self._diff_video, self._diff_audio,
                self._output_prev, self._input_prev)

        if not self.cache_bytes:
            self.cache_bytes = sum(
                getattr(t, "nbytes", 0) for t in
                (self._diff_video, self._diff_audio,
                 self._output_prev, self._input_prev))

        return out_video, out_audio

    # -- reporting ----------------------------------------------------------

    def summary(self):
        """What it actually did, for the render log. A cache that silently does
        nothing and one that saves half the work look identical from outside."""
        return {
            "steps": self.step,
            "skipped": self.skipped,
            "window": [self.start_step, self.end_step],
            "reuse_threshold": self.reuse_threshold,
            "cache_bytes": self.cache_bytes,
        }
