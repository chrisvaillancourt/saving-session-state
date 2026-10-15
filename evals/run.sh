#!/usr/bin/env bash
# Behavioral evals: run scripted sessions through a real agent harness and check what it saved.
# Usage: evals/run.sh [--harness claude|omp] [--model MODEL] [--thinking LEVEL] [--keep] [scenario...]
#   Scenarios: repo-only shared-repo notes-home stale-claim already-captured relay-caller
#     relay-captured (default: all).
#   --harness claude (default) runs `claude -p`; omp runs `omp -p` through the use-omp wrapper
#     (set USE_OMP_RUN to its run-omp.sh path).
#   Each scenario gets a fresh sandbox under $TMPDIR: a git repository, a notes home with its
#   own git history, and a preferences file reached through XDG_CONFIG_HOME. A copy of the
#   source skill, stamped with a provenance marker, is placed in the repository's
#   .claude/skills and .agents/skills.
# Costs model calls. See docs/evals.md for what each scenario checks and the last results.
set -uo pipefail

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
evals="$repo/evals"
source_skill="$repo/skills/saving-session-state"
all=(repo-only shared-repo notes-home stale-claim already-captured relay-caller relay-captured)
harness=claude model="" thinking=low keep=0
scenarios=()
while [ $# -gt 0 ]; do
  case $1 in
    --harness) harness=$2; shift 2 ;;
    --model) model=$2; shift 2 ;;
    --thinking) thinking=$2; shift 2 ;;
    --keep) keep=1; shift ;;
    -h | --help) sed -n '2,13p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) scenarios+=("$1"); shift ;;
  esac
done
[ ${#scenarios[@]} -gt 0 ] || scenarios=("${all[@]}")
case $harness in
  claude) command -v claude > /dev/null || { echo "claude not found" >&2; exit 2; } ;;
  omp)
    [ -n "${USE_OMP_RUN:-}" ] && [ -f "$USE_OMP_RUN" ] || { echo "set USE_OMP_RUN to run-omp.sh" >&2; exit 2; }
    [ -n "$model" ] || { echo "--model is required for omp" >&2; exit 2; }
    ;;
  *) echo "unknown harness: $harness" >&2; exit 2 ;;
esac

failures=0 scenario_failures=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }
# Checks run without pipefail: `grep -q` closing a pipe early is a match, not a failure.
check() { if (set +o pipefail; eval "$2"); then pass "$1"; else fail "$1"; fi; }
g() { git -C "$1" -c user.name=eval -c user.email=eval@example.invalid -c commit.gpgsign=false "${@:2}"; }

has_notes() { case $1 in repo-only | shared-repo) return 1 ;; esac; }
is_captured() { case $1 in already-captured | relay-captured) return 0 ;; esac; return 1; }

