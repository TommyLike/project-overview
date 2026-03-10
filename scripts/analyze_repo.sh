#!/usr/bin/env bash
# GitHub Project Analyzer Script
# Usage: ./analyze_repo.sh <github-url-or-owner/repo>
# Requires: git, jq, curl; optionally: gh CLI (authenticated)
#
# Token config file: ~/.config/github-analyzer/config
# Format:  GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

set -e

# Trap unexpected exits to give a helpful message instead of silent failure
trap 'echo "" >&2; echo "ERROR: Script exited unexpectedly at line $LINENO. Run with: bash -x $0 $* 2>&1 | head -80" >&2' ERR

INPUT="${1:-}"

if [ -z "$INPUT" ]; then
  echo "Usage: $0 <github-url-or-owner/repo>" >&2
  exit 1
fi

# Normalize input: extract owner/repo from URL or use directly
REPO=$(echo "$INPUT" | sed -E 's|https?://github\.com/||' | sed 's|\.git$||' | sed 's|/$||')
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPONAME=$(echo "$REPO" | cut -d'/' -f2)
CLONE_URL="https://github.com/${REPO}.git"

echo "=== GitHub Project Analyzer: $REPO ==="
echo ""

# ---------------------------------------------------------------
# Auth: load config file, validate token, set AUTH_METHOD
# ---------------------------------------------------------------

# Config file locations (checked in order):
#   1. ~/.config/github-analyzer/config   (primary, user-level)
#   2. <script-dir>/../config             (project-local fallback)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PRIMARY="${HOME}/.config/github-analyzer/config"
CONFIG_LOCAL="${SCRIPT_DIR}/../config"

# Load GITHUB_TOKEN from config file (if not already set in environment)
_load_config() {
  local cfg="$1"
  [ -f "$cfg" ] || return 1
  while IFS= read -r line; do
    # Strip leading whitespace and skip comments/empty lines
    line="${line#"${line%%[! ]*}"}"
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
    local key="${line%%=*}"
    local val="${line#*=}"
    # Strip surrounding quotes from value
    val="${val#\"}" ; val="${val%\"}"
    val="${val#\'}" ; val="${val%\'}"
    case "$key" in
      GITHUB_TOKEN) [ -z "$GITHUB_TOKEN" ] && GITHUB_TOKEN="$val" ;;
    esac
  done < "$cfg"
}

: "${GITHUB_TOKEN:=}"   # initialise to empty if unset

# Use || true so set -e doesn't exit when config files are absent
_load_config "$CONFIG_PRIMARY" || true
_load_config "$CONFIG_LOCAL" || true

# Validate the token with a lightweight API call; set AUTH_METHOD accordingly
AUTH_METHOD=""
TOKEN_VALID=false

_check_token() {
  local token="$1"
  local tmp
  tmp=$(mktemp)
  local http_code
  http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
    "https://api.github.com/user" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" 2>/dev/null)
  rm -f "$tmp"
  echo "$http_code"
}

echo "### Auth Status"
if [ -n "$GITHUB_TOKEN" ]; then
  echo -n "  Token found (source: config/env) — validating ... "
  HTTP_CODE=$(_check_token "$GITHUB_TOKEN")
  case "$HTTP_CODE" in
    200)
      echo "✓ valid"
      TOKEN_VALID=true
      AUTH_METHOD="token"
      ;;
    401)
      echo "✗ INVALID"
      echo ""
      echo "  ╔══════════════════════════════════════════════════════════════╗"
      echo "  ║  ⚠️  GITHUB TOKEN ERROR: Token is invalid or expired (401)  ║"
      echo "  ║                                                              ║"
      echo "  ║  To fix: update GITHUB_TOKEN in your config file:           ║"
      echo "  ║    ${CONFIG_PRIMARY}"
      echo "  ║                                                              ║"
      echo "  ║  Get a new token at:                                         ║"
      echo "  ║    https://github.com/settings/tokens                        ║"
      echo "  ║                                                              ║"
      echo "  ║  Falling back to unauthenticated (60 req/hr limit).          ║"
      echo "  ╚══════════════════════════════════════════════════════════════╝"
      echo ""
      GITHUB_TOKEN=""
      AUTH_METHOD="unauthenticated"
      ;;
    403)
      echo "✗ FORBIDDEN"
      echo ""
      echo "  ╔══════════════════════════════════════════════════════════════╗"
      echo "  ║  ⚠️  GITHUB TOKEN ERROR: Token is forbidden (403)           ║"
      echo "  ║                                                              ║"
      echo "  ║  Your token lacks required permissions.                      ║"
      echo "  ║  For public repos: no scope needed (try a fine-grained       ║"
      echo "  ║  token with 'Public Repositories' read access).              ║"
      echo "  ║  For private repos: add 'repo' scope.                        ║"
      echo "  ║                                                              ║"
      echo "  ║  Regenerate at: https://github.com/settings/tokens           ║"
      echo "  ║  Falling back to unauthenticated (60 req/hr limit).          ║"
      echo "  ╚══════════════════════════════════════════════════════════════╝"
      echo ""
      GITHUB_TOKEN=""
      AUTH_METHOD="unauthenticated"
      ;;
    *)
      echo "✗ unexpected response (HTTP $HTTP_CODE)"
      echo "  Falling back to unauthenticated mode."
      GITHUB_TOKEN=""
      AUTH_METHOD="unauthenticated"
      ;;
  esac
elif command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  echo "  No config token — using gh CLI (authenticated)"
  AUTH_METHOD="gh"
else
  echo "  No token configured and gh CLI not authenticated."
  echo ""
  echo "  ╔══════════════════════════════════════════════════════════════╗"
  echo "  ║  ℹ️  Running unauthenticated (60 API requests/hour limit)   ║"
  echo "  ║                                                              ║"
  echo "  ║  To avoid rate limits, add a GitHub token:                  ║"
  echo "  ║    mkdir -p ~/.config/github-analyzer                        ║"
  echo "  ║    echo 'GITHUB_TOKEN=ghp_xxx' > ~/.config/github-analyzer/config  ║"
  echo "  ║                                                              ║"
  echo "  ║  Get a token (no scopes needed for public repos):            ║"
  echo "  ║    https://github.com/settings/tokens                        ║"
  echo "  ╚══════════════════════════════════════════════════════════════╝"
  echo ""
  AUTH_METHOD="unauthenticated"
fi
echo ""

