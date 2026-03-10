#!/usr/bin/env python3
"""GitHub Project Analyzer v3.0 — Data Collection Script.

Usage:
    python analyze_repo.py [OPTIONS] <github-url-or-owner/repo>

Options:
    --cache-dir DIR    Root directory for cache (default: ./cache)
    --max-age DAYS     Cache max age in days (default: 7)
    --force            Bypass all caches, re-fetch everything

Auth config: ~/.config/github-analyzer/config
    GITHUB_TOKEN=ghp_...
    LIBRARIES_IO_KEY=...    (optional)
    YOUTUBE_API_KEY=...     (optional)
"""

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from analyzer.cache import CacheManager
from analyzer.config import Config
from analyzer import (
    commercial,
    community,
    ecosystem,
    foundation,
    github_meta,
    local_repo,
    output,
    security,
)


def _parse_repo(raw: str) -> tuple[str, str, str]:
    """Return (owner/repo, owner, reponame) from a URL or owner/repo string."""
    repo = re.sub(r"https?://github\.com/", "", raw)
    repo = re.sub(r"\.git$", "", repo).rstrip("/")
    parts = repo.split("/")
    if len(parts) != 2:
        print(f"ERROR: expected owner/repo or GitHub URL, got: {raw}", file=sys.stderr)
        sys.exit(1)
    return repo, parts[0], parts[1]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="GitHub Project Analyzer v3.0 — data collection",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("repo", help="GitHub URL or owner/repo (e.g. torvalds/linux)")
    parser.add_argument("--cache-dir", default="./cache", metavar="DIR",
                        help="Root directory for cache (default: ./cache)")
    parser.add_argument("--max-age", type=int, default=7, metavar="DAYS",
                        help="Cache max age in days (default: 7)")
    parser.add_argument("--force", action="store_true",
                        help="Bypass all caches and re-fetch everything")
    args = parser.parse_args()

    repo, owner, reponame = _parse_repo(args.repo)
    clone_url = f"https://github.com/{repo}.git"

    cfg = Config()
    cache = CacheManager(
        base_dir=Path(args.cache_dir),
        slug=f"{owner}-{reponame}",
        max_age_days=args.max_age,
        force=args.force,
    )

    output.console.print(f"\n[bold]=== GitHub Project Analyzer v3.0: {repo} ===[/bold]")
    output.console.print(f"Cache dir : {cache.cache_dir}")
    output.console.print(f"Max age   : {args.max_age}d | Force: {args.force}\n")

    # Auth
    output.section("Auth Status")
    cfg.authenticate()

    # Phase 1 — Clone / update
    output.section("Phase 1: Data Collection")
    output.subsection("Repository Clone")
    local_repo.clone_or_update(repo, clone_url, cache)

    # Sections 1-4: GitHub API metadata
    repo_json  = github_meta.section1_repo_metadata(repo, cache, cfg)
    org_json   = github_meta.section2_org_backing(owner, cache, cfg, repo_dir=cache.repo_dir)
    contrib_json = github_meta.section3_contributors(repo, cache, cfg)
    github_meta.section4_activity(repo, cache, cfg, repo_json)

    # Section 5: Ecosystem downloads
    ecosystem.section5_downloads(repo, owner, reponame, cache, repo_dir=cache.repo_dir)

    # Sections 6 & 6b: Local file analysis
    local_repo.section6_local_files(cache.repo_dir)
    local_repo.section6b_technical_deepdive(cache.repo_dir, repo_json)

    # Section 7: Git stats
    local_repo.section7_git_stats(cache)

    # Section 8: Community investment signals
    community.section8_community_investment(repo, cache, cfg, contrib_json, repo_dir=cache.repo_dir)

    # Section 9: Extended package ecosystems
    ecosystem.section9_extended_ecosystems(owner, reponame, cache, repo_dir=cache.repo_dir)

    # Section 10: Search & community signals
    community.section10_search_signals(reponame, cache)

    # Section 11: Security health
    security.section11_security_health(repo, reponame, cache, repo_dir=cache.repo_dir)

    # Section 12: Foundation & governance
    foundation.section12_foundation_status(owner, reponame, cache, org_json)

    # Section 13: Commercial intelligence
    commercial.section13_commercial(owner, reponame, cache, cfg, org_json)

    # Write cache metadata
    fetch_ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    meta = {
        "repo": repo,
        "owner": owner,
        "reponame": reponame,
        "fetched_at": fetch_ts,
        "script_version": "3.0",
        "max_age_days": args.max_age,
        "cache_dir": str(cache.cache_dir),
        "raw_dir": str(cache.raw_dir),
        "repo_dir": str(cache.repo_dir),
    }
    (cache.cache_dir / "meta.json").write_text(json.dumps(meta, indent=2))

    output.console.print("\n[bold]=== Data Collection Complete ===[/bold]")
    output.console.print(f"\nCACHE_DIR={cache.cache_dir}")
    output.console.print(f"RAW_DIR={cache.raw_dir}")
    output.console.print(f"LOCAL_REPO_PATH={cache.repo_dir}")
    output.console.print(f"FETCHED_AT={fetch_ts}")
    output.console.print(f"\nPhase 2 (Analysis): read raw cache files and save notes to:")
    output.console.print(f"  {cache.cache_dir}/analysis/{{section}}.md")
    output.console.print(f"Phase 3 (Reports):  write to ./reports/{cache.slug}/")


if __name__ == "__main__":
    main()
