#!/usr/bin/env bash
# GitHub Project Analyzer — Data Collection Script
# Version: 2.0 (cache-aware, phased)
#
# Usage:
#   ./analyze_repo.sh [OPTIONS] <github-url-or-owner/repo>
#
# Options:
#   --cache-dir DIR    Root directory for cache (default: ./cache)
#   --max-age DAYS     Cache max age in days (default: 7)
#   --force            Bypass all caches, re-fetch everything
#
# Output:
#   - Prints collected data to stdout (same format as before)
#   - Saves raw API responses to $CACHE_DIR/raw/
#   - Saves repo clone to $CACHE_DIR/repo/
#   - Writes $CACHE_DIR/meta.json on completion
#
# Auth config: ~/.config/github-analyzer/config
#   GITHUB_TOKEN=ghp_...
#   LIBRARIES_IO_KEY=...    (optional)
#   YOUTUBE_API_KEY=...     (optional)

set -eo pipefail
trap 'echo "" >&2; echo "ERROR at line $LINENO — run: bash -x $0 $* 2>&1 | head -100" >&2' ERR

# ---------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------
CACHE_BASE_DIR="./cache"
MAX_AGE_DAYS=7
FORCE_REFRESH=false
INPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache-dir) CACHE_BASE_DIR="$2"; shift 2 ;;
    --max-age)   MAX_AGE_DAYS="$2";   shift 2 ;;
    --force)     FORCE_REFRESH=true;  shift   ;;
    -*)          echo "Unknown option: $1" >&2; exit 1 ;;
    *)           INPUT="$1";           shift   ;;
  esac
done

if [ -z "$INPUT" ]; then
  echo "Usage: $0 [--cache-dir DIR] [--max-age DAYS] [--force] <github-url-or-owner/repo>" >&2
  exit 1
fi

# Normalize input
REPO=$(echo "$INPUT" | sed -E 's|https?://github\.com/||' | sed 's|\.git$||' | sed 's|/$||')
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPONAME=$(echo "$REPO" | cut -d'/' -f2)
CLONE_URL="https://github.com/${REPO}.git"

echo "=== GitHub Project Analyzer v2.0: $REPO ==="
echo "Cache dir : $CACHE_BASE_DIR/${OWNER}-${REPONAME}"
echo "Max age   : ${MAX_AGE_DAYS}d | Force: $FORCE_REFRESH"
echo ""

# ---------------------------------------------------------------
# Cache configuration
# ---------------------------------------------------------------
CACHE_SLUG="${OWNER}-${REPONAME}"
CACHE_DIR="${CACHE_BASE_DIR}/${CACHE_SLUG}"
RAW_DIR="${CACHE_DIR}/raw"
REPO_DIR="${CACHE_DIR}/repo"

mkdir -p "$RAW_DIR"

# ---------------------------------------------------------------
# Cache helpers
# ---------------------------------------------------------------

# Returns 0 (true) if the file exists and is younger than MAX_AGE_DAYS
cache_is_fresh() {
  local file="$1" max_age="${2:-$MAX_AGE_DAYS}"
  [ "$FORCE_REFRESH" = "true" ] && return 1
  [ ! -f "$file" ] && return 1
  local now file_ts age
  now=$(date +%s)
  file_ts=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)
  age=$(( (now - file_ts) / 86400 ))
  [ "$age" -lt "$max_age" ]
}

# Age in days of a file (for display)
file_age_days() {
  local file="$1"
  local now file_ts
  now=$(date +%s)
  file_ts=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)
  echo $(( (now - file_ts) / 86400 ))
}

# Print a cache status line
cache_status() {
  local label="$1" file="$2"
  if cache_is_fresh "$file"; then
    printf "  [CACHE HIT  %dd] %s\n" "$(file_age_days "$file")" "$label"
  else
    printf "  [CACHE MISS    ] %s\n" "$label"
  fi
}

# ---------------------------------------------------------------
# Auth: load config file, validate token
# ---------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PRIMARY="${HOME}/.config/github-analyzer/config"
CONFIG_LOCAL="${SCRIPT_DIR}/../config"

: "${GITHUB_TOKEN:=}"
: "${LIBRARIES_IO_KEY:=}"
: "${YOUTUBE_API_KEY:=}"

_load_config() {
  local cfg="$1"
  [ -f "$cfg" ] || return 1
  while IFS= read -r line; do
    line="${line#"${line%%[! ]*}"}"
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
    local key="${line%%=*}" val="${line#*=}"
    val="${val#\"}" ; val="${val%\"}" ; val="${val#\'}" ; val="${val%\'}"
    case "$key" in
      GITHUB_TOKEN)    [ -z "$GITHUB_TOKEN" ]    && GITHUB_TOKEN="$val" ;;
      LIBRARIES_IO_KEY)[ -z "$LIBRARIES_IO_KEY" ] && LIBRARIES_IO_KEY="$val" ;;
      YOUTUBE_API_KEY) [ -z "$YOUTUBE_API_KEY" ]  && YOUTUBE_API_KEY="$val" ;;
    esac
  done < "$cfg"
}
_load_config "$CONFIG_PRIMARY" || true
_load_config "$CONFIG_LOCAL"   || true

AUTH_METHOD="" TOKEN_VALID=false

_check_token() {
  local token="$1" tmp http_code
  tmp=$(mktemp)
  http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
    "https://api.github.com/user" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" 2>/dev/null)
  rm -f "$tmp"; echo "$http_code"
}

echo "### Auth Status"
if [ -n "$GITHUB_TOKEN" ]; then
  echo -n "  Token found — validating ... "
  HTTP_CODE=$(_check_token "$GITHUB_TOKEN")
  case "$HTTP_CODE" in
    200) echo "✓ valid"; TOKEN_VALID=true; AUTH_METHOD="token" ;;
    401) echo "✗ INVALID (401) — falling back to unauthenticated"
         GITHUB_TOKEN=""; AUTH_METHOD="unauthenticated" ;;
    403) echo "✗ FORBIDDEN (403) — falling back to unauthenticated"
         GITHUB_TOKEN=""; AUTH_METHOD="unauthenticated" ;;
    *)   echo "✗ HTTP $HTTP_CODE — falling back to unauthenticated"
         GITHUB_TOKEN=""; AUTH_METHOD="unauthenticated" ;;
  esac
elif command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  echo "  Using gh CLI (authenticated)"; AUTH_METHOD="gh"
else
  echo "  No token — unauthenticated (60 req/hr limit)"
  AUTH_METHOD="unauthenticated"
fi
echo ""