# ---------------------------------------------------------------
# Helper: call GitHub API with correct auth method
# ---------------------------------------------------------------
github_api() {
  local endpoint="$1"
  local tmp body http_code

  if [ "$AUTH_METHOD" = "token" ]; then
    tmp=$(mktemp)
    http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
      "https://api.github.com/$endpoint" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" 2>/dev/null)
    body=$(cat "$tmp")
    rm -f "$tmp"

    case "$http_code" in
      200|201|204)
        echo "$body"
        ;;
      401)
        echo "" >&2
        echo "  ⚠️  Token auth failed mid-run (401). Token may have been revoked." >&2
        echo "     Update: ${CONFIG_PRIMARY}" >&2
        echo "" >&2
        return 1
        ;;
      403)
        echo "" >&2
        echo "  ⚠️  Token forbidden for this endpoint (403): $endpoint" >&2
        echo "" >&2
        return 1
        ;;
      404)
        # Repo not found or private — not a token error
        echo "$body"
        ;;
      *)
        echo "" >&2
        echo "  ⚠️  GitHub API returned HTTP $http_code for: $endpoint" >&2
        return 1
        ;;
    esac

  elif [ "$AUTH_METHOD" = "gh" ]; then
    gh api "$endpoint" 2>/dev/null

  else
    # Unauthenticated
    tmp=$(mktemp)
    http_code=$(curl -s -o "$tmp" -w "%{http_code}" \
      "https://api.github.com/$endpoint" \
      -H "Accept: application/vnd.github+json" 2>/dev/null)
    body=$(cat "$tmp")
    rm -f "$tmp"

    if [ "$http_code" = "403" ]; then
      echo "" >&2
      echo "  ⚠️  GitHub API rate limit hit (unauthenticated, 60 req/hr)." >&2
      echo "     Add a token to avoid this:" >&2
      echo "       mkdir -p ~/.config/github-analyzer" >&2
      echo "       echo 'GITHUB_TOKEN=ghp_xxx' > ~/.config/github-analyzer/config" >&2
      echo "" >&2
      return 1
    fi
    echo "$body"
  fi
}

# ---------------------------------------------------------------
# SECTION 0: Clone to temp directory
# ---------------------------------------------------------------
TEMP_DIR=$(mktemp -d /tmp/github-analyzer-XXXXXX)
echo "### Cloning repository to local temp dir"
echo "Clone URL : $CLONE_URL"
echo "Local path: $TEMP_DIR/repo"
echo ""

if ! git clone --depth=1 --quiet "$CLONE_URL" "$TEMP_DIR/repo" 2>&1; then
  echo "ERROR: Failed to clone $CLONE_URL" >&2
  rm -rf "$TEMP_DIR"
  exit 1
fi
REPO_DIR="$TEMP_DIR/repo"
echo "Clone complete."
echo ""

# ---------------------------------------------------------------
# SECTION 1: Core GitHub metadata
# ---------------------------------------------------------------

echo "### Repository Info (GitHub API)"
REPO_JSON=$(github_api "repos/$REPO" || echo "{}")
echo "$REPO_JSON" | jq '{
  name: .name,
  description: .description,
  url: .html_url,
  homepage: .homepage,
  owner_type: .owner.type,
  owner_login: .owner.login,
  stars: .stargazers_count,
  forks: .forks_count,
  watchers: .subscribers_count,
  open_issues: .open_issues_count,
  primary_language: .language,
  license: .license.name,
  license_spdx: .license.spdx_id,
  created_at: .created_at,
  last_pushed: .pushed_at,
  default_branch: .default_branch,
  archived: .archived,
  fork: .fork,
  topics: .topics,
  network_count: .network_count,
  subscribers_count: .subscribers_count
}' 2>/dev/null || echo "(could not parse repo info)"
echo ""

# ---------------------------------------------------------------
# SECTION 2: Organizational & Backing Info
# ---------------------------------------------------------------

echo "### Organization / Owner Info"
ORG_JSON=$(github_api "orgs/$OWNER" 2>/dev/null || github_api "users/$OWNER" 2>/dev/null || echo "{}")
echo "$ORG_JSON" | jq '{
  name: .name,
  blog: .blog,
  location: .location,
  description: .description,
  company: .company,
  email: .email,
  twitter_username: .twitter_username,
  public_repos: .public_repos,
  followers: .followers,
  type: .type,
  created_at: .created_at
}' 2>/dev/null || echo "(could not fetch org info)"
echo ""

echo "### Sponsorship / Funding"
if [ -f "$REPO_DIR/.github/FUNDING.yml" ]; then
  echo "(FUNDING.yml found)"
  cat "$REPO_DIR/.github/FUNDING.yml"
else
  echo "(no FUNDING.yml)"
fi
echo ""

# ---------------------------------------------------------------
# SECTION 3: Contributor analysis (bus factor signals)
# ---------------------------------------------------------------

echo "### Top Contributors (up to 15)"
CONTRIB_JSON=$(github_api "repos/$REPO/contributors?per_page=15" || echo "[]")
echo "$CONTRIB_JSON" | jq '[.[] | {login: .login, contributions: .contributions}]' 2>/dev/null \
  || echo "(unavailable)"

# Bus factor: top-3 share
echo ""
echo "### Bus Factor Signal"
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
  else "no contributor data"
  end
' 2>/dev/null || echo "(could not compute)"
echo ""

# ---------------------------------------------------------------
# SECTION 4: Activity & Release Health
# ---------------------------------------------------------------

echo "### Recent Releases (up to 8)"
github_api "repos/$REPO/releases?per_page=8" \
  | jq '[.[] | {tag: .tag_name, name: .name, published: .published_at, prerelease: .prerelease}]' \
  2>/dev/null || echo "(no releases)"
echo ""

echo "### Open Pull Requests — count and oldest unreviewed"
PR_JSON=$(github_api "repos/$REPO/pulls?state=open&per_page=100" || echo "[]")
echo "$PR_JSON" | jq '
  {
    open_pr_count: length,
    oldest_pr_created: (if length > 0 then (. | sort_by(.created_at) | .[0].created_at) else null end),
    sample_titles: [.[:5][] | .title]
  }
' 2>/dev/null || echo "(unavailable)"
echo ""

echo "### Recent Closed Issues (response time sample)"
github_api "repos/$REPO/issues?state=closed&per_page=5&sort=updated" \
  | jq '[.[] | {number: .number, title: .title, created: .created_at, closed: .closed_at}]' \
  2>/dev/null || echo "(unavailable)"
