# Evals

`evals/run.sh` runs scripted sessions through a real agent harness and checks what the agent saved. Each run costs model calls. Run it after any change to the skill's behavior, and record the results below.

## How a run works

For each scenario, the runner:

1. builds a fresh sandbox under `$TMPDIR`:
   - a `widget` git repository: a CSV reader whose BOM bug the "session" fixed, with the fix committed and a new test left uncommitted;
   - for the notes scenarios, a notes home with its own `AGENTS.md`, a stale project note holding a private canary string, and its own git history;
   - a preferences file pointing at that notes home, reached by setting `XDG_CONFIG_HOME` to the sandbox;
2. copies the source skill into the repository's `.claude/skills` and `.agents/skills` (git ignores both) and stamps each copy with a provenance marker;
3. sends the shared session summary (`evals/scenarios/_session.md`, plus `_captured.md` for the captured scenarios) and the scenario's request, with the repository as the working directory;
4. checks the harness's verdict, the provenance, files, commits and the final answer.

**Isolation, and its limits.**

- **Claude** runs as `claude -p` in `acceptEdits` mode with `--tools` limited to `Skill Read Edit Write Bash Glob Grep`, no MCP servers, writes limited to the sandbox directories, and shell access limited to `git`, `cat`, `ls`, `echo` and `python -m pytest`. It still loads the user's global `CLAUDE.md`; isolating that through `CLAUDE_CONFIG_DIR` drops authentication.
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
| `relay-captured` | relay's save prompt after everything was already captured. | A tagged note still ends the message (caller mode), with the same contents. The notes home is unchanged. |

**Checks every scenario runs:**

- The harness finished cleanly: Claude's result is `success` and not an error; omp's summary `looks_complete`.
- The agent loaded the stamped source copy, or an installed copy identical to the source.
- The agent gave a final answer.
- The code under work (`widget/`) is unchanged.
- The session's in-progress test is intact (not checked in the captured scenarios, where the session had committed it). In `relay-caller` it must also still be uncommitted (caller mode). Elsewhere a commit is allowed, because the user's standing instructions may say to commit at a closeout.

**Checks every notes-home scenario adds:**

- The agent read the sandbox preferences, not the user's own.
- The preferences file is unchanged.
- The canary and the notes path never reach the repository's files or commit messages.

The checks are keyword-based. They show that facts landed in the right places, not that the prose is good. Read a kept sandbox's `answer.md` and its diffs when judging quality.

## Commands

```sh
evals/run.sh                                  # all seven scenarios, claude -p, its default model
evals/run.sh --model sonnet notes-home        # one scenario, another model
USE_OMP_RUN=/path/to/use-omp/scripts/run-omp.sh \
  evals/run.sh --harness omp --model openai-codex/gpt-6-luna --thinking low
```

## Results

Results are recorded newest first, with the date, harness, model and outcome.

| Date | Harness and model | Skill revision | Result |
|---|---|---|---|
| 2026-10-15 | `claude -p`, default model (Opus 5.5) | after both reviews | 7/7 scenarios, 72/72 checks |
| 2026-10-15 | omp, `openai-codex/gpt-6.1-sol`, medium thinking | after both reviews | 7/7 scenarios, 72/72 checks |
| 2026-10-15 | omp, `openai-codex/gpt-6.1-sol` | before the step 4 notes-home split | 6/7: `stale-claim` put the repository gotcha in the private note |
| 2026-10-15 | `claude -p` | before the commit-scope exception | 6/7: `notes-home` committed the in-progress test under the user's global commit rule (the `relay-captured` failure in that run came from editing `run.sh` mid-run) |
| 2026-10-15 | omp, `openai-codex/gpt-6-luna`, low thinking | before the step 1 rewrite | `already-captured` passed, but the trace showed a literal `$XDG_CONFIG_HOME/…` read, then a read of the user's real preferences. This led to the read-own-preferences check. |
| 2026-10-15 | `claude -p` and omp `gpt-6.1-sol` | first commit (`a2371bd`), 4 scenarios | 4/4 on each. One earlier Claude `already-captured` failure: the fixture said "tomorrow", which led to decision 15. |

Each scenario takes 25–100 s. A full run on one harness takes about 8 minutes.
