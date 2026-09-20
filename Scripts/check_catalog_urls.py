#!/usr/bin/env python3
"""Check that every ComfyUI-format weight in the catalogue can actually be fetched.

`ComfyUIFile.folder` says where a file belongs under `<models>/comfyui/`. It does
*not* say where the file lives inside its repository, and the two only coincide
by luck. Twice now a mismatch has shipped and surfaced to the user as
huggingface_hub's unrelated warning about unauthenticated requests:

  - the uncensored text encoder sits at its repository's root, not under
    `text_encoders/`;
  - the FL2VA turbo LoRA is published by lightx2v at v1.2, while the Comfy-Org
    mirror carries only v1.0.

Run this after touching the catalogue. No token needed: every repository here is
public, and an anonymous HEAD is enough to tell a redirect from a 404.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ENTRIES = Path(__file__).resolve().parent.parent / "Sources/VideoGen/Models/ModelCatalog+Entries.swift"
ALIASES = {
    "comfyRepoID": "Comfy-Org/MiniMax-H3",
    "upstreamRepoID": "MiniMaxAI/MiniMax-H3",
    "turboRepoID": "lightx2v/Minimax-h3-Turbo",
}


def catalogue() -> list[tuple[str, str]]:
    source = ENTRIES.read_text(encoding="utf-8")
    found = []
    for entry in re.findall(r"CatalogEntry\((.*?)\n        \)", source, re.S):
        file = re.search(r"comfyUIFile:\s*\.init\((.*?)\)", entry, re.S)
        if not file:
            continue
        body = file.group(1)
        folder = re.search(r'folder:\s*"([^"]+)"', body).group(1)
        filename = re.search(r'filename:\s*"([^"]+)"', body).group(1)
        override = re.search(r'repoPath:\s*"([^"]+)"', body)
        repo = re.search(r"repoID:\s*([^\n,]+)", entry).group(1).strip().strip('",')
        repo = ALIASES.get(repo, repo)
        found.append((repo, override.group(1) if override else f"{folder}/{filename}"))
    return found


def main() -> int:
    failures = 0
    for repo, path in catalogue():
        url = f"https://huggingface.co/{repo}/resolve/main/{path}"
        code = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-I", url],
            capture_output=True, text=True, check=False).stdout.strip()
        ok = code in {"200", "302"}
        failures += not ok
        print(f"{'ok ' if ok else 'BAD'} {code}  {repo}/{path}")
    if failures:
        print(f"\n{failures} catalogue entr{'y' if failures == 1 else 'ies'} "
              "point at a file that is not there.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
