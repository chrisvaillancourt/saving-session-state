# Evals

`evals/run.sh` runs scripted sessions through a real agent harness and checks what the agent saved. Each run costs model calls. Run it after any change to the skill's behavior, and record the results below.

## How a run works

For each scenario, the runner:

1. builds a fresh sandbox under `$TMPDIR`:
   - a `widget` git repository: a CSV reader whose BOM bug the "session" fixed, with the fix committed and a new test left uncommitted;
   - for every scenario except `repo-only`, a notes home with its own `AGENTS.md`, a stale project note and its own git history;
   - a preferences file pointing at that notes home, reached by setting `XDG_CONFIG_HOME` to the sandbox;
2. links the source skill into the repository's `.claude/skills` and `.agents/skills` (git ignores both), so this checkout is tested, not an installed copy;
3. sends the shared session summary (`evals/scenarios/_session.md`) plus the scenario's request, with the repository as the working directory;
4. checks the files, commits and final answer.

Claude runs as `claude -p` in `acceptEdits` mode, with writes limited to the sandbox and shell access limited to `git`, `cat`, `ls`, `echo` and `python -m pytest`. omp runs through the `use-omp` wrapper with memory off and no recorded transcript. omp has no equivalent write limit, so check the user's own notes with `git status` before and after an omp run.

Keep sandboxes with `--keep`. A failing scenario's sandbox is always kept.

## Scenarios

| Scenario | The request | Checks |
|---|---|---|
| `repo-only` | "widget is my personal side project… save the session state." No preferences file. | The skill loaded. The BOM fixture gotcha is in the repository's docs. The 0.2.0 release step is in the repository. The Latin-1 question is in the repository or the answer. |
| `notes-home` | "Update whatever needs updating." The preferences name the notes home, whose rules retire session logs. | The skill loaded through its description (the request doesn't name it). The project note's stale current state was replaced and has the release step and the Latin-1 question. No new files in the notes home. The gotcha is in the repository. No notes-home path in the repository's files or commit messages. |
| `relay-caller` | relay's save prompt with `saveInstructions` set to "Follow the saving-session-state skill." | The final message holds a tagged handoff note. The agent didn't write the caller's note file. The project note was still updated. |
| `already-captured` | The summary says everything was already saved, and it was. | Nothing changed in the notes home or the repository. |

Every scenario also checks that the agent loaded the skill and gave a final answer.

## Commands

```sh
evals/run.sh                                  # all scenarios, claude -p, its default model
evals/run.sh --model sonnet notes-home        # one scenario, another model
USE_OMP_RUN=/path/to/use-omp/scripts/run-omp.sh \
  evals/run.sh --harness omp --model openai-codex/gpt-6-luna --thinking low
```

## Results

Results are recorded newest first, with the date, harness, model and outcome.
