# GitHub Project Analysis Guide

> **Guide version**: 1.1 · **Last updated**: 2026-02-20
> Download benchmarks, bus-factor ratios, and calibration thresholds reflect the ecosystem
> as of early 2026. Review annually or whenever reports yield systematically skewed verdicts.

## Table of Contents
1. [Decision Brief](#decision-brief)
2. [Organizational Background](#org-background)
3. [Real-World Adoption](#adoption)
4. [Competitive Landscape](#competitive)
5. [Momentum & Trajectory](#momentum)
6. [Risk Assessment](#risk)
7. [Technical Deep-Dive](#technical)
8. [Trending Repos](#trending)
9. [Handling Missing Data](#missing-data)
10. [Analysis Depth by Mode](#depth-by-mode)

---

## Decision Brief <a name="decision-brief"></a>

> **Written to**: `index.md` (top section)

The required output format for any decision-maker analysis. Always produce this section first,
even when doing a full deep-dive. Keep it scannable — maximum 1 page.

```markdown
## Decision Brief: <Project Name>

**Verdict**: Adopt ✅ | Evaluate ⚠️ | Avoid ❌

**One-line summary**: [What it does and who it's for]

| Signal | Status |
|--------|--------|
| Organizational backing | [Individual / Startup / FAANG / Foundation] |
| Real-world adoption | [Niche / Growing / Mainstream] |
| Maintenance health | [Active / Stable / Declining / Abandoned] |
| License risk | [Low / Medium / High] — [license name] |
| Bus factor | [Low (<3 key devs) / Medium / High] |
| Breaking-change risk | [Low / Medium / High] |

**Best suited for**: [specific use cases where this project excels]
**Not suited for**: [anti-patterns or scenarios to avoid]
**Key risk**: [the single most important concern]
**Primary alternative**: [best competing option with one-line rationale]
**Recommended next step**: [POC / wait for vX.Y / adopt now / keep watching]
```

### Verdict criteria

| Verdict | Signals |
|---------|---------|
| **Adopt ✅** | Backed by org or foundation · mainstream adoption · active maintenance · permissive license · low bus factor |
| **Evaluate ⚠️** | Some concerns present but manageable · promising but early · narrow adoption · non-trivial license |
| **Avoid ❌** | Abandoned / archived · copyleft license conflicts · critical bus factor risk · major security history · losing to competitor |

---

## Organizational Background <a name="org-background"></a>

> **Written to**: `background.md`

**Goal**: Understand who controls this project and whether they'll still be around in 3 years.

### What to determine

**1. Backing type** (check GitHub org page, README badges, NOTICE, FUNDING.yml):

| Type | Examples | Sustainability |
|------|---------|---------------|
| FAANG / Big Tech | Google, Meta, Microsoft, AWS repos | High — internal usage drives maintenance |
| Open Source Foundation | CNCF, Apache, Linux Foundation | High — governance beyond any single company |
| VC-backed startup | Vercel, HashiCorp, Databricks OSS | Medium — depends on runway and commercialization |
| Community / Individual | Personal GitHub, no org | Low — vulnerable to burnout, life changes |
| Academic | University labs, research groups | Low-Medium — often prototype-quality |

**2. Governance model**:
- **BDFL**: one person makes all decisions → bus factor 1 at the top level
- **Core team / TSC**: committee → more resilient
- **Foundation steering committee**: highest resilience (e.g., Kubernetes SIG structure)
- Check: `GOVERNANCE.md`, `MAINTAINERS`, `.github/CODEOWNERS`

**3. Commercial relationship**:
- Is there a paid/enterprise version? (open-core model)
- Is the OSS version the lead product or a marketing vehicle?
- Who are the primary sponsors? (check `FUNDING.yml`, README sponsor badges, Open Collective)

**4. Key signals to surface**:
- Name of backing company/org and their primary business
- Link between OSS project and commercial offering
- Whether the project predates or postdates the company's founding
- Any announced acquisition, pivot, or shutdown risk

### Output template

```markdown
# Organizational Background — {Project Name}

> **Source**: {github-url} | **Analyzed**: {YYYY-MM-DD}

## Backing Entity

[2–3 paragraphs: who owns the project, lineage/acquisition/founding history,
relationship between the OSS project and any commercial entity.]

## Governance Model

| Mechanism | Detail |
|-----------|--------|
| Governance type | [BDFL / Core team / Foundation steering committee] |
| Key governance files | [e.g., GOVERNANCE.md, MAINTAINERS, .github/CODEOWNERS — what each says] |
| Named maintainers | [count + affiliation] |
| Contribution process | [PR workflow, CLA requirement, merge automation] |

## Commercial Relationship

- **Business model**: [open-core / fully open-source / marketing vehicle / internal tool]
- **Paid/enterprise tier**: [yes — link | no]
- **Primary sponsors/funders**: [FUNDING.yml entries / Open Collective / none — commercially funded]
- **Incentive alignment**: [why the backing org continues to invest]

## Sustainability Assessment

| Signal | Assessment |
|--------|------------|
| Backing type | [FAANG / Foundation / VC-backed startup / Individual] |
| Financial stability | [High / Medium / Low — rationale] |
| Acquisition / pivot / shutdown risk | [Low / Medium / High — rationale] |
| Community independence | [Would the project survive if the primary backer stepped away?] |

## Summary

[1 paragraph synthesis of organizational health and long-term viability outlook]
```

---

## Real-World Adoption <a name="adoption"></a>

> **Written to**: `adoption.md`

**Goal**: Distinguish projects people *star* from projects people *run in production*.

### Quantitative signals

**Package download stats** (from script output):
- PyPI: weekly downloads via `https://pypistats.org/api/packages/{name}/recent`
- npm: weekly downloads via `https://api.npmjs.org/downloads/point/last-week/{name}`
- crates.io: `https://crates.io/api/v1/crates/{name}`
- Docker Hub: `https://hub.docker.com/v2/repositories/{org}/{name}/`

**Benchmark downloads** (rough calibration — PyPI/npm scale):

| Weekly downloads | Adoption level |
|-----------------|----------------|
| < 10K | Niche / experimental |
| 10K – 500K | Growing, real user base |
| 500K – 5M | Mainstream in its niche |
| > 5M | Category standard (e.g., React, requests) |

**Ecosystem-specific calibration** (scale varies significantly across registries):

| Ecosystem | Niche threshold | Category-standard threshold | Download API |
|-----------|----------------|-----------------------------|-------------|
| PyPI (Python) | < 10K/week | > 5M/week | pypistats.org/api |
| npm (JS/TS) | < 50K/week | > 10M/week | api.npmjs.org/downloads |
| crates.io (Rust) | < 5K/week | > 500K/week | crates.io/api/v1/crates |
| RubyGems | < 5K/week | > 1M/week | rubygems.org/api |
| Docker Hub pulls | < 1M total | > 100M total | hub.docker.com/v2/repositories |
| Maven Central (Java) | No reliable download API — use GitHub dependents instead | — | — |
| Go modules | No central download stats — use GitHub stars + dependents | — | — |

For Go, Java, and other ecosystems without download APIs, weight **GitHub dependents count**
and **named adopters** more heavily than download figures.

**GitHub dependents count** (from script):
- Number of public repos that import this package → direct proxy for developer adoption
- > 1,000 dependents = well-established in the ecosystem

### Qualitative signals

**Named adopters** (check `ADOPTERS.md`, `USERS.md`, README logos section, official blog):
- Are they recognizable companies (Fortune 500, well-known tech firms)?
- Are adopters in the same domain as the potential user?
- How many are listed? (10 = early, 100+ = mainstream)

**Cloud provider support**:
- Native managed service (e.g., AWS MSK for Kafka) → de-facto standard
- First-party integration in major clouds → strong adoption signal
- No cloud support → niche or very new

**Ecosystem size**:
- Number of third-party plugins / extensions / integrations
- Active marketplace (npm ecosystem, VS Code extensions, Helm charts, etc.)
- Industry standard compliance (OpenTelemetry, ONNX, gRPC) — reduces lock-in

**Community channels**:
- Stack Overflow: search `[project-name]` tag → question count and recency
- Reddit: subreddit existence and activity
- Discord / Slack: member count if publicly listed

### Output template

```markdown
# Real-World Adoption — {Project Name}

> **Source**: {github-url} | **Analyzed**: {YYYY-MM-DD}

## Download Statistics

| Metric | Value | Interpretation |
|--------|-------|---------------|
| [PyPI/npm/crates.io] weekly downloads | ... | [Niche / Growing / Mainstream / Category standard] |
| [PyPI/npm] monthly downloads | ... | [annualized estimate] |
| GitHub stars | ... | [downloads-to-stars ratio context] |
| GitHub forks | ... | [fork rate interpretation] |
| GitHub dependents | ... | [public repos importing this package] |

[1 paragraph contextualizing the numbers relative to similar tools in the same niche.]

## Named Adopters

[List known production users from ADOPTERS.md / USERS.md / README logos / blog posts.
If none found, state explicitly and list indirect signals (pre-compressed model checkpoints,
conference talks, case studies).]

## Ecosystem Integration

| Integration | Status | Significance |
|-------------|--------|-------------|
| [Tool/platform] | [Native / Plugin / Partial / None] | [why it matters] |

## Community Channels

| Channel | Detail |
|---------|--------|
| [Slack/Discord] | [member count or activity level] |
| GitHub Issues | [open count; avg. response time] |
| Stack Overflow tag | [`[tag-name]` — N questions, last activity] |

## Cloud & Platform Support

[Managed services, first-party cloud integrations, or "none — library only".]

## Adoption Assessment

| Dimension | Signal |
|-----------|--------|
| Download volume | [Niche / Growing / Mainstream / Category standard] |
| Ecosystem fit | [Tight / Good / Loose] |
| Named enterprise users | [None found / Few / Many] |
| Community activity | [High / Medium / Low] |
| Adoption stage | [Experimental / Growing / Mainstream / Declining] |

**Bottom line**: [1–2 sentence synthesis]
```

---

## Competitive Landscape <a name="competitive"></a>

> **Written to**: `competitive.md`

**Goal**: Help the decision-maker understand the market position and make a relative choice,
not just an absolute one.

### How to identify competitors

1. Check the project's own README — mature projects often list alternatives honestly
2. Look at GitHub topics — other repos with the same tags
3. Ask: "What would teams use if this project didn't exist?"

### Comparison table format

Always produce a side-by-side table:

```markdown
| Dimension | <This Project> | <Alt 1> | <Alt 2> |
|-----------|---------------|---------|---------|
| Stars | Xk | Yk | Zk |
| Weekly downloads | X | Y | Z |
| License | MIT | Apache-2.0 | GPL-3.0 |
| Backed by | Company A | Foundation B | Individual |
| Primary language | Python | Go | Rust |
| Last release | YYYY-MM | YYYY-MM | YYYY-MM |
| Key strength | ... | ... | ... |
| Key weakness | ... | ... | ... |
```

### Market positioning

Classify the project's position:

| Position | Description |
|----------|-------------|
| **Incumbent** | Dominant player, switching cost is high, others build on top of it |
| **Challenger** | Growing fast, targeting the incumbent's weaknesses |
| **Niche specialist** | Narrow use case, best-in-class for that case |
| **Early mover** | First to solve a new problem, but market not yet formed |
| **Legacy** | Was once dominant, now losing ground to newer alternatives |

### When to pick this over alternatives

List 2-3 specific scenarios where this project wins the comparison, and 2-3 where it loses.

---

## Momentum & Trajectory <a name="momentum"></a>

> **Written to**: `momentum.md`

**Goal**: Understand whether the project is accelerating, plateauing, or declining — because
a project's future matters as much as its present.

### Growth signals

**Star velocity** (from script: stars today vs created_at):
- Calculate rough star/month rate: `total_stars / months_since_creation`
- High acceleration = recent viral growth (often after a blog post or conference talk)
- Flat = mature and stable (not bad, but not growing community)
- Declining forks-to-stars ratio = stalling

**Release cadence**:
- Regular minor releases (monthly/quarterly) = actively developed
- Only patch releases = maintenance mode
- No releases in 12+ months = potentially abandoned (verify by checking commit history)

**Issue & PR velocity**:
- Are issues getting responses within days or weeks?
- Is the PR backlog growing or shrinking?
- Time to merge for community PRs: < 2 weeks = healthy, > 2 months = bottleneck

**Contributor growth**:
- Is the contributor count growing each year?
- Are new contributors becoming regulars, or is it a one-time spike?

### Media & community signals

- **HackerNews**: search `site:news.ycombinator.com <project-name>` — number of front-page hits
- **Major conference talks**: keynotes at KubeCon, PyCon, React Conf, etc. = mainstream signal
- **Developer survey presence**: State of JS, JetBrains Developer Survey, Stack Overflow survey
- **Twitter/X buzz**: trending mentions, retweets by influential developers

### Life-cycle stage

Synthesize all signals into one of:

| Stage | Signals |
|-------|---------|
| **Early Growth** | Stars < 2K, few named adopters, <2 years old, frequent breaking changes |
| **Rapid Growth** | Stars doubling yearly, new contributors joining, conference buzz |
| **Mature/Stable** | Large user base, slow star growth, few breaking changes, predictable releases |
| **Maintenance Mode** | No new features, only bug fixes, team shrinking |
| **Declining** | Issues unanswered, PRs stalling, maintainers stepping back publicly |

### Output template

```markdown
# Momentum & Trajectory — {Project Name}

> **Source**: {github-url} | **Analyzed**: {YYYY-MM-DD}

## Life-Cycle Stage: **[Early Growth / Rapid Growth / Mature/Stable / Maintenance Mode / Declining]**

## Star & Fork Velocity

| Metric | Value | Rate |
|--------|-------|------|
| Total stars | ... | ~N stars/month since creation |
| Total forks | ... | N% fork-to-star ratio |
| Created | YYYY-MM-DD | ~N months/years old |
| Last pushed | YYYY-MM-DD | [today / N days ago / N months ago] |

[1 paragraph interpreting velocity in context of the project's niche and life-cycle stage.]

## Release Cadence

| Release | Date | Time since previous |
|---------|------|-------------------|
| vX.Y.Z | YYYY-MM-DD | N days |
| ... | ... | ... |

**Pattern**: [Active development / Maintenance mode / Sporadic / Abandoned — with evidence]

## Issue & PR Health

| Signal | Value | Assessment |
|--------|-------|------------|
| Open PRs | N | [Healthy / Backlog forming / Stalled] |
| Oldest open PR | YYYY-MM-DD (~N months) | [context] |
| Issue response time | [hours / days / weeks] | [Excellent / Adequate / Poor] |
| Open issues | N | [Normal / Accumulating without response] |

## Feature Velocity

[Recent release highlights — 3–5 significant additions from the last 1–2 versions.
If only bug fixes, state "maintenance mode" explicitly.]

## Contributor Trends

| Metric | Value |
|--------|-------|
| Total contributors | N |
| New contributors (last 6 months) | N |
| Top contributor share | N% of commits |

## Media & Community Signals

| Signal | Detail |
|--------|--------|
| [HackerNews / conference / developer survey] | [front-page hits / keynote / listed] |

## Trajectory Outlook

[1 paragraph: is the project accelerating, plateauing, or declining? What structural
factors drive the outlook? What risks could change the trajectory?]
```

---

## Risk Assessment <a name="risk"></a>

> **Written to**: `risk.md`

**Goal**: Surface the risks a team takes on when adopting this project.

### Bus Factor

**Definition**: How many key people need to leave before the project stalls?

From script output (contributor list):
1. Calculate top-3 contributors' share of total contributions
2. Check if they're from the same organization (correlated risk)

| Bus factor signal | Risk |
|------------------|------|
| Top 1 contributor > 60% of commits | 🔴 Critical — single point of failure |
| Top 3 contributors > 80% of commits | 🟠 High |
| Top 3 contributors < 50% of commits | 🟢 Healthy |
| Contributors from 3+ different orgs | 🟢 Resilient |

**Mitigation check**: Is there a succession plan? Foundation governance? Documented architecture?

### Security Posture

- **SECURITY.md present**: responsible disclosure process exists
- **CVE history**: search `site:nvd.nist.gov <project-name>` or GitHub Security tab
- **Dependency audit**: are major dependencies actively maintained?
- **Security audit**: has the project undergone a third-party audit? (often mentioned in README)
- **Supply chain**: is the project itself used in CI pipelines of others? (higher-value target)

### Breaking Change Risk

From CHANGELOG / RELEASES analysis:
- Frequency of `BREAKING CHANGE` markers
- Semver discipline: does v1.x → v2.x actually mean breaking changes?
- Migration guide quality: are upgrade paths documented?

| Pattern | Risk |
|---------|------|
| SemVer respected, migration guides provided | 🟢 Low |
| Occasional breaking changes, documented | 🟡 Medium |
| Frequent breaking changes with poor docs | 🔴 High |
| No versioning discipline / pre-v1 forever | 🔴 High |

### Abandonment Signals

Check these explicitly:

- [ ] Last commit older than 6 months?
- [ ] Open issues with no maintainer response older than 3 months?
- [ ] PR backlog > 50 unreviewed PRs?
- [ ] Maintainer publicly announced stepping back or seeking new owners?
- [ ] Repo explicitly archived?
- [ ] No release in 12+ months despite open bugs?

### License Risk

| Scenario | Risk |
|----------|------|
| MIT / BSD / Apache-2.0, internal use | 🟢 None |
| MIT / BSD / Apache-2.0, SaaS product | 🟢 None |
| GPL-2.0/3.0, linking in proprietary code | 🔴 Copyleft contamination |
| AGPL, running as network service | 🔴 Must open-source your service |
| SSPL (MongoDB, Elasticsearch old) | 🔴 Blocks cloud SaaS use |
| Custom license | ⚠️ Must read carefully — engage legal |
| No license | 🔴 Cannot legally use (default copyright) |

---

## Technical Deep-Dive <a name="technical"></a>

> **Written to**: `technical.md`

Provides the technical context a decision-maker needs to evaluate what they're actually
adopting: what the project does under the hood, what ideas it is built on, where to go
deeper, and what a first experience with it looks like.

---

### 1. Core Concepts & Mental Model

**Goal**: Give the decision-maker the mental model to "get" the project in 5 minutes.

- **Core abstraction**: What is the primary concept the project introduces?
  (e.g., "middleware", "modifier", "recipe", "plugin", "stream", "actor")
- **One-sentence workflow**: input → transform → output in plain language
- **Key terminology**: 5–8 domain-specific terms, each with a one-line definition

  ```markdown
  | Term | Definition |
  |------|-----------|
  | Recipe | A declarative config specifying which compression algorithms to apply |
  | Modifier | A pluggable algorithm (e.g. GPTQ, SmoothQuant) implementing a compression step |
  | ...  | ... |
  ```

- **Mental model paragraph**: One paragraph explaining *how to think about* this project —
  not what it does, but the mental frame needed to use it effectively.

Derive from: README overview / "How it works" section, `docs/concepts/`, introductory blog posts,
any "design philosophy" or "motivation" section.

---

### 2. Architecture Overview

**Goal**: Show how the system is structured so the decision-maker understands what they're committing to.

**Diagram**: Check script output for architecture images in the repo. If found, note the path
and describe what it shows:
- Look for: `ARCHITECTURE.md`, `docs/architecture*`, images named `*arch*`, `*overview*`,
  `*flow*`, `*diagram*` under `docs/assets/`, `docs/images/`, or referenced in README
- Mermaid / PlantUML blocks in docs: copy them as-is with a fenced code block
- If no diagram exists: produce a text-based component diagram using ASCII or a table

**Scope for ASCII/text diagrams**: Show 3–6 top-level components and their connections.
Do not attempt to map every class or function — the goal is a 30-second mental model,
not a complete UML diagram. A table of components (§3 Key Components) is more appropriate
for exhaustive detail.

**Component interaction**: How do the major pieces connect?
- What is the call/data flow from user entry point through to output?
- Where are the main extension/plugin points?

**Layer structure**: What are the abstraction layers?

```
User API  (oneshot / model_free_ptq)
    ↓
Pipeline  (CalibrationPipeline)
    ↓
Modifiers (GPTQ, AWQ, SmoothQuant, ...)
    ↓
Observers (activation stats collection)
    ↓
Output    (compressed-tensors format → safetensors)
```

Derive from: `ARCHITECTURE.md`, source directory structure, `__init__.py` / `mod.rs` / `index.ts`
top-level docstrings, README architecture diagrams.

---

### 3. Key Components

**Goal**: Map directory structure to human-understandable module responsibilities.

For each major module / package in the source tree, provide a table:

```markdown
| Component | Location | Responsibility |
|-----------|----------|---------------|
| Entrypoints | `src/xxx/entrypoints/` | Public API surface — `oneshot()`, `model_free_ptq()` |
| Core | `src/xxx/core/` | Session lifecycle, modifier orchestration |
| Modifiers | `src/xxx/modifiers/` | One subdirectory per algorithm (GPTQ, AWQ, ...) |
| Pipelines | `src/xxx/pipelines/` | Calibration pipeline — runs modifiers in recipe order |
| Recipe | `src/xxx/recipe/` | YAML ↔ Python object parsing |
| Observers | `src/xxx/observers/` | Collect activation statistics during calibration |
| ... | ... | ... |
```

Add a brief note for any component with a non-obvious design decision.

Derive from: directory tree (depth 2–3 under `src/`), top-level docstrings in `__init__` files,
README "Project Structure" section if present.

---

### 4. Research & Academic References

**Goal**: Surface the theoretical foundations so readers can evaluate algorithmic claims
and understand design decisions.

**Where to look** (from script output):
- `CITATION.cff` — formal citation file; extract title, authors, year, URL
- `paper.md` — JOSS-style paper
- README arXiv / DOI / proceedings links (script greps these automatically)
- `references/` or `docs/references.bib`

**Output format**:

```markdown
#### Academic Papers
| Paper | Authors | Venue | Link |
|-------|---------|-------|------|
| GPTQ: Accurate Post-Training Quantization... | Frantar et al. | ICLR 2023 | [arXiv:2210.17323](https://arxiv.org/abs/2210.17323) |
| SmoothQuant | Xiao et al. | ICML 2023 | [arXiv:2211.10438](https://arxiv.org/abs/2211.10438) |

#### Technical Blog Posts & Talks
| Title | Source | Link |
|-------|--------|------|
| LLM Compressor is here | Neural Magic Blog | [link](...) |
| Talk at KubeCon 2024 | YouTube | [link](...) |
```

If no formal citation exists, grep README for `arxiv.org`, `doi.org`,
`proceedings.mlr.press`, `aclanthology.org`, `openreview.net`.

---

### 5. Documentation & Learning Resources

**Goal**: Give a complete map of official resources so the decision-maker can assess documentation quality and onboarding cost.

```markdown
| Resource | URL | What it covers |
|----------|-----|---------------|
| Official docs site | https://... | Full API reference and guides |
| Getting started guide | https://.../getting-started | Install, first run |
| API reference | https://.../api | All public classes and functions |
| Examples directory | `examples/` (local) | End-to-end runnable scripts |
| Community Slack/Discord | https://... | Live help, announcements |
| GitHub Discussions | https://github.com/.../discussions | Q&A, RFCs |
| Video tutorials | https://... | Walkthroughs (if available) |
```

**How to find the docs URL** (from script output):
- `readthedocs.yaml` → project name → `https://{name}.readthedocs.io`
- `mkdocs.yml` → `site_url:` field
- `docusaurus.config.js` → `url:` field
- Repo `homepage` field from GitHub API
- README "Documentation" badge

---

### 6. Hello World

**Goal**: The minimal, copy-pasteable path from zero to something working.

1. **Prerequisites**: Runtime version, system dependencies, OS constraints
   (e.g., "Python ≥ 3.10, Linux only, CUDA GPU required for calibration")

2. **Install**:
   ```bash
   # exact command from README
   pip install packagename
   ```

3. **Minimal working example**: The simplest snippet that produces meaningful output.
   Pull from `examples/`, README quickstart, or docs getting-started page.
   Prefer the shortest example that is still realistic (not a toy).

4. **Expected output**: What should the user see when it works?
   (file created, server started, metric printed, etc.)

5. **Common pitfalls**: Top 2–3 things that commonly go wrong.
   Derive from: open/closed issues tagged `bug` or `question`, README warnings, CONTRIBUTING notes.

---

### 7. Code Quality Signals

Output **three verdicts** in plain language — do not list raw config files or tool names.

```markdown
**Testing**: [Comprehensive / Adequate / Minimal / None]
→ [one evidence sentence, e.g., "pytest with 5 tiers (smoke/sanity/regression/integration/unit),
   CI-enforced on every PR to main"]

**CI/CD**: [Production-grade / Basic / Manual]
→ [one evidence sentence, e.g., "GitHub Actions on push + PR to main and release/* branches,
   dedicated GPU runners for integration tests"]

**Maintenance discipline**: [Active / Stable / Declining]
→ [one evidence sentence, e.g., "ruff check + format enforced in CI, pre-commit hooks present,
   mypy present in dev deps but not yet enforced"]
```

**If any red flag is observed, append it inline under the most relevant verdict**:

```markdown
**Testing**: Minimal
→ Only two test files found; no CI enforcement.
  ⚠️ *Red flag*: Silent regressions likely on contributions.
```

Only mention red flags actually observed. Omit the red flag line entirely if none apply.

Reference table of red flags:

| Observation | Plain-language risk | Most relevant verdict |
|------------|-------------------|-----------------------|
| No test directory | Silent regressions on changes | Testing |
| No CI config | Release quality depends on individual discipline | CI/CD |
| Single giant source file | High coupling — hard to contribute or debug | Maintenance discipline |
| Dependencies pinned to old majors | Significant upgrade debt | Maintenance discipline |
| No linting config | Style inconsistency across contributors | Maintenance discipline |

---

## Trending Repos <a name="trending"></a>

> **Written to**: chat response only (no file — trending results are ephemeral)

To find trending GitHub repos, use the GitHub API search (no clone needed):

```bash
# Trending this week by stars (all languages)
gh api "search/repositories?q=created:>$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)&sort=stars&order=desc&per_page=10" \
  | jq '[.items[] | {rank: (. | input_line_number), name: .full_name, stars: .stargazers_count, description: .description, language: .language, url: .html_url}]'

# Trending for a specific language
gh api "search/repositories?q=language:python+created:>$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)&sort=stars&order=desc&per_page=10" \
  | jq '[.items[] | {name: .full_name, stars: .stargazers_count, description: .description}]'
```

Present as a ranked table: **Rank · Repo · Stars · Language · One-line description**.

Default: all languages, past 7 days, top 10.

---

## Handling Missing Data <a name="missing-data"></a>

> **Cross-cutting guideline** — applies to all sections.

Data will sometimes be unavailable (new projects, API failures, private registries).

| Situation | Convention |
|-----------|-----------|
| Metric not collected / API failed | `N/A (source unavailable)` |
| File not present in repo | `Not found` + note why it matters |
| Project too new for trend data | `Insufficient history (<6 months)` |
| No CHANGELOG | Note absence explicitly in risk.md Breaking Change section |
| No named adopters found | State "No public adopters listed" — do not invent or speculate |

**For very new projects** (< 6 months old or < 500 stars):
- Skip star velocity calculation (insufficient data for a meaningful rate).
- Skip download trend analysis (too early to be meaningful).
- Flag prominently in the Decision Brief:
  > ⚠️ Early-stage project — most adoption and momentum signals are premature.
  > Evaluate primarily based on organizational backing and technical merit.

---

## Analysis Depth by Mode <a name="depth-by-mode"></a>

When the user requests a **partial report** (single section), apply these depth guidelines
rather than the full-report standard:

| Mode | Files written | Depth standard |
|------|--------------|----------------|
| Full report (default) | All 7 + introduction.md | All subsections at maximum depth; all templates filled |
| Single section (e.g., "just the risk") | That one dimension file + index.md | Dimension file at full depth; index.md with Decision Brief only; other 5 files skipped |
| Quick overview ("should I adopt X?") | index.md only | Decision Brief + Key Metrics + one-sentence summaries; target ≤ 1 page |
| Compare mode (X vs Y) | Full reports for both + chat summary | No depth reduction |
| Trending repos | Chat table only | No files written |

**Quick overview index.md**: When writing index.md only, derive section summaries from
script data without writing the full dimension files. Mark each row in the Contents table
with `[not generated]` in place of a file link:

```markdown
| Section | Summary | File |
|---------|---------|------|
| Organizational Background | [one sentence] | *not generated* |
| Real-World Adoption | [one sentence] | *not generated* |
```