# ---------------------------------------------------------------
# GitHub API helper
# ---------------------------------------------------------------
github_api() {
  local endpoint="$1" tmp body http_code
  if [ "$AUTH_METHOD" = "token" ]; then
    tmp=$(mktemp)
    http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
      "https://api.github.com/$endpoint" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" 2>/dev/null)
    body=$(cat "$tmp"); rm -f "$tmp"
    case "$http_code" in
      200|201|204|404) echo "$body" ;;
      401|403) echo "" >&2; echo "  ⚠️  GitHub API auth error ($http_code): $endpoint" >&2; return 1 ;;
      *) echo "" >&2; echo "  ⚠️  GitHub API HTTP $http_code: $endpoint" >&2; return 1 ;;
    esac
  elif [ "$AUTH_METHOD" = "gh" ]; then
    gh api "$endpoint" 2>/dev/null
  else
    tmp=$(mktemp)
    http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
      "https://api.github.com/$endpoint" \
      -H "Accept: application/vnd.github+json" 2>/dev/null)
    body=$(cat "$tmp"); rm -f "$tmp"
    if [ "$http_code" = "403" ]; then
      echo "  ⚠️  Rate limit hit — add GITHUB_TOKEN to $CONFIG_PRIMARY" >&2; return 1
    fi
    echo "$body"
  fi
}

# ---------------------------------------------------------------
# Phase 1 — Clone or update repository (persistent cache)
# ---------------------------------------------------------------
echo "### Phase 1: Data Collection"
echo ""
echo "#### Repository Clone"

_CLONE_CACHE="$RAW_DIR/clone_meta.txt"
if [ -d "$REPO_DIR/.git" ] && cache_is_fresh "$_CLONE_CACHE"; then
  echo "  [CACHE HIT  $(file_age_days "$_CLONE_CACHE")d] Repository clone"
  echo "  Updating to latest HEAD..."
  git -C "$REPO_DIR" fetch --depth=1 --quiet origin 2>/dev/null || true
  git -C "$REPO_DIR" reset --hard FETCH_HEAD --quiet 2>/dev/null || true
  echo "  Updated."
else
  echo "  [CACHE MISS    ] Cloning $CLONE_URL"
  rm -rf "$REPO_DIR"
  if ! git clone --depth=1 --quiet "$CLONE_URL" "$REPO_DIR" 2>&1; then
    echo "ERROR: Clone failed for $CLONE_URL" >&2; exit 1
  fi
  echo "Clone URL: $CLONE_URL" > "$_CLONE_CACHE"
  echo "  Cloned successfully."
fi
echo ""

# ---------------------------------------------------------------
# Section 1: Core GitHub metadata
# ---------------------------------------------------------------
echo "#### Section 1 — GitHub Repository Metadata"
_CACHE="$RAW_DIR/github_repo.json"
cache_status "github_repo" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  REPO_JSON=$(cat "$_CACHE")
else
  REPO_JSON=$(github_api "repos/$REPO" || echo "{}")
  echo "$REPO_JSON" > "$_CACHE"
fi
echo "$REPO_JSON" | jq '{
  name: .name, description: .description, url: .html_url, homepage: .homepage,
  owner_type: .owner.type, owner_login: .owner.login,
  stars: .stargazers_count, forks: .forks_count, watchers: .subscribers_count,
  open_issues: .open_issues_count, primary_language: .language,
  license: .license.name, license_spdx: .license.spdx_id,
  created_at: .created_at, last_pushed: .pushed_at,
  default_branch: .default_branch, archived: .archived,
  fork: .fork, topics: .topics,
  network_count: .network_count, subscribers_count: .subscribers_count
}' 2>/dev/null || echo "(could not parse repo info)"
echo ""

# ---------------------------------------------------------------
# Section 2: Organization / Backing Info
# ---------------------------------------------------------------
echo "#### Section 2 — Organization / Backing"
_CACHE="$RAW_DIR/github_org.json"
cache_status "github_org" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  ORG_JSON=$(cat "$_CACHE")
else
  ORG_JSON=$(github_api "orgs/$OWNER" 2>/dev/null || github_api "users/$OWNER" 2>/dev/null || echo "{}")
  echo "$ORG_JSON" > "$_CACHE"
fi
echo "$ORG_JSON" | jq '{
  name: .name, blog: .blog, location: .location, description: .description,
  company: .company, email: .email, twitter_username: .twitter_username,
  public_repos: .public_repos, followers: .followers, type: .type, created_at: .created_at
}' 2>/dev/null || echo "(could not parse org info)"
echo ""

echo "#### Sponsorship / Funding"
if [ -f "$REPO_DIR/.github/FUNDING.yml" ]; then
  echo "(FUNDING.yml found)"; cat "$REPO_DIR/.github/FUNDING.yml"
else
  echo "(no FUNDING.yml)"
fi
echo ""

# ---------------------------------------------------------------
# Section 3: Contributors (bus factor signals)
# ---------------------------------------------------------------
echo "#### Section 3 — Contributors"
_CACHE="$RAW_DIR/github_contributors.json"
cache_status "github_contributors" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  CONTRIB_JSON=$(cat "$_CACHE")
else
  CONTRIB_JSON=$(github_api "repos/$REPO/contributors?per_page=15" || echo "[]")
  echo "$CONTRIB_JSON" > "$_CACHE"
fi

echo "Top Contributors (up to 15):"
echo "$CONTRIB_JSON" | jq '[.[] | {login: .login, contributions: .contributions}]' 2>/dev/null \
  || echo "(unavailable)"
echo ""
echo "Bus Factor Signal:"
echo "$CONTRIB_JSON" | jq '
  if length > 0 then
    . as $all |
    ($all | map(.contributions) | add) as $total |
    ($all[:1] | map(.contributions) | add) as $top1 |
    ($all[:3] | map(.contributions) | add) as $top3 |
    {
      total_contributors: ($all | length),
      top1_share_pct: (($top1 / $total * 100) | round),
      top3_share_pct: (($top3 / $total * 100) | round),
      total_contributions: $total
    }
  else "no contributor data" end
' 2>/dev/null || echo "(could not compute)"
echo ""

# ---------------------------------------------------------------
# Section 4: Activity & Release Health
# ---------------------------------------------------------------
echo "#### Section 4 — Activity & Release Health"

_CACHE="$RAW_DIR/github_releases.json"
cache_status "github_releases" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  RELEASES_JSON=$(cat "$_CACHE")
else
  RELEASES_JSON=$(github_api "repos/$REPO/releases?per_page=8" || echo "[]")
  echo "$RELEASES_JSON" > "$_CACHE"
