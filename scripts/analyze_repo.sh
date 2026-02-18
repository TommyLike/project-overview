#!/usr/bin/env bash
# GitHub Project Analyzer Script
# Usage: ./analyze_repo.sh <github-url-or-owner/repo>
# Requires: git, jq, curl; optionally: gh CLI (authenticated)
#
# Token config file: ~/.config/github-analyzer/config
# Format:  GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

set -e

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

_load_config "$CONFIG_PRIMARY"
_load_config "$CONFIG_LOCAL"

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
  PYPI_NAME_PARSED=$(grep -E '^name\s*=' "$REPO_DIR/pyproject.toml" 2>/dev/null \
    | head -1 | sed 's/name\s*=\s*["\x27]//' | sed 's/["\x27].*//' | tr -d ' ' || true)
  [ -n "$PYPI_NAME_PARSED" ] && PYPI_NAME="$PYPI_NAME_PARSED"
elif [ -f "$REPO_DIR/setup.py" ]; then
  PYPI_NAME_PARSED=$(grep -E "name\s*=" "$REPO_DIR/setup.py" 2>/dev/null \
    | head -1 | sed "s/.*name\s*=\s*['\"]//;s/['\"].*//" | tr -d ' ' || true)
  [ -n "$PYPI_NAME_PARSED" ] && PYPI_NAME="$PYPI_NAME_PARSED"
fi

PYPI_JSON=$(curl -sf "https://pypistats.org/api/packages/$PYPI_NAME/recent" 2>/dev/null || echo "")
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
# Output
# ---------------------------------------------------------------

echo "=== Analysis Complete ==="
echo ""
echo "LOCAL_REPO_PATH=$REPO_DIR"
echo "TEMP_DIR=$TEMP_DIR"
echo ""
echo "Claude: use LOCAL_REPO_PATH to read files for deeper analysis."
echo "        Clean up when done:  rm -rf $TEMP_DIR"
