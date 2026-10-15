# AGENTS.md

This repository is the `saving-session-state` agent skill: the procedure an agent follows at a stopping point to move a session's state into durable homes, plus its checks and evals. Read this file first, then open only the documents your task needs.

## Where to look

| Task | Read |
|---|---|
| Understand what the skill tells agents to do | [skills/saving-session-state/SKILL.md](skills/saving-session-state/SKILL.md) |
| Change where gaps go, or how new homes are created | SKILL.md step 4, then [references/new-homes.md](skills/saving-session-state/references/new-homes.md) |
| Change the handoff note or the contract with a calling tool | [references/handoff-note.md](skills/saving-session-state/references/handoff-note.md) |
| Change the preferences file format | [references/preferences.md](skills/saving-session-state/references/preferences.md) and the README's Preferences section |
| Know why something is the way it is, before changing it | [docs/decisions.md](docs/decisions.md) |
| Run or change the evals, or read the latest results | [docs/evals.md](docs/evals.md) |
| See what the independent reviews found and how each finding was handled | [docs/2026-10-15-reviews.md](docs/2026-10-15-reviews.md) |
| Install, use, and how it composes with relay | [README.md](README.md) |

## Rules

- **The installed copy is separate.** `skills add … --agent claude-code universal --global` copies the skill to `~/.agents/skills` and symlinks it into `~/.claude/skills` (see the README; `claude-code` alone skips `~/.agents/skills`, so omp misses it). Editing this checkout doesn't change it. Ask the user before reinstalling.
- **Keep the skill harness-neutral.** Frontmatter uses only the open spec's fields. The body names actions ("read", "commit"), not one harness's tool names, and uses no harness variables such as `${CLAUDE_SKILL_DIR}`. `scripts/check.sh` enforces the frontmatter part.
- **Keep the skill and docs publishable.** No personal paths, account names, emails or organization names. Personal routing belongs in the user's preferences file, never in the skill. `scripts/check.sh` scans for some of this.
- **Respect the disclosure split.** SKILL.md holds what every run needs. A reference file holds one branch, is reached by a pointer in SKILL.md that names its condition, and links to no other reference file. Before moving material between them, read decision 6 in [docs/decisions.md](docs/decisions.md).
- **The skill stays model-invocable.** relay's `saveInstructions` asks the model to load it, so it must not get `disable-model-invocation`.
- **Caller mode is a contract with relay.** No questions, the tagged note always ends the turn, pending drafts go in the note, and in-progress work stays uncommitted. The `relay-caller` and `relay-captured` evals check it; change it only together with relay.
- **Don't reverse a decision silently.** If a change contradicts [docs/decisions.md](docs/decisions.md), raise it with the user first. Record new or changed decisions there, with the evidence and when to revisit.
- **Update every reference when something changes:** the README, AGENTS.md, docs, eval checks and the table above.

## Before you finish

1. Run `scripts/check.sh`. All checks must pass.
2. If the skill's behavior changed, run `evals/run.sh` (it costs model calls) and record the results in [docs/evals.md](docs/evals.md). A new behavior gets a scenario or a check that fails without it.
3. Commit with Conventional Commits (`feat(skill):`, `fix(skill):`, `docs:`, `test:`). Explain why in the body, and leave out tool attribution.