fi
echo "Recent Releases (up to 8):"
echo "$RELEASES_JSON" | jq \
  '[.[] | {tag: .tag_name, name: .name, published: .published_at, prerelease: .prerelease}]' \
  2>/dev/null || echo "(no releases)"
echo ""

_CACHE="$RAW_DIR/github_prs_open.json"
cache_status "github_prs_open" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  PR_JSON=$(cat "$_CACHE")
else
  PR_JSON=$(github_api "repos/$REPO/pulls?state=open&per_page=100" || echo "[]")
  echo "$PR_JSON" > "$_CACHE"
fi
echo "Open Pull Requests:"
echo "$PR_JSON" | jq '{
  open_pr_count: length,
  oldest_pr_created: (if length > 0 then (. | sort_by(.created_at) | .[0].created_at) else null end),
  sample_titles: [.[:5][] | .title]
}' 2>/dev/null || echo "(unavailable)"
echo ""

_CACHE="$RAW_DIR/github_issues_closed.json"
cache_status "github_issues_closed" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  ISSUES_JSON=$(cat "$_CACHE")
else
  ISSUES_JSON=$(github_api "repos/$REPO/issues?state=closed&per_page=5&sort=updated" || echo "[]")
  echo "$ISSUES_JSON" > "$_CACHE"
fi
echo "Recent Closed Issues (response time sample):"
echo "$ISSUES_JSON" | jq \
  '[.[] | {number: .number, title: .title, created: .created_at, closed: .closed_at}]' \
  2>/dev/null || echo "(unavailable)"
echo ""

echo "Repository Topics:"
echo "$REPO_JSON" | jq '.topics' 2>/dev/null || echo "[]"
echo ""

# ---------------------------------------------------------------
# Section 5: Ecosystem & Download Metrics
# ---------------------------------------------------------------
echo "#### Section 5 — Ecosystem & Downloads"

# GitHub Dependents
_CACHE="$RAW_DIR/github_dependents.txt"
cache_status "github_dependents" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  DEP_PAGE=$(curl -sf "https://github.com/$REPO/network/dependents" \
    -H "Accept: text/html" 2>/dev/null || echo "")
  DEP_RESULT=""
  if [ -n "$DEP_PAGE" ]; then
    DEP_RESULT=$(echo "$DEP_PAGE" | grep -oE '[0-9,]+ Repositories' | head -1 \
      | sed 's/ Repositories/ repositories depend on this package/' || echo "(could not parse)")
  else
    DEP_RESULT="(could not fetch dependents page)"
  fi
  echo "GitHub Dependents: $DEP_RESULT"
  echo "GitHub Dependents: $DEP_RESULT" > "$_CACHE"
fi
echo ""

# PyPI
echo "PyPI Download Stats:"
_CACHE="$RAW_DIR/pypi_stats.json"
cache_status "pypi_stats" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  PYPI_CACHED=$(cat "$_CACHE")
  echo "$PYPI_CACHED"
else
  # Derive package name
  PYPI_NAME="$REPONAME"
  if [ -f "$REPO_DIR/pyproject.toml" ]; then
    PYPI_NAME_PARSED=$(grep -E '^\s*name\s*=' "$REPO_DIR/pyproject.toml" 2>/dev/null \
      | head -1 | sed 's/.*name\s*=\s*["\x27]//' | sed 's/["\x27].*//' | tr -d ' ' || true)
    [ -n "$PYPI_NAME_PARSED" ] && PYPI_NAME="$PYPI_NAME_PARSED"
  elif [ -f "$REPO_DIR/setup.py" ]; then
    PYPI_NAME_PARSED=$(grep -E "name\s*=" "$REPO_DIR/setup.py" 2>/dev/null \
      | head -1 | sed "s/.*name\s*=\s*['\"]//;s/['\"].*//" | tr -d ' ' || true)
    [ -n "$PYPI_NAME_PARSED" ] && PYPI_NAME="$PYPI_NAME_PARSED"
  fi
  # Try with normalization fallbacks
  PYPI_JSON=$(curl -sf "https://pypistats.org/api/packages/$PYPI_NAME/recent" 2>/dev/null || echo "")
  if ! echo "$PYPI_JSON" | jq -e '.data' &>/dev/null 2>&1; then
    PYPI_NAME_ALT=$(echo "$PYPI_NAME" | tr '_' '-')
    PYPI_JSON=$(curl -sf "https://pypistats.org/api/packages/$PYPI_NAME_ALT/recent" 2>/dev/null || echo "")
    echo "$PYPI_JSON" | jq -e '.data' &>/dev/null 2>&1 && PYPI_NAME="$PYPI_NAME_ALT"
  fi
  if ! echo "$PYPI_JSON" | jq -e '.data' &>/dev/null 2>&1; then
    PYPI_NAME_ALT=$(echo "$PYPI_NAME" | tr '-' '_')
    PYPI_JSON=$(curl -sf "https://pypistats.org/api/packages/$PYPI_NAME_ALT/recent" 2>/dev/null || echo "")
    echo "$PYPI_JSON" | jq -e '.data' &>/dev/null 2>&1 && PYPI_NAME="$PYPI_NAME_ALT"
  fi
  if echo "$PYPI_JSON" | jq -e '.data' &>/dev/null 2>&1; then
    OUTPUT="Package: $PYPI_NAME
$(echo "$PYPI_JSON" | jq '{last_day: .data.last_day, last_week: .data.last_week, last_month: .data.last_month}')"
  else
    OUTPUT="(not a PyPI package, or name differs — tried '$PYPI_NAME')"
  fi
  echo "$OUTPUT"
  echo "$OUTPUT" > "$_CACHE"
fi
echo ""

# npm
echo "npm Download Stats:"
_CACHE="$RAW_DIR/npm_stats.json"
cache_status "npm_stats" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  NPM_OUTPUT=""
  if [ -f "$REPO_DIR/package.json" ]; then
    NPM_NAME=$(jq -r '.name // empty' "$REPO_DIR/package.json" 2>/dev/null || echo "")
    if [ -n "$NPM_NAME" ]; then
      NPM_JSON=$(curl -sf "https://api.npmjs.org/downloads/point/last-week/$NPM_NAME" 2>/dev/null || echo "")
      if echo "$NPM_JSON" | jq -e '.downloads' &>/dev/null 2>&1; then
        NPM_OUTPUT=$(echo "$NPM_JSON" | jq '{weekly_downloads: .downloads, package: .package}')
      else
        NPM_OUTPUT="(npm API returned no data for '$NPM_NAME')"
      fi
    else
      NPM_OUTPUT="(no name field in package.json)"
    fi
  else
    NPM_OUTPUT="(no package.json — not an npm package)"
  fi
  echo "$NPM_OUTPUT"
  echo "$NPM_OUTPUT" > "$_CACHE"
