---
name: github-project-analyzer
description: >
  Analyze GitHub projects from a URL. Use this skill when the user provides a GitHub
  repository URL (e.g., https://github.com/owner/repo) and wants to understand:
  (1) basic concepts and purpose of the project,
  (2) a hello world / getting started guide,
  (3) code quality and project structure,
  (4) repository metrics (stars, contributors, activity, license),
  (5) trending GitHub repositories by language or time period.
  Triggers on: "analyze this GitHub repo", "explain this project", "how do I get started with X",
  "what is this GitHub project", "show me trending repos", "review this codebase".
---

# GitHub Project Analyzer

## Workflow

### 1. Fetch raw data
Run the analysis script to gather repo data:

```bash
bash <skill-dir>/scripts/analyze_repo.sh <github-url-or-owner/repo>
```

The script uses the `gh` CLI and outputs: repo info, contributors, releases, PRs, topics, file structure, and README.

If `gh` is not authenticated, fall back to the GitHub REST API via `curl` with public endpoints:
```bash
curl -s "https://api.github.com/repos/<owner>/<repo>"
```

### 2. Select analysis mode based on user intent

| User asks | Mode | Reference |
|-----------|------|-----------|
| "What is this?" / "explain it" | Basic concepts | references/analysis_guide.md §Basic Concepts |
| "How do I use it?" / "get started" | Hello world | references/analysis_guide.md §Hello World |
| "Is it well-maintained?" / "code quality" | Structure & quality | references/analysis_guide.md §Code Quality |
| "How popular is it?" / "metrics" | Repo metrics | references/analysis_guide.md §Repo Metrics |
| "Trending repos" / "what's popular" | Trending search | references/analysis_guide.md §Trending |

Read `references/analysis_guide.md` for detailed guidance on any mode.

### 3. Produce structured output

Always format the response with clear sections using markdown. Include:
- A one-paragraph TL;DR summary at the top
- Relevant sections based on the mode (see analysis_guide.md)
- Concrete commands, code snippets, or tables where useful
- A "Next steps" or "Learn more" callout at the end

## Tips

- **README-first**: The README is the most authoritative source—prioritize it over assumptions.
- **Multiple modes**: If the user didn't specify, default to covering Basic Concepts + Hello World + Metrics together.
- **Trending**: For trending repos, if no language or timeframe is specified, default to "all languages, past 7 days".
- **No gh CLI**: If `gh` is unavailable, use `curl https://api.github.com/repos/<owner>/<repo>` for public repos.
