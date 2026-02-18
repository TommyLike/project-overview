---
name: github-project-analyzer
description: >
  Analyze GitHub projects to help decision-makers quickly evaluate technology choices.
  Use this skill when the user provides a GitHub repository URL (e.g., https://github.com/owner/repo)
  and wants to understand:
  (1) what the project is and who backs it (organizational background),
  (2) real-world adoption and ecosystem maturity,
  (3) competitive landscape and alternatives,
  (4) momentum and growth trajectory,
  (5) adoption risk assessment (security, bus factor, breaking changes),
  (6) a final decision brief with a clear adopt/evaluate/avoid recommendation,
  (7) technical deep-dive: architecture, core concepts, key components, papers, docs links,
  (8) trending GitHub repositories by language or time period.
  Triggers on: "analyze this GitHub repo", "should we adopt X", "compare X vs Y",
  "is X still maintained", "what's the risk of using X", "how popular is X",
  "explain this project", "how do I get started with X", "show me trending repos",
  "review this codebase", "is X backed by a company".
---

# GitHub Project Analyzer

## Target audience

This skill has **one audience: the decision-maker** (CTO, tech lead, architect, or anyone
evaluating whether to adopt a project). Every section — including technical architecture,
papers, and getting started — is written to help a decision-maker form a complete picture,
not to serve developers looking for implementation details.

---

## Workflow

### 1. Clone & gather data

Run the analysis script. It clones the repo into a local temp directory and fetches
remote metadata via the `gh` CLI (falls back to unauthenticated `curl` if needed):

```bash
bash <skill-dir>/scripts/analyze_repo.sh <github-url-or-owner/repo>
```

The script outputs two important paths at the end:

```
LOCAL_REPO_PATH=/tmp/github-analyzer-XXXXXX/repo
TEMP_DIR=/tmp/github-analyzer-XXXXXX
```

The script collects:
- **Remote** (GitHub API): repo info, contributors, releases, open PRs, topics, dependents count
- **Package registries**: PyPI downloads, npm downloads (where applicable)
- **Local** (cloned files): README, manifests, CI configs, community health files,
  CHANGELOG/breaking-change history, git stats, org/sponsorship files

### 2. Read key local files

Use the **Read** tool on files from `LOCAL_REPO_PATH` that are most relevant to the selected mode:

| Mode | Key files to read |
|------|------------------|
| Org Background | `README.md`, `NOTICE`, `LICENSE`, `.github/CODEOWNERS`, `FUNDING.yml` |
| Adoption & Ecosystem | `README.md` (logos/badges section), `ADOPTERS.md`, `USERS.md`, `docs/` |
| Risk Assessment | `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`, top CI workflow |
| Code Quality | `package.json`/`pyproject.toml`/`go.mod`, CI workflows, sample source file |
| Getting Started | `README.md`, `docs/getting-started*`, `examples/` |

Use **Glob** and **Grep** for targeted searches:
```
# Find adopter/user mentions
pattern: "(?i)(production|used by|powered by|built with|case study)"  path: <LOCAL_REPO_PATH>

# Find breaking change markers in changelog
pattern: "(?i)(breaking|BREAKING CHANGE|incompatible|migration)"  path: <LOCAL_REPO_PATH>/CHANGELOG.md
```

### 3. Clean up temp directory

After analysis is complete, remove the temp directory:

```bash
rm -rf <TEMP_DIR>
```

### 4. Select analysis mode based on user intent

| User asks | Focus section(s) |
|-----------|----------------|
| "Analyze X" / "full report on X" | All 7 files (default) |
| "Should we adopt X?" / "evaluate X" | index.md §Decision Brief |
| "Who backs X?" / "is it corporate?" | background.md |
| "How widely used is X?" | adoption.md |
| "X vs Y" / "alternatives to X" | competitive.md |
| "Is X growing?" / "still active?" | momentum.md |
| "Risk of using X?" / "is it maintained?" | risk.md |
| "How does X work?" / "architecture?" / "key concepts?" | technical.md §1–3 |
| "Any papers?" / "research behind X?" / "docs?" | technical.md §4–5 |
| "How do I try it?" / "quick start?" | technical.md §6 |
| "Trending repos" / "what's popular" | Chat only — no files written |

Read `references/analysis_guide.md` for detailed guidance on each section.

**Default behavior**: If user intent is unspecified, always produce the **full report** —
all 7 files. Every section contributes to a complete decision-maker picture.

### 5. Generate report files

Do NOT output the full analysis as a chat message. Instead, write it as a set of structured
markdown files so the user can navigate and reference them easily.

#### Report directory

```
./reports/{owner}-{reponame}/
```

Example: analyzing `vllm-project/llm-compressor` → `./reports/vllm-project-llm-compressor/`

#### File layout and content responsibilities

| File | Content |
|------|---------|
| `index.md` | Decision Brief + key metrics table + one-sentence summary per section + links |
| `background.md` | Org backing, governance model, commercial relationship |
| `adoption.md` | Download stats, dependents, named adopters, ecosystem, cloud support |
| `competitive.md` | Alternatives table, market positioning, when to pick this vs others |
| `momentum.md` | Star velocity, release cadence, PR/issue health, lifecycle stage |
| `risk.md` | Bus factor, security, breaking-change history, abandonment signals, license |
| `technical.md` | Core concepts · Architecture · Key components · Papers · Docs links · Hello World · Code quality |

#### Writing order

Write the **6 dimension files first** (background → adoption → competitive → momentum → risk →
technical), then write `index.md` last — because the index summarizes all of them.

Use the **Write** tool for every file. Create the directory automatically (Write creates
parent directories).

#### index.md structure

```markdown
# {Project Name} — Analysis Report
> **Source**: {github-url} | **Analyzed**: {YYYY-MM-DD}

## Decision Brief
[Full Decision Brief block — see analysis_guide.md §Decision Brief]

## Key Metrics
| Metric | Value |
|--------|-------|
| Stars | ... |
| Weekly downloads (PyPI/npm) | ... |
| License | ... |
| Backed by | ... |
| Last pushed | ... |
| GitHub dependents | ... |

## Contents
| Section | Summary | File |
|---------|---------|------|
| Organizational Background | [one sentence] | [background.md](./background.md) |
| Real-World Adoption | [one sentence] | [adoption.md](./adoption.md) |
| Competitive Landscape | [one sentence] | [competitive.md](./competitive.md) |
| Momentum & Trajectory | [one sentence] | [momentum.md](./momentum.md) |
| Risk Assessment | [one sentence] | [risk.md](./risk.md) |
| Technical Details | [one sentence] | [technical.md](./technical.md) |
```

#### After writing all files

Tell the user:
```
Report written to ./reports/{owner}-{reponame}/
Open ./reports/{owner}-{reponame}/index.md to start reading.
```

Do NOT repeat the full report content in the chat. A brief summary (3-5 sentences) is fine.

---

## Tips

- **Stars are vanity, downloads are reality**: Always try to surface PyPI/npm download numbers
  alongside star count. A project with 500 stars and 2M weekly downloads beats one with
  10K stars and 5K downloads for adoption assessment.
- **Org = sustainability**: The single most predictive factor for long-term viability is who
  backs the project. FAANG / foundation-backed > VC-startup-backed > individual maintainer.
- **Changelog tells the truth**: The CHANGELOG reveals breaking-change frequency and versioning
  discipline better than any other single file.
- **Bus factor matters**: If the top 1-2 contributors own >70% of commits, flag it explicitly.
- **No gh CLI**: The script falls back to `curl https://api.github.com/repos/<owner>/<repo>`
  for public repo metadata. Package registry APIs (PyPI, npm) require no authentication.
- **Large repos**: The script uses `--depth=1` (shallow clone) for speed.
- **Trending**: For trending repos, no local clone needed — use the GitHub search API directly.
  Default to "all languages, past 7 days" if not specified.
- **Compare mode**: When comparing X vs Y, run the script for both repos sequentially, then
  synthesize a side-by-side comparison table before writing the narrative.
