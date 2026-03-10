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
  (8) trending GitHub repositories by language or time period,
  (9) community investment assessment: entry barriers, contributor experience, governance openness,
  (10) investment ROI analysis: strategic value, cost estimation, expected returns.
  Triggers on: "analyze this GitHub repo", "should we adopt X", "compare X vs Y",
  "is X still maintained", "what's the risk of using X", "how popular is X",
  "explain this project", "how do I get started with X", "show me trending repos",
  "review this codebase", "is X backed by a company",
  "should we contribute to X", "is it worth investing in X community",
  "how open is X's community", "can we influence X's roadmap".
---

# GitHub Project Analyzer

## Target Audience

This skill has **one audience: the decision-maker** (CTO, tech lead, team manager, architect,
or anyone evaluating whether to adopt a project **and/or invest resources into its community**).
Every section is written to help a decision-maker form a complete picture — not just "should
we use this?" but also "should we invest people into contributing to this community, and
what's the expected return?"

---

## Dependencies

This skill requires two companion skills to be installed and available. Each one is
invoked automatically during analysis:

| Skill | When used | What happens without it |
|-------|-----------|------------------------|
| `read-arxiv-paper` | **technical.md §Research & Papers** — when the project links to arXiv/DOI papers, this skill is invoked to produce a structured paper summary instead of a bare URL | Papers are listed as plain links only; no summary or key-takeaways |
| `translate` | **On demand** — when the user requests the report (or a section) in a language other than English | Output is English only; translation requests cannot be fulfilled |

**Installation**: Skills are installed via Claude Code settings or the skill marketplace.
If a skill is missing, the dependency check (Step 0 below) will tell the user exactly
what to install before analysis begins.

---

## Workflow

### 0. Dependency check — run this FIRST, before any analysis

Before cloning the repo or calling any API, check whether both required skills are
available in the current session.

**How to check**: Look at the list of available skills shown in your system context
(the `Skill` tool description). Both `translate` and `read-arxiv-paper` must appear.

**For each missing skill**, stop and tell the user:

```text
⚠️  Missing dependency: the `<skill-name>` skill is not installed.

This skill is needed for: <purpose from table above>.

Install it with:
  npx skills add https://github.com/sunqb/ccsdk --skill <skill-name>

Once installed, restart the session and try again.
```

**Exact install commands for each dependency**:

| Skill | Install command |
|-------|----------------|
| `read-arxiv-paper` | `npx skills add https://github.com/sunqb/ccsdk --skill read-arxiv-paper` |
| `translate` | `npx skills add https://github.com/sunqb/ccsdk --skill translate` |

**Degraded-mode exception**: If the user explicitly says "proceed anyway / 继续":
- Missing `read-arxiv-paper` → list paper URLs in technical.md without summaries; add a note:
  `> ⚠️ read-arxiv-paper skill not installed — paper summaries unavailable.`
- Missing `translate` → continue in English; add a note at the top of index.md:
  `> ⚠️ translate skill not installed — report is English only.`

Do NOT silently skip the check. Always surface missing dependencies to the user.

---

### 1. Clone & gather data

**Check for an existing report first**: Before running the script, check whether
`./reports/{owner}-{reponame}/` already exists.
- If it exists and the user gave no explicit instruction, ask:
  > "A report for this project already exists. Re-run full analysis (overwrites), update
  > specific sections only, or view the existing report?"
- If the user says "proceed" / "overwrite" / gives no preference → continue below.

**Finding and running the script**: Locate the script with `find`, then run it directly.
If installed via `npx skills add`, the installer prints the path.

```bash
# Locate and run in one step (recommended)
ANALYZER=$(find ~/.claude -name analyze_repo.sh 2>/dev/null | head -1)
bash "$ANALYZER" <github-url-or-owner/repo>
```

> **Note**: Do NOT use `xargs dirname` on the find result and then append `/scripts/` —
> the find already returns the full path to the script itself.

Run the analysis script. It clones the repo into a local temp directory and fetches
remote metadata via the `gh` CLI (falls back to unauthenticated `curl` if needed).

