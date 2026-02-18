# GitHub Project Analysis Guide

## Table of Contents
1. [Basic Concepts Analysis](#basic-concepts)
2. [Hello World Guide](#hello-world)
3. [Code Quality & Structure](#code-quality)
4. [Repository Metrics](#repo-metrics)
5. [Trending Repos](#trending)

---

## Basic Concepts Analysis <a name="basic-concepts"></a>

When explaining basic concepts of a project:
- **Purpose**: What problem does it solve? Who is it for?
- **Core abstractions**: Key types, interfaces, or patterns (e.g., "middleware", "plugin", "store")
- **Architecture style**: MVC, event-driven, microservices, monolith, etc.
- **Key dependencies**: What major libraries/frameworks does it build on and why?
- **Mental model**: One paragraph explaining how to think about the project

Derive this from: README, docs/, architecture diagrams, main entry point files, and package metadata.

---

## Hello World Guide <a name="hello-world"></a>

Produce a minimal getting-started walkthrough:
1. **Prerequisites**: Runtime versions, system dependencies
2. **Install**: Exact commands from README or package manager files
3. **Run**: Minimal command to get something working
4. **First code example**: The simplest meaningful usage snippet
5. **What to explore next**: Point to key docs, tutorials, or example directories

Derive from: README, CONTRIBUTING.md, docs/getting-started*, examples/, quickstart sections.

---

## Code Quality & Structure <a name="code-quality"></a>

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

### Language-specific quality signals
- **Has linting config**: `.eslintrc`, `pyproject.toml [ruff]`, `.golangci.yml`, etc.
- **Has type checking**: `tsconfig.json`, `mypy.ini`, type stubs
- **Has formatting**: `.prettierrc`, `black`, `gofmt` enforced in CI
- **Test coverage**: Look for coverage badges, `codecov.yml`, or coverage config
- **CI/CD**: `.github/workflows/`, `.circleci/`, `Makefile` targets

### Architecture red flags
- No tests directory → low test confidence
- Single giant file → poor separation of concerns
- No CI config → manual release process
- Pinned to old major versions → maintenance concern

---

## Repository Metrics <a name="repo-metrics"></a>

### Activity signals
| Metric | Healthy signal |
|--------|---------------|
| Last push | Within 3-6 months |
| Stars trajectory | Steady or growing |
| Issue close rate | >50% issues closed |
| PR merge time | <2 weeks median |
| Contributors | >3 active in last year |
| Release cadence | Regular releases (not years apart) |

### Community health
- Has CONTRIBUTING.md → structured contribution process
- Has CODE_OF_CONDUCT.md → inclusive community
- Has SECURITY.md → responsible disclosure policy
- Issue templates → organized bug reports/feature requests
- Discussion board enabled → community engagement

### License interpretation
| License | Implications |
|---------|-------------|
| MIT/BSD/Apache-2.0 | Permissive, commercial use OK |
| GPL-2.0/3.0 | Copyleft, derivatives must be open |
| LGPL | Library use OK commercially, modifications open |
| AGPL | Network use triggers copyleft |
| No license | Default copyright, cannot use |
| Custom | Read carefully |

---

## Trending Repos <a name="trending"></a>

To find trending GitHub repos, use the GitHub API search or gh CLI:

```bash
# Trending this week by stars (example: all languages)
gh api "search/repositories?q=created:>$(date -d '7 days ago' +%Y-%m-%d)&sort=stars&order=desc&per_page=10" \
  | jq '[.items[] | {name: .full_name, stars: .stargazers_count, description: .description, language: .language, url: .html_url}]'

# Trending for a specific language
gh api "search/repositories?q=language:python+created:>$(date -d '7 days ago' +%Y-%m-%d)&sort=stars&order=desc&per_page=10" \
  | jq '[.items[] | {name: .full_name, stars: .stargazers_count, description: .description}]'
```

Present trending results as a ranked table with: rank, repo name, stars, language, and one-line description.
