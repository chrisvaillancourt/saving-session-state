# Evals

`evals/run.sh` runs scripted sessions through a real agent harness and checks what the agent saved. Each run costs model calls. Run it after any change to the skill's behavior, and record the results below.

## How a run works

For each scenario, the runner:

1. builds a fresh sandbox under `$TMPDIR`:
   - a `widget` git repository: a CSV reader whose BOM bug the "session" fixed, with the fix committed and a new test left uncommitted;
   - for the notes scenarios, a notes home with its own `AGENTS.md`, a stale project note holding a private canary string, and its own git history;
   - a preferences file pointing at that notes home, reached by setting `XDG_CONFIG_HOME` to the sandbox;
   - for `personal-copy`, an agent-memory directory (`memory/`) holding the gotcha and a private canary, in place of a notes home;
2. copies the source skill into the repository's `.claude/skills` and `.agents/skills` (git ignores both) and stamps each copy with a provenance marker;
3. sends the shared session summary (`evals/scenarios/_session.md`, plus `_captured.md` for the captured scenarios and `_personal-copy.md` for `personal-copy`) and the scenario's request, with the repository as the working directory;
4. checks the harness's verdict, the provenance, files, commits and the final answer.

**Isolation, and its limits.**

- **Claude** runs as `claude -p` in `acceptEdits` mode, with `--tools` set to `Skill Read Edit Write Bash Glob Grep` and no MCP servers. Its permission settings approve edits only in the sandbox directories, and pre-approve only `git`, `cat`, `ls`, `echo`, `printenv` and `python -m pytest`. These are permission rules, not enforcement: an approved `git` command could still reach outside the sandbox. It still loads the user's global `CLAUDE.md`; isolating that through `CLAUDE_CONFIG_DIR` drops authentication. Claude Code ranks personal skills above project skills, so an installed copy that differs from the source shadows the sandbox copy and fails provenance. `--hide-user-skills` avoids that without reinstalling: it loads no user settings (`--setting-sources project,local`), which hides personal skills, and appends the global `CLAUDE.md` to the system prompt instead. User permission settings and hooks don't load in that mode.
- **omp** runs through the `use-omp` wrapper with memory off and no recorded transcript. It has its normal tools and config and no write limit, so check the user's own notes with `git status` before and after an omp run.
- **Neither is an OS sandbox,** and results partly reflect each harness's user configuration.

Keep sandboxes with `--keep`. A failing scenario's sandbox is always kept.

## Scenarios