echo ""

echo "### Repository Topics"
echo "$REPO_JSON" | jq '.topics' 2>/dev/null || echo "[]"
echo ""

# ---------------------------------------------------------------
# SECTION 5: Ecosystem & Adoption metrics
# ---------------------------------------------------------------

echo "### GitHub Dependents (approximate)"
# GitHub dependents page — parse count from network tab (best available without auth)
DEPENDENTS_PAGE=$(curl -sf "https://github.com/$REPO/network/dependents" \
  -H "Accept: text/html" 2>/dev/null || echo "")
if [ -n "$DEPENDENTS_PAGE" ]; then
  echo "$DEPENDENTS_PAGE" | grep -oE '[0-9,]+ Repositories' | head -1 \
    | sed 's/ Repositories/ repositories depend on this package/' \
    || echo "(could not parse dependent count)"
else
  echo "(could not fetch dependents page)"
fi
echo ""

echo "### PyPI Download Stats (if Python package)"
# Derive package name: try repo name, then check setup.py/pyproject.toml
PYPI_NAME="$REPONAME"
if [ -f "$REPO_DIR/pyproject.toml" ]; then
  # Match 'name = "..."' in both root scope and under [project] or [tool.poetry]
  PYPI_NAME_PARSED=$(grep -E '^\s*name\s*=' "$REPO_DIR/pyproject.toml" 2>/dev/null \
    | head -1 | sed 's/.*name\s*=\s*["\x27]//' | sed 's/["\x27].*//' | tr -d ' ' || true)
  [ -n "$PYPI_NAME_PARSED" ] && PYPI_NAME="$PYPI_NAME_PARSED"
elif [ -f "$REPO_DIR/setup.py" ]; then
  PYPI_NAME_PARSED=$(grep -E "name\s*=" "$REPO_DIR/setup.py" 2>/dev/null \
    | head -1 | sed "s/.*name\s*=\s*['\"]//;s/['\"].*//" | tr -d ' ' || true)
  [ -n "$PYPI_NAME_PARSED" ] && PYPI_NAME="$PYPI_NAME_PARSED"
fi

# Try primary name, then normalized variants (PyPI treats hyphens, underscores, and dots as equivalent)
PYPI_JSON=$(curl -sf "https://pypistats.org/api/packages/$PYPI_NAME/recent" 2>/dev/null || echo "")
if ! echo "$PYPI_JSON" | jq -e '.data' &>/dev/null 2>&1; then
  # Fallback 1: replace underscores with hyphens (most common normalization)
  PYPI_NAME_ALT=$(echo "$PYPI_NAME" | tr '_' '-')
  PYPI_JSON=$(curl -sf "https://pypistats.org/api/packages/$PYPI_NAME_ALT/recent" 2>/dev/null || echo "")
  [ "$(echo "$PYPI_JSON" | jq -e '.data' 2>/dev/null)" != "" ] && PYPI_NAME="$PYPI_NAME_ALT"
fi
if ! echo "$PYPI_JSON" | jq -e '.data' &>/dev/null 2>&1; then
  # Fallback 2: replace hyphens with underscores
  PYPI_NAME_ALT=$(echo "$PYPI_NAME" | tr '-' '_')
  PYPI_JSON=$(curl -sf "https://pypistats.org/api/packages/$PYPI_NAME_ALT/recent" 2>/dev/null || echo "")
  [ "$(echo "$PYPI_JSON" | jq -e '.data' 2>/dev/null)" != "" ] && PYPI_NAME="$PYPI_NAME_ALT"
fi

if echo "$PYPI_JSON" | jq -e '.data' &>/dev/null 2>&1; then
  echo "Package name: $PYPI_NAME"
  echo "$PYPI_JSON" | jq '{
    last_day: .data.last_day,
    last_week: .data.last_week,
    last_month: .data.last_month
  }'
else
  echo "(not a PyPI package, or package name differs from repo name: tried '$PYPI_NAME')"
fi
echo ""

echo "### npm Download Stats (if Node.js package)"
# Derive npm package name from package.json
NPM_NAME=""
if [ -f "$REPO_DIR/package.json" ]; then
  NPM_NAME=$(jq -r '.name // empty' "$REPO_DIR/package.json" 2>/dev/null || echo "")
fi
if [ -n "$NPM_NAME" ]; then
  NPM_JSON=$(curl -sf "https://api.npmjs.org/downloads/point/last-week/$NPM_NAME" 2>/dev/null || echo "")
  if echo "$NPM_JSON" | jq -e '.downloads' &>/dev/null 2>&1; then
    echo "Package name: $NPM_NAME"
    echo "$NPM_JSON" | jq '{weekly_downloads: .downloads, package: .package}'
  else
    echo "(npm API returned no data for '$NPM_NAME')"
  fi
else
  echo "(no package.json found — not an npm package)"
fi
echo ""

# ---------------------------------------------------------------
# SECTION 6: Local file analysis
# ---------------------------------------------------------------

echo "### Local Repository Structure"
echo "REPO_DIR: $REPO_DIR"
echo ""

echo "#### Top-level Directory Listing"
ls -la "$REPO_DIR"
echo ""

echo "#### Full Directory Tree (depth 3, .git excluded)"
find "$REPO_DIR" -maxdepth 3 \
  -not -path '*/.git' \
  -not -path '*/.git/*' \
  | sort \
  | sed "s|$REPO_DIR||" \
  | sed 's|^/||'
echo ""

echo "#### README (first 200 lines)"
README=""
for f in README.md README.rst README.txt README; do
  [ -f "$REPO_DIR/$f" ] && README="$REPO_DIR/$f" && break
done
if [ -n "$README" ]; then
  echo "(source: $README)"
  head -200 "$README"
else
  echo "(no README found)"
fi
echo ""

echo "#### Named Adopters / Case Studies"
for f in ADOPTERS.md ADOPTERS USERS.md USERS COMPANIES.md; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(source: $f)"
    cat "$REPO_DIR/$f"
    echo ""
  fi
done
# Also grep README for production/used-by mentions
if [ -n "$README" ]; then
  echo "--- Production/adoption mentions in README ---"
  grep -iE "(production|used by|powered by|adopted by|trusted by|case study|customer)" \
    "$README" 2>/dev/null | head -20 || echo "(none found)"
fi
echo ""

