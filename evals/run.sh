#!/usr/bin/env bash
# Behavioral evals: run scripted sessions through a real agent harness and check what it saved.
# Usage: evals/run.sh [--harness claude|omp] [--model MODEL] [--thinking LEVEL] [--keep] [scenario...]
#   Scenarios: repo-only notes-home relay-caller already-captured (default: all).
#   --harness claude (default) runs `claude -p`; omp runs `omp -p` through the use-omp wrapper
#     (set USE_OMP_RUN to its run-omp.sh path).
#   Each scenario gets a fresh sandbox under $TMPDIR: a git repository, a notes home with its
#   own git history, and a preferences file reached through XDG_CONFIG_HOME. The skill under
#   test is linked into the repository's .claude/skills and .agents/skills, so the source
#   checkout is tested, not an installed copy.
# Costs model calls. See docs/evals.md for what each scenario checks and the last results.
set -uo pipefail

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
evals="$repo/evals"
harness=claude model="" thinking=low keep=0
scenarios=()
while [ $# -gt 0 ]; do
  case $1 in
    --harness) harness=$2; shift 2 ;;
    --model) model=$2; shift 2 ;;
    --thinking) thinking=$2; shift 2 ;;
    --keep) keep=1; shift ;;
    -h | --help) sed -n '2,12p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) scenarios+=("$1"); shift ;;
  esac
done
[ ${#scenarios[@]} -gt 0 ] || scenarios=(repo-only notes-home relay-caller already-captured)
case $harness in
  claude) command -v claude > /dev/null || { echo "claude not found" >&2; exit 2; } ;;
  omp)
    [ -n "${USE_OMP_RUN:-}" ] && [ -f "$USE_OMP_RUN" ] || { echo "set USE_OMP_RUN to run-omp.sh" >&2; exit 2; }
    [ -n "$model" ] || { echo "--model is required for omp" >&2; exit 2; }
    ;;
  *) echo "unknown harness: $harness" >&2; exit 2 ;;
esac

failures=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }
# Checks run without pipefail: `grep -q` closing a pipe early is a match, not a failure.
check() { if (set +o pipefail; eval "$2"); then pass "$1"; else fail "$1"; fi; }
g() { git -C "$1" -c user.name=eval -c user.email=eval@example.invalid -c commit.gpgsign=false "${@:2}"; }