**If the script fails or returns incomplete data**:
- **Silent exit after first line** → most common cause: `~/.config/github-analyzer/config`
  does not exist. This is now fixed in the script (v2+), but if you see only one line of
  output, debug with:
  ```bash
  bash -x "$ANALYZER" <github-url> 2>&1 | head -80
  ```
- **Clone failure** → verify the URL is a public repo; try `gh repo view <owner>/<repo>`
  to confirm access.
- **GitHub API rate-limit** → configure a token (see Tips §GitHub Token) and re-run; or
  continue with only local clone data, marking remote fields as `N/A (API unavailable)`.
- **PyPI/npm/registry API failure** → mark download stats as
  `N/A (registry unavailable — {date})` and continue.
- **General rule**: never halt the entire report for a single data-source failure. Write
  all sections with available data; use `N/A` markers where data is missing.

The script outputs two important paths at the end:

```text
LOCAL_REPO_PATH=/tmp/github-analyzer-XXXXXX/repo
TEMP_DIR=/tmp/github-analyzer-XXXXXX
```

The script collects:
- **Remote** (GitHub API): repo info, contributors, releases, open PRs, topics, dependents count
- **Package registries**: PyPI, npm, Docker Hub, Homebrew, conda-forge downloads (where applicable)
- **Dependency intelligence**: Libraries.io SourceRank, deps.dev dependency graph
- **Community signals**: Stack Overflow tag stats + unanswered rate, Hacker News story count, Dev.to article count
- **Security health**: OpenSSF Scorecard (10-point automated score), OSV vulnerability count, NVD CVE history
- **Foundation status**: CNCF landscape lookup, Apache Software Foundation project list
- **Commercial intelligence**: Crunchbase manual link (automated lookup requires paid API key)
- **Local** (cloned files): README, manifests, CI configs, community health files,
  CHANGELOG/breaking-change history, git stats, org/sponsorship files, CONTRIBUTING.md, GOVERNANCE.md

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
```text
# Find adopter/user mentions
pattern: "(?i)(production|used by|powered by|built with|case study)"  path: <LOCAL_REPO_PATH>

# Find breaking change markers in changelog
pattern: "(?i)(breaking|BREAKING CHANGE|incompatible|migration)"  path: <LOCAL_REPO_PATH>/CHANGELOG.md
```

#### 📄 Invoke `read-arxiv-paper` for referenced papers

When the script output lists paper/DOI links (in the "Paper/DOI links found in README"
or CITATION.cff section), and the link points to an arXiv paper:

1. Check if a summary already exists in `./knowledge/summary_*.md` — read it if so.
2. If no local summary exists, invoke the `read-arxiv-paper` skill with the arXiv URL.
   The skill downloads the TeX source and writes a summary to `./knowledge/summary_<tag>.md`.
3. Reference the summary when writing `technical.md §Research & Papers`.

Only invoke this skill for arXiv links. For non-arXiv paper links (ACL Anthology, NeurIPS
proceedings, etc.), include the URL and title in technical.md but do not attempt a deep read.

### 3. Clean up temp directory

After analysis is complete, remove the temp directory:

```bash
rm -rf <TEMP_DIR>
```

### 4. Select analysis mode based on user intent

| User asks | Focus section(s) |
|-----------|----------------|
| "Analyze X" / "full report on X" | All 8 files (default) |
| "Should we adopt X?" / "evaluate X" | index.md §Decision Brief |
| "Who backs X?" / "is it corporate?" | background.md |
| "How widely used is X?" | adoption.md |
| "X vs Y" / "alternatives to X" | competitive.md |
| "Is X growing?" / "still active?" | momentum.md |
| "Risk of using X?" / "is it maintained?" | risk.md |
| "How does X work?" / "architecture?" / "key concepts?" | technical.md §1–3 |
| "Any papers?" / "research behind X?" / "docs?" | technical.md §4–5 |
| "How do I try it?" / "quick start?" | technical.md §6 |
| "Should we contribute to X?" / "invest in X community?" | investment.md + index.md |
| "How open is X's community?" | investment.md §Community Openness |
| "Trending repos" / "what's popular" | Chat only — no files written |