fi
echo ""

# ---------------------------------------------------------------
# Section 6: Local File Analysis (uses persistent repo clone)
# ---------------------------------------------------------------
echo "#### Section 6 — Local Repository Files"
echo "REPO_DIR: $REPO_DIR"
echo ""

echo "Top-level Directory Listing:"
ls -la "$REPO_DIR"
echo ""

echo "Full Directory Tree (depth 3, .git excluded):"
find "$REPO_DIR" -maxdepth 3 \
  -not -path '*/.git' -not -path '*/.git/*' \
  | sort | sed "s|$REPO_DIR||" | sed 's|^/||'
echo ""

echo "README (first 200 lines):"
README=""
for f in README.md README.rst README.txt README; do
  [ -f "$REPO_DIR/$f" ] && README="$REPO_DIR/$f" && break
done
if [ -n "$README" ]; then
  echo "(source: $README)"; head -200 "$README"
else
  echo "(no README found)"
fi
echo ""

echo "Named Adopters / Case Studies:"
for f in ADOPTERS.md ADOPTERS USERS.md USERS COMPANIES.md; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(source: $f)"; cat "$REPO_DIR/$f"; echo ""
  fi
done
if [ -n "$README" ]; then
  echo "--- Production/adoption mentions in README ---"
  grep -iE "(production|used by|powered by|adopted by|trusted by|case study|customer)" \
    "$README" 2>/dev/null | head -20 || echo "(none found)"
fi
echo ""

echo "Breaking Changes in CHANGELOG:"
for f in CHANGELOG.md CHANGELOG.rst CHANGELOG HISTORY.md CHANGES.md RELEASES.md; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(source: $f — breaking-change markers)"
    grep -inE "(breaking|BREAKING CHANGE|incompatible|migration required|removed|deprecated)" \
      "$REPO_DIR/$f" 2>/dev/null | head -30 || echo "(no breaking markers)"
    echo ""; echo "(first 80 lines for cadence)"; head -80 "$REPO_DIR/$f"
    break
  fi
done
echo ""

echo "Package / Project Manifests:"
find "$REPO_DIR" -maxdepth 2 -not -path '*/.git/*' \
  \( -name "package.json" -o -name "Cargo.toml" -o -name "pyproject.toml" \
     -o -name "setup.py" -o -name "setup.cfg" -o -name "requirements*.txt" \
     -o -name "go.mod" -o -name "pom.xml" -o -name "build.gradle" \
     -o -name "Gemfile" -o -name "composer.json" \
     -o -name "CMakeLists.txt" -o -name "Makefile" -o -name "makefile" \
  \) 2>/dev/null | sort
echo ""

echo "CI/CD Configs:"
find "$REPO_DIR" -maxdepth 4 -not -path '*/.git/*' \
  \( \( -name "*.yml" -o -name "*.yaml" \) -path "*/.github/workflows/*" \
     -o -name "Jenkinsfile" -o -name ".travis.yml" \
     -o -name "azure-pipelines.yml" -o -name ".gitlab-ci.yml" \
     -o -path "*/.circleci/config.yml" \
  \) 2>/dev/null | sort
echo ""

echo "Community & Governance Health Files:"
for f in CONTRIBUTING.md CONTRIBUTING.rst CODE_OF_CONDUCT.md SECURITY.md \
          GOVERNANCE.md MAINTAINERS CODEOWNERS ROADMAP.md; do
  [ -f "$REPO_DIR/$f" ]        && echo "  FOUND: $f"
  [ -f "$REPO_DIR/.github/$f" ] && echo "  FOUND: .github/$f"
done
[ -d "$REPO_DIR/.github" ] && ls "$REPO_DIR/.github/" 2>/dev/null | sed 's/^/  .github\//'
echo ""

echo "License (first 5 lines):"
for f in LICENSE LICENSE.md LICENSE.txt LICENSE.rst COPYING; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(source: $f)"; head -5 "$REPO_DIR/$f"; break
  fi
done
echo ""

# ---------------------------------------------------------------
# Section 6b: Technical Deep-Dive
# ---------------------------------------------------------------
echo "#### Section 6b — Technical Deep-Dive (local)"

echo "Academic Papers & Citations:"
if [ -f "$REPO_DIR/CITATION.cff" ]; then
  echo "(CITATION.cff found)"; cat "$REPO_DIR/CITATION.cff"
elif [ -f "$REPO_DIR/paper.md" ]; then
  echo "(paper.md found — JOSS)"; cat "$REPO_DIR/paper.md"
else
  echo "(no CITATION.cff or paper.md)"
fi
echo ""
echo "Paper/DOI links in README:"
if [ -n "$README" ]; then
  grep -oE '(https?://(arxiv\.org|doi\.org|proceedings\.mlr\.press|aclanthology\.org|openreview\.net|dl\.acm\.org|papers\.nips\.cc)[^)> "]*|arXiv:[0-9]+\.[0-9]+)' \
    "$README" 2>/dev/null | sort -u || echo "(none found)"
fi
echo ""
echo "Blog/announcement links in README:"
if [ -n "$README" ]; then
  grep -oiE 'https?://[^)> "]*blog[^)> "]*' "$README" 2>/dev/null | sort -u || echo "(none found)"
fi
echo ""

echo "Documentation Site:"
if [ -f "$REPO_DIR/mkdocs.yml" ]; then
  echo "(mkdocs.yml found)"
  grep -E '^\s*(site_name|site_url|site_description|repo_url|docs_dir):' \
    "$REPO_DIR/mkdocs.yml" 2>/dev/null | head -10
fi
if [ -f "$REPO_DIR/.readthedocs.yaml" ] || [ -f "$REPO_DIR/.readthedocs.yml" ]; then
  RTD=$(ls "$REPO_DIR"/.readthedocs.y*ml 2>/dev/null | head -1)
  echo "(readthedocs: $RTD)"; head -20 "$RTD" 2>/dev/null
fi
if [ -f "$REPO_DIR/docusaurus.config.js" ] || [ -f "$REPO_DIR/docusaurus.config.ts" ]; then
  DOCU=$(ls "$REPO_DIR"/docusaurus.config.* 2>/dev/null | head -1)
  echo "(docusaurus: $DOCU)"
  grep -E '(url|baseUrl|tagline|title)\s*:' "$DOCU" 2>/dev/null | head -10
