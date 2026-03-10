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

This skill requires companion skills to be installed and available. Each one is
invoked automatically during analysis:

| Skill | When used | What happens without it |
|-------|-----------|------------------------|
| `read-arxiv-paper` | **technical.md §Research & Papers** — when the project links to arXiv/DOI papers, this skill is invoked to produce a structured paper summary instead of a bare URL | Papers are listed as plain links only; no summary or key-takeaways |
| `translate` | **Phase 3b** — translates all 8 English report files to Chinese (`zh/`) | Output is English only; Chinese translation cannot be fulfilled |
| `document-skills:pdf` | **Phase 4** — generates a PDF report from Chinese markdown files | PDF generation unavailable; Phase 4 must be skipped |
| `document-skills:pptx` | **Phase 5** — generates a PPTX slide deck from Chinese markdown files | PPTX generation unavailable; Phase 5 must be skipped |

`document-skills:pdf` and `document-skills:pptx` are **optional** — only checked if the user requests
PDF/PPTX output (see Pre-execution Consultation below).

**Installation**: Skills are installed via Claude Code settings or the skill marketplace.
If a skill is missing, the dependency check (Phase 0 below) will tell the user exactly
what to install before analysis begins.

---

## Workflow

The workflow has **five explicit phases**. Each phase persists its output locally so that
re-runs skip completed work and reduce API calls and token usage.

```
Phase 0: Dependency check  +  Pre-execution consultation (PDF / PPTX preference)
Phase 1: Data Collection   →  saves to ./cache/{owner}-{repo}/raw/
Phase 2: Analysis          →  saves to ./cache/{owner}-{repo}/analysis/
Phase 3: Report Generation →  writes to ./reports/{owner}-{repo}/  (en/ + zh/ + introduction.md)
Phase 4: PDF Generation    →  ./reports/{owner}-{repo}/report_zh.pdf   [optional, independent]
Phase 5: PPTX Generation   →  ./reports/{owner}-{repo}/slides_zh.pptx  [optional, independent]
```

Phases 4 and 5 are **independent** of each other and of Phase 3 — each can be re-run
individually after a failure without re-running the others.

---

### Phase 0 — Dependency Check + Pre-execution Consultation

#### Step 0a — Pre-execution consultation

**Before checking any skills or running any analysis**, ask the user:

```text
分析完成后是否需要生成以下格式的报告？（均由中文版 markdown 生成）

  [1] PDF 格式报告（report_zh.pdf）
  [2] PPT 格式幻灯片（slides_zh.pptx）
  [3] 两者都需要
  [4] 都不需要（仅生成 markdown 报告）

请回复编号或直接说明需求。
```

Record the user's answer as **`WANT_PDF`** (true/false) and **`WANT_PPTX`** (true/false).
These flags control which dependencies to check and which phases to execute.

**Skip this question** if:
- The user's original request already specified PDF/PPTX (e.g., "生成报告并导出PDF")
- The user is re-running a failed Phase 4 or Phase 5 directly

#### Step 0b — Required dependency check

Check whether the **always-required** skills are available (look in the `Skill` tool
description in your system context):

| Skill | Required for | Install command |
|-------|-------------|----------------|
| `read-arxiv-paper` | Phase 1 (paper summaries) | `npx skills add https://github.com/sunqb/ccsdk --skill read-arxiv-paper` |
| `translate` | Phase 3b (Chinese translation) | `npx skills add https://github.com/sunqb/ccsdk --skill translate` |

**For each missing required skill**, stop and tell the user:

```text
⚠️  Missing dependency: the `<skill-name>` skill is not installed.

This skill is needed for: <purpose from table above>.

Install it with:
  npx skills add https://github.com/sunqb/ccsdk --skill <skill-name>

Once installed, restart the session and try again.
```

**Degraded-mode exception** (user says "proceed anyway / 继续"):
- Missing `read-arxiv-paper` → list paper URLs only; add `> ⚠️ read-arxiv-paper skill not installed.`
- Missing `translate` → English only; add `> ⚠️ translate skill not installed — English only.`

#### Step 0c — Optional dependency check (PDF / PPTX)

Only perform this check if `WANT_PDF=true` or `WANT_PPTX=true`:

| Flag | Skill needed | Install command |
|------|-------------|----------------|
| `WANT_PDF=true` | `document-skills:pdf` | `npx skills add https://github.com/sunqb/ccsdk --skill document-skills:pdf` |
| `WANT_PPTX=true` | `document-skills:pptx` | `npx skills add https://github.com/sunqb/ccsdk --skill document-skills:pptx` |

If a required optional skill is missing:

```text
⚠️  Missing dependency: the `<skill-name>` skill is not installed.

This skill is needed to generate <PDF/PPTX> output (Phase <4/5>).

Install it with:
  npx skills add https://github.com/sunqb/ccsdk --skill <skill-name>

You can:
  [1] Install it now, then restart the session and re-run
  [2] Skip <PDF/PPTX> generation and continue with markdown only
  [3] Run Phases 1–3 now, then install the skill later and run Phase <4/5> separately
```

If the user chooses option [2] or [3], set the corresponding flag to false and continue.

---

### Phase 1 — Data Collection

**Cache check first**: Before running the script, check whether a fresh cache exists.

```bash
OWNER_REPO="owner-reponame"   # e.g. vllm-project-llm-compressor
META="./cache/$OWNER_REPO/meta.json"
```

- If `meta.json` exists and is < 7 days old → the script will use cached API responses
  (shows `[CACHE HIT]`). Still run the script to get any refreshed sections and to
  confirm `CACHE_DIR` and `LOCAL_REPO_PATH`.
- If `meta.json` missing or stale → full data fetch (all `[CACHE MISS]`).
- Use `--force` to bypass all caches and re-fetch everything.

**Run the script**:

```bash
ANALYZER=$(find ~/.claude -name analyze_repo.py 2>/dev/null | head -1)

# Normal run (uses cache if fresh):
python "$ANALYZER" <github-url-or-owner/repo>

# Specify custom cache location:
python "$ANALYZER" --cache-dir ./cache <github-url>

# Force full re-fetch (ignore all caches):
python "$ANALYZER" --force <github-url>

# Change cache max age (default: 7 days):
python "$ANALYZER" --max-age 14 <github-url>
```

> **First run**: install dependencies once with `pip install -r scripts/requirements.txt`
> (requires `requests` and `rich`)

> **Note**: The script saves the repo clone to `./cache/{owner}-{repo}/repo/` — it persists
> between runs. Do NOT delete this directory manually unless you want a full re-clone.

**Script output ends with**:

```text
CACHE_DIR=./cache/{owner}-{reponame}
RAW_DIR=./cache/{owner}-{reponame}/raw
LOCAL_REPO_PATH=./cache/{owner}-{reponame}/repo
FETCHED_AT=2026-03-10T12:00:00Z
```

**Cache directory layout** (created automatically by the script):

```text
./cache/{owner}-{reponame}/
├── meta.json                    ← fetch metadata + timestamps
├── repo/                        ← persistent git clone (updated each run)
├── raw/                         ← raw API responses (per-source cache files)
│   ├── github_repo.json
│   ├── github_org.json
│   ├── github_contributors.json
│   ├── github_releases.json
│   ├── github_prs_open.json
│   ├── github_issues_closed.json
│   ├── github_dependents.txt
│   ├── pypi_stats.txt
│   ├── npm_stats.txt
│   ├── clone_meta.txt
│   ├── git_stats.txt
│   ├── contributor_orgs.txt
│   ├── pr_merge_times.json
│   ├── good_first_issues.json
│   ├── docker_stats.txt
│   ├── homebrew_stats.txt
│   ├── conda_stats.txt
│   ├── depsdev.txt
│   ├── stackoverflow.txt
│   ├── hackernews.json
│   ├── devto.json
│   ├── openssf.txt
│   ├── osv.txt
│   ├── nvd.txt
│   ├── cncf.txt
│   └── asf.txt
└── analysis/                    ← Claude's analysis notes (Phase 2 output)
    ├── background.md
    ├── adoption.md
    ├── competitive.md
    ├── momentum.md
    ├── risk.md
    ├── technical.md
    └── investment.md
```

**If the script fails**:
- **Auth/rate-limit** → add `GITHUB_TOKEN` to `~/.config/github-analyzer/config`; re-run.
- **Clone failure** → verify repo is public; try `gh repo view <owner>/<repo>`.
- **Single section failure** → mark that field `N/A (unavailable — {date})`; continue.
- **Debug**: `python "$ANALYZER" <url> --force 2>&1 | head -100`
- **Missing deps**: `pip install -r scripts/requirements.txt`

