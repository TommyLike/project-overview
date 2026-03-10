"""Section 12: Foundation & governance status — CNCF, ASF."""
from __future__ import annotations

import json

import requests

from .cache import CacheManager
from . import output


def _get(url: str, timeout: int = 20) -> dict | list | None:
    try:
        resp = requests.get(url, timeout=timeout)
        return resp.json() if resp.status_code == 200 else None
    except Exception:
        return None


def section12_foundation_status(owner: str, reponame: str, cache: CacheManager, org_json: dict) -> None:
    output.subsection("Section 12 — Foundation & Governance Status")
    name_lower = reponame.lower()

    # CNCF
    output.console.print("CNCF Landscape:")
    _cache = cache.raw_dir / "cncf.txt"
    cache.status("cncf", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        data = _get("https://raw.githubusercontent.com/cncf/landscape/master/hosted_data/projects.json")
        if isinstance(data, list):
            match = next((p for p in data if name_lower in (p.get("name") or "").lower()), None)
            result = (
                json.dumps({"name": match.get("name"), "project": match.get("project"),
                            "category": match.get("category")}, indent=2)
                if match else f"(not in CNCF landscape for '{reponame}')"
            )
        else:
            result = "(could not fetch CNCF data)"
        result += f"\nManual: https://landscape.cncf.io/?selected={reponame}"
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    # ASF
    output.console.print("Apache Software Foundation:")
    _cache = cache.raw_dir / "asf.txt"
    cache.status("asf", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        data = _get("https://projects.apache.org/json/foundation/projects.json")
        if isinstance(data, dict):
            key = next((k for k in data if name_lower in k.lower()), None)
            result = (
                json.dumps({"name": key, "description": data[key].get("description")}, indent=2)
                if key else f"(not in Apache Software Foundation for '{reponame}')"
            )
        else:
            result = "(could not fetch ASF data)"
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    output.console.print("Other Foundations (manual):")
    output.console.print("  Linux Foundation: https://www.linuxfoundation.org/projects")
    output.console.print("  OpenSSF: https://openssf.org/community/projects/")
    output.console.print("  Eclipse: https://projects.eclipse.org")
    output.console.print()
