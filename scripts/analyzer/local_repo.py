"""Sections 6, 6b, 7: Local repository file analysis and git stats."""
from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

from .cache import CacheManager
from . import output

_README_NAMES = ["README.md", "README.rst", "README.txt", "README"]
_CHANGELOG_NAMES = ["CHANGELOG.md", "CHANGELOG.rst", "CHANGELOG", "HISTORY.md", "CHANGES.md", "RELEASES.md"]
_GOVERNANCE_FILES = [
    "CONTRIBUTING.md", "CONTRIBUTING.rst", "CODE_OF_CONDUCT.md", "SECURITY.md",
    "GOVERNANCE.md", "MAINTAINERS", "CODEOWNERS", "ROADMAP.md",
]
_MANIFEST_NAMES = [
    "package.json", "Cargo.toml", "pyproject.toml", "setup.py", "setup.cfg",
    "go.mod", "pom.xml", "build.gradle", "Gemfile", "composer.json",
    "CMakeLists.txt", "Makefile", "makefile",
]


def _find_file(repo_dir: Path, names: list[str]) -> Path | None:
    for name in names:
        p = repo_dir / name
        if p.exists():
            return p
    return None


def clone_or_update(repo: str, clone_url: str, cache: CacheManager) -> None:
    clone_cache = cache.raw_dir / "clone_meta.txt"
    repo_dir = cache.repo_dir

    if repo_dir.is_dir() and (repo_dir / ".git").exists() and cache.is_fresh(clone_cache):
        output.cache_hit("Repository clone", cache.age_days(clone_cache))
        output.console.print("  Updating to latest HEAD...")
        try:
            subprocess.run(
                ["git", "-C", str(repo_dir), "fetch", "--depth=1", "--quiet", "origin"],
                capture_output=True, timeout=120,
            )
            subprocess.run(
                ["git", "-C", str(repo_dir), "reset", "--hard", "FETCH_HEAD", "--quiet"],
                capture_output=True, timeout=30,
            )
            output.console.print("  Updated.")
        except Exception as e:
            output.warn(f"Could not update repo: {e}")
    else:
        output.cache_miss("Repository clone")
        output.console.print(f"  Cloning {clone_url}")
        if repo_dir.exists():
            shutil.rmtree(repo_dir)
        result = subprocess.run(
            ["git", "clone", "--depth=1", "--quiet", clone_url, str(repo_dir)],
            capture_output=True, text=True, timeout=300,
        )
        if result.returncode != 0:
            output.error(f"Clone failed: {result.stderr}")
            raise SystemExit(1)
        cache.write_text(clone_cache, f"Clone URL: {clone_url}\n")
        output.console.print("  Cloned successfully.")
    output.console.print()