Read `references/analysis_guide.md` for detailed guidance on each section.

**Default behavior**: If user intent is unspecified, always produce the **full report** —
all 8 files. Every section contributes to a complete decision-maker picture.

#### Compare mode (X vs Y)

When the user asks to compare two projects (e.g., "X vs Y", "compare X and Y"):

1. Run the script for **each repo separately**:
   ```bash
   bash <skill-dir>/scripts/analyze_repo.sh <url-or-owner/repo-A>
   bash <skill-dir>/scripts/analyze_repo.sh <url-or-owner/repo-B>
   ```
2. Generate **full reports for both** projects under their respective directories
   (`./reports/{owner-A}-{repo-A}/` and `./reports/{owner-B}-{repo-B}/`).
3. In `competitive.md` of **each** project, ensure the other appears in the comparison table.
4. After both report directories are written, output a **chat-only summary** (no additional
   file) containing:
   - A side-by-side table: Stars · Downloads · License · Backing · Last release ·
     Key strength · Key weakness
   - A "pick A when … / pick B when …" recommendation block

#### Trending repos mode

For trending queries ("show me trending repos", "what's popular in Python"):

- Skip the clone script entirely — use the `gh` CLI or GitHub search API directly
  (see `analysis_guide.md §Trending Repos` for the exact commands).
- Default parameters when unspecified: **all languages, past 7 days, top 10**.
- Output as a ranked table in chat. **No files are written.**

### 5. Generate report files

Do NOT output the full analysis as a chat message. Instead, write it as a set of structured
markdown files so the user can navigate and reference them easily.

#### Report directory structure

Every report lives under a project directory split into two language subdirectories:

```text
./reports/{owner}-{reponame}/
├── introduction.md  ← bilingual entry point (written last, after en/ and zh/)
├── en/              ← English originals (written first)
│   ├── index.md
│   ├── background.md
│   ├── adoption.md
│   ├── competitive.md
│   ├── momentum.md
│   ├── risk.md
│   ├── technical.md
│   └── investment.md
└── zh/              ← Chinese translations (written second, via translate skill)
    ├── index.md
    ├── background.md
    ├── adoption.md
    ├── competitive.md
    ├── momentum.md
    ├── risk.md
    ├── technical.md
    └── investment.md
```

Example: analyzing `vllm-project/llm-compressor` →
- English: `./reports/vllm-project-llm-compressor/en/`
- Chinese: `./reports/vllm-project-llm-compressor/zh/`

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
| `investment.md` | Community investment assessment: strategic value · entry barriers · cost estimation · expected returns · governance openness |

#### Step 5a — Write English report (`en/`)

Write all 8 files to the `en/` subdirectory. Order: **7 dimension files first**
(background → adoption → competitive → momentum → risk → technical → investment), then `index.md` last.

Use the **Write** tool for every file. Parent directories are created automatically.

`index.md` structure:

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
| External contributor ratio | ... |
| External PR merge time (median) | ... |
| Good first issues (open) | ... |

## Contents
| Section | Summary | File |
|---------|---------|------|
| Organizational Background | [one sentence] | [background.md](./background.md) |
| Real-World Adoption | [one sentence] | [adoption.md](./adoption.md) |
| Competitive Landscape | [one sentence] | [competitive.md](./competitive.md) |
| Momentum & Trajectory | [one sentence] | [momentum.md](./momentum.md) |
| Risk Assessment | [one sentence] | [risk.md](./risk.md) |
| Technical Details | [one sentence] | [technical.md](./technical.md) |
| Community Investment | [one sentence] | [investment.md](./investment.md) |
```

#### Step 5b — Translate to Chinese (`zh/`) via `translate` skill

After all 8 English files are written, **always** invoke the `translate` skill to produce
the Chinese version. This is not optional — both language versions are always generated.

**For each of the 8 files**, in the same order (background → adoption → competitive →
momentum → risk → technical → investment → index):

1. Read the English file from `en/<file>.md`.
2. Invoke the `translate` skill with the following parameters:
   - `target_language`: `zh`
   - `translation_style`: `professional`
   - `retain_format`: `true`  ← preserve all markdown structure, headings, tables, links
   - `auto_humanize`: `true`  ← remove AI-sounding phrasing after translation
3. Write the translated content to `zh/<file>.md` using the **Write** tool.

Translation rules:
- All prose and table cell content → translate to Chinese
- Headings → translate to Chinese
- Technical terms, algorithm names (GPTQ, AWQ, FP8…), project/company names, code blocks,
  URLs, CLI commands → keep in original English, do NOT translate

#### Step 5c — Write bilingual `introduction.md`

After both `en/` and `zh/` are complete, write a single bilingual entry-point file at the
**project root** (same level as `en/` and `zh/`):

```text
./reports/{owner}-{reponame}/introduction.md
```

This file serves as the landing page for the whole report. Write it with the Write tool.

**Structure**:

```markdown
# {Project Name} — Analysis Report