**What the script collects** (13 sections, all cached individually):

| Section | Data source | Cache file |
|---------|-------------|-----------|
| 1 | GitHub repo metadata | `raw/github_repo.json` |
| 2 | Org/owner info + funding | `raw/github_org.json` |
| 3 | Contributors + bus factor | `raw/github_contributors.json` |
| 4 | Releases, PRs, issues | `raw/github_releases.json` etc. |
| 5 | PyPI, npm downloads | `raw/pypi_stats.txt`, `raw/npm_stats.txt` |
| 6 | Local files (README, CHANGELOG, CI) | `repo/` (persistent clone) |
| 7 | Git stats | `raw/git_stats.txt` |
| 8 | Community signals (org diversity, PR times, GFI) | `raw/contributor_orgs.txt` etc. |
| 9 | Docker Hub, Homebrew, conda, deps.dev | `raw/docker_stats.txt` etc. |
| 10 | Stack Overflow, HN, Dev.to, Google Trends | `raw/stackoverflow.txt` etc. |
| 11 | OpenSSF Scorecard, OSV, NVD CVEs | `raw/openssf.txt` etc. |
| 12 | CNCF, Apache Foundation status | `raw/cncf.txt`, `raw/asf.txt` |
| 13 | Crunchbase, YouTube (manual/optional) | (stdout only — manual steps) |

#### 📄 Invoke `read-arxiv-paper` for referenced papers

When the script output lists arXiv paper links (Section 6b):

1. Check if a summary already exists in `./knowledge/summary_*.md` — read it if so.
2. If not, invoke the `read-arxiv-paper` skill with the arXiv URL.
3. Reference the summary when writing `technical.md §Research & Papers`.

Only invoke for arXiv links. For ACL/NeurIPS/other proceedings, include URL+title only.

---

### Phase 2 — Analysis (with analysis cache)

**Goal**: Transform raw collected data into structured analysis notes, one per report section.
Analysis notes are saved to `./cache/{owner}-{repo}/analysis/` so re-runs skip completed sections.

**For each of the 7 analysis sections** (background → adoption → competitive → momentum →
risk → technical → investment), follow this decision tree:

```
1. Does ./cache/{owner}-{repo}/analysis/{section}.md exist?
   │
   ├─ YES → Is the raw data that feeds this section newer than the analysis note?
   │         │
   │         ├─ NO  (analysis is current) → READ from cache, skip re-analysis ✓
   │         └─ YES (raw data was refreshed) → RE-ANALYZE and overwrite cache
   │
   └─ NO → ANALYZE from raw data and SAVE to analysis cache
```

**How to check if raw data is newer**: Compare the mtime of the relevant raw cache files
against the analysis note file. If `meta.json`'s `fetched_at` timestamp is after the
analysis note's modification time, re-analyze. Otherwise, use the cached note.

**Practical check** (run this before each section):

```bash
ANALYSIS_NOTE="./cache/{owner}-{repo}/analysis/{section}.md"
META="./cache/{owner}-{repo}/meta.json"

if [ -f "$ANALYSIS_NOTE" ] && [ "$ANALYSIS_NOTE" -nt "$META" ]; then
  echo "Analysis cache is current — reading from cache"
else
  echo "Need to (re-)analyze this section"
fi
```

**Analysis note format** — save as markdown to `./cache/{owner}-{repo}/analysis/{section}.md`:

```markdown
# Analysis Note: {Section Name} — {owner}/{repo}
> Generated: {YYYY-MM-DD} | Data from: {fetched_at from meta.json}

## Key Facts
[Bullet points of concrete facts extracted from raw data]

## Signals
[What the data signals — positive/negative/neutral]

## Assessment
[1-3 sentence synthesis: what does this mean for the decision-maker?]
```

**Section → raw files mapping** (which raw files to read for each section):