echo "#### Breaking Changes in CHANGELOG"
for f in CHANGELOG.md CHANGELOG.rst CHANGELOG HISTORY.md CHANGES.md RELEASES.md; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(source: $f — showing breaking-change markers)"
    grep -inE "(breaking|BREAKING CHANGE|incompatible|migration required|removed|deprecated)" \
      "$REPO_DIR/$f" 2>/dev/null | head -30 || echo "(no breaking-change markers found)"
    echo ""
    echo "(first 80 lines of changelog for release cadence)"
    head -80 "$REPO_DIR/$f"
    break
  fi
done
[ ! -f "$REPO_DIR/CHANGELOG.md" ] && [ ! -f "$REPO_DIR/CHANGELOG.rst" ] \
  && [ ! -f "$REPO_DIR/CHANGELOG" ] && echo "(no CHANGELOG found)"
echo ""

echo "#### Package / Project Manifests"
find "$REPO_DIR" -maxdepth 2 \
  -not -path '*/.git/*' \
  \( \
    -name "package.json"    -o -name "Cargo.toml" \
    -o -name "pyproject.toml" -o -name "setup.py" -o -name "setup.cfg" \
    -o -name "requirements*.txt" \
    -o -name "go.mod" \
    -o -name "pom.xml"      -o -name "build.gradle" -o -name "build.gradle.kts" \
    -o -name "Gemfile" \
    -o -name "composer.json" \
    -o -name "CMakeLists.txt" \
    -o -name "Makefile"     -o -name "makefile" \
  \) 2>/dev/null | sort
echo ""

echo "#### CI/CD Configs"
find "$REPO_DIR" -maxdepth 4 \
  -not -path '*/.git/*' \
  \( \
    -name "*.yml" -path "*/.github/workflows/*" \
    -o -name "*.yaml" -path "*/.github/workflows/*" \
    -o -name "Jenkinsfile" \
    -o -name ".travis.yml" \
    -o -name "azure-pipelines.yml" \
    -o -name ".gitlab-ci.yml" \
    -o -path "*/.circleci/config.yml" \
  \) 2>/dev/null | sort
echo ""

echo "#### Community & Governance Health Files"
for f in CONTRIBUTING.md CONTRIBUTING.rst CODE_OF_CONDUCT.md SECURITY.md \
          GOVERNANCE.md MAINTAINERS CODEOWNERS ROADMAP.md; do
  [ -f "$REPO_DIR/$f" ] && echo "  FOUND: $f"
  [ -f "$REPO_DIR/.github/$f" ] && echo "  FOUND: .github/$f"
done
[ -d "$REPO_DIR/.github" ] && ls "$REPO_DIR/.github/" 2>/dev/null | sed 's/^/  .github\//'
echo ""

echo "#### License File"
for f in LICENSE LICENSE.md LICENSE.txt LICENSE.rst COPYING; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(source: $f — first 5 lines)"
    head -5 "$REPO_DIR/$f"
    break
  fi
done
echo ""

# ---------------------------------------------------------------
# SECTION 6b: Technical deep-dive data (architecture, papers, docs)
# ---------------------------------------------------------------

echo "### Academic Papers & Citations"
if [ -f "$REPO_DIR/CITATION.cff" ]; then
  echo "(CITATION.cff found)"
  cat "$REPO_DIR/CITATION.cff"
elif [ -f "$REPO_DIR/paper.md" ]; then
  echo "(paper.md found — JOSS paper)"
  cat "$REPO_DIR/paper.md"
else
  echo "(no CITATION.cff or paper.md)"
fi

# Grep README and docs for paper links
echo ""
echo "--- Paper/DOI links found in README ---"
if [ -n "$README" ]; then
  grep -oE '(https?://(arxiv\.org|doi\.org|proceedings\.mlr\.press|aclanthology\.org|openreview\.net|dl\.acm\.org|papers\.nips\.cc)[^)> "]*|arXiv:[0-9]+\.[0-9]+)' \
    "$README" 2>/dev/null | sort -u || echo "(none found)"
fi
echo ""
echo "--- Blog/announcement links found in README ---"
if [ -n "$README" ]; then
  grep -oiE 'https?://[^)> "]*blog[^)> "]*' "$README" 2>/dev/null | sort -u \
    || echo "(none found)"
fi
echo ""

echo "### Documentation Site"
# Check common doc config files for the site URL
DOC_URL=""
if [ -f "$REPO_DIR/mkdocs.yml" ]; then
  echo "(mkdocs.yml found)"
  DOC_URL=$(grep -E '^\s*site_url:' "$REPO_DIR/mkdocs.yml" 2>/dev/null \
    | sed 's/.*site_url:\s*//' | tr -d "\"'" | head -1 || true)
  grep -E '^\s*(site_name|site_url|site_description|repo_url|docs_dir):' \
    "$REPO_DIR/mkdocs.yml" 2>/dev/null | head -10
fi
if [ -f "$REPO_DIR/.readthedocs.yaml" ] || [ -f "$REPO_DIR/.readthedocs.yml" ]; then
  RTD_FILE=$(ls "$REPO_DIR"/.readthedocs.y*ml 2>/dev/null | head -1)
  echo "(readthedocs config found: $RTD_FILE)"
  cat "$RTD_FILE" 2>/dev/null | head -20
fi
if [ -f "$REPO_DIR/docusaurus.config.js" ] || [ -f "$REPO_DIR/docusaurus.config.ts" ]; then
  DOCU_FILE=$(ls "$REPO_DIR"/docusaurus.config.* 2>/dev/null | head -1)
  echo "(docusaurus config found: $DOCU_FILE)"
  grep -E '(url|baseUrl|tagline|title)\s*:' "$DOCU_FILE" 2>/dev/null | head -10
fi
# Also surface the homepage from repo JSON
echo ""
echo "Repo homepage (from GitHub API): $(echo "$REPO_JSON" | jq -r '.homepage // "(none)"' 2>/dev/null)"
echo ""

echo "### Architecture Files & Diagrams"
# Look for dedicated architecture docs
for f in ARCHITECTURE.md ARCHITECTURE.rst DESIGN.md DESIGN.rst \
          docs/architecture.md docs/ARCHITECTURE.md docs/design.md; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(found: $f)"
    head -60 "$REPO_DIR/$f"
    echo ""
  fi
done

