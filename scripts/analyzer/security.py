"""Section 11: Security health — OpenSSF Scorecard, OSV, NVD."""
from __future__ import annotations

import json
import re
import urllib.parse
from pathlib import Path

import requests

from .cache import CacheManager
from . import output


def _get(url: str, timeout: int = 20) -> dict | None:
    try:
        resp = requests.get(url, timeout=timeout)
        return resp.json() if resp.status_code == 200 else None
    except Exception:
        return None


def _post(url: str, body: dict, timeout: int = 20) -> dict | None:
    try:
        resp = requests.post(url, json=body, timeout=timeout)
        return resp.json() if resp.status_code == 200 else None
    except Exception:
        return None


def _detect_ecosystem(repo_dir: Path, reponame: str) -> tuple[str, str]:
    if (repo_dir / "pyproject.toml").exists() or (repo_dir / "setup.py").exists():
        return "PyPI", _parse_pypi_name(repo_dir, reponame)
    if (repo_dir / "package.json").exists():
        try:
            name = json.loads((repo_dir / "package.json").read_text()).get("name") or reponame
        except Exception:
            name = reponame
        return "npm", name
    if (repo_dir / "go.mod").exists():
        return "Go", reponame
    if (repo_dir / "Cargo.toml").exists():
        return "crates.io", reponame
    return "", reponame


def _parse_pypi_name(repo_dir: Path, default: str) -> str:
    for fname in ["pyproject.toml", "setup.py"]:
        p = repo_dir / fname
        if not p.exists():
            continue
        m = re.search(r'^\s*name\s*=\s*["\']([^"\']+)["\']', p.read_text(errors="replace"), re.MULTILINE)
        if m:
            return m.group(1).strip()
    return default


def section11_security_health(repo: str, reponame: str, cache: CacheManager, repo_dir: Path) -> None:
    output.subsection("Section 11 — Security Health")

    # OpenSSF Scorecard
    output.console.print("OpenSSF Scorecard:")
    _cache = cache.raw_dir / "openssf.txt"
    cache.status("openssf", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        d = _get(f"https://api.securityscorecards.dev/projects/github.com/{repo}")
        if d and "score" in d:
            result = json.dumps({
                "score": d.get("score"),
                "date": d.get("date"),
                "checks": [
                    {"name": c.get("name"), "score": c.get("score"), "reason": c.get("reason")}
                    for c in d.get("checks", [])
                ],
            }, indent=2)
        else:
            result = (
                f"(not indexed — run: scorecard --repo=github.com/{repo})\n"
                f"Check: https://securityscorecards.dev/#/github.com/{repo}"
            )
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    # OSV
    output.console.print("OSV Vulnerability Database:")
    _cache = cache.raw_dir / "osv.txt"
    cache.status("osv", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        ecosystem, pkg_name = _detect_ecosystem(repo_dir, reponame)
        if ecosystem:
            osv = _post("https://api.osv.dev/v1/query", {"package": {"name": pkg_name, "ecosystem": ecosystem}})
        else:
            osv = _post("https://api.osv.dev/v1/query", {"package": {"name": f"github.com/{repo}"}})
        if osv and "vulns" in osv:
            result = json.dumps({
                "ecosystem": ecosystem or "github",
                "package": pkg_name,
                "total_vulnerabilities": len(osv["vulns"]),
                "vulns": [
                    {"id": v.get("id"), "summary": v.get("summary"), "published": v.get("published")}
                    for v in osv["vulns"][:5]
                ],
            }, indent=2)
        else:
            result = f"(no vulnerabilities found for {ecosystem or 'github'}/{pkg_name})"
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    # NVD
    output.console.print("NVD CVE History:")
    _cache = cache.raw_dir / "nvd.txt"
    cache.status("nvd", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        enc = urllib.parse.quote(reponame)
        d = _get(
            f"https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch={enc}&resultsPerPage=5",
            timeout=30,
        )
        if d and "totalResults" in d:
            samples = []
            for v in d.get("vulnerabilities", []):
                cve = v["cve"]
                metrics = cve.get("metrics", {})
                severity = (
                    ((metrics.get("cvssMetricV31") or [{}])[0].get("cvssData", {}).get("baseSeverity"))
                    or ((metrics.get("cvssMetricV2") or [{}])[0].get("baseSeverity"))
                    or "N/A"
                )
                desc = next(
                    (d_["value"] for d_ in cve.get("descriptions", []) if d_.get("lang") == "en"), "N/A"
                )
                samples.append({
                    "id": cve["id"],
                    "published": cve.get("published"),
                    "severity": severity,
                    "description": desc[:100] + ("..." if len(desc) > 100 else ""),
                })
            result = json.dumps({"total_cves": d.get("totalResults"), "sample": samples}, indent=2)
        else:
            result = "(could not fetch NVD data)"
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()
