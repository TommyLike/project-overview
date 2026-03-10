"""Cache management — freshness checks, read/write helpers."""
from __future__ import annotations

import json
import time
from pathlib import Path

from . import output


class CacheManager:
    def __init__(self, base_dir: Path, slug: str, max_age_days: int, force: bool):
        self.slug = slug
        self.max_age_days = max_age_days
        self.force = force
        self.cache_dir = base_dir / slug
        self.raw_dir = self.cache_dir / "raw"
        self.repo_dir = self.cache_dir / "repo"
        self.raw_dir.mkdir(parents=True, exist_ok=True)

    def is_fresh(self, path: Path, max_age: int | None = None) -> bool:
        if self.force:
            return False
        if not path.exists():
            return False
        limit = max_age if max_age is not None else self.max_age_days
        return self.age_days(path) < limit

    def age_days(self, path: Path) -> int:
        try:
            return int((time.time() - path.stat().st_mtime) / 86400)
        except Exception:
            return 999

    def status(self, label: str, path: Path) -> None:
        if self.is_fresh(path):
            output.cache_hit(label, self.age_days(path))
        else:
            output.cache_miss(label)

    def read_json(self, path: Path) -> dict | list | None:
        try:
            return json.loads(path.read_text())
        except Exception:
            return None

    def write_json(self, path: Path, data: dict | list) -> None:
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False))

    def read_text(self, path: Path) -> str | None:
        try:
            return path.read_text()
        except Exception:
            return None

    def write_text(self, path: Path, text: str) -> None:
        path.write_text(text)