# List diagram images
echo "--- Diagram/architecture images in repo ---"
find "$REPO_DIR" -maxdepth 4 \
  -not -path '*/.git/*' \
  \( \
    -iname "*arch*"     -o -iname "*architecture*" \
    -o -iname "*overview*" -o -iname "*diagram*" \
    -o -iname "*flow*"   -o -iname "*design*" \
    -o -iname "*structure*" \
  \) \
  \( -name "*.png" -o -name "*.svg" -o -name "*.jpg" -o -name "*.gif" -o -name "*.webp" \) \
  2>/dev/null | sort | head -20 \
  | sed "s|$REPO_DIR/||" \
  || echo "(none found)"

# Also look for mermaid or plantuml blocks in any .md file
echo ""
echo "--- Mermaid/PlantUML diagram blocks in docs ---"
find "$REPO_DIR" -maxdepth 4 -name "*.md" -not -path '*/.git/*' \
  -exec grep -l '```mermaid\|```plantuml\|@startuml' {} \; 2>/dev/null \
  | sed "s|$REPO_DIR/||" | head -10 \
  || echo "(none found)"
echo ""

echo "### Examples Directory Overview"
if [ -d "$REPO_DIR/examples" ]; then
  echo "(examples/ found — top-level contents)"
  ls -1 "$REPO_DIR/examples/" 2>/dev/null | head -30
else
  echo "(no examples/ directory)"
fi
echo ""

# ---------------------------------------------------------------
# SECTION 7: Local git stats
# ---------------------------------------------------------------

echo "### Local Git Stats"
cd "$REPO_DIR"
echo "Total commits in shallow clone : $(git rev-list --count HEAD 2>/dev/null || echo 'N/A (shallow)')"
echo "Last commit                     : $(git log -1 --format='%ci  %s' 2>/dev/null)"
echo "Unique author emails in clone   : $(git log --format='%ae' 2>/dev/null | sort -u | wc -l | tr -d ' ')"
cd - > /dev/null
echo ""

# ---------------------------------------------------------------
# SECTION 8: Community Investment Signals
# ---------------------------------------------------------------

echo "### Community Investment Signals"
echo ""

echo "#### Contributor Org Diversity"
# Fetch contributors with more details to identify org affiliations
echo "$CONTRIB_JSON" | jq '[.[] | .login]' 2>/dev/null | jq -r '.[]' 2>/dev/null | while read -r login; do
  USER_JSON=$(github_api "users/$login" 2>/dev/null || echo "{}")
  COMPANY=$(echo "$USER_JSON" | jq -r '.company // "(none)"' 2>/dev/null)
  echo "  $login: $COMPANY"
done 2>/dev/null || echo "(could not fetch contributor orgs)"
echo ""

echo "#### External vs Internal PR Merge Time (sample)"
# Get recent merged PRs and check if author is from the org
echo "--- Last 20 merged PRs with author association ---"
github_api "repos/$REPO/pulls?state=closed&sort=updated&direction=desc&per_page=20" \
  | jq '[.[] | select(.merged_at != null) | {
      number: .number,
      author: .user.login,
      author_association: .author_association,
      created: .created_at,
      merged: .merged_at,
      title: (.title | if length > 60 then .[:60] + "..." else . end)
    }]' 2>/dev/null || echo "(unavailable)"
echo ""

echo "#### Good First Issues"
GFI_JSON=$(github_api "repos/$REPO/issues?labels=good+first+issue&state=open&per_page=10" 2>/dev/null \
  || github_api "repos/$REPO/issues?labels=good-first-issue&state=open&per_page=10" 2>/dev/null \
  || echo "[]")
echo "$GFI_JSON" | jq '{
  count: length,
  sample: [.[:5][] | {number: .number, title: .title, created: .created_at}]
}' 2>/dev/null || echo "(no good first issues found)"
echo ""

echo "#### CONTRIBUTING.md Content"
if [ -f "$REPO_DIR/CONTRIBUTING.md" ]; then
  echo "(CONTRIBUTING.md found — first 80 lines)"
  head -80 "$REPO_DIR/CONTRIBUTING.md"
elif [ -f "$REPO_DIR/.github/CONTRIBUTING.md" ]; then
  echo "(.github/CONTRIBUTING.md found — first 80 lines)"
  head -80 "$REPO_DIR/.github/CONTRIBUTING.md"
else
  echo "(no CONTRIBUTING.md found)"
fi
echo ""

echo "#### GOVERNANCE.md Content"
if [ -f "$REPO_DIR/GOVERNANCE.md" ]; then
  echo "(GOVERNANCE.md found — first 80 lines)"
  head -80 "$REPO_DIR/GOVERNANCE.md"
elif [ -f "$REPO_DIR/.github/GOVERNANCE.md" ]; then
  echo "(.github/GOVERNANCE.md found — first 80 lines)"
  head -80 "$REPO_DIR/.github/GOVERNANCE.md"
else
  echo "(no GOVERNANCE.md found)"
fi
echo ""

echo "#### MAINTAINERS / CODEOWNERS"
for f in MAINTAINERS MAINTAINERS.md .github/CODEOWNERS CODEOWNERS; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(found: $f)"
    cat "$REPO_DIR/$f"
    echo ""
  fi
done
echo ""

echo "#### Community Meeting / Communication Links"
# Search README and docs for community meeting references
if [ -n "$README" ]; then
  echo "--- Community/meeting references in README ---"
  grep -iE "(community meeting|office hours|slack|discord|mailing list|forum|gitter|matrix|zulip|discuss)" \
    "$README" 2>/dev/null | head -15 || echo "(none found)"
fi
echo ""

echo "#### CLA / DCO Requirements"
# Check for CLA or DCO mentions
CLA_FOUND=false
for f in CLA.md .github/CLA.md DCO .github/DCO; do
  if [ -f "$REPO_DIR/$f" ]; then
    echo "(found: $f)"
    head -20 "$REPO_DIR/$f"
    CLA_FOUND=true
    echo ""
  fi
done
if [ "$CLA_FOUND" = false ]; then
  # Check CONTRIBUTING.md for CLA/DCO mentions
  for f in CONTRIBUTING.md .github/CONTRIBUTING.md; do
    if [ -f "$REPO_DIR/$f" ]; then
      grep -iE "(CLA|DCO|contributor license|developer certificate|sign.off)" \
        "$REPO_DIR/$f" 2>/dev/null | head -5
    fi
  done
fi
echo ""

echo "#### PR Review Culture (sample)"
# Get comments from recent PRs to gauge review culture
echo "--- Recent PR review comments sample (last 5 PRs) ---"
github_api "repos/$REPO/pulls?state=closed&sort=updated&direction=desc&per_page=5" \
  | jq '[.[] | {number: .number, review_comments: .review_comments, comments: .comments}]' \
  2>/dev/null || echo "(unavailable)"
