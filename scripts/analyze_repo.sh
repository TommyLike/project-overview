#!/usr/bin/env bash
# GitHub Project Analyzer Script
# Usage: ./analyze_repo.sh <github-url-or-owner/repo>
# Requires: gh CLI (authenticated), jq

set -e

INPUT="${1:-}"

if [ -z "$INPUT" ]; then
  echo "Usage: $0 <github-url-or-owner/repo>" >&2
  exit 1
fi

# Normalize input: extract owner/repo from URL or use directly
REPO=$(echo "$INPUT" | sed -E 's|https?://github\.com/||' | sed 's|\.git$||' | sed 's|/$||')

echo "=== GitHub Project Analyzer: $REPO ==="
echo ""

# --- Basic repo info ---
echo "### Repository Info"
gh repo view "$REPO" --json name,description,url,homepageUrl,isPrivate,isFork,isArchived,stargazerCount,forkCount,watchers,openIssueCount,primaryLanguage,languages,licenseInfo,createdAt,updatedAt,pushedAt,defaultBranchRef 2>/dev/null | jq '{
  name: .name,
  description: .description,
  url: .url,
  homepage: .homepageUrl,
  private: .isPrivate,
  fork: .isFork,
  archived: .isArchived,
  stars: .stargazerCount,
  forks: .forkCount,
  watchers: .watchers,
  open_issues: .openIssueCount,
  primary_language: .primaryLanguage.name,
  languages: [.languages[].name],
  license: .licenseInfo.name,
  created_at: .createdAt,
  last_pushed: .pushedAt,
  default_branch: .defaultBranchRef.name
}'
echo ""

# --- Contributors ---
echo "### Top Contributors (up to 10)"
gh api "repos/$REPO/contributors?per_page=10" 2>/dev/null | jq '[.[] | {login: .login, contributions: .contributions}]'
echo ""

# --- Recent releases ---
echo "### Recent Releases (up to 5)"
gh release list --repo "$REPO" --limit 5 2>/dev/null || echo "(no releases)"
echo ""

# --- Open PRs ---
echo "### Open Pull Requests (up to 5)"
gh pr list --repo "$REPO" --limit 5 --json number,title,author,createdAt,labels 2>/dev/null | jq '.[] | {number: .number, title: .title, author: .author.login, created: .createdAt}' || echo "(none)"
echo ""

# --- Repository topics ---
echo "### Topics / Tags"
gh api "repos/$REPO" 2>/dev/null | jq '.topics'
echo ""

# --- File structure (top level) ---
echo "### Top-level File Structure"
gh api "repos/$REPO/contents/" 2>/dev/null | jq '[.[] | {name: .name, type: .type}]'
echo ""

# --- README (first 100 lines) ---
echo "### README (first 100 lines)"
gh api "repos/$REPO/readme" 2>/dev/null | jq -r '.content' | base64 --decode 2>/dev/null | head -100 || echo "(no README)"
echo ""

echo "=== Analysis Complete ==="