| Section | Raw files to read |
|---------|------------------|
| `background.md` | `github_repo.json`, `github_org.json` + local `FUNDING.yml`, `LICENSE`, `CODEOWNERS` |
| `adoption.md` | `github_dependents.txt`, `pypi_stats.txt`, `npm_stats.txt`, `docker_stats.txt` + local `ADOPTERS.md` |
| `competitive.md` | `github_repo.json` (topics, description), `stackoverflow.json`, `hackernews.json` + README competitive section |
| `momentum.md` | `github_releases.json`, `github_prs_open.json`, `github_contributors.json`, `hackernews.json`, `devto.json` |
| `risk.md` | `github_contributors.json`, `openssf.txt`, `osv.txt`, `nvd.txt` + local `CHANGELOG.md` |
| `technical.md` | `github_repo.json` + local `README.md`, architecture files, `examples/`, `CITATION.cff` |
| `investment.md` | `contributor_orgs.txt`, `pr_merge_times.json`, `good_first_issues.json` + local `CONTRIBUTING.md`, `GOVERNANCE.md`, `CODEOWNERS` |

**Read raw files using the Read tool** — paths are `$RAW_DIR/{filename}` (from script output).
For local repo files, use `$LOCAL_REPO_PATH/{filename}`.

**Do NOT re-run the script** to read data. Use the cached raw files directly.

### Phase 2 — Mode selection

Decide which sections to analyze based on user intent:

| User asks | Analyze sections |
|-----------|----------------|
| "Analyze X" / "full report on X" | All 7 sections (default) |
| "Should we adopt X?" / "evaluate X" | background + adoption + risk |
| "Who backs X?" / "is it corporate?" | background |
| "How widely used is X?" | adoption |
| "X vs Y" / "alternatives to X" | competitive |
| "Is X growing?" / "still active?" | momentum |
| "Risk of using X?" / "is it maintained?" | risk |
| "How does X work?" / "architecture?" | technical |
| "Should we contribute to X?" / "invest?" | investment + background |
| "How open is X's community?" | investment |
| "Trending repos" / "what's popular" | Chat only — no files written |

Read `references/analysis_guide.md` for detailed guidance on each section's content.

**Default behavior**: If user intent is unspecified, always produce the **full report** (all 7
analysis sections + index.md). Every section contributes to a complete decision-maker picture.

#### Compare mode (X vs Y)

1. Run Phase 1 for each repo separately (each gets its own cache directory).
2. Run Phase 2 for both, ensuring competitive.md cross-references each other.
3. Run Phase 3 for both.
4. Output a **chat-only** side-by-side table (Stars · Downloads · License · Backing ·
   Key strength · Key weakness) and "pick A when … / pick B when …" recommendation.

#### Trending repos mode

Skip Phases 1-3 entirely. Use `gh` CLI or GitHub search API directly:

```bash
gh api "search/repositories?q=created:>$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)&sort=stars&order=desc&per_page=10" \
  | jq '[.items[] | {rank: (. | input_line_number), name: .full_name, stars: .stargazers_count, description: .description, language: .language}]'
```

Output as ranked table in chat. **No files are written.**

---

### Phase 3 — Report Generation

**Goal**: Produce the final structured report files from analysis notes.
Phase 3 is idempotent — if a report file already exists and the analysis note hasn't changed,
skip that file (or prompt the user if they want to regenerate it).

**Re-run behavior**:

```
For each en/{section}.md:
  - If file exists AND analysis note hasn't changed → SKIP (already current)
  - If file missing OR analysis note is newer → WRITE (generate/regenerate)
```

#### Phase 3a — Write English report (`en/`)

Write all 8 files to `./reports/{owner}-{reponame}/en/`. Order: **7 dimension files first**
(background → adoption → competitive → momentum → risk → technical → investment), then `index.md` last.

Use the **Write** tool for every file. Read the analysis note from
`./cache/{owner}-{repo}/analysis/{section}.md` as the primary source for content.

`index.md` structure:

```markdown
# {Project Name} — Analysis Report
> **Source**: {github-url} | **Analyzed**: {YYYY-MM-DD}

## Decision Brief
[Full Decision Brief — see analysis_guide.md §Decision Brief]

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

#### Phase 3b — Translate to Chinese (`zh/`) via `translate` skill

After all 8 English files are written, invoke the `translate` skill for each file.
Check if the `zh/` file already exists and is current before translating:

```
For each en/{section}.md:
  - If zh/{section}.md exists AND is newer than en/{section}.md → SKIP
  - Otherwise → translate and write