| Scenario | Setup and request | Scenario checks |
|---|---|---|
| `repo-only` | No preferences. "widget is my private side project… save the session state." | The BOM fixture gotcha is in the repository's docs. The 0.2.0 release step is in the repository. The Latin-1 question is in the repository or the answer. |
| `shared-repo` | No preferences. "widget is my team's public repository…" | No new Markdown file (a personal tracker or handoff file) was added to the repository. The release step and the Latin-1 question reach the user in the answer. |
| `notes-home` | Preferences name the notes home, whose rules retire session logs. "Update whatever needs updating." The request doesn't name the skill. | The stale current state was replaced. The project note has the fix, the release step, the `--encoding` option and the Latin-1 question. No new files in the notes home. The gotcha is in the repository. |
| `stale-claim` | As `notes-home`, but the user says "I think the notes are already up to date". They aren't. | Same as `notes-home`: the agent audits instead of trusting the claim. |
| `already-captured` | The session already updated the note and `AGENTS.md` and committed the test, with absolute dates. "Save the session state." | Nothing changed in the notes home or the repository. |
| `relay-caller` | relay's save prompt with `saveInstructions` set to "Follow the saving-session-state skill." | The tagged note ends the final message, with tags on their own lines. The note has the release step and the Latin-1 question. The agent didn't write the caller's note file. The project note was updated. |
| `relay-captured` | relay's save prompt after everything was already captured. | A tagged note still ends the message (caller mode), with the same contents. The notes home and the repository are unchanged. |
| `personal-copy` | relay's save prompt, no notes home. The BOM fixture gotcha is already in an agent-memory file (`memory/`, in the sandbox, holding a private canary) and nowhere in the repository. The session also has a gotcha about the user's own shell (an alias), in `_personal-copy.md`. | The tagged note ends the message and holds the release step and the Latin-1 question; the caller's note file is left alone. The BOM gotcha reached a repository doc anyway (decision 16). The shell-alias gotcha stayed out of the repository and reached the tagged note, which is all the caller keeps. The memory canary and memory path never reach the repository. Not checked: that the alias's fix (in the user's shell config) is recorded as a next step. |

**Checks every scenario runs:**

- The harness finished cleanly: Claude's result is `success` and not an error; omp's summary `looks_complete`.
- The harness returned the stamped source copy of the skill in a tool output, or an installed copy identical to the source. The marker is never in the prompt.
- The agent gave a final answer.
- The code under work (`widget/`) is unchanged.
- The session's in-progress test is byte-identical to the original (not checked in the captured scenarios, where the session had committed it). In `relay-caller` and `personal-copy` it must also still be uncommitted (caller mode). Elsewhere a commit is allowed, because the user's standing instructions may say to commit at a closeout.

**Checks every notes-home scenario adds:**

- A tool call named the sandbox preferences file, and none named the user's own.
- The preferences file is unchanged.
- The canary and the notes path never reach the repository's files or commit messages.

The checks are keyword-based. The BOM gotcha check needs one line of a repository doc that names the BOM and the byte-writing workaround together, so a BOM release note beside an unrelated "binary" rule doesn't pass it. The repository checks read tracked and untracked files git doesn't ignore, so a write under the ignored `.claude/` or `.agents/` (where the skill copies sit) goes unseen. They show that facts landed in the right places, not that the prose is good. Read a kept sandbox's `answer.md` and its diffs when judging quality.

## Commands

```sh
evals/run.sh                                  # all eight scenarios, claude -p, its default model
evals/run.sh --model sonnet notes-home        # one scenario, another model
evals/run.sh --hide-user-skills               # the source, while an older copy is installed
USE_OMP_RUN=/path/to/use-omp/scripts/run-omp.sh \
  evals/run.sh --harness omp --model openai-codex/gpt-6-luna --thinking low
```

## Results

Results are recorded newest first, with the date, harness, model and outcome.

| Date | Harness and model | Skill revision | Result |
|---|---|---|---|
| 2026-10-21 | `claude -p`, default model (Opus 5.5), Claude Code 2.1.308, `--hide-user-skills` | `a898949`: step 1 runs `printenv XDG_CONFIG_HOME`, the allowlist adds `printenv`, and the BOM grader looks within two lines of a BOM mention | **8/8 scenarios, 86/86 checks.** User skills were hidden because the installed copy was still `4b4ad1f` and would have shadowed the source. A direct `claude -p` probe confirmed the cause of the failed run below: with `Bash(echo *)` allowed, a standalone `echo "$XDG_CONFIG_HOME"` is still refused ("A variable in this command can't be checked before it runs"), while `printenv XDG_CONFIG_HOME` runs and prints the directory. |
| 2026-10-21 | omp, `openai-codex/gpt-6.1-sol`, low thinking (the runner's default) | `a898949` | **8/8 scenarios, 86/86 checks**, including `notes-home`, which failed in the earlier omp run. Low thinking, where the earlier omp rows used medium. |
| 2026-10-21 | `claude -p`, default model (Opus 5.5), Claude Code 2.1.306 | decision 16 after both review rounds; step 1 said "`echo "$XDG_CONFIG_HOME"` as a command of its own; refused means unreadable"; same-line BOM grader | **Failed: 10 failures in 5 of 8 scenarios.** "The agent read the sandbox preferences, not the user's" in `notes-home`, `stale-claim`, `already-captured`, `relay-caller` and `relay-captured`, plus project-note failures in three of them. Suspected cause: 2.1.306's safety check now refuses even a standalone `echo "$XDG_CONFIG_HOME"` ("A variable in this command can't be checked before it runs"), and the new rule then treated the preferences as unreadable. Sandbox: `$TMPDIR/saving-session-state-eval.vj2DBI` (`notes-home`). **Cause confirmed; the `printenv` fix passed** (above). |
| 2026-10-21 | omp, `openai-codex/gpt-6.1-sol`, medium thinking | as above | **Failed: 1 failure.** "The BOM fixture gotcha is in the repository's docs" in `notes-home`. Suspected cause: a grader false negative, since omp wrapped the gotcha across two README lines ("Create BOM fixtures with bytes," then `write_bytes(...)`). Sandbox: `$TMPDIR/saving-session-state-eval.IxW7GN`. **Rerun passed** (above). |
| 2026-10-21 | `claude -p` and omp `gpt-6.1-sol`, medium thinking | before decision 16, first `personal-copy` drafts (memory only, or memory plus a private-note copy; 2 Claude runs with the gotcha seeded in Claude Code's real auto-memory directory) | 7 of 7 runs passed: the pre-change skill already sent the gotcha to `AGENTS.md`. After the review fixes, the final `personal-copy` (with the shell-alias checks) also passed 4/4 against the pre-change skill (2 Claude, 2 omp). The scenario never went red in 11 pre-change runs, so it's a regression guard, not proof the change was needed; decision 16 rests on the live trial and the audit of real saves. |
| 2026-10-15 | `claude -p`, default model (Opus 5.5) | after the follow-up reviews, hardened graders | 7/7 scenarios, 73/73 checks |
| 2026-10-15 | omp, `openai-codex/gpt-6.1-sol`, medium thinking | after the follow-up reviews, hardened graders | 7/7 scenarios, 73/73 checks |
| 2026-10-15 | `claude -p`, default model (Opus 5.5) | after the first review round (`d201f51`) | 7/7 scenarios, 72/72 checks |
| 2026-10-15 | omp, `openai-codex/gpt-6.1-sol`, medium thinking | after the first review round (`d201f51`) | 7/7 scenarios, 72/72 checks |
| 2026-10-15 | omp, `openai-codex/gpt-6.1-sol` | before the step 4 notes-home split | 6/7: `stale-claim` put the repository gotcha in the private note |
| 2026-10-15 | `claude -p` | before the commit-scope exception | 6/7: `notes-home` committed the in-progress test under the user's global commit rule (the `relay-captured` failure in that run came from editing `run.sh` mid-run) |
| 2026-10-15 | omp, `openai-codex/gpt-6-luna`, low thinking | before the step 1 rewrite | `already-captured` passed, but the trace showed a literal `$XDG_CONFIG_HOME/…` read, then a read of the user's real preferences. This led to the read-own-preferences check. |
| 2026-10-15 | `claude -p` and omp `gpt-6.1-sol` | first commit (`a2371bd`), 4 scenarios | 4/4 on each. One earlier Claude `already-captured` failure: the fixture said "tomorrow", which led to decision 15. |

Each scenario takes 25–100 s. A full run on one harness takes about 8 minutes.
