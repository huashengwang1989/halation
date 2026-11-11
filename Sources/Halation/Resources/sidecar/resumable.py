"""Downloads that survive being interrupted.

huggingface_hub does not resume across runs. Since 1.x it writes each transfer
to a temporary file whose name carries a random suffix, opened fresh, so a
second run cannot find the first run's bytes — and a run that is killed rather
than failing (which is what Cancel does) leaves that file behind as dead weight.
Its own retry only covers a dropped connection inside one run. For a 67 GB
encoder on a home connection, that means one sleep of the laptop costs hours.

So the large files are fetched here instead, in fixed-size ranges over several
connections, into a file whose name does not change between runs. A small state
file beside it records which ranges are complete; a range is only marked once
every byte of it is written, so an interruption loses at most the ranges that
were in flight. The finished file is checked against the SHA-256 the hub
publishes for it before it is moved into place, so a resumed file is never
trusted on the strength of its size.

What happens afterwards is the hub's own business again. A blob already present
in the cache is only linked by `snapshot_download`, never fetched, so placing
the large blobs first and calling it second keeps the cache layout exactly what
the hub would have made.
"""

from __future__ import annotations

import hashlib
import json
import os
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Callable, Dict, Optional, Set

#: Large enough that request overhead is noise, small enough that losing the
#: ranges in flight on an interruption costs seconds, not minutes.
CHUNK_BYTES = 64 * 1024 * 1024
#: Files smaller than this are left to the hub: there is nothing to resume.
MIN_RESUMABLE_BYTES = 256 * 1024 * 1024
PART_SUFFIX = ".part"
STATE_SUFFIX = ".part.json"
_ATTEMPTS = 6


class ChecksumMismatch(Exception):
    pass


def part_paths(target: Path) -> tuple[Path, Path]:
    return (target.with_name(target.name + PART_SUFFIX),
            target.with_name(target.name + STATE_SUFFIX))


def discard(target: Path) -> int:
    """Remove a partial download of `target`. Returns the bytes freed."""
    freed = 0
    for path in part_paths(target):
        try:
            freed += path.stat().st_size if path.suffix != ".json" else 0
            path.unlink()
        except FileNotFoundError:
            pass
    return freed


def discard_hub_leftovers(directory: Path) -> int:
    """Remove the `*.incomplete` files a killed huggingface_hub run leaves.

    They are never reused — each run picks a new name — so they are only ever
    disk space. Returns the bytes freed.
    """
    freed = 0
    if not directory.is_dir():
        return 0
    for path in directory.rglob("*.incomplete"):
        try:
            freed += path.stat().st_size
            path.unlink()
        except OSError:
            continue
    return freed