```

**For each file** (background → adoption → competitive → momentum → risk → technical →
investment → index):

1. Read the English file from `en/<file>.md`.
2. Invoke `translate` skill: `target_language=zh`, `translation_style=professional`,
   `retain_format=true`, `auto_humanize=true`.
3. Write result to `zh/<file>.md`.

Translation rules:
- Prose, headings, table cells → Chinese
- Technical terms, algorithm names, project/company names, code blocks, URLs, CLI commands → keep English

#### Phase 3c — Write bilingual `introduction.md`

After both `en/` and `zh/` are complete, write the entry-point file:

```text
./reports/{owner}-{reponame}/introduction.md
```

```markdown
# {Project Name} — Analysis Report

> {one-sentence verdict in English from index.md Decision Brief}

📖 [Read in English](./en/index.md)

---

# {Project Name} — 分析报告

> {上面英文摘要的中文翻译，一句话}

📖 [阅读中文版](./zh/index.md)
```

#### After Phase 3 completes

Tell the user:
```text
Markdown 报告已生成：
  入口：  ./reports/{owner}-{reponame}/introduction.md
  英文版：./reports/{owner}-{reponame}/en/index.md
  中文版：./reports/{owner}-{reponame}/zh/index.md
  缓存：  ./cache/{owner}-{reponame}/
