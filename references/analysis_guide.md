# GitHub Project Analysis Guide

## Table of Contents
1. [Decision Brief](#decision-brief) ← **Start here for decision-makers**
2. [Organizational Background](#org-background)
3. [Real-World Adoption](#adoption)
4. [Competitive Landscape](#competitive)
5. [Momentum & Trajectory](#momentum)
6. [Risk Assessment](#risk)
7. [Code Quality & Maintainability](#code-quality) ← For technical audiences
8. [Getting Started](#getting-started) ← For developer audiences
9. [Trending Repos](#trending)

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

**Benchmark downloads** (rough calibration):

| Weekly downloads | Adoption level |
|-----------------|----------------|
| < 10K | Niche / experimental |
| 10K – 500K | Growing, real user base |
| 500K – 5M | Mainstream in its niche |
| > 5M | Category standard (e.g., React, requests) |

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

## Code Quality & Maintainability <a name="code-quality"></a>

> **Written to**: `technical.md` (first section)

**For technical audiences only.** Decision-makers should rely on Risk Assessment instead.

### Translate findings into 3 verdicts (don't list raw signals)

```markdown
**Testing**: [Comprehensive / Adequate / Minimal / None]
→ [one sentence of evidence, e.g., "pytest with 5 test tiers, CI enforced on every PR"]

**CI/CD**: [Production-grade / Basic / Manual]
→ [one sentence, e.g., "GitHub Actions on push to main and release branches, GPU runners"]

**Maintenance discipline**: [Active / Stable / Declining]
→ [one sentence, e.g., "Ruff + pre-commit enforced, mypy present but not mandatory"]
```

### Directory layout interpretation

| Pattern | Meaning |
|---------|---------|
| `src/` or `lib/` | Main source code |
| `test/` or `__tests__/` or `spec/` | Tests |
| `docs/` | Documentation |
| `examples/` | Usage examples |
| `scripts/` | Build/dev scripts |
| `packages/` | Monorepo packages |
| `.github/` | CI/CD workflows, issue templates |

### Red flags (translate to plain-language risk, not raw observations)

| Observation | Plain-language risk |
|------------|-------------------|
| No test directory | Changes may break existing behavior silently |
| No CI config | Releases are manual; quality depends on individual discipline |
| Single giant file | High coupling — hard to contribute, extend, or debug |
| All deps pinned to very old majors | Tech debt — upgrade cost likely significant |
| No linting config | Code style inconsistency across contributors |

---

## Getting Started <a name="getting-started"></a>

> **Written to**: `technical.md` (second section, after Code Quality)

**For developer audiences only.** Produce a minimal walkthrough to get something running.

1. **Prerequisites**: Runtime versions, system dependencies, OS constraints
2. **Install**: Exact commands from README or package manager
3. **Run**: Minimal command to get something working
4. **First code example**: Simplest meaningful usage snippet
5. **What to explore next**: Key docs, tutorials, or example directories

Derive from: README, CONTRIBUTING.md, `docs/getting-started*`, `examples/`.

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