class ResumableFile:
    """One file, fetched in ranges into `<target>.part`, then moved to `target`."""

    def __init__(self, url: str, size: int, target: Path, sha256: Optional[str],
                 headers: Dict[str, str], label: str, workers: int = 8):
        self.url = url
        self.size = size
        self.target = target
        self.sha256 = sha256
        self.headers = headers
        self.label = label
        self.workers = max(1, workers)
        self.part, self.state_path = part_paths(target)
        self.chunks = max(1, -(-size // CHUNK_BYTES))
        self._lock = threading.Lock()
        self._done: Set[int] = set()
        self._in_flight: Dict[int, int] = {}
        self.verifying = False

    # -- state -----------------------------------------------------------------------

    def _load_state(self) -> None:
        """Pick up a previous run's ranges, if it was fetching this same file."""
        if not (self.part.exists() and self.state_path.exists()):
            discard(self.target)
            return
        try:
            state = json.loads(self.state_path.read_text())
        except (OSError, ValueError):
            discard(self.target)
            return
        # A different size or hash means the repository changed underneath the
        # partial; its bytes belong to another file.
        if (state.get("size") != self.size or state.get("sha256") != self.sha256
                or state.get("chunk") != CHUNK_BYTES):
            discard(self.target)
            return
        self._done = {int(i) for i in state.get("done", []) if 0 <= int(i) < self.chunks}

    def _save_state(self) -> None:
        state = {"size": self.size, "sha256": self.sha256, "chunk": CHUNK_BYTES,
                 "label": self.label, "done": sorted(self._done)}
        temporary = self.state_path.with_name(self.state_path.name + ".tmp")
        temporary.write_text(json.dumps(state))
        os.replace(temporary, self.state_path)

    def completed_bytes(self) -> int:
        with self._lock:
            whole = sum(self._chunk_length(i) for i in self._done)
            return whole + sum(self._in_flight.values())

    def _chunk_length(self, index: int) -> int:
        start = index * CHUNK_BYTES
        return min(CHUNK_BYTES, self.size - start)

    # -- transfer --------------------------------------------------------------------

    def _fetch(self, client, index: int) -> None:
        start = index * CHUNK_BYTES
        end = start + self._chunk_length(index) - 1
        headers = dict(self.headers, Range=f"bytes={start}-{end}")
        delay = 2.0
        for attempt in range(_ATTEMPTS):
            with self._lock:
                self._in_flight[index] = 0
            try:
                with client.stream("GET", self.url, headers=headers) as response:
                    if response.status_code != 206:
                        # A 200 would be the whole file from byte 0: writing it at
                        # this offset would corrupt everything after it.
                        raise IOError(f"server answered {response.status_code} to a range request")
                    written = 0
                    with open(self.part, "r+b") as handle:
                        handle.seek(start)
                        for block in response.iter_bytes(1024 * 1024):
                            handle.write(block)
                            written += len(block)
                            with self._lock:
                                self._in_flight[index] = written
                    if written != end - start + 1:
                        raise IOError(f"range {index} ended at {written} of {end - start + 1} bytes")
                with self._lock:
                    self._in_flight.pop(index, None)
                    self._done.add(index)
                    self._save_state()
                return
            except Exception:
                with self._lock:
                    self._in_flight.pop(index, None)
                if attempt == _ATTEMPTS - 1:
                    raise
                time.sleep(delay)
                delay = min(delay * 2, 60)

    def _verify(self) -> None:
        if not self.sha256:
            return
        self.verifying = True
        digest = hashlib.sha256()
        with open(self.part, "rb") as handle:
            for block in iter(lambda: handle.read(16 * 1024 * 1024), b""):
                digest.update(block)
        if digest.hexdigest() != self.sha256:
            # A bad file is worse than a slow one: start this file over.
            discard(self.target)
            raise ChecksumMismatch(
                f"{self.label} did not match its published checksum and was discarded. "
                "Download it again.")

    def run(self) -> None:
        import httpx

        self.target.parent.mkdir(parents=True, exist_ok=True)
        self._load_state()
        if not self.part.exists():
            with open(self.part, "wb") as handle:
                handle.truncate(self.size)  # sparse on APFS: no space is spent up front
            self._save_state()

        pending = [i for i in range(self.chunks) if i not in self._done]
        if pending:
            timeout = httpx.Timeout(60.0, connect=30.0)
            with httpx.Client(follow_redirects=True, timeout=timeout,
                              transport=_transport(self.url),
                              limits=httpx.Limits(max_connections=self.workers + 2)) as client:
                with ThreadPoolExecutor(max_workers=self.workers) as pool:
                    futures = [pool.submit(self._fetch, client, i) for i in pending]
                    for future in as_completed(futures):
                        future.result()

        self._verify()
        os.replace(self.part, self.target)
        try:
            self.state_path.unlink()
        except FileNotFoundError:
            pass


def _transport(url: str):
    """IPv4 when the host has an IPv4 address, otherwise whatever resolves.

    Python tries addresses in resolver order and does not race them the way
    curl and browsers do (RFC 8305). On a network whose IPv6 route to the CDN is
    broken that is not a slow start but a stall: measured on one such network,
    curl over IPv6 moved 0 bytes in 25 s while IPv4 ran at 9.7 MB/s, and
    huggingface_hub's own downloads crawled at under 1 MB/s. Binding to the
    IPv4 wildcard address forces every connection — including the one the
    redirect leads to — onto IPv4. An IPv6-only network has no IPv4 address to
    resolve, and keeps the default.
    """
    import socket
    from urllib.parse import urlparse

    import httpx

    host = urlparse(url).hostname or ""
    try:
        socket.getaddrinfo(host, 443, socket.AF_INET, socket.SOCK_STREAM)
    except OSError:
        return httpx.HTTPTransport(retries=2)
    return httpx.HTTPTransport(local_address="0.0.0.0", retries=2)


def route_hub_over_ipv4() -> None:
    """Give huggingface_hub's own client the same IPv4 preference.

    Its API calls — the file list, the small files — go through one shared
    httpx client, and on a broken IPv6 route the very first of them stalls
    before anything else can happen. Mirrors the hub's default factory, so its
    request hook (auth, user agent) still runs.
    """
    import httpx
    from huggingface_hub.utils import _http

    def factory() -> httpx.Client:
        return httpx.Client(
            event_hooks={"request": [_http.hf_request_event_hook]},
            follow_redirects=True,
            timeout=None,
            transport=_transport("https://huggingface.co"),
        )

    _http.set_client_factory(factory)


class ProgressPump:
    """Reports the combined progress of a transfer once a second."""

    def __init__(self, report: Callable[[int, Optional[str]], None]):
        self.report = report
        self.sources: list[Callable[[], int]] = []
        self.note: Callable[[], Optional[str]] = lambda: None
        self.base = 0
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None

    def total(self) -> int:
        return self.base + sum(source() for source in self.sources)

    def _run(self) -> None:
        while not self._stop.wait(1.0):
            self.report(self.total(), self.note())

    def __enter__(self) -> "ProgressPump":
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()
        return self

    def __exit__(self, *exc) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=3)