> {one-sentence verdict in English, drawn from index.md Decision Brief}

📖 [Read in English](./en/index.md)

---

# {Project Name} — 分析报告

> {上面英文摘要的中文翻译，一句话}

📖 [阅读中文版](./zh/index.md)
```

The one-sentence verdict must be derived from the Decision Brief already written in
`en/index.md` — summarise the Adopt/Evaluate/Avoid verdict and the key reason in plain
language. The Chinese sentence is the translation of that verdict (apply `auto_humanize`
as well).

#### After writing all files

Tell the user:
```text
报告已生成：
  入口：  ./reports/{owner}-{reponame}/introduction.md
  英文版：./reports/{owner}-{reponame}/en/index.md
  中文版：./reports/{owner}-{reponame}/zh/index.md
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
- **GitHub Token (recommended)**: The script supports a personal access token to avoid
  the 60 req/hr unauthenticated rate limit. Token priority order:
  1. `~/.config/github-analyzer/config` file (primary — see setup below)
  2. `GITHUB_TOKEN` environment variable
  3. `gh` CLI (if authenticated)
  4. Unauthenticated curl (60 req/hr limit — warns user)

  **Setup** (tell users this if they hit rate limits or want authenticated access):
  ```bash
  mkdir -p ~/.config/github-analyzer
  cat > ~/.config/github-analyzer/config <<'EOF'
  # GitHub Personal Access Token
  # Get one at: https://github.com/settings/tokens
  # No scopes needed for public repos; add 'repo' for private repos.
  GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
  EOF
  chmod 600 ~/.config/github-analyzer/config
  ```
  The script validates the token on every run. If the token is expired or
  revoked, it prints a clear error box and falls back to unauthenticated.
- **No token / no gh CLI**: Falls back to unauthenticated `curl`. Works fine for
  occasional use; hits rate limits on rapid repeated analysis. Package registry
  APIs (PyPI, npm) require no authentication regardless.
- **Large repos**: The script uses `--depth=1` (shallow clone) for speed.
- **Trending**: For trending repos, no local clone needed — use the GitHub search API directly.
  Default to "all languages, past 7 days" if not specified.
- **Compare mode**: When comparing X vs Y, run the script for both repos sequentially, then
  synthesize a side-by-side comparison table before writing the narrative.
- **Google Trends is manual**: The script outputs a direct Trends URL for the project. Always check it — it reveals whether mindshare is growing or has peaked, which star counts cannot show.
- **OpenSSF Scorecard**: If the automated API returns no data, the score can be generated locally with `scorecard --repo=github.com/{owner}/{repo}` (requires the `scorecard` CLI tool).
- **Libraries.io API key**: Free tier available at `https://libraries.io/api`. Add `LIBRARIES_IO_KEY=xxx` to `~/.config/github-analyzer/config` to enable automated SourceRank lookups.
- **YouTube API key**: Optional. Add `YOUTUBE_API_KEY=xxx` to `~/.config/github-analyzer/config` to enable automated tutorial video stats. Free quota is sufficient for occasional use.
- **Community signals complement GitHub data**: Stack Overflow unanswered rate and HackerNews sentiment often reveal adoption friction that GitHub metrics hide. A project with great stars but 60% SO unanswered rate has a real support problem.
