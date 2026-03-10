"""Section 13: Commercial intelligence — Crunchbase, YouTube."""
from __future__ import annotations

import urllib.parse

import requests

from .cache import CacheManager
from .config import Config
from . import output


def section13_commercial(
    owner: str, reponame: str, cache: CacheManager, cfg: Config, org_json: dict
) -> None:
    output.subsection("Section 13 — Commercial Intelligence")

    # Crunchbase (manual only — no public API key required)
    output.console.print("Crunchbase:")
    output.console.print(f"  Org: {owner} | GitHub type: {org_json.get('type', 'unknown')}")
    output.console.print(f"  Blog: {org_json.get('blog') or '(none)'}")
    output.console.print(f"  Manual: https://www.crunchbase.com/organization/{owner}")
    output.console.print()

    # YouTube
    output.console.print("YouTube Content:")
    yt_q = urllib.parse.quote(f"{reponame} tutorial")
    output.console.print(f"  https://www.youtube.com/results?search_query={yt_q}")
    if cfg.youtube_api_key:
        try:
            enc = urllib.parse.quote(reponame)
            resp = requests.get(
                f"https://www.googleapis.com/youtube/v3/search"
                f"?part=snippet&q={enc}&type=video&order=viewCount&maxResults=5"
                f"&key={cfg.youtube_api_key}",
                timeout=15,
            )
            if resp.status_code == 200:
                items = resp.json().get("items", [])
                if items:
                    output.console.print("Top videos by view count:")
                    output.print_data([
                        {
                            "title": i["snippet"]["title"],
                            "channel": i["snippet"]["channelTitle"],
                            "published": i["snippet"]["publishedAt"],
                        }
                        for i in items[:5]
                    ])
        except Exception as e:
            output.warn(f"YouTube API error: {e}")
    output.console.print()