def section6_local_files(repo_dir: Path) -> None:
    output.subsection("Section 6 — Local Repository Files")
    output.console.print(f"REPO_DIR: {repo_dir}\n")

    # Top-level listing
    output.console.print("Top-level Directory Listing:")
    try:
        for entry in sorted(repo_dir.iterdir(), key=lambda p: p.name):
            output.console.print(f"  {'d' if entry.is_dir() else '-'} {entry.name}")
    except Exception:
        output.console.print("  (could not list directory)")
    output.console.print()

    # Directory tree depth 3
    output.console.print("Full Directory Tree (depth 3, .git excluded):")
    _print_tree(repo_dir, max_depth=3)
    output.console.print()

    # README
    output.console.print("README (first 200 lines):")
    readme = _find_file(repo_dir, _README_NAMES)
    if readme:
        output.console.print(f"(source: {readme.name})")
        lines = readme.read_text(errors="replace").splitlines()
        output.console.print("\n".join(lines[:200]))
    else:
        output.console.print("(no README found)")
    output.console.print()

    # Adopters
    output.console.print("Named Adopters / Case Studies:")
    for name in ["ADOPTERS.md", "ADOPTERS", "USERS.md", "USERS", "COMPANIES.md"]:
        p = repo_dir / name
        if p.exists():
            output.console.print(f"(source: {name})")
            output.console.print(p.read_text(errors="replace"))
    if readme:
        output.console.print("--- Production/adoption mentions in README ---")
        pattern = re.compile(
            r"(production|used by|powered by|adopted by|trusted by|case study|customer)", re.IGNORECASE
        )
        matches = [l for l in readme.read_text(errors="replace").splitlines() if pattern.search(l)]
        output.console.print("\n".join(matches[:20]) if matches else "(none found)")
    output.console.print()

    # CHANGELOG
    output.console.print("Breaking Changes in CHANGELOG:")
    changelog = _find_file(repo_dir, _CHANGELOG_NAMES)
    if changelog:
        content = changelog.read_text(errors="replace")
        output.console.print(f"(source: {changelog.name} — breaking-change markers)")
        pattern = re.compile(
            r"(breaking|BREAKING CHANGE|incompatible|migration required|removed|deprecated)", re.IGNORECASE
        )
        breaking = [l for l in content.splitlines() if pattern.search(l)]
        output.console.print("\n".join(breaking[:30]) if breaking else "(no breaking markers)")
        output.console.print("\n(first 80 lines for cadence)")
        output.console.print("\n".join(content.splitlines()[:80]))
    output.console.print()

    # Package manifests (depth ≤ 2)
    output.console.print("Package / Project Manifests:")
    for name in _MANIFEST_NAMES:
        for p in sorted(repo_dir.glob(f"**/{name}")):
            if ".git" not in p.parts and len(p.relative_to(repo_dir).parts) <= 2:
                output.console.print(f"  {p.relative_to(repo_dir)}")
    # requirements*.txt separately (glob pattern)
    for p in sorted(repo_dir.glob("**/requirements*.txt")):
        if ".git" not in p.parts and len(p.relative_to(repo_dir).parts) <= 2:
            output.console.print(f"  {p.relative_to(repo_dir)}")
    output.console.print()

    # CI/CD
    output.console.print("CI/CD Configs:")
    ci_paths: list[Path] = []
    workflow_dir = repo_dir / ".github" / "workflows"
    if workflow_dir.exists():
        ci_paths.extend(sorted(workflow_dir.glob("*.yml")) + sorted(workflow_dir.glob("*.yaml")))
    for name in ["Jenkinsfile", ".travis.yml", "azure-pipelines.yml", ".gitlab-ci.yml"]:
        p = repo_dir / name
        if p.exists():
            ci_paths.append(p)
    circleci = repo_dir / ".circleci" / "config.yml"
    if circleci.exists():
        ci_paths.append(circleci)
    for p in sorted(ci_paths):
        output.console.print(f"  {p.relative_to(repo_dir)}")
    output.console.print()

    # Governance
    output.console.print("Community & Governance Health Files:")
    for name in _GOVERNANCE_FILES:
        if (repo_dir / name).exists():
            output.console.print(f"  FOUND: {name}")
        if (repo_dir / ".github" / name).exists():
            output.console.print(f"  FOUND: .github/{name}")
    github_dir = repo_dir / ".github"
    if github_dir.exists():
        for f in sorted(github_dir.iterdir()):
            output.console.print(f"  .github/{f.name}")
    output.console.print()

    # License
    output.console.print("License (first 5 lines):")
    for name in ["LICENSE", "LICENSE.md", "LICENSE.txt", "LICENSE.rst", "COPYING"]:
        p = repo_dir / name
        if p.exists():
            output.console.print(f"(source: {name})")
            output.console.print("\n".join(p.read_text(errors="replace").splitlines()[:5]))
            break
    output.console.print()