echo ""

# ---------------------------------------------------------------
# SECTION 9: Extended Package Ecosystems
# ---------------------------------------------------------------

echo "### Extended Package Ecosystems"
echo ""

echo "#### Docker Hub"
DOCKER_JSON=$(curl -sf "https://hub.docker.com/v2/repositories/$OWNER/$REPONAME/" 2>/dev/null \
  || curl -sf "https://hub.docker.com/v2/repositories/library/$REPONAME/" 2>/dev/null \
  || echo "")
if echo "$DOCKER_JSON" | jq -e '.pull_count' &>/dev/null 2>&1; then
  echo "$DOCKER_JSON" | jq '{
    full_name: .full_name,
    pull_count: .pull_count,
    star_count: .star_count,
    last_updated: .last_updated
  }' 2>/dev/null
else
  echo "(not found on Docker Hub — tried $OWNER/$REPONAME and library/$REPONAME)"
fi
echo ""

echo "#### Homebrew"
BREW_JSON=$(curl -sf "https://formulae.brew.sh/api/formula/$REPONAME.json" 2>/dev/null \
  || curl -sf "https://formulae.brew.sh/api/cask/$REPONAME.json" 2>/dev/null \
  || echo "")
if echo "$BREW_JSON" | jq -e '.name' &>/dev/null 2>&1; then
  echo "$BREW_JSON" | jq '{
    name: .name,
    desc: .desc,
    analytics_installs_30d: .analytics.install["30d"],
    analytics_installs_90d: .analytics.install["90d"],
    analytics_installs_365d: .analytics.install["365d"]
  }' 2>/dev/null || echo "$BREW_JSON" | jq '{name: .name, desc: .desc}' 2>/dev/null
else
  echo "(not found on Homebrew — tried formula and cask for '$REPONAME')"
fi
echo ""

echo "#### conda-forge"
CONDA_JSON=$(curl -sf "https://api.anaconda.org/package/conda-forge/$REPONAME" 2>/dev/null || echo "")
if echo "$CONDA_JSON" | jq -e '.name' &>/dev/null 2>&1; then
  echo "$CONDA_JSON" | jq '{
    name: .name,
    summary: .summary,
    downloads: .downloads,
    last_modified: .modified_at
  }' 2>/dev/null
else
  echo "(not found on conda-forge — tried '$REPONAME')"
fi
echo ""

echo "#### Libraries.io (dependency & ecosystem)"
# Libraries.io provides SourceRank, dependent repos count, and ecosystem info
# Detect ecosystem from manifest files
LIBRARIESIO_ECOSYSTEM=""
[ -f "$REPO_DIR/pyproject.toml" ] || [ -f "$REPO_DIR/setup.py" ] && LIBRARIESIO_ECOSYSTEM="pypi"
[ -f "$REPO_DIR/package.json" ] && LIBRARIESIO_ECOSYSTEM="npm"
[ -f "$REPO_DIR/Cargo.toml" ] && LIBRARIESIO_ECOSYSTEM="cargo"
[ -f "$REPO_DIR/go.mod" ] && LIBRARIESIO_ECOSYSTEM="go"
[ -f "$REPO_DIR/Gemfile" ] && LIBRARIESIO_ECOSYSTEM="rubygems"

if [ -n "$LIBRARIESIO_ECOSYSTEM" ]; then
  echo "Detected ecosystem: $LIBRARIESIO_ECOSYSTEM"
  echo "Manual check URL: https://libraries.io/$LIBRARIESIO_ECOSYSTEM/$REPONAME"
  echo "(Libraries.io API requires a free key — see https://libraries.io/api for signup)"
  echo "Key metrics to check manually: SourceRank, Dependent repositories count, Dependent packages count"
else
  echo "(could not detect package ecosystem for Libraries.io lookup)"
fi
echo ""

echo "#### deps.dev (Google Open Source Insights)"
# Try to detect package name from manifests
DEPSDEV_SYSTEM=""
DEPSDEV_NAME="$REPONAME"
if [ -f "$REPO_DIR/pyproject.toml" ]; then
  DEPSDEV_SYSTEM="PYPI"
  PYPI_NAME_PARSED=$(grep -E '^\s*name\s*=' "$REPO_DIR/pyproject.toml" 2>/dev/null \
    | head -1 | sed 's/.*name\s*=\s*["\x27]//' | sed 's/["\x27].*//' | tr -d ' ' || true)
  [ -n "$PYPI_NAME_PARSED" ] && DEPSDEV_NAME="$PYPI_NAME_PARSED"
elif [ -f "$REPO_DIR/package.json" ]; then
  DEPSDEV_SYSTEM="NPM"
  NPM_NAME_PARSED=$(jq -r '.name // empty' "$REPO_DIR/package.json" 2>/dev/null || echo "")
  [ -n "$NPM_NAME_PARSED" ] && DEPSDEV_NAME="$NPM_NAME_PARSED"
elif [ -f "$REPO_DIR/go.mod" ]; then
  DEPSDEV_SYSTEM="GO"
  GO_MODULE=$(grep '^module ' "$REPO_DIR/go.mod" 2>/dev/null | head -1 | awk '{print $2}' || echo "")
  [ -n "$GO_MODULE" ] && DEPSDEV_NAME="$GO_MODULE"
fi

if [ -n "$DEPSDEV_SYSTEM" ]; then
  DEPSDEV_JSON=$(curl -sf \
    "https://api.deps.dev/v3/systems/${DEPSDEV_SYSTEM}/packages/${DEPSDEV_NAME}" \
    2>/dev/null || echo "")
  if echo "$DEPSDEV_JSON" | jq -e '.packageKey' &>/dev/null 2>&1; then
    echo "$DEPSDEV_JSON" | jq '{
      name: .packageKey.name,
      system: .packageKey.system,
      versions_count: (.versions | length),
      latest_version: (.versions | sort_by(.publishedAt) | last | {version: .versionKey.version, published: .publishedAt, is_default: .isDefault})
    }' 2>/dev/null
  else
    echo "(deps.dev returned no data for $DEPSDEV_SYSTEM/$DEPSDEV_NAME)"
  fi
  echo "Full dependency graph: https://deps.dev/$DEPSDEV_SYSTEM/$DEPSDEV_NAME"
