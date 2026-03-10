# GitHub Project Analyzer

A Claude Code skill that produces structured, multi-dimensional reports on any public GitHub repository — helping decision-makers evaluate whether to **adopt**, **evaluate**, or **avoid** a project, and whether to invest engineering resources into its community.

## What It Does

Given a GitHub URL, the skill runs a Python data-collection script across 13 data sources (GitHub API, npm, PyPI, Docker Hub, OpenSSF, HN, Stack Overflow, and more), then produces:

- **7-dimension analysis** — background, adoption, competitive landscape, momentum, risk, technical details, community investment
- **Bilingual reports** — English (`en/`) + Chinese (`zh/`) Markdown files
- **Optional exports** — PDF and PPTX slide deck (via companion skills)

## Quick Start

```bash
# 1. Install Python dependencies (one-time)
pip install -r scripts/requirements.txt

# 2. (Recommended) Set GitHub token for higher API rate limits
mkdir -p ~/.config/github-analyzer
echo "GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx" > ~/.config/github-analyzer/config
chmod 600 ~/.config/github-analyzer/config

# 3. Ask Claude Code to analyze a repo
# Just paste a GitHub URL in chat — the skill activates automatically
```

## Output Structure

```text
reports/{owner}-{repo}/
├── introduction.md      ← bilingual entry point (verdict + links)
├── en/
│   ├── index.md         ← decision brief + key metrics
│   ├── background.md    ← org backing, license, funding
│   ├── adoption.md      ← downloads, dependents, real-world usage
│   ├── competitive.md   ← positioning, alternatives, threats
│   ├── momentum.md      ← release cadence, growth trajectory
│   ├── risk.md          ← bus factor, CVEs, API stability
│   ├── technical.md     ← architecture, stack, key components
│   └── investment.md    ← community openness, contribution ROI
└── zh/
    └── (same structure, translated to Chinese)
```

## Cache

Raw API responses and analysis notes are cached locally to avoid redundant API calls:

```text
cache/{owner}-{repo}/
├── meta.json            ← fetch metadata + timestamps
├── repo/                ← persistent git clone
├── raw/                 ← per-source API responses (7-day TTL by default)
└── analysis/            ← analysis notes per section
```

Re-runs automatically skip fresh cache entries. Use `--force` to bypass all caches.

## Companion Skills

| Skill | Purpose |
|-------|---------|
| `translate` | Translates English reports to Chinese (required) |
| `read-arxiv-paper` | Summarizes referenced research papers (required) |
| `document-skills:pdf` | Generates PDF from Chinese Markdown (optional) |
| `document-skills:pptx` | Generates PPTX slide deck (optional) |

Install via:

```bash
npx skills add https://github.com/sunqb/ccsdk --skill translate
npx skills add https://github.com/sunqb/ccsdk --skill read-arxiv-paper
```

## Script Reference

```bash
ANALYZER=$(find ~/.claude -name analyze_repo.py | head -1)

python "$ANALYZER" https://github.com/owner/repo          # normal run
python "$ANALYZER" --force https://github.com/owner/repo  # bypass cache
python "$ANALYZER" --max-age 14 https://github.com/owner/repo  # extend TTL
python "$ANALYZER" --cache-dir ./cache https://github.com/owner/repo
```

## Authentication

Token priority order (highest to lowest):

1. `GITHUB_TOKEN` environment variable
2. `~/.config/github-analyzer/config`
3. Local `./config` next to the script
4. `gh` CLI (if authenticated)
5. Unauthenticated (60 req/hr — rate limit applies)

## Repository Layout

```text
scripts/
├── analyze_repo.py          ← CLI entry point
└── analyzer/
    ├── __init__.py
    ├── cache.py             ← CacheManager (read/write, freshness checks)
    ├── config.py            ← Config (token loading, GitHub API routing)
    ├── output.py            ← Rich console helpers
    ├── github_meta.py       ← Sections 1–4: repo, org, contributors, activity
    ├── local_repo.py        ← Sections 6–7: clone, file scan, git stats
    ├── ecosystem.py         ← Sections 5, 9: PyPI, npm, Docker, Homebrew, conda
    ├── community.py         ← Sections 8, 10: contributor orgs, SO, HN, Dev.to
    ├── security.py          ← Section 11: OpenSSF, OSV, NVD
    ├── foundation.py        ← Section 12: CNCF, Apache Foundation
    └── commercial.py        ← Section 13: Crunchbase, YouTube (manual/optional)
references/
└── analysis_guide.md        ← Detailed guidance for each report section
SKILL.md                     ← Claude Code skill definition
requirements.txt             ← Python dependencies (requests, rich)
```