fi
echo "Repo homepage: $(echo "$REPO_JSON" | jq -r '.homepage // "(none)"' 2>/dev/null)"
echo ""

echo "Architecture Files & Diagrams:"
for f in ARCHITECTURE.md ARCHITECTURE.rst DESIGN.md docs/architecture.md docs/design.md; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(found: $f)"; head -60 "$REPO_DIR/$f"; echo ""
  fi
done
find "$REPO_DIR" -maxdepth 4 -not -path '*/.git/*' \
  \( -iname "*arch*" -o -iname "*architecture*" -o -iname "*overview*" \
     -o -iname "*diagram*" -o -iname "*flow*" -o -iname "*design*" \) \
  \( -name "*.png" -o -name "*.svg" -o -name "*.jpg" -o -name "*.gif" \) \
  2>/dev/null | sort | head -20 | sed "s|$REPO_DIR/||"
echo ""
echo "Mermaid/PlantUML blocks in docs:"
find "$REPO_DIR" -maxdepth 4 -name "*.md" -not -path '*/.git/*' \
  -exec grep -l '```mermaid\|```plantuml\|@startuml' {} \; 2>/dev/null \
  | sed "s|$REPO_DIR/||" | head -10 || echo "(none found)"
echo ""

echo "Examples Directory:"
if [ -d "$REPO_DIR/examples" ]; then
  echo "(examples/ found)"; ls -1 "$REPO_DIR/examples/" 2>/dev/null | head -30
else
  echo "(no examples/ directory)"
fi
echo ""

# ---------------------------------------------------------------
# Section 7: Local git stats
# ---------------------------------------------------------------
echo "#### Section 7 — Git Stats"
_CACHE="$RAW_DIR/git_stats.txt"
cache_status "git_stats" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  cd "$REPO_DIR"
  GIT_OUTPUT="Total commits (shallow): $(git rev-list --count HEAD 2>/dev/null || echo 'N/A')
Last commit: $(git log -1 --format='%ci  %s' 2>/dev/null)
Unique author emails: $(git log --format='%ae' 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  cd - > /dev/null
  echo "$GIT_OUTPUT"
  echo "$GIT_OUTPUT" > "$_CACHE"
fi
echo ""

# ---------------------------------------------------------------
# Section 8: Community Investment Signals
# ---------------------------------------------------------------
echo "#### Section 8 — Community Investment Signals"
echo ""

echo "Contributor Org Diversity:"
_CACHE="$RAW_DIR/contributor_orgs.txt"
cache_status "contributor_orgs" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  ORG_DIVERSITY=""
  while IFS= read -r login; do
    USER_JSON=$(github_api "users/$login" 2>/dev/null || echo "{}")
    COMPANY=$(echo "$USER_JSON" | jq -r '.company // "(none)"' 2>/dev/null)
    ORG_DIVERSITY="${ORG_DIVERSITY}  ${login}: ${COMPANY}
"
  done < <(echo "$CONTRIB_JSON" | jq -r '[.[] | .login][]' 2>/dev/null)
  [ -z "$ORG_DIVERSITY" ] && ORG_DIVERSITY="(could not fetch contributor orgs)"
  printf "%s" "$ORG_DIVERSITY"
  printf "%s" "$ORG_DIVERSITY" > "$_CACHE"
fi
echo ""

echo "External vs Internal PR Merge Time (last 20 merged PRs):"
_CACHE="$RAW_DIR/pr_merge_times.json"
cache_status "pr_merge_times" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  PR_MERGE=$(github_api "repos/$REPO/pulls?state=closed&sort=updated&direction=desc&per_page=20" \
    | jq '[.[] | select(.merged_at != null) | {
        number: .number,
        author: .user.login,
        author_association: .author_association,
        created: .created_at,
        merged: .merged_at,
        title: (.title | if length > 60 then .[:60] + "..." else . end)
      }]' 2>/dev/null || echo "[]")
  echo "$PR_MERGE"
  echo "$PR_MERGE" > "$_CACHE"
fi
echo ""

echo "Good First Issues:"
_CACHE="$RAW_DIR/good_first_issues.json"
cache_status "good_first_issues" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  GFI_JSON=$(github_api "repos/$REPO/issues?labels=good+first+issue&state=open&per_page=10" 2>/dev/null \
    || github_api "repos/$REPO/issues?labels=good-first-issue&state=open&per_page=10" 2>/dev/null \
    || echo "[]")
  GFI_OUT=$(echo "$GFI_JSON" | jq '{
    count: length,
    sample: [.[:5][] | {number: .number, title: .title, created: .created_at}]
  }' 2>/dev/null || echo "(no good first issues found)")
  echo "$GFI_OUT"
  echo "$GFI_OUT" > "$_CACHE"
fi
echo ""

echo "CONTRIBUTING.md:"
for f in CONTRIBUTING.md .github/CONTRIBUTING.md; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(found: $f — first 80 lines)"; head -80 "$REPO_DIR/$f"; break
  fi
done
[ ! -f "$REPO_DIR/CONTRIBUTING.md" ] && [ ! -f "$REPO_DIR/.github/CONTRIBUTING.md" ] \
  && echo "(no CONTRIBUTING.md)"
echo ""

echo "GOVERNANCE.md:"
for f in GOVERNANCE.md .github/GOVERNANCE.md; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(found: $f — first 80 lines)"; head -80 "$REPO_DIR/$f"; break
  fi
done
[ ! -f "$REPO_DIR/GOVERNANCE.md" ] && [ ! -f "$REPO_DIR/.github/GOVERNANCE.md" ] \
  && echo "(no GOVERNANCE.md)"
echo ""

echo "MAINTAINERS / CODEOWNERS:"
for f in MAINTAINERS MAINTAINERS.md .github/CODEOWNERS CODEOWNERS; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(found: $f)"; cat "$REPO_DIR/$f"; echo ""
  fi
done
echo ""

echo "Community Meeting / Communication Links:"
if [ -n "$README" ]; then
  grep -iE "(community meeting|office hours|slack|discord|mailing list|forum|gitter|matrix|zulip|discuss)" \
    "$README" 2>/dev/null | head -15 || echo "(none found)"
fi
echo ""

echo "CLA / DCO Requirements:"
CLA_FOUND=false
for f in CLA.md .github/CLA.md DCO .github/DCO; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(found: $f)"; head -20 "$REPO_DIR/$f"; CLA_FOUND=true; echo ""
  fi