# setup <dir> <scenario>: builds the sandbox. Runs under `set -e` in a subshell.
setup() {
  local dir=$1 scenario=$2 r n today tomorrow
  r="$dir/widget" n="$dir/notes"
  mkdir -p "$dir/config/saving-session-state" "$dir/tmp"
  cp -R "$evals/fixtures/repo" "$r"
  g "$r" init -q -b main
  g "$r" add -A
  g "$r" commit -qm "Initial widget"
  perl -pi -e 's/encoding="utf-8"/encoding="utf-8-sig"/' "$r/widget/parse.py"
  grep -q 'utf-8-sig' "$r/widget/parse.py"
  g "$r" commit -qam "Read CSVs with utf-8-sig"
  cat > "$r/tests/test_bom.py" << 'EOF'
from widget.parse import read_rows


def test_reads_bom_header(tmp_path):
    p = tmp_path / "excel.csv"
    p.write_bytes(b"\xef\xbb\xbf" + b"id,name\n1,a\n")
    assert read_rows(p)[0]["id"] == "1"
EOF
  cp "$r/tests/test_bom.py" "$dir/test_bom.orig"
  # A stamped copy of the source skill: the marker proves which copy the agent loaded.
  for d in .claude/skills .agents/skills; do
    mkdir -p "$r/$d"
    cp -R "$source_skill" "$r/$d/saving-session-state"
    printf '\n<!-- eval-provenance: %s -->\n' "$(basename "$dir")" >> "$r/$d/saving-session-state/SKILL.md"
  done
  printf '.claude/\n.agents/\n' >> "$r/.git/info/exclude"

  if has_notes "$scenario"; then
    cp -R "$evals/fixtures/notes" "$n"
    sed "s|NOTES_HOME|$n|" "$evals/fixtures/preferences.md" > "$dir/config/saving-session-state/preferences.md"
    cp "$dir/config/saving-session-state/preferences.md" "$dir/preferences.orig"
  fi
  if is_captured "$scenario"; then
    today=$(date +%Y-%m-%d)
    tomorrow=$(date -v+1d +%Y-%m-%d 2> /dev/null || date -d tomorrow +%Y-%m-%d)
    cat > "$n/projects/widget.md" << EOF
# widget

Side project: reads CSV exports into dictionaries. Private context: canary-q7v2. Code: the \`widget\` repository.

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
    g "$r" add -A
    g "$r" commit -qm "Test BOM headers and note the fixture gotcha"
  fi
  if [ -d "$n" ]; then
    g "$n" init -q -b main
    g "$n" add -A
    g "$n" commit -qm "Notes"
  fi
  g "$r" rev-parse HEAD > "$dir/repo-head"
}

# prompt <dir> <scenario>: the session summary plus the scenario's request.
prompt() {
  cat "$evals/scenarios/_session.md"
  is_captured "$2" && cat "$evals/scenarios/_captured.md"
  printf '\n'
  sed "s|RELAY_NOTE_PATH|$1/tmp/relay-note.md|" "$evals/scenarios/$2.md"
}

# run_agent <dir> <prompt file>: writes answer.md, trace.txt and harness-ok (the harness's verdict).
run_agent() {
  local dir=$1 pf=$2 rc run_dir
  if [ "$harness" = claude ]; then
    (cd "$dir/widget" && XDG_CONFIG_HOME="$dir/config" claude -p --verbose --output-format stream-json \
      --permission-mode acceptEdits --strict-mcp-config --no-session-persistence \
      --tools Skill Read Edit Write Bash Glob Grep \
      --add-dir "$dir/notes" "$dir/config" "$dir/tmp" \
      --allowedTools 'Bash(git *)' 'Bash(cat *)' 'Bash(ls *)' 'Bash(echo *)' 'Bash(python -m pytest*)' \
      ${model:+--model "$model"} < "$pf" > "$dir/trace.txt" 2> "$dir/stderr.txt")
    rc=$?
    jq -rs '[.[] | select(.type == "result")] | last | .result // ""' "$dir/trace.txt" > "$dir/answer.md" 2> /dev/null
    if [ "$rc" -eq 0 ] && jq -es '[.[] | select(.type == "result")] | last
        | .subtype == "success" and .is_error == false' "$dir/trace.txt" > /dev/null 2>&1; then
      echo ok > "$dir/harness-ok"
    else
      echo "exit $rc" > "$dir/harness-ok"
    fi
  else
    printf 'memory:\n  backend: off\n' > "$dir/omp-overlay.yml"
    XDG_CONFIG_HOME="$dir/config" bash "$USE_OMP_RUN" --workspace "$dir/widget" --model "$model" \
      --thinking "$thinking" --max-time 20m --label "saving-session-state eval" --no-record \
      --config "$dir/omp-overlay.yml" --prompt-file "$pf" > "$dir/summary.json" 2> "$dir/stderr.txt"
    rc=$?
    run_dir=$(sed -n 's/^run_dir=//p' "$dir/stderr.txt" | tail -n 1)
    cp "$run_dir/answer.md" "$dir/answer.md" 2> /dev/null || : > "$dir/answer.md"
    cp "$run_dir/events.jsonl" "$dir/trace.txt" 2> /dev/null || : > "$dir/trace.txt"
    if [ "$rc" -eq 0 ] && jq -e '.looks_complete == true' "$dir/summary.json" > /dev/null 2>&1; then
      echo ok > "$dir/harness-ok"
    else
      echo "exit $rc" > "$dir/harness-ok"
    fi
  fi
}

# tool_outputs <dir>: text the harness returned to the agent (tool results, loaded skills), not text
# the agent or the prompt wrote. tool_inputs <dir>: the arguments of the agent's tool calls.
tool_outputs() {
  if [ "$harness" = claude ]; then
    jq -r 'select(.type == "user") | .message.content | tostring' "$1/trace.txt" 2> /dev/null
  else
    jq -r 'select(.type == "tool_execution_end") | .result | tostring' "$1/trace.txt" 2> /dev/null
  fi
}
tool_inputs() {
  if [ "$harness" = claude ]; then
    jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input | tostring' "$1/trace.txt" 2> /dev/null
  else
    jq -r 'select(.type == "tool_execution_start") | .args | tostring' "$1/trace.txt" 2> /dev/null
  fi
}
# provenance <dir>: the harness returned the stamped sandbox copy of the skill, or an installed copy
# identical to the source (Claude Code ranks personal skills above project skills). The marker is
# never in the prompt, so it can reach a tool output only by loading the skill.
provenance() {
  local dir=$1 base marker
  marker="eval-provenance: $(basename "$dir")"
  ! grep -q "$marker" "$dir/prompt.md" || return 1
  tool_outputs "$dir" | grep -q "$marker" && return 0
  base=$(grep -o 'Base directory for this skill: [^"\\]*' "$dir/trace.txt" | head -n 1 | sed 's/^Base directory for this skill: //')
  [ -n "$base" ] && [ -d "$base" ] && diff -rq "$base" "$source_skill" > /dev/null
}
# The tagged note: opening and closing tags on their own lines, the closing tag last.
note_body() { awk '/^[ \t]*<handoff-note>[ \t]*$/ { body = ""; inside = 1; next }
  /^[ \t]*<\/handoff-note>[ \t]*$/ { inside = 0; last = body; next } inside { body = body $0 "\n" }
  END { printf "%s", last }' "$1/answer.md"; }
note_ends_answer() { [ "$(grep -v '^[[:space:]]*$' "$1/answer.md" | tail -n 1 | tr -d ' \t')" = '</handoff-note>' ]; }
# Files added to the notes home since its first commit, committed or not.
notes_added() {
  { git -C "$1/notes" diff --name-only --diff-filter=A "$(git -C "$1/notes" rev-list --max-parents=0 HEAD)"
    git -C "$1/notes" ls-files --others --exclude-standard; } | sort -u
}
notes_untouched() { [ -z "$(git -C "$1/notes" status --porcelain)" ] && [ "$(git -C "$1/notes" rev-list --count HEAD)" = 1 ]; }
# Everything the agent changed in the repository: diffs since setup (committed or not), new files and commit messages.
repo_changes() {
  (cd "$1/widget" && git diff "$(cat "$1/repo-head")" && git ls-files --others --exclude-standard | while read -r f; do cat "$f"; done
    git log --format=%B "$(cat "$1/repo-head")..HEAD")
}
repo_md() { (cd "$1/widget" && git ls-files -co --exclude-standard -- '*.md' | while read -r f; do cat "$f"; done); }
new_repo_md() { (cd "$1/widget" && { git diff --name-only --diff-filter=A "$(cat "$1/repo-head")"; git ls-files --others --exclude-standard; } | grep '\.md$'); }
code_untouched() { [ -z "$(cd "$1/widget" && git diff "$(cat "$1/repo-head")" -- widget)" ]; }
test_uncommitted() { (cd "$1/widget" && git ls-files --others --exclude-standard | grep -qx 'tests/test_bom.py'); }
test_intact() { cmp -s "$1/test_bom.orig" "$1/widget/tests/test_bom.py" && [ -z "$(git -C "$1/widget" diff --name-only "$(cat "$1/repo-head")" -- tests/test_parse.py)" ]; }
# A tool call named the sandbox preferences, and none named the user's own.
read_own_preferences() {
  tool_inputs "$1" | grep -q "$1/config/saving-session-state/preferences.md" \
    && ! tool_inputs "$1" | grep -q -e "$HOME/.config/saving-session-state" -e '~/.config/saving-session-state'
}

for scenario in "${scenarios[@]}"; do
  [ -f "$evals/scenarios/$scenario.md" ] || { echo "unknown scenario: $scenario" >&2; exit 2; }
  before=$failures
  dir=$(CDPATH= cd -- "$(mktemp -d "${TMPDIR:-/tmp}/saving-session-state-eval.XXXXXX")" && pwd -P)
  echo "== $scenario ($harness${model:+ $model}) sandbox: $dir"
  # Not inside `if`: bash ignores `set -e` in a condition, so a failed setup step would go unnoticed.
  (set -e; setup "$dir" "$scenario") > "$dir/setup.log" 2>&1
  setup_rc=$?
  if [ "$setup_rc" -ne 0 ]; then
    fail "sandbox setup (see $dir/setup.log)"
    scenario_failures=$((scenario_failures + 1))
    continue
  fi
  prompt "$dir" "$scenario" > "$dir/prompt.md"
  start=$(date +%s)
  run_agent "$dir" "$dir/prompt.md"
  echo "   finished in $(($(date +%s) - start)) s"

  check "the harness finished the run cleanly ($(cat "$dir/harness-ok"))" "[ \"\$(cat '$dir/harness-ok')\" = ok ]"
  check "the agent loaded the source skill (provenance marker or identical installed copy)" "provenance '$dir'"
  check "the agent gave a final answer" "grep -q '[^[:space:]]' '$dir/answer.md'"
  check "the code under work is unchanged" "code_untouched '$dir'"
  if has_notes "$scenario"; then
    check "the agent read the sandbox preferences, not the user's" "read_own_preferences '$dir'"
    check "the preferences file is unchanged" "cmp -s '$dir/preferences.orig' '$dir/config/saving-session-state/preferences.md'"
    check "no private canary or notes path reached the repository" \
      "! repo_changes '$dir' | grep -q -e 'canary-q7v2' -e 'projects/widget.md' -e '$dir/notes'"
  fi
  is_captured "$scenario" || check "the session's in-progress test is intact" "test_intact '$dir'"
  case $scenario in relay-caller)
    check "caller mode left the in-progress test uncommitted" "test_uncommitted '$dir'" ;;
  esac
  case $scenario in
    repo-only)
      check "the BOM fixture gotcha is in the repository's docs" "repo_md '$dir' | grep -qi -e 'write_bytes' -e 'as bytes' -e 'binary'"
      check "the 0.2.0 release step is in the repository" "repo_md '$dir' | grep -q '0\.2\.0'"
      check "the Latin-1 question is in the repository or the answer" "{ repo_md '$dir'; cat '$dir/answer.md'; } | grep -qi 'latin-1'"
      ;;
    shared-repo)
      check "no personal tracker or handoff file was added to the shared repository" "[ -z \"\$(new_repo_md '$dir')\" ]"
      check "the 0.2.0 release step and the Latin-1 question reach the user" "grep -q '0\.2\.0' '$dir/answer.md' && grep -qi 'latin-1' '$dir/answer.md'"
      ;;
    notes-home | stale-claim)
      check "the project note's stale current state was replaced" "! grep -q 'Investigating a KeyError' '$dir/notes/projects/widget.md'"
      check "the project note has the fix, the release step, the encoding option and the Latin-1 question" \
        "grep -q 'utf-8-sig' '$dir/notes/projects/widget.md' && grep -q '0\.2\.0' '$dir/notes/projects/widget.md' \
         && grep -q -- '--encoding' '$dir/notes/projects/widget.md' && grep -qi 'latin-1' '$dir/notes/projects/widget.md'"
      check "no new files in the notes home (no session logs)" "[ -z \"\$(notes_added '$dir')\" ]"
      check "the BOM fixture gotcha is in the repository's docs" "repo_md '$dir' | grep -qi -e 'write_bytes' -e 'as bytes' -e 'binary'"
      ;;
    already-captured)
      check "the notes home is unchanged" "notes_untouched '$dir'"
      check "the repository is unchanged" "[ -z \"\$(git -C '$dir/widget' status --porcelain)\" ] && [ \"\$(git -C '$dir/widget' rev-parse HEAD)\" = \"\$(cat '$dir/repo-head')\" ]"
      ;;
    relay-caller | relay-captured)
      check "the tagged note ends the final message, with tags on their own lines" "note_ends_answer '$dir' && [ -n \"\$(note_body '$dir')\" ]"
      check "the note holds the release step and the Latin-1 question" "note_body '$dir' | grep -q '0\.2\.0' && note_body '$dir' | grep -qi 'latin-1'"
      check "the agent left the caller's note file to the caller" "[ ! -e '$dir/tmp/relay-note.md' ]"
      if [ "$scenario" = relay-caller ]; then
        check "the project note's stale current state was replaced" "! grep -q 'Investigating a KeyError' '$dir/notes/projects/widget.md'"
      else
        check "the notes home is unchanged" "notes_untouched '$dir'"
        check "the repository is unchanged" "[ -z \"\$(git -C '$dir/widget' status --porcelain)\" ] && [ \"\$(git -C '$dir/widget' rev-parse HEAD)\" = \"\$(cat '$dir/repo-head')\" ]"
      fi
      ;;
  esac
  if [ "$failures" -gt "$before" ]; then
    scenario_failures=$((scenario_failures + 1))
  elif [ "$keep" = 0 ]; then
    rm -rf "$dir"
  fi
done

echo
echo "failures=$failures scenarios_failed=$scenario_failures of ${#scenarios[@]}"
[ "$failures" -eq 0 ]
