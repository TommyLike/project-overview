"""Sections 5 & 9: Ecosystem and package download metrics."""
from __future__ import annotations

import json
import re
from pathlib import Path

import requests

from .cache import CacheManager
from . import output


def _get(url: str, timeout: int = 15) -> dict | list | None:
    try:
        resp = requests.get(url, timeout=timeout)
        return resp.json() if resp.status_code == 200 else None
    except Exception:
        return None


def _detect_pypi_name(repo_dir: Path, default: str) -> str:
    for fname in ["pyproject.toml", "setup.py"]:
        p = repo_dir / fname
        if not p.exists():
            continue
        m = re.search(r'^\s*name\s*=\s*["\']([^"\']+)["\']', p.read_text(errors="replace"), re.MULTILINE)
        if m:
            return m.group(1).strip()
    return default


def _detect_npm_name(repo_dir: Path) -> str | None:
    pkg = repo_dir / "package.json"
    if not pkg.exists():
        return None
    try:
        return json.loads(pkg.read_text()).get("name")
    except Exception:
        return None


def _detect_ecosystem(repo_dir: Path, reponame: str) -> tuple[str, str]:
    """Return (ecosystem, package_name) for the repo."""
    if (repo_dir / "pyproject.toml").exists() or (repo_dir / "setup.py").exists():
        return "pypi", _detect_pypi_name(repo_dir, reponame)
    if (repo_dir / "package.json").exists():
        return "npm", _detect_npm_name(repo_dir) or reponame
    if (repo_dir / "Cargo.toml").exists():
        return "cargo", reponame
    if (repo_dir / "go.mod").exists():
        return "go", reponame
    if (repo_dir / "Gemfile").exists():
        return "rubygems", reponame
    return "", reponame