done
if [ "$CLA_FOUND" = false ]; then
  for f in CONTRIBUTING.md .github/CONTRIBUTING.md; do
    if [ -f "$REPO_DIR/$f" ]; then
      grep -iE "(CLA|DCO|contributor license|developer certificate|sign.off)" \
        "$REPO_DIR/$f" 2>/dev/null | head -5
    fi
  done
fi
echo ""

# ---------------------------------------------------------------
# Section 9: Extended Package Ecosystems
# ---------------------------------------------------------------
echo "#### Section 9 — Extended Package Ecosystems"
echo ""

echo "Docker Hub:"
_CACHE="$RAW_DIR/docker_stats.json"
cache_status "docker_stats" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  DOCKER_JSON=$(curl -sf "https://hub.docker.com/v2/repositories/$OWNER/$REPONAME/" 2>/dev/null \
    || curl -sf "https://hub.docker.com/v2/repositories/library/$REPONAME/" 2>/dev/null \
    || echo "")
  if echo "$DOCKER_JSON" | jq -e '.pull_count' &>/dev/null 2>&1; then
    OUT=$(echo "$DOCKER_JSON" | jq '{
      full_name: .full_name, pull_count: .pull_count,
      star_count: .star_count, last_updated: .last_updated
    }' 2>/dev/null)
  else
    OUT="(not found on Docker Hub — tried $OWNER/$REPONAME and library/$REPONAME)"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "Homebrew:"
_CACHE="$RAW_DIR/homebrew_stats.json"
cache_status "homebrew_stats" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  BREW_JSON=$(curl -sf "https://formulae.brew.sh/api/formula/$REPONAME.json" 2>/dev/null \
    || curl -sf "https://formulae.brew.sh/api/cask/$REPONAME.json" 2>/dev/null || echo "")
  if echo "$BREW_JSON" | jq -e '.name' &>/dev/null 2>&1; then
    OUT=$(echo "$BREW_JSON" | jq '{
      name: .name, desc: .desc,
      installs_30d: .analytics.install["30d"],
      installs_365d: .analytics.install["365d"]
    }' 2>/dev/null || echo "$BREW_JSON" | jq '{name: .name, desc: .desc}' 2>/dev/null)
  else
    OUT="(not found on Homebrew)"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "conda-forge:"
_CACHE="$RAW_DIR/conda_stats.json"
cache_status "conda_stats" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  CONDA_JSON=$(curl -sf "https://api.anaconda.org/package/conda-forge/$REPONAME" 2>/dev/null || echo "")
  if echo "$CONDA_JSON" | jq -e '.name' &>/dev/null 2>&1; then
    OUT=$(echo "$CONDA_JSON" | jq '{
      name: .name, summary: .summary, downloads: .downloads, last_modified: .modified_at
    }' 2>/dev/null)
  else
    OUT="(not found on conda-forge)"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "Libraries.io (dependency ecosystem):"
LIBRARIESIO_ECOSYSTEM=""
{ [ -f "$REPO_DIR/pyproject.toml" ] || [ -f "$REPO_DIR/setup.py" ]; } && LIBRARIESIO_ECOSYSTEM="pypi"
[ -f "$REPO_DIR/package.json" ] && LIBRARIESIO_ECOSYSTEM="npm"
[ -f "$REPO_DIR/Cargo.toml" ]   && LIBRARIESIO_ECOSYSTEM="cargo"
[ -f "$REPO_DIR/go.mod" ]       && LIBRARIESIO_ECOSYSTEM="go"
[ -f "$REPO_DIR/Gemfile" ]      && LIBRARIESIO_ECOSYSTEM="rubygems"
if [ -n "$LIBRARIESIO_ECOSYSTEM" ]; then
  if [ -n "$LIBRARIES_IO_KEY" ]; then
    LIO_JSON=$(curl -sf \
      "https://libraries.io/api/$LIBRARIESIO_ECOSYSTEM/$REPONAME?api_key=$LIBRARIES_IO_KEY" \
      2>/dev/null || echo "")
    if echo "$LIO_JSON" | jq -e '.rank' &>/dev/null 2>&1; then
      echo "$LIO_JSON" | jq '{
        name: .name, platform: .platform, rank: .rank,
        dependents_count: .dependents_count,
        dependent_repos_count: .dependent_repos_count
      }' 2>/dev/null
    else
      echo "Manual URL: https://libraries.io/$LIBRARIESIO_ECOSYSTEM/$REPONAME"
    fi
  else
    echo "Ecosystem: $LIBRARIESIO_ECOSYSTEM"
    echo "Manual URL: https://libraries.io/$LIBRARIESIO_ECOSYSTEM/$REPONAME"
    echo "(add LIBRARIES_IO_KEY to config for automated lookup)"
  fi
else
  echo "(ecosystem not detected)"
fi
echo ""

echo "deps.dev (Google Open Source Insights):"
_CACHE="$RAW_DIR/depsdev.json"
cache_status "depsdev" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  DEPSDEV_SYSTEM="" DEPSDEV_NAME="$REPONAME"
  if [ -f "$REPO_DIR/pyproject.toml" ]; then
    DEPSDEV_SYSTEM="PYPI"
    DD_PARSED=$(grep -E '^\s*name\s*=' "$REPO_DIR/pyproject.toml" 2>/dev/null \
      | head -1 | sed 's/.*name\s*=\s*["\x27]//' | sed 's/["\x27].*//' | tr -d ' ' || true)
    [ -n "$DD_PARSED" ] && DEPSDEV_NAME="$DD_PARSED"
  elif [ -f "$REPO_DIR/package.json" ]; then
    DEPSDEV_SYSTEM="NPM"
    DD_PARSED=$(jq -r '.name // empty' "$REPO_DIR/package.json" 2>/dev/null || echo "")
    [ -n "$DD_PARSED" ] && DEPSDEV_NAME="$DD_PARSED"
  elif [ -f "$REPO_DIR/go.mod" ]; then
    DEPSDEV_SYSTEM="GO"
    DD_PARSED=$(grep '^module ' "$REPO_DIR/go.mod" 2>/dev/null | head -1 | awk '{print $2}' || echo "")
    [ -n "$DD_PARSED" ] && DEPSDEV_NAME="$DD_PARSED"
  fi
  if [ -n "$DEPSDEV_SYSTEM" ]; then
    DD_JSON=$(curl -sf \
      "https://api.deps.dev/v3/systems/${DEPSDEV_SYSTEM}/packages/${DEPSDEV_NAME}" \
      2>/dev/null || echo "")
    if echo "$DD_JSON" | jq -e '.packageKey' &>/dev/null 2>&1; then
      OUT=$(echo "$DD_JSON" | jq '{
        name: .packageKey.name, system: .packageKey.system,
        versions_count: (.versions | length),
        latest: (.versions | sort_by(.publishedAt) | last | {version: .versionKey.version, published: .publishedAt})
      }' 2>/dev/null)
      OUT="${OUT}