```

Then proceed to Phase 4 and/or Phase 5 if the user requested PDF/PPTX.

Do NOT repeat the full report in chat. A brief 3-5 sentence summary is sufficient.

---

### Phase 4 — PDF Generation (optional, independent)

**Prerequisite**: `WANT_PDF=true` AND `document-skills:pdf` skill is installed.
**Skip entirely** if `WANT_PDF=false`.

**Re-run behavior**: Phase 4 is independent — it can be re-run after a failure without
re-running Phases 1–3. If `report_zh.pdf` already exists and none of the `zh/*.md` files
are newer than the PDF, ask the user whether to regenerate.

**Source files** (in order):

```text
./reports/{owner}-{reponame}/zh/index.md
./reports/{owner}-{reponame}/zh/background.md
./reports/{owner}-{reponame}/zh/adoption.md
./reports/{owner}-{reponame}/zh/competitive.md
./reports/{owner}-{reponame}/zh/momentum.md
./reports/{owner}-{reponame}/zh/risk.md
./reports/{owner}-{reponame}/zh/technical.md
./reports/{owner}-{reponame}/zh/investment.md
```

**Output file**: `./reports/{owner}-{reponame}/report_zh.pdf`

**Execution**:

1. Verify all 8 source `zh/*.md` files exist. If any are missing, tell the user to run
   Phase 3 first.
2. Invoke the `document-skills:pdf` skill with the ordered list of source files and the output path.
3. On success, confirm to the user:
   ```text
   ✅ PDF 已生成：./reports/{owner}-{reponame}/report_zh.pdf
   ```
4. On failure, tell the user:
   ```text
   ❌ PDF 生成失败：<error message>

   排查建议：
   - 确认 document-skills:pdf skill 已正确安装
   - 检查源文件是否存在：./reports/{owner}-{reponame}/zh/
   - 重新运行 Phase 4：直接告诉我"重新生成 PDF"即可，无需重新运行整个分析
   ```

---

### Phase 5 — PPTX Generation (optional, independent)

**Prerequisite**: `WANT_PPTX=true` AND `document-skills:pptx` skill is installed.
**Skip entirely** if `WANT_PPTX=false`.

**Re-run behavior**: Phase 5 is independent — it can be re-run after a failure without
re-running Phases 1–4. If `slides_zh.pptx` already exists and none of the `zh/*.md` files
are newer than the PPTX, ask the user whether to regenerate.

**Source files** and **slide mapping**:

| Source file | Slide group | Notes |
|-------------|-------------|-------|
| `zh/index.md` | Cover + Decision Brief | Decision Brief → 2–3 summary slides |
| `zh/background.md` | Organizational Background | 1–2 slides |
| `zh/adoption.md` | Real-World Adoption | 1–2 slides |
| `zh/competitive.md` | Competitive Landscape | 1–2 slides (keep comparison table) |
| `zh/momentum.md` | Momentum & Trajectory | 1 slide |
| `zh/risk.md` | Risk Assessment | 1–2 slides |
| `zh/technical.md` | Technical Details | 2–3 slides |
| `zh/investment.md` | Community Investment | 2–3 slides (keep cost/return tables) |

**Output file**: `./reports/{owner}-{reponame}/slides_zh.pptx`

**Execution**:

1. Verify all 8 source `zh/*.md` files exist. If any are missing, tell the user to run
   Phase 3 first.
2. Invoke the `document-skills:pptx` skill with the ordered source files, slide mapping hints,
   and the output path.
3. On success, confirm to the user:
   ```text
   ✅ PPT 已生成：./reports/{owner}-{reponame}/slides_zh.pptx
   ```
4. On failure, tell the user:
   ```text
   ❌ PPT 生成失败：<error message>

   排查建议：
   - 确认 document-skills:pptx skill 已正确安装
   - 检查源文件是否存在：./reports/{owner}-{reponame}/zh/
   - 重新运行 Phase 5：直接告诉我"重新生成 PPT"即可，无需重新运行整个分析
   ```

---

#### After all requested phases complete

Tell the user a final summary of everything generated:

```text
分析报告已全部生成：

  📄 Markdown 报告
     入口：      ./reports/{owner}-{reponame}/introduction.md
     英文版：    ./reports/{owner}-{reponame}/en/index.md
     中文版：    ./reports/{owner}-{reponame}/zh/index.md

  📑 PDF 报告    ./reports/{owner}-{reponame}/report_zh.pdf       ✅ / ⏭️ 跳过
  📊 PPT 幻灯片  ./reports/{owner}-{reponame}/slides_zh.pptx      ✅ / ⏭️ 跳过

  缓存目录：      ./cache/{owner}-{reponame}/
```

If a phase failed, show `❌ 失败` and remind the user they can retry that phase alone.

---

---

## Tips

### Cache management

- **Normal re-run** (e.g., checking for updates after a week): just run the script again.
  Sections with fresh cache show `[CACHE HIT Nd]` and skip the API call. Stale or new
  sections show `[CACHE MISS]` and re-fetch.
- **Force full re-fetch**: `python "$ANALYZER" --force <url>` bypasses all caches.
- **Change cache age**: `python "$ANALYZER" --max-age 14 <url>` extends the freshness window
  to 14 days (useful for stable projects that rarely change).
- **Custom cache location**: `python "$ANALYZER" --cache-dir /path/to/cache <url>` — useful
  for teams sharing a mounted cache directory.
- **Clear cache for one project**: `rm -rf ./cache/{owner}-{reponame}/`
- **Clear analysis notes only** (re-analyze with existing raw data):
  `rm -rf ./cache/{owner}-{reponame}/analysis/`
- **Partial report update**: Delete only the specific en/ file you want to regenerate, then
  run Phase 3. Claude will regenerate only that file.

### Authentication

- **GitHub Token (recommended)**: Raises rate limit from 60 to 5,000 req/hr. Token priority:
  1. `GITHUB_TOKEN` environment variable
  2. `~/.config/github-analyzer/config` (primary config file)
  3. Local `./config` file next to the script
  4. `gh` CLI (if authenticated)
  5. Unauthenticated (60 req/hr — warns user)

  **Setup**:
  ```bash
  mkdir -p ~/.config/github-analyzer
  # create config file:
  # GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
  # LIBRARIES_IO_KEY=xxx   # optional — https://libraries.io/api
  # YOUTUBE_API_KEY=xxx    # optional — for automated tutorial stats
  chmod 600 ~/.config/github-analyzer/config
  ```
- **No token / no gh CLI**: Falls back to unauthenticated requests. Package registry APIs
  (PyPI, npm, Docker Hub, etc.) require no authentication regardless.

### Analysis quality

- **Stars are vanity, downloads are reality**: PyPI/npm numbers beat star counts for
  real adoption assessment. A project with 500 stars and 2M weekly downloads wins.
- **Org = sustainability**: The most predictive factor for longevity is who backs the
  project. FAANG / foundation-backed > VC-startup-backed > individual maintainer.
- **Changelog tells the truth**: The CHANGELOG reveals breaking-change frequency better
  than any other single file.
- **Bus factor matters**: If the top 1-2 contributors own >70% of commits, flag it.
- **Google Trends is manual**: The script outputs a direct Trends URL. Always check it —
  it shows whether mindshare is growing or has peaked, which star counts cannot reveal.
- **OpenSSF Scorecard**: If the API returns no data, run locally:
  `scorecard --repo=github.com/{owner}/{repo}`
- **Community signals complement GitHub data**: Stack Overflow unanswered rate and HN
  sentiment reveal adoption friction that GitHub stars hide.