else
  echo "(could not detect package ecosystem for deps.dev lookup)"
fi
echo ""

# ---------------------------------------------------------------
# SECTION 10: Search & Community Signals
# ---------------------------------------------------------------

echo "### Search & Community Signals"
echo ""

echo "#### Stack Overflow Tag Stats"
# Try both the repo name and common variations
SO_TAG=$(echo "$REPONAME" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
SO_JSON=$(curl -sf \
  "https://api.stackexchange.com/2.3/tags/$SO_TAG/info?site=stackoverflow" \
  2>/dev/null || echo "")
if echo "$SO_JSON" | jq -e '.items[0]' &>/dev/null 2>&1; then
  echo "$SO_JSON" | jq '.items[0] | {
    tag: .name,
    total_questions: .count,
    has_synonyms: .has_synonyms,
    is_moderator_only: .is_moderator_only
  }' 2>/dev/null
  # Fetch unanswered count for this tag
  SO_UNANSWERED=$(curl -sf \
    "https://api.stackexchange.com/2.3/tags/$SO_TAG/info?site=stackoverflow&filter=!nNPvSNQDYW" \
    2>/dev/null || echo "")
  echo "$SO_UNANSWERED" | jq '.items[0] | {unanswered_count: .count}' 2>/dev/null || true
else
  echo "(tag '$SO_TAG' not found on Stack Overflow)"
fi
echo ""

echo "#### Hacker News Mentions (via Algolia)"
HN_JSON=$(curl -sf \
  "https://hn.algolia.com/api/v1/search?query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPONAME'))" 2>/dev/null || echo "$REPONAME")&tags=story&hitsPerPage=5" \
  2>/dev/null || echo "")
if echo "$HN_JSON" | jq -e '.hits' &>/dev/null 2>&1; then
  echo "$HN_JSON" | jq '{
    total_hits: .nbHits,
    sample_stories: [.hits[:5][] | {
      title: .title,
      points: .points,
      num_comments: .num_comments,
      created_at: .created_at,
      url: .story_url
    }]
  }' 2>/dev/null
else
  echo "(could not fetch HN data)"
fi
echo ""

echo "#### Dev.to Articles"
DEVTO_TAG=$(echo "$REPONAME" | tr '[:upper:]' '[:lower:]' | sed 's/-//g' | sed 's/_//g')
DEVTO_JSON=$(curl -sf \
  "https://dev.to/api/articles?tag=$DEVTO_TAG&per_page=5&top=1" \
  2>/dev/null || echo "")
if echo "$DEVTO_JSON" | jq -e '.[0]' &>/dev/null 2>&1; then
  echo "$DEVTO_JSON" | jq '{
    article_count_in_sample: length,
    sample: [.[:5][] | {
      title: .title,
      published_at: .published_at,
      positive_reactions_count: .positive_reactions_count,
      comments_count: .comments_count
    }]
  }' 2>/dev/null
  echo ""
  echo "Full tag page: https://dev.to/t/$DEVTO_TAG"
else
  echo "(no Dev.to articles found for tag '$DEVTO_TAG')"
fi
echo ""

echo "#### Google Trends (manual step required)"
echo "Google Trends has no public API. Check manually:"
echo "  https://trends.google.com/trends/explore?q=$REPONAME&date=today%205-y"
echo "Key signals to note: 5-year trend direction (rising/peak/declining), geographic distribution"
echo ""

# ---------------------------------------------------------------
# SECTION 11: Security Health
# ---------------------------------------------------------------

echo "### Security Health"
echo ""

echo "#### OpenSSF Scorecard"
SCORECARD_JSON=$(curl -sf \
  "https://api.securityscorecards.dev/projects/github.com/$REPO" \
  2>/dev/null || echo "")
if echo "$SCORECARD_JSON" | jq -e '.score' &>/dev/null 2>&1; then
  echo "$SCORECARD_JSON" | jq '{
    score: .score,
    date: .date,
    checks: [.checks[] | {name: .name, score: .score, reason: .reason}]
  }' 2>/dev/null
else
  echo "(Scorecard data not available for this repo — may not be indexed yet)"
  echo "Run locally: scorecard --repo=github.com/$REPO"
  echo "Or check: https://securityscorecards.dev/#/github.com/$REPO"
fi
echo ""

echo "#### OSV Vulnerability Database"
# Detect ecosystem for OSV query
OSV_ECOSYSTEM=""
OSV_NAME="$REPONAME"
if [ -f "$REPO_DIR/pyproject.toml" ] || [ -f "$REPO_DIR/setup.py" ]; then
  OSV_ECOSYSTEM="PyPI"
elif [ -f "$REPO_DIR/package.json" ]; then
  OSV_ECOSYSTEM="npm"
  OSV_NAME_PARSED=$(jq -r '.name // empty' "$REPO_DIR/package.json" 2>/dev/null || echo "")
  [ -n "$OSV_NAME_PARSED" ] && OSV_NAME="$OSV_NAME_PARSED"
elif [ -f "$REPO_DIR/go.mod" ]; then
  OSV_ECOSYSTEM="Go"
elif [ -f "$REPO_DIR/Cargo.toml" ]; then
  OSV_ECOSYSTEM="crates.io"
fi