def section6b_technical_deepdive(repo_dir: Path, repo_json: dict) -> None:
    output.subsection("Section 6b — Technical Deep-Dive (local)")

    # Papers
    output.console.print("Academic Papers & Citations:")
    for name, label in [("CITATION.cff", "CITATION.cff found"), ("paper.md", "paper.md found — JOSS")]:
        p = repo_dir / name
        if p.exists():
            output.console.print(f"({label})")
            output.console.print(p.read_text(errors="replace"))
            break
    else:
        output.console.print("(no CITATION.cff or paper.md)")
    output.console.print()

    readme = _find_file(repo_dir, _README_NAMES)

    output.console.print("Paper/DOI links in README:")
    if readme:
        pattern = re.compile(
            r"https?://(arxiv\.org|doi\.org|proceedings\.mlr\.press|aclanthology\.org"
            r"|openreview\.net|dl\.acm\.org|papers\.nips\.cc)[^\s)>\"]*"
            r"|arXiv:\d+\.\d+"
        )
        links = sorted(set(m.group() for m in pattern.finditer(readme.read_text(errors="replace"))))
        output.console.print("\n".join(links) if links else "(none found)")
    output.console.print()

    output.console.print("Blog/announcement links in README:")
    if readme:
        pattern = re.compile(r"https?://[^\s)>\"]*blog[^\s)>\"]*", re.IGNORECASE)
        links = sorted(set(m.group() for m in pattern.finditer(readme.read_text(errors="replace"))))
        output.console.print("\n".join(links) if links else "(none found)")
    output.console.print()

    output.console.print("Documentation Site:")
    mkdocs = repo_dir / "mkdocs.yml"
    if mkdocs.exists():
        output.console.print("(mkdocs.yml found)")
        for line in mkdocs.read_text(errors="replace").splitlines():
            if re.match(r"\s*(site_name|site_url|site_description|repo_url|docs_dir):", line):
                output.console.print(f"  {line.strip()}")
    for name in [".readthedocs.yaml", ".readthedocs.yml"]:
        p = repo_dir / name
        if p.exists():
            output.console.print(f"(readthedocs: {name})")
            output.console.print("\n".join(p.read_text(errors="replace").splitlines()[:20]))
    for name in ["docusaurus.config.js", "docusaurus.config.ts"]:
        p = repo_dir / name
        if p.exists():
            output.console.print(f"(docusaurus: {name})")
            for line in p.read_text(errors="replace").splitlines():
                if re.search(r"(url|baseUrl|tagline|title)\s*:", line):
                    output.console.print(f"  {line.strip()}")
    output.console.print(f"Repo homepage: {repo_json.get('homepage') or '(none)'}")
    output.console.print()

    output.console.print("Architecture Files & Diagrams:")
    for name in ["ARCHITECTURE.md", "ARCHITECTURE.rst", "DESIGN.md", "docs/architecture.md", "docs/design.md"]:
        p = repo_dir / name
        if p.exists():
            output.console.print(f"(found: {name})")
            output.console.print("\n".join(p.read_text(errors="replace").splitlines()[:60]))
    img_pattern = re.compile(r"(arch|architecture|overview|diagram|flow|design)", re.IGNORECASE)
    for ext in ["*.png", "*.svg", "*.jpg", "*.gif"]:
        for p in sorted(repo_dir.rglob(ext)):
            if ".git" not in str(p) and img_pattern.search(p.name):
                output.console.print(f"  {p.relative_to(repo_dir)}")
    output.console.print()

    output.console.print("Mermaid/PlantUML blocks in docs:")
    diagrams = [
        str(p.relative_to(repo_dir))
        for p in sorted(repo_dir.rglob("*.md"))
        if ".git" not in str(p)
        and any(m in p.read_text(errors="replace") for m in ["```mermaid", "```plantuml", "@startuml"])
    ]
    output.console.print("\n".join(diagrams[:10]) if diagrams else "(none found)")
    output.console.print()

    output.console.print("Examples Directory:")
    examples_dir = repo_dir / "examples"
    if examples_dir.exists():
        output.console.print("(examples/ found)")
        for e in sorted(examples_dir.iterdir())[:30]:
            output.console.print(f"  {e.name}")
    else:
        output.console.print("(no examples/ directory)")
    output.console.print()


def section7_git_stats(cache: CacheManager) -> None:
    output.subsection("Section 7 — Git Stats")
    _cache = cache.raw_dir / "git_stats.txt"
    cache.status("git_stats", _cache)
    if cache.is_fresh(_cache):
        output.console.print(cache.read_text(_cache))
    else:
        repo_dir = str(cache.repo_dir)

        def _git(*args: str) -> str:
            try:
                return subprocess.run(
                    ["git", "-C", repo_dir, *args], capture_output=True, text=True, timeout=60
                ).stdout.strip()
            except Exception:
                return "N/A"

        count = _git("rev-list", "--count", "HEAD")
        last_commit = _git("log", "-1", "--format=%ci  %s")
        author_emails = _git("log", "--format=%ae")
        unique_authors = len(set(author_emails.splitlines())) if author_emails and author_emails != "N/A" else "N/A"

        text = (
            f"Total commits (shallow): {count}\n"
            f"Last commit: {last_commit}\n"
            f"Unique author emails: {unique_authors}"
        )
        output.console.print(text)
        cache.write_text(_cache, text)
    output.console.print()


def _print_tree(root: Path, max_depth: int) -> None:
    output.console.print(f"{root.name}/")

    def _walk(path: Path, depth: int, prefix: str) -> None:
        if depth > max_depth:
            return
        try:
            entries = sorted(path.iterdir(), key=lambda p: (p.is_file(), p.name))
        except Exception:
            return
        entries = [e for e in entries if e.name != ".git"]
        for i, entry in enumerate(entries):
            last = i == len(entries) - 1
            output.console.print(f"{prefix}{'└── ' if last else '├── '}{entry.name}")
            if entry.is_dir() and depth < max_depth:
                _walk(entry, depth + 1, prefix + ("    " if last else "│   "))

    _walk(root, 1, "")
