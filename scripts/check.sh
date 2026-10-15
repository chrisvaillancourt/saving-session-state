#!/usr/bin/env bash
# Offline checks for the saving-session-state skill: no model calls, about a second.
# Usage: scripts/check.sh
#   1. Frontmatter follows the Agent Skills spec (name, description, allowed fields).
#   2. Progressive disclosure: SKILL.md size, links resolve, references stay one level deep.
#   3. Portability and privacy: forward-slash paths, no personal paths or org names.
#   4. The skills CLI discovers the skill (skipped when `skills` isn't installed).
# Run after any edit to the skill or docs.
set -uo pipefail

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
name=saving-session-state
skill="$repo/skills/$name"
failures=0 skipped=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }
skip() { printf 'SKIP  %s\n' "$1"; skipped=$((skipped + 1)); }

# The YAML frontmatter between the first two `---` lines.
frontmatter=$(awk 'NR == 1 && $0 == "---" { inside = 1; next } inside && $0 == "---" { exit } inside { print }' "$skill/SKILL.md")
field() { printf '%s\n' "$frontmatter" | sed -n "s/^$1: *//p" | head -n 1; }

echo "== frontmatter"
fm_name=$(field name)
fm_desc=$(field description)
if [ "$fm_name" = "$name" ] && [ "$(basename "$skill")" = "$fm_name" ]; then
  pass "name matches its directory ($fm_name)"
else
  fail "name '$fm_name' must match the directory '$(basename "$skill")'"
fi
if printf '%s' "$fm_name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' && [ ${#fm_name} -le 64 ]; then
  pass "name uses 1-64 lowercase letters, digits and single hyphens"
else
  fail "name breaks the spec's character rules"
fi
if [ -n "$fm_desc" ] && [ ${#fm_desc} -le 1024 ]; then
  pass "description is present and ${#fm_desc} <= 1024 characters"
else
  fail "description is missing or longer than 1024 characters (${#fm_desc})"
fi
if printf '%s' "$fm_desc" | grep -q 'Use when'; then
  pass "description says when to use the skill"
else
  fail "description needs a 'Use when' clause"
fi
extra=$(printf '%s\n' "$frontmatter" | sed -n 's/^\([A-Za-z_-]*\):.*/\1/p' \
  | grep -Ev '^(name|description|license|compatibility|metadata|allowed-tools)$' || true)
if [ -z "$extra" ]; then
  pass "frontmatter uses only fields from the open spec"
else
  fail "harness-specific frontmatter fields: $(printf '%s' "$extra" | tr '\n' ' ')"
fi

echo "== progressive disclosure"
body_lines=$(awk 'BEGIN { n = 0 } /^---$/ { n++; next } n >= 2 { c++ } END { print c + 0 }' "$skill/SKILL.md")
body_words=$(awk 'BEGIN { n = 0 } /^---$/ { n++; next } n >= 2 { print }' "$skill/SKILL.md" | wc -w | tr -d ' ')
if [ "$body_lines" -lt 500 ] && [ "$body_words" -lt 3500 ]; then
  pass "SKILL.md body is $body_lines lines and $body_words words (limits 500 lines, ~5000 tokens)"
else
  fail "SKILL.md body is too long: $body_lines lines, $body_words words"
fi

# links <file>: the relative Markdown link targets in a file, without anchors.
links() { grep -o '](\([^)#:]*\)[)#]' "$1" | sed 's/^](//; s/[)#]$//' | grep -v '^$' || true; }

for file in "$skill"/SKILL.md "$skill"/references/*.md; do
  rel=${file#"$repo"/}
  for target in $(links "$file"); do
    if [ -f "$(dirname "$file")/$target" ]; then
      pass "$rel links to $target"
    else
      fail "$rel links to missing $target"
    fi
  done
done

for ref in "$skill"/references/*.md; do
  base=$(basename "$ref")
  if grep -q "references/$base" "$skill/SKILL.md"; then
    pass "SKILL.md points to references/$base"
  else
    fail "references/$base has no pointer in SKILL.md"
  fi
  if [ -z "$(links "$ref" | grep '\.md$')" ]; then
    pass "references/$base links to no other skill file (one level deep)"
  else
    fail "references/$base links onward; keep references one level deep"
  fi
  lines=$(wc -l < "$ref" | tr -d ' ')
  if [ "$lines" -le 100 ] || grep -qi '^## contents' "$ref"; then
    pass "references/$base is $lines lines (a contents list is required above 100)"
  else
    fail "references/$base is $lines lines with no '## Contents' list"
  fi
done

echo "== portability and privacy"
scan_paths=("$skill" "$repo/docs" "$repo/evals" "$repo/README.md" "$repo/AGENTS.md")
if grep -rEn '[A-Za-z]:\\|\\[A-Za-z_]+\\' "$skill" > /dev/null; then
  fail "Windows-style backslash paths in the skill"
else
  pass "the skill uses forward-slash paths only"
fi
private=$(grep -rEn -i '/Users/|~/n/|genomenon|@[a-z0-9-]+\.(com|io)\b' "${scan_paths[@]}" 2> /dev/null \
  | grep -v 'scripts/check.sh' || true)
if [ -z "$private" ]; then
  pass "no personal paths, org names or email addresses in the skill, docs or evals"
else
  fail "private details found:"
  printf '%s\n' "$private" | sed 's/^/      /'
fi

echo "== skills CLI"
if command -v skills > /dev/null 2>&1; then
  listed=$(skills add "$repo" --list 2>&1 || true)
  if printf "%s" "$listed" | grep -q "$name"; then
    pass "skills add --list discovers $name"
  else
    fail "skills add --list does not discover $name"
  fi
else
  skip "skills CLI not installed"
fi

echo
echo "failures=$failures skipped=$skipped"
[ "$failures" -eq 0 ]