if [ -n "$OSV_ECOSYSTEM" ]; then
  OSV_RESPONSE=$(curl -sf -X POST "https://api.osv.dev/v1/query" \
    -H "Content-Type: application/json" \
    -d "{\"package\": {\"name\": \"$OSV_NAME\", \"ecosystem\": \"$OSV_ECOSYSTEM\"}}" \
    2>/dev/null || echo "")
  if echo "$OSV_RESPONSE" | jq -e '.vulns' &>/dev/null 2>&1; then
    echo "$OSV_RESPONSE" | jq '{
      total_vulnerabilities: (.vulns | length),
      vulns: [.vulns[:5][] | {id: .id, summary: .summary, published: .published, severity: (.severity // "N/A")}]
    }' 2>/dev/null
  else
    echo "(no vulnerabilities found in OSV for $OSV_ECOSYSTEM/$OSV_NAME)"
  fi
else
  # Fall back to GitHub advisory query
  echo "(ecosystem not detected — querying OSV by GitHub repo)"
  OSV_RESPONSE=$(curl -sf -X POST "https://api.osv.dev/v1/query" \
    -H "Content-Type: application/json" \
    -d "{\"package\": {\"name\": \"github.com/$REPO\"}}" \
    2>/dev/null || echo "")
  echo "$OSV_RESPONSE" | jq '{total_vulnerabilities: (.vulns | length)}' 2>/dev/null \
    || echo "(could not query OSV)"
fi
echo ""

echo "#### NVD CVE History"
NVD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPONAME'))" 2>/dev/null || echo "$REPONAME")
NVD_JSON=$(curl -sf \
  "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=$NVD_ENCODED&resultsPerPage=5" \
  2>/dev/null || echo "")
if echo "$NVD_JSON" | jq -e '.totalResults' &>/dev/null 2>&1; then
  echo "$NVD_JSON" | jq '{
    total_cves: .totalResults,
    sample: [.vulnerabilities[:5][] | {
      id: .cve.id,
      published: .cve.published,
      severity: (.cve.metrics.cvssMetricV31[0].cvssData.baseSeverity // .cve.metrics.cvssMetricV2[0].baseSeverity // "N/A"),
      description: (.cve.descriptions[] | select(.lang=="en") | .value | if length > 100 then .[:100]+"..." else . end)
    }]
  }' 2>/dev/null
else
  echo "(could not fetch NVD data)"
fi
echo ""

# ---------------------------------------------------------------
# SECTION 12: Foundation & Governance Status
# ---------------------------------------------------------------

echo "### Foundation & Governance Status"
echo ""

echo "#### CNCF Landscape"
CNCF_LANDSCAPE=$(curl -sf \
  "https://landscape.cncf.io/api/projects?project=$REPONAME" \
  2>/dev/null || echo "")
# Also check via the landscape data directly
CNCF_DATA=$(curl -sf \
  "https://raw.githubusercontent.com/cncf/landscape/master/hosted_data/projects.json" \
  2>/dev/null || echo "")
if echo "$CNCF_DATA" | jq -e '.' &>/dev/null 2>&1; then
  CNCF_MATCH=$(echo "$CNCF_DATA" | jq \
    "[.[] | select(.name | ascii_downcase | contains(\"$(echo $REPONAME | tr '[:upper:]' '[:lower:]')\"))] | .[0]" \
    2>/dev/null || echo "null")
  if [ "$CNCF_MATCH" != "null" ] && [ -n "$CNCF_MATCH" ]; then
    echo "$CNCF_MATCH" | jq '{name: .name, project: .project, category: .category}' 2>/dev/null
  else
    echo "(not found in CNCF landscape for '$REPONAME')"
  fi
else
  echo "(could not fetch CNCF landscape data)"
fi
echo "Manual check: https://landscape.cncf.io/?selected=$REPONAME"
echo ""

echo "#### Apache Software Foundation"
ASF_JSON=$(curl -sf \
  "https://projects.apache.org/json/foundation/projects.json" \
  2>/dev/null || echo "")
if echo "$ASF_JSON" | jq -e '.' &>/dev/null 2>&1; then
  ASF_MATCH=$(echo "$ASF_JSON" | jq \
    "[to_entries[] | select(.key | ascii_downcase | contains(\"$(echo $REPONAME | tr '[:upper:]' '[:lower:]')\"))] | .[0]" \
    2>/dev/null || echo "null")
  if [ "$ASF_MATCH" != "null" ] && [ -n "$ASF_MATCH" ]; then
    echo "$ASF_MATCH" | jq '{name: .key, description: .value.description, category: .value.category}' 2>/dev/null
  else
    echo "(not found in Apache Software Foundation projects for '$REPONAME')"
  fi
else
  echo "(could not fetch ASF project data)"
fi
echo ""

echo "#### Linux Foundation / Other Foundations"
echo "Manual checks:"
echo "  Linux Foundation projects: https://www.linuxfoundation.org/projects"
echo "  OpenSSF projects: https://openssf.org/community/projects/"
echo "  Eclipse Foundation: https://projects.eclipse.org"
echo ""

# ---------------------------------------------------------------
# SECTION 13: Commercial Intelligence
# ---------------------------------------------------------------

echo "### Commercial Intelligence"
echo ""

echo "#### Crunchbase (backing org)"
# No free API for automated Crunchbase data
# Surface the org info we already have and provide direct link
echo "Org name    : $OWNER"
echo "GitHub type : $(echo "$ORG_JSON" | jq -r '.type // "unknown"' 2>/dev/null)"
echo "GitHub blog : $(echo "$ORG_JSON" | jq -r '.blog // "(none)"' 2>/dev/null)"
echo ""
echo "Manual Crunchbase lookup (funding rounds, investors, headcount trend):"
echo "  https://www.crunchbase.com/organization/$OWNER"
echo "(Crunchbase requires a paid API key for automated access)"
echo ""

echo "#### YouTube Content Signals"
# YouTube Data API requires a key - provide the search URL and note
echo "Manual check — search for tutorials and talks:"
echo "  https://www.youtube.com/results?search_query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPONAME tutorial'))" 2>/dev/null || echo "$REPONAME+tutorial")"
echo "  https://www.youtube.com/results?search_query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPONAME 2024 OR 2025'))" 2>/dev/null || echo "$REPONAME+2024")"
echo ""
echo "If YOUTUBE_API_KEY is configured, automated stats can be added."
echo "Key signals: total video count, view count on top tutorials, recent upload frequency"
if [ -n "${YOUTUBE_API_KEY:-}" ]; then
  YT_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPONAME'))" 2>/dev/null || echo "$REPONAME")
  YT_JSON=$(curl -sf \
    "https://www.googleapis.com/youtube/v3/search?part=snippet&q=$YT_ENCODED&type=video&order=viewCount&maxResults=5&key=$YOUTUBE_API_KEY" \
    2>/dev/null || echo "")
  if echo "$YT_JSON" | jq -e '.items' &>/dev/null 2>&1; then
    echo ""
    echo "Top YouTube videos by view count:"
    echo "$YT_JSON" | jq '[.items[:5][] | {
      title: .snippet.title,
      channel: .snippet.channelTitle,
      published: .snippet.publishedAt
    }]' 2>/dev/null
  fi
fi
echo ""

# ---------------------------------------------------------------
# Output
# ---------------------------------------------------------------

echo "=== Analysis Complete ==="
echo ""
echo "LOCAL_REPO_PATH=$REPO_DIR"
echo "TEMP_DIR=$TEMP_DIR"
echo ""
echo "Claude: use LOCAL_REPO_PATH to read files for deeper analysis."
echo "        Clean up when done:  rm -rf $TEMP_DIR"
