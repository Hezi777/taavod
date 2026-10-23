#!/usr/bin/env python3
"""Populate ignored local runtime caches from the pinned runtime manifest."""

import hashlib
import json
import os
from pathlib import Path
import tempfile
import urllib.request


NATIVE_DIR = Path(__file__).resolve().parents[1]
MANIFEST_PATH = NATIVE_DIR / "Taavod" / "Resources" / "runtime-manifest.json"
CACHE_DIR = NATIVE_DIR / ".runtime-cache"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    for kind, pack in manifest.items():
        pack_dir = CACHE_DIR / kind
        pack_dir.mkdir(parents=True, exist_ok=True)
        for entry in pack["files"]:
            filename = Path(entry["path"])
            if filename.name != entry["path"] or filename.is_absolute():
                raise ValueError(f"Unsafe runtime filename: {entry['path']}")
            target = pack_dir / filename
            if target.is_file() and sha256(target) == entry["sha256"]:
                continue

            print(f"Fetching {kind}/{filename}", flush=True)
            request = urllib.request.Request(entry["url"], headers={"User-Agent": "Taavod-test-runtime-prep/1"})
            with urllib.request.urlopen(request, timeout=180) as response:
                if response.status != 200:
                    raise RuntimeError(f"Download failed for {entry['url']}: HTTP {response.status}")
                data = response.read()
            digest = hashlib.sha256(data).hexdigest()
            if digest != entry["sha256"]:
                raise RuntimeError(f"SHA-256 mismatch for {kind}/{filename}: {digest}")
            if len(data) != entry["bytes"]:
                raise RuntimeError(f"Size mismatch for {kind}/{filename}: {len(data)} bytes")

            fd, temporary = tempfile.mkstemp(prefix=f".{filename.name}.", dir=pack_dir)
            try:
                with os.fdopen(fd, "wb") as output:
                    output.write(data)
                os.replace(temporary, target)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)

    print(f"Verified test runtimes in {CACHE_DIR}")


if __name__ == "__main__":
    main()