# setup <dir> <scenario>: builds the sandbox; prints nothing.
setup() {
  local dir=$1 scenario=$2 r n
  r="$dir/widget" n="$dir/notes"
  mkdir -p "$dir/config/saving-session-state" "$dir/tmp"
  cp -R "$evals/fixtures/repo" "$r"
  g "$r" init -q -b main && g "$r" add -A && g "$r" commit -qm "Initial widget"
  sed -i '' 's/encoding="utf-8"/encoding="utf-8-sig"/' "$r/widget/parse.py"
  g "$r" commit -qam "Read CSVs with utf-8-sig"
  cat > "$r/tests/test_bom.py" << 'EOF'
from widget.parse import read_rows


def test_reads_bom_header(tmp_path):
    p = tmp_path / "excel.csv"
    p.write_bytes(b"\xef\xbb\xbf" + b"id,name\n1,a\n")
    assert read_rows(p)[0]["id"] == "1"
EOF
  mkdir -p "$r/.claude/skills" "$r/.agents/skills"
  ln -s "$repo/skills/saving-session-state" "$r/.claude/skills/saving-session-state"
  ln -s "$repo/skills/saving-session-state" "$r/.agents/skills/saving-session-state"
  printf '.claude/\n.agents/\n' >> "$r/.git/info/exclude"

  if [ "$scenario" != repo-only ]; then
    cp -R "$evals/fixtures/notes" "$n"
    sed "s|NOTES_HOME|$n|" "$evals/fixtures/preferences.md" > "$dir/config/saving-session-state/preferences.md"
  fi
  if [ "$scenario" = already-captured ]; then
    local today tomorrow
    today=$(date +%Y-%m-%d)
    tomorrow=$(date -v+1d +%Y-%m-%d 2> /dev/null || date -d tomorrow +%Y-%m-%d)
    cat > "$n/projects/widget.md" << EOF
# widget

Side project: reads CSV exports into dictionaries. Code: the \`widget\` repository.

## Current state

Fixed the KeyError on Excel exports: they start with a UTF-8 byte-order mark, so \`read_rows\` now opens files with \`utf-8-sig\` (commit "Read CSVs with utf-8-sig"). \`tests/test_bom.py\` covers it; \`python -m pytest\` passes (2 passed).

Tried and dropped: stripping the BOM from the first field name, which callers passing their own \`fieldnames\` never reach.

## Next steps

- Release 0.2.0 (do, $tomorrow): bump the version and tag it.
- \`--encoding\` option (defer): decide after the release.

## Open questions

- Do Latin-1 exports need support? Asked the data team on $today; waiting on their answer.
EOF
    printf -- '- Write BOM test fixtures as bytes (`write_bytes`); editors strip a BOM from text files on save.\n' >> "$r/AGENTS.md"
    g "$r" add -A && g "$r" commit -qm "Test BOM headers and note the fixture gotcha"
  fi
  if [ -d "$n" ]; then g "$n" init -q -b main && g "$n" add -A && g "$n" commit -qm "Notes"; fi
}

# prompt <dir> <scenario>: the session summary plus the scenario's request.
prompt() {
  cat "$evals/scenarios/_session.md"
  [ "$2" = already-captured ] && cat "$evals/scenarios/already-captured.md" && return
  printf '\n'
  sed "s|RELAY_NOTE_PATH|$1/tmp/relay-note.md|" "$evals/scenarios/$2.md"
}

# run_agent <dir> <prompt file>: writes $dir/answer.md and $dir/trace.txt.
run_agent() {
  local dir=$1 pf=$2
  if [ "$harness" = claude ]; then
    (cd "$dir/widget" && XDG_CONFIG_HOME="$dir/config" claude -p --verbose --output-format stream-json \
      --permission-mode acceptEdits --add-dir "$dir/notes" "$dir/config" --no-session-persistence \
      --allowedTools 'Bash(git *)' 'Bash(cat *)' 'Bash(ls *)' 'Bash(echo *)' 'Bash(python -m pytest*)' \
      ${model:+--model "$model"} < "$pf" > "$dir/trace.txt" 2> "$dir/stderr.txt")
    jq -rs '[.[] | select(.type == "result")] | last | .result // ""' "$dir/trace.txt" > "$dir/answer.md"
  else
    local overlay="$dir/omp-overlay.yml" run_dir
    printf 'memory:\n  backend: off\n' > "$overlay"
    XDG_CONFIG_HOME="$dir/config" bash "$USE_OMP_RUN" --workspace "$dir/widget" --model "$model" \
      --thinking "$thinking" --max-time 20m --label "saving-session-state eval" --no-record \
      --config "$overlay" --prompt-file "$pf" > "$dir/summary.json" 2> "$dir/stderr.txt"
    run_dir=$(sed -n 's/^run_dir=//p' "$dir/stderr.txt" | tail -n 1)
    cp "$run_dir/answer.md" "$dir/answer.md" 2> /dev/null || : > "$dir/answer.md"
    cp "$run_dir/events.jsonl" "$dir/trace.txt" 2> /dev/null || : > "$dir/trace.txt"
  fi
}

# skill_loaded <trace>: whether the agent loaded the skill (a Skill call, or a read of its SKILL.md).
skill_loaded() {
  if [ "$harness" = claude ]; then
    jq -e -s 'any(.[]; .type == "assistant" and any(.message.content[]?;
      .type == "tool_use" and .name == "Skill" and (.input.skill // "" | test("saving-session-state"))))' "$1" > /dev/null
  else
    grep -Eq 'skill://saving-session-state|saving-session-state/SKILL\.md' "$1"
  fi
}
# Files added to the notes home since its first commit, committed or not.
notes_added() {
  local first
  first=$(git -C "$1/notes" rev-list --max-parents=0 HEAD)
  { git -C "$1/notes" diff --name-only --diff-filter=A "$first"; git -C "$1/notes" ls-files --others --exclude-standard; } | sort -u
}
# Files that differ from the notes home's last commit, including new ones.
notes_changes() { git -C "$1/notes" status --porcelain --untracked-files=all 2> /dev/null; }
# Markdown in the repository other than the notes home, tracked or not.
repo_md() { (cd "$1/widget" && git ls-files -co --exclude-standard -- '*.md' | while read -r f; do cat "$f"; done); }

for scenario in "${scenarios[@]}"; do
  [ -f "$evals/scenarios/$scenario.md" ] || { echo "unknown scenario: $scenario" >&2; exit 2; }
  dir=$(CDPATH= cd -- "$(mktemp -d "${TMPDIR:-/tmp}/saving-session-state-eval.XXXXXX")" && pwd)
  setup "$dir" "$scenario"
  prompt "$dir" "$scenario" > "$dir/prompt.md"
  echo "== $scenario ($harness${model:+ $model}) sandbox: $dir"
  start=$(date +%s)
  run_agent "$dir" "$dir/prompt.md"
  echo "   finished in $(($(date +%s) - start)) s"

  check "the skill was loaded" "skill_loaded '$dir/trace.txt'"
  check "the agent gave a final answer" "grep -q '[^[:space:]]' '$dir/answer.md'"
  case $scenario in
    repo-only)
      check "the BOM fixture gotcha is in the repository's docs" "repo_md '$dir' | grep -qi 'write_bytes\|as bytes\|binary'"
      check "the 0.2.0 release step is in the repository" "repo_md '$dir' | grep -q '0\.2\.0'"
      check "the Latin-1 question is recorded in the repository or the answer" \
        "{ repo_md '$dir'; cat '$dir/answer.md'; } | grep -qi 'latin-1'"
      ;;
    notes-home)
      check "the project note's current state was replaced" "! grep -q 'Investigating a KeyError' '$dir/notes/projects/widget.md'"
      check "the project note has the 0.2.0 release step" "grep -q '0\.2\.0' '$dir/notes/projects/widget.md'"
      check "the project note has the Latin-1 question" "grep -qi 'latin-1' '$dir/notes/projects/widget.md'"
      check "no new files in the notes home (no session logs)" "[ -z \"\$(notes_added '$dir')\" ]"
      check "the BOM fixture gotcha is in the repository's docs" "repo_md '$dir' | grep -qi 'write_bytes\|as bytes\|binary'"
      check "no notes-home path in the repository's files or commits" \
        "! { repo_md '$dir'; git -C '$dir/widget' log --format=%B; } | grep -q 'projects/widget.md\|$dir/notes'"
      ;;
    relay-caller)
      check "the final message holds a tagged handoff note" "grep -q '<handoff-note>' '$dir/answer.md' && grep -q '</handoff-note>' '$dir/answer.md'"
      check "the agent left the caller's note file to the caller" "[ ! -e '$dir/tmp/relay-note.md' ]"
      check "the project note's current state was replaced" "! grep -q 'Investigating a KeyError' '$dir/notes/projects/widget.md'"
      ;;
    already-captured)
      check "the notes home is unchanged" "[ -z \"\$(notes_changes '$dir')\" ] && [ \"\$(git -C '$dir/notes' rev-list --count HEAD)\" = 1 ]"
      check "the repository is unchanged" "[ -z \"\$(git -C '$dir/widget' status --porcelain)\" ] && [ \"\$(git -C '$dir/widget' rev-list --count HEAD)\" = 3 ]"
      ;;
  esac
  [ "$keep" = 1 ] || [ "$failures" -gt 0 ] || rm -rf "$dir"
done

echo
echo "failures=$failures"
[ "$failures" -eq 0 ]