def section5_downloads(repo: str, owner: str, reponame: str, cache: CacheManager, repo_dir: Path) -> None:
    output.subsection("Section 5 — Ecosystem & Downloads")

    # GitHub Dependents
    _cache = cache.raw_dir / "github_dependents.txt"
    cache.status("github_dependents", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        try:
            resp = requests.get(
                f"https://github.com/{repo}/network/dependents",
                headers={"Accept": "text/html"}, timeout=15,
            )
            m = re.search(r"([\d,]+)\s+Repositories", resp.text)
            result = (
                f"GitHub Dependents: {m.group(1)} repositories depend on this package"
                if m else "GitHub Dependents: (could not parse)"
            )
        except Exception:
            result = "GitHub Dependents: (could not fetch)"
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    # PyPI
    output.console.print("PyPI Download Stats:")
    _cache = cache.raw_dir / "pypi_stats.txt"
    cache.status("pypi_stats", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        base_name = _detect_pypi_name(repo_dir, reponame)
        result = None
        for name_try in [base_name, base_name.replace("_", "-"), base_name.replace("-", "_")]:
            data = _get(f"https://pypistats.org/api/packages/{name_try}/recent")
            if data and "data" in data:
                d = data["data"]
                result = (
                    f"Package: {name_try}\n"
                    f"last_day: {d.get('last_day')} | last_week: {d.get('last_week')} | last_month: {d.get('last_month')}"
                )
                break
        if result is None:
            result = f"(not a PyPI package, or name differs — tried '{base_name}')"
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    # npm
    output.console.print("npm Download Stats:")
    _cache = cache.raw_dir / "npm_stats.txt"
    cache.status("npm_stats", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        npm_name = _detect_npm_name(repo_dir)
        if npm_name:
            data = _get(f"https://api.npmjs.org/downloads/point/last-week/{npm_name}")
            result = (
                f"weekly_downloads: {data['downloads']} | package: {data.get('package')}"
                if data and "downloads" in data
                else f"(npm API returned no data for '{npm_name}')"
            )
        else:
            result = "(no package.json — not an npm package)"
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()


def section9_extended_ecosystems(owner: str, reponame: str, cache: CacheManager, repo_dir: Path) -> None:
    output.subsection("Section 9 — Extended Package Ecosystems")

    # Docker Hub
    output.console.print("Docker Hub:")
    _cache = cache.raw_dir / "docker_stats.txt"
    cache.status("docker_stats", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        d = _get(f"https://hub.docker.com/v2/repositories/{owner}/{reponame}/") or \
            _get(f"https://hub.docker.com/v2/repositories/library/{reponame}/")
        result = (
            f"full_name: {d.get('full_name')} | pull_count: {d.get('pull_count')} | "
            f"star_count: {d.get('star_count')} | last_updated: {d.get('last_updated')}"
            if d and "pull_count" in d
            else f"(not found on Docker Hub — tried {owner}/{reponame} and library/{reponame})"
        )
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    # Homebrew
    output.console.print("Homebrew:")
    _cache = cache.raw_dir / "homebrew_stats.txt"
    cache.status("homebrew_stats", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        d = _get(f"https://formulae.brew.sh/api/formula/{reponame}.json") or \
            _get(f"https://formulae.brew.sh/api/cask/{reponame}.json")
        if d and "name" in d:
            analytics = d.get("analytics", {}).get("install", {})
            result = (
                f"name: {d.get('name')} | desc: {d.get('desc')} | "
                f"installs_30d: {analytics.get('30d')} | installs_365d: {analytics.get('365d')}"
            )
        else:
            result = "(not found on Homebrew)"
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    # conda-forge
    output.console.print("conda-forge:")
    _cache = cache.raw_dir / "conda_stats.txt"
    cache.status("conda_stats", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        d = _get(f"https://api.anaconda.org/package/conda-forge/{reponame}")
        result = (
            f"name: {d.get('name')} | summary: {d.get('summary')} | "
            f"downloads: {d.get('downloads')} | last_modified: {d.get('modified_at')}"
            if d and "name" in d
            else "(not found on conda-forge)"
        )
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    # Libraries.io
    output.console.print("Libraries.io (dependency ecosystem):")
    ecosystem, _ = _detect_ecosystem(repo_dir, reponame)
    output.console.print(f"Ecosystem: {ecosystem or '(not detected)'}")
    if ecosystem:
        output.console.print(f"Manual URL: https://libraries.io/{ecosystem}/{reponame}")
        output.console.print("(add LIBRARIES_IO_KEY to config for automated lookup)")
    output.console.print()

    # deps.dev
    output.console.print("deps.dev (Google Open Source Insights):")
    _cache = cache.raw_dir / "depsdev.txt"
    cache.status("depsdev", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        result = _fetch_depsdev(repo_dir, reponame)
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()


def _fetch_depsdev(repo_dir: Path, reponame: str) -> str:
    system, name = "", reponame
    if (repo_dir / "pyproject.toml").exists() or (repo_dir / "setup.py").exists():
        system, name = "PYPI", _detect_pypi_name(repo_dir, reponame)
    elif (repo_dir / "package.json").exists():
        system = "NPM"
        name = _detect_npm_name(repo_dir) or reponame
    elif (repo_dir / "go.mod").exists():
        system = "GO"
        m = re.search(r"^module\s+(\S+)", (repo_dir / "go.mod").read_text(errors="replace"), re.MULTILINE)
        if m:
            name = m.group(1)

    if not system:
        return "(ecosystem not detected for deps.dev)"

    d = _get(f"https://api.deps.dev/v3/systems/{system}/packages/{name}")
    if d and "packageKey" in d:
        versions = d.get("versions", [])
        latest = sorted(versions, key=lambda v: v.get("publishedAt", ""))[-1] if versions else {}
        return (
            f"name: {d['packageKey'].get('name')} | system: {d['packageKey'].get('system')} | "
            f"versions_count: {len(versions)} | "
            f"latest: {latest.get('versionKey', {}).get('version')} ({latest.get('publishedAt')})\n"
            f"Graph: https://deps.dev/{system}/{name}"
        )
    return f"(deps.dev: no data for {system}/{name})\nGraph: https://deps.dev/{system}/{name}"