Graph: https://deps.dev/$DEPSDEV_SYSTEM/$DEPSDEV_NAME"
    else
      OUT="(deps.dev: no data for $DEPSDEV_SYSTEM/$DEPSDEV_NAME)
Graph: https://deps.dev/$DEPSDEV_SYSTEM/$DEPSDEV_NAME"
    fi
  else
    OUT="(ecosystem not detected for deps.dev)"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

# ---------------------------------------------------------------
# Section 10: Search & Community Signals
# ---------------------------------------------------------------
echo "#### Section 10 — Search & Community Signals"
echo ""

echo "Stack Overflow Tag Stats:"
_CACHE="$RAW_DIR/stackoverflow.json"
cache_status "stackoverflow" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  SO_TAG=$(echo "$REPONAME" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
  SO_JSON=$(curl -sf \
    "https://api.stackexchange.com/2.3/tags/$SO_TAG/info?site=stackoverflow" \
    2>/dev/null || echo "")
  if echo "$SO_JSON" | jq -e '.items[0]' &>/dev/null 2>&1; then
    OUT=$(echo "$SO_JSON" | jq '.items[0] | {
      tag: .name, total_questions: .count, has_synonyms: .has_synonyms
    }' 2>/dev/null)
  else
    OUT="(tag '$SO_TAG' not found on Stack Overflow)"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "Hacker News Mentions (Algolia):"
_CACHE="$RAW_DIR/hackernews.json"
cache_status "hackernews" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  HN_Q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPONAME'))" 2>/dev/null \
    || echo "$REPONAME")
  HN_JSON=$(curl -sf \
    "https://hn.algolia.com/api/v1/search?query=$HN_Q&tags=story&hitsPerPage=5" \
    2>/dev/null || echo "")
  if echo "$HN_JSON" | jq -e '.hits' &>/dev/null 2>&1; then
    OUT=$(echo "$HN_JSON" | jq '{
      total_hits: .nbHits,
      sample: [.hits[:5][] | {title: .title, points: .points, comments: .num_comments, date: .created_at}]
    }' 2>/dev/null)
  else
    OUT="(could not fetch HN data)"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "Dev.to Articles:"
_CACHE="$RAW_DIR/devto.json"
cache_status "devto" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  DEVTO_TAG=$(echo "$REPONAME" | tr '[:upper:]' '[:lower:]' | tr -d '[-_]')
  DEVTO_JSON=$(curl -sf "https://dev.to/api/articles?tag=$DEVTO_TAG&per_page=5&top=1" 2>/dev/null || echo "")
  if echo "$DEVTO_JSON" | jq -e '.[0]' &>/dev/null 2>&1; then
    OUT=$(echo "$DEVTO_JSON" | jq '{
      count_in_sample: length,
      tag_page: "https://dev.to/t/'"$DEVTO_TAG"'",
      sample: [.[:5][] | {title: .title, published: .published_at, reactions: .positive_reactions_count}]
    }' 2>/dev/null)
  else
    OUT="(no Dev.to articles for tag '$DEVTO_TAG')"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "Google Trends (manual):"
echo "  https://trends.google.com/trends/explore?q=$REPONAME&date=today%205-y"
echo "  (No public API — check manually for 5-year trend and geographic spread)"
echo ""

# ---------------------------------------------------------------
# Section 11: Security Health
# ---------------------------------------------------------------
echo "#### Section 11 — Security Health"
echo ""

echo "OpenSSF Scorecard:"
_CACHE="$RAW_DIR/openssf.json"
cache_status "openssf" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  SC_JSON=$(curl -sf "https://api.securityscorecards.dev/projects/github.com/$REPO" 2>/dev/null || echo "")
  if echo "$SC_JSON" | jq -e '.score' &>/dev/null 2>&1; then
    OUT=$(echo "$SC_JSON" | jq '{
      score: .score, date: .date,
      checks: [.checks[] | {name: .name, score: .score, reason: .reason}]
    }' 2>/dev/null)
  else
    OUT="(not indexed — run: scorecard --repo=github.com/$REPO)
Check: https://securityscorecards.dev/#/github.com/$REPO"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "OSV Vulnerability Database:"
_CACHE="$RAW_DIR/osv.json"
cache_status "osv" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  OSV_ECOSYSTEM="" OSV_NAME="$REPONAME"
  { [ -f "$REPO_DIR/pyproject.toml" ] || [ -f "$REPO_DIR/setup.py" ]; } && OSV_ECOSYSTEM="PyPI"
  [ -f "$REPO_DIR/package.json" ] && OSV_ECOSYSTEM="npm" \
    && OSV_NAME=$(jq -r '.name // empty' "$REPO_DIR/package.json" 2>/dev/null || echo "$REPONAME")
  [ -f "$REPO_DIR/go.mod" ]    && OSV_ECOSYSTEM="Go"
  [ -f "$REPO_DIR/Cargo.toml" ] && OSV_ECOSYSTEM="crates.io"
  if [ -n "$OSV_ECOSYSTEM" ]; then
    OSV_RESP=$(curl -sf -X POST "https://api.osv.dev/v1/query" \
      -H "Content-Type: application/json" \
      -d "{\"package\": {\"name\": \"$OSV_NAME\", \"ecosystem\": \"$OSV_ECOSYSTEM\"}}" \
      2>/dev/null || echo "")
  else
    OSV_RESP=$(curl -sf -X POST "https://api.osv.dev/v1/query" \
      -H "Content-Type: application/json" \
      -d "{\"package\": {\"name\": \"github.com/$REPO\"}}" \
      2>/dev/null || echo "")
  fi
  if echo "$OSV_RESP" | jq -e '.vulns' &>/dev/null 2>&1; then
    OUT=$(echo "$OSV_RESP" | jq '{
      ecosystem: "'"${OSV_ECOSYSTEM:-github}"'", package: "'"$OSV_NAME"'",
      total_vulnerabilities: (.vulns | length),
      vulns: [.vulns[:5][] | {id: .id, summary: .summary, published: .published}]
    }' 2>/dev/null)
  else
    OUT="(no vulnerabilities found for ${OSV_ECOSYSTEM:-github}/$OSV_NAME)"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "NVD CVE History:"
_CACHE="$RAW_DIR/nvd.json"
cache_status "nvd" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  NVD_ENC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPONAME'))" 2>/dev/null \
    || echo "$REPONAME")
  NVD_JSON=$(curl -sf \
    "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=$NVD_ENC&resultsPerPage=5" \
    2>/dev/null || echo "")
  if echo "$NVD_JSON" | jq -e '.totalResults' &>/dev/null 2>&1; then
    OUT=$(echo "$NVD_JSON" | jq '{
      total_cves: .totalResults,
      sample: [.vulnerabilities[:5][] | {
        id: .cve.id, published: .cve.published,
        severity: (.cve.metrics.cvssMetricV31[0].cvssData.baseSeverity // .cve.metrics.cvssMetricV2[0].baseSeverity // "N/A"),
        description: (.cve.descriptions[] | select(.lang=="en") | .value | if length > 100 then .[:100]+"..." else . end)
      }]
    }' 2>/dev/null)
  else
    OUT="(could not fetch NVD data)"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

# ---------------------------------------------------------------
# Section 12: Foundation & Governance Status
# ---------------------------------------------------------------
echo "#### Section 12 — Foundation & Governance Status"
echo ""

echo "CNCF Landscape:"
_CACHE="$RAW_DIR/cncf.json"
cache_status "cncf" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  CNCF_DATA=$(curl -sf \
    "https://raw.githubusercontent.com/cncf/landscape/master/hosted_data/projects.json" \
    2>/dev/null || echo "")
  if echo "$CNCF_DATA" | jq -e '.' &>/dev/null 2>&1; then
    CNCF_MATCH=$(echo "$CNCF_DATA" | jq \
      "[.[] | select(.name | ascii_downcase | contains(\"$(echo $REPONAME | tr '[:upper:]' '[:lower:]')\"))] | .[0]" \
      2>/dev/null || echo "null")
    if [ "$CNCF_MATCH" != "null" ] && [ -n "$CNCF_MATCH" ]; then
      OUT=$(echo "$CNCF_MATCH" | jq '{name: .name, project: .project, category: .category}' 2>/dev/null)
    else
      OUT="(not in CNCF landscape for '$REPONAME')"
    fi
  else
    OUT="(could not fetch CNCF data)"
  fi
  OUT="${OUT}
Manual: https://landscape.cncf.io/?selected=$REPONAME"
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "Apache Software Foundation:"
_CACHE="$RAW_DIR/asf.json"
cache_status "asf" "$_CACHE"
if cache_is_fresh "$_CACHE"; then
  cat "$_CACHE"
else
  ASF_JSON=$(curl -sf "https://projects.apache.org/json/foundation/projects.json" 2>/dev/null || echo "")
  if echo "$ASF_JSON" | jq -e '.' &>/dev/null 2>&1; then
    ASF_MATCH=$(echo "$ASF_JSON" | jq \
      "[to_entries[] | select(.key | ascii_downcase | contains(\"$(echo $REPONAME | tr '[:upper:]' '[:lower:]')\"))] | .[0]" \
      2>/dev/null || echo "null")
    if [ "$ASF_MATCH" != "null" ] && [ -n "$ASF_MATCH" ]; then
      OUT=$(echo "$ASF_MATCH" | jq '{name: .key, description: .value.description}' 2>/dev/null)
    else
      OUT="(not in Apache Software Foundation for '$REPONAME')"
    fi
  else
    OUT="(could not fetch ASF data)"
  fi
  echo "$OUT"; echo "$OUT" > "$_CACHE"
fi
echo ""

echo "Other Foundations (manual):"
echo "  Linux Foundation: https://www.linuxfoundation.org/projects"
echo "  OpenSSF: https://openssf.org/community/projects/"
echo "  Eclipse: https://projects.eclipse.org"
echo ""

# ---------------------------------------------------------------
# Section 13: Commercial Intelligence
# ---------------------------------------------------------------
echo "#### Section 13 — Commercial Intelligence"
echo ""

echo "Crunchbase:"
echo "  Org: $OWNER | GitHub type: $(echo "$ORG_JSON" | jq -r '.type // "unknown"' 2>/dev/null)"
echo "  Blog: $(echo "$ORG_JSON" | jq -r '.blog // "(none)"' 2>/dev/null)"
echo "  Manual: https://www.crunchbase.com/organization/$OWNER"
echo ""

echo "YouTube Content:"
YT_Q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPONAME tutorial'))" 2>/dev/null \
  || echo "$REPONAME+tutorial")
echo "  https://www.youtube.com/results?search_query=$YT_Q"
if [ -n "${YOUTUBE_API_KEY:-}" ]; then
  YT_ENC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPONAME'))" 2>/dev/null \
    || echo "$REPONAME")
  YT_JSON=$(curl -sf \
    "https://www.googleapis.com/youtube/v3/search?part=snippet&q=$YT_ENC&type=video&order=viewCount&maxResults=5&key=$YOUTUBE_API_KEY" \
    2>/dev/null || echo "")
  if echo "$YT_JSON" | jq -e '.items' &>/dev/null 2>&1; then
    echo "Top videos by view count:"
    echo "$YT_JSON" | jq '[.items[:5][] | {
      title: .snippet.title, channel: .snippet.channelTitle, published: .snippet.publishedAt
    }]' 2>/dev/null
  fi
fi
echo ""

# ---------------------------------------------------------------
# Write cache metadata
# ---------------------------------------------------------------
FETCH_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$CACHE_DIR/meta.json" <<EOF
{
  "repo": "$REPO",
  "owner": "$OWNER",
  "reponame": "$REPONAME",
  "fetched_at": "$FETCH_TS",
  "script_version": "2.0",
  "max_age_days": $MAX_AGE_DAYS,
  "cache_dir": "$CACHE_DIR",
  "raw_dir": "$RAW_DIR",
  "repo_dir": "$REPO_DIR"
}
EOF

# ---------------------------------------------------------------
# Final output
# ---------------------------------------------------------------
echo "=== Data Collection Complete ==="
echo ""
echo "CACHE_DIR=$CACHE_DIR"
echo "RAW_DIR=$RAW_DIR"
echo "LOCAL_REPO_PATH=$REPO_DIR"
echo "FETCHED_AT=$FETCH_TS"
echo ""
echo "Phase 2 (Analysis): read raw cache files and save notes to:"
echo "  $CACHE_DIR/analysis/{section}.md"
echo "Phase 3 (Reports):  write to ./reports/${CACHE_SLUG}/"
