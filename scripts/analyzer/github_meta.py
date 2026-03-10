"""Sections 1-4: GitHub repository metadata, org/backing, contributors, activity."""
from __future__ import annotations

from pathlib import Path

from .cache import CacheManager
from .config import Config
from . import output


def section1_repo_metadata(repo: str, cache: CacheManager, cfg: Config) -> dict:
    output.subsection("Section 1 — GitHub Repository Metadata")
    _cache = cache.raw_dir / "github_repo.json"
    cache.status("github_repo", _cache)
    if cache.is_fresh(_cache):
        data = cache.read_json(_cache) or {}
    else:
        data = cfg.github_api(f"repos/{repo}") or {}
        cache.write_json(_cache, data)

    owner = data.get("owner") or {}
    license_ = data.get("license") or {}
    output.print_data({
        "name": data.get("name"),
        "description": data.get("description"),
        "url": data.get("html_url"),
        "homepage": data.get("homepage"),
        "owner_type": owner.get("type"),
        "owner_login": owner.get("login"),
        "stars": data.get("stargazers_count"),
        "forks": data.get("forks_count"),
        "watchers": data.get("subscribers_count"),
        "open_issues": data.get("open_issues_count"),
        "primary_language": data.get("language"),
        "license": license_.get("name"),
        "license_spdx": license_.get("spdx_id"),
        "created_at": data.get("created_at"),
        "last_pushed": data.get("pushed_at"),
        "default_branch": data.get("default_branch"),
        "archived": data.get("archived"),
        "fork": data.get("fork"),
        "topics": data.get("topics"),
        "network_count": data.get("network_count"),
        "subscribers_count": data.get("subscribers_count"),
    })
    output.console.print()
    return data


def section2_org_backing(owner: str, cache: CacheManager, cfg: Config, repo_dir: Path) -> dict:
    output.subsection("Section 2 — Organization / Backing")
    _cache = cache.raw_dir / "github_org.json"
    cache.status("github_org", _cache)
    if cache.is_fresh(_cache):
        data = cache.read_json(_cache) or {}
    else:
        data = cfg.github_api(f"orgs/{owner}") or cfg.github_api(f"users/{owner}") or {}
        cache.write_json(_cache, data)

    output.print_data({
        "name": data.get("name"),
        "blog": data.get("blog"),
        "location": data.get("location"),
        "description": data.get("description"),
        "company": data.get("company"),
        "email": data.get("email"),
        "twitter_username": data.get("twitter_username"),
        "public_repos": data.get("public_repos"),
        "followers": data.get("followers"),
        "type": data.get("type"),
        "created_at": data.get("created_at"),
    })
    output.console.print()

    output.console.print("[bold]#### Sponsorship / Funding[/bold]")
    funding = repo_dir / ".github" / "FUNDING.yml"
    if funding.exists():
        output.console.print("(FUNDING.yml found)")
        output.console.print(funding.read_text())
    else:
        output.console.print("(no FUNDING.yml)")
    output.console.print()
    return data


def section3_contributors(repo: str, cache: CacheManager, cfg: Config) -> list:
    output.subsection("Section 3 — Contributors")
    _cache = cache.raw_dir / "github_contributors.json"
    cache.status("github_contributors", _cache)
    if cache.is_fresh(_cache):
        data = cache.read_json(_cache) or []
    else:
        data = cfg.github_api(f"repos/{repo}/contributors?per_page=15") or []
        cache.write_json(_cache, data)

    output.console.print("Top Contributors (up to 15):")
    output.print_data([{"login": c.get("login"), "contributions": c.get("contributions")} for c in data])
    output.console.print()

    output.console.print("Bus Factor Signal:")
    if data:
        total = sum(c.get("contributions", 0) for c in data)
        output.print_data({
            "total_contributors": len(data),
            "top1_share_pct": round(data[0].get("contributions", 0) / total * 100) if total else 0,
            "top3_share_pct": round(sum(c.get("contributions", 0) for c in data[:3]) / total * 100) if total else 0,
            "total_contributions": total,
        })
    else:
        output.console.print("no contributor data")
    output.console.print()
    return data


def section4_activity(repo: str, cache: CacheManager, cfg: Config, repo_json: dict) -> None:
    output.subsection("Section 4 — Activity & Release Health")

    # Releases
    _cache = cache.raw_dir / "github_releases.json"
    cache.status("github_releases", _cache)
    if cache.is_fresh(_cache):
        releases = cache.read_json(_cache) or []
    else:
        releases = cfg.github_api(f"repos/{repo}/releases?per_page=8") or []
        cache.write_json(_cache, releases)
    output.console.print("Recent Releases (up to 8):")
    output.print_data([
        {"tag": r.get("tag_name"), "name": r.get("name"),
         "published": r.get("published_at"), "prerelease": r.get("prerelease")}
        for r in releases
    ])
    output.console.print()

    # Open PRs
    _cache = cache.raw_dir / "github_prs_open.json"
    cache.status("github_prs_open", _cache)
    if cache.is_fresh(_cache):
        prs = cache.read_json(_cache) or []
    else:
        prs = cfg.github_api(f"repos/{repo}/pulls?state=open&per_page=100") or []
        cache.write_json(_cache, prs)
    output.console.print("Open Pull Requests:")
    oldest = sorted(prs, key=lambda p: p.get("created_at", ""))[0].get("created_at") if prs else None
    output.print_data({
        "open_pr_count": len(prs),
        "oldest_pr_created": oldest,
        "sample_titles": [p.get("title") for p in prs[:5]],
    })
    output.console.print()

    # Closed issues
    _cache = cache.raw_dir / "github_issues_closed.json"
    cache.status("github_issues_closed", _cache)
    if cache.is_fresh(_cache):
        issues = cache.read_json(_cache) or []
    else:
        issues = cfg.github_api(f"repos/{repo}/issues?state=closed&per_page=5&sort=updated") or []
        cache.write_json(_cache, issues)
    output.console.print("Recent Closed Issues (response time sample):")
    output.print_data([
        {"number": i.get("number"), "title": i.get("title"),
         "created": i.get("created_at"), "closed": i.get("closed_at")}
        for i in issues
    ])
    output.console.print()

    output.console.print("Repository Topics:")
    output.print_data(repo_json.get("topics", []))
    output.console.print()
