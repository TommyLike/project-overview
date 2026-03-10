"""Sections 8 & 10: Community investment signals and search/community signals."""
from __future__ import annotations

import json
import re
import urllib.parse
from pathlib import Path

import requests

from .cache import CacheManager
from .config import Config
from . import output


def _get(url: str, timeout: int = 15) -> dict | list | None:
    try:
        resp = requests.get(url, timeout=timeout)
        return resp.json() if resp.status_code == 200 else None
    except Exception:
        return None


def _find_readme(repo_dir: Path) -> Path | None:
    for name in ["README.md", "README.rst", "README.txt", "README"]:
        p = repo_dir / name
        if p.exists():
            return p
    return None


def section8_community_investment(
    repo: str, cache: CacheManager, cfg: Config, contrib_json: list, repo_dir: Path
) -> None:
    output.subsection("Section 8 — Community Investment Signals")

    # Contributor org diversity
    output.console.print("Contributor Org Diversity:")
    _cache = cache.raw_dir / "contributor_orgs.txt"
    cache.status("contributor_orgs", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        lines = []
        for c in contrib_json:
            login = c.get("login", "")
            user = cfg.github_api(f"users/{login}") or {}
            lines.append(f"  {login}: {user.get('company') or '(none)'}")
        text = "\n".join(lines) if lines else "(could not fetch contributor orgs)"
        output.console.print(text)
        cache.write_text(_cache, text)
    output.console.print()

    # PR merge times
    output.console.print("External vs Internal PR Merge Time (last 20 merged PRs):")
    _cache = cache.raw_dir / "pr_merge_times.json"
    cache.status("pr_merge_times", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        prs = cfg.github_api(
            f"repos/{repo}/pulls?state=closed&sort=updated&direction=desc&per_page=20"
        ) or []
        merged = [
            {
                "number": p.get("number"),
                "author": (p.get("user") or {}).get("login"),
                "author_association": p.get("author_association"),
                "created": p.get("created_at"),
                "merged": p.get("merged_at"),
                "title": (p.get("title") or "")[:60] + ("..." if len(p.get("title") or "") > 60 else ""),
            }
            for p in prs if p.get("merged_at")
        ]
        text = json.dumps(merged, indent=2)
        output.console.print(text)
        cache.write_text(_cache, text)
    output.console.print()

    # Good first issues
    output.console.print("Good First Issues:")
    _cache = cache.raw_dir / "good_first_issues.json"
    cache.status("good_first_issues", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        gfi = (
            cfg.github_api(f"repos/{repo}/issues?labels=good+first+issue&state=open&per_page=10")
            or cfg.github_api(f"repos/{repo}/issues?labels=good-first-issue&state=open&per_page=10")
            or []
        )
        text = json.dumps({
            "count": len(gfi),
            "sample": [
                {"number": i.get("number"), "title": i.get("title"), "created": i.get("created_at")}
                for i in gfi[:5]
            ],
        }, indent=2)
        output.console.print(text)
        cache.write_text(_cache, text)
    output.console.print()

    # CONTRIBUTING
    output.console.print("CONTRIBUTING.md:")
    for path in [repo_dir / "CONTRIBUTING.md", repo_dir / ".github" / "CONTRIBUTING.md"]:
        if path.exists():
            output.console.print(f"(found: {path.name} — first 80 lines)")
            output.console.print("\n".join(path.read_text(errors="replace").splitlines()[:80]))
            break
    else:
        output.console.print("(no CONTRIBUTING.md)")
    output.console.print()

    # GOVERNANCE
    output.console.print("GOVERNANCE.md:")
    for path in [repo_dir / "GOVERNANCE.md", repo_dir / ".github" / "GOVERNANCE.md"]:
        if path.exists():
            output.console.print(f"(found: {path.name} — first 80 lines)")
            output.console.print("\n".join(path.read_text(errors="replace").splitlines()[:80]))
            break
    else:
        output.console.print("(no GOVERNANCE.md)")
    output.console.print()

    # MAINTAINERS / CODEOWNERS
    output.console.print("MAINTAINERS / CODEOWNERS:")
    for name in ["MAINTAINERS", "MAINTAINERS.md", ".github/CODEOWNERS", "CODEOWNERS"]:
        p = repo_dir / name
        if p.exists():
            output.console.print(f"(found: {name})")
            output.console.print(p.read_text(errors="replace"))
    output.console.print()

    # Community links
    output.console.print("Community Meeting / Communication Links:")
    readme = _find_readme(repo_dir)
    if readme:
        pattern = re.compile(
            r"(community meeting|office hours|slack|discord|mailing list|"
            r"forum|gitter|matrix|zulip|discuss)", re.IGNORECASE
        )
        lines = [l for l in readme.read_text(errors="replace").splitlines() if pattern.search(l)]
        output.console.print("\n".join(lines[:15]) if lines else "(none found)")
    output.console.print()

    # CLA / DCO
    output.console.print("CLA / DCO Requirements:")
    cla_found = False
    for name in ["CLA.md", ".github/CLA.md", "DCO", ".github/DCO"]:
        p = repo_dir / name
        if p.exists():
            output.console.print(f"(found: {name})")
            output.console.print("\n".join(p.read_text(errors="replace").splitlines()[:20]))
            cla_found = True
    if not cla_found:
        pattern = re.compile(
            r"(CLA|DCO|contributor license|developer certificate|sign.off)", re.IGNORECASE
        )
        for name in ["CONTRIBUTING.md", ".github/CONTRIBUTING.md"]:
            p = repo_dir / name
            if p.exists():
                lines = [l for l in p.read_text(errors="replace").splitlines() if pattern.search(l)]
                if lines:
                    output.console.print("\n".join(lines[:5]))
    output.console.print()


def section10_search_signals(reponame: str, cache: CacheManager) -> None:
    output.subsection("Section 10 — Search & Community Signals")

    # Stack Overflow
    output.console.print("Stack Overflow Tag Stats:")
    _cache = cache.raw_dir / "stackoverflow.txt"
    cache.status("stackoverflow", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        tag = reponame.lower().replace("_", "-")
        d = _get(f"https://api.stackexchange.com/2.3/tags/{tag}/info?site=stackoverflow")
        if d and d.get("items"):
            item = d["items"][0]
            result = (
                f"tag: {item.get('name')} | total_questions: {item.get('count')} | "
                f"has_synonyms: {item.get('has_synonyms')}"
            )
        else:
            result = f"(tag '{tag}' not found on Stack Overflow)"
        output.console.print(result)
        cache.write_text(_cache, result)
    output.console.print()

    # Hacker News
    output.console.print("Hacker News Mentions (Algolia):")
    _cache = cache.raw_dir / "hackernews.json"
    cache.status("hackernews", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        q = urllib.parse.quote(reponame)
        d = _get(f"https://hn.algolia.com/api/v1/search?query={q}&tags=story&hitsPerPage=5")
        if d and "hits" in d:
            text = json.dumps({
                "total_hits": d.get("nbHits"),
                "sample": [
                    {"title": h.get("title"), "points": h.get("points"),
                     "comments": h.get("num_comments"), "date": h.get("created_at")}
                    for h in d["hits"][:5]
                ],
            }, indent=2)
        else:
            text = "(could not fetch HN data)"
        output.console.print(text)
        cache.write_text(_cache, text)
    output.console.print()

    # Dev.to
    output.console.print("Dev.to Articles:")
    _cache = cache.raw_dir / "devto.json"
    cache.status("devto", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        tag = re.sub(r"[-_]", "", reponame.lower())
        d = _get(f"https://dev.to/api/articles?tag={tag}&per_page=5&top=1")
        if d and len(d) > 0:
            text = json.dumps({
                "count_in_sample": len(d),
                "tag_page": f"https://dev.to/t/{tag}",
                "sample": [
                    {"title": a.get("title"), "published": a.get("published_at"),
                     "reactions": a.get("positive_reactions_count")}
                    for a in d[:5]
                ],
            }, indent=2)
        else:
            text = f"(no Dev.to articles for tag '{tag}')"
        output.console.print(text)
        cache.write_text(_cache, text)
    output.console.print()

    # Google Trends (manual only)
    output.console.print("Google Trends (manual):")
    output.console.print(
        f"  https://trends.google.com/trends/explore?q={reponame}&date=today%205-y"
    )
    output.console.print("  (No public API — check manually for 5-year trend and geographic spread)")
    output.console.print()
