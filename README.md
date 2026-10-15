# saving-session-state

An [Agent Skill](https://agentskills.io) that saves a work session's state before you close the session or compact its context. It works in Claude Code, Oh My Pi (omp), Codex and any other harness that reads the open Agent Skills format.

At a stopping point, the agent:

1. reads your preferences, which say where your notes live and when to use them;
2. lists everything the session touched, checking each repository with git;
3. finds the **gaps**: decisions, gotchas, workarounds, status, next steps and open questions that live only in the conversation;
4. gives each gap one **durable home**: the repository's docs, your notes, a tracker, or a drafted ticket comment for you to approve;
5. updates those homes in place, so a status section says where things stand now instead of growing into a log;
6. writes a handoff note only for what has no other home, or when the tool that called it asks for one;
7. commits the docs and notes it wrote, leaving the session's in-progress work as it is, and reports what it saved where.

When the session's artifacts already hold everything, it says so and writes nothing.

## Why it exists

Ending a session well is the same chore every time: update the docs and notes the work made stale, and write down what happened, what broke and what's next. Where that goes depends on the work. A repository with no other notes keeps it in its own docs. Work you track in a notes vault keeps it there. A greenfield session has no home yet. Doing this by hand, or with a prompt retyped each time, gives uneven results. Tools that save to one fixed place miss the others.

The skill holds the routine in one place, so a person can run it at a stopping point and a tool can run it as one step of a larger flow. The [relay](https://github.com/chrisvaillancourt/claude-relay) Claude Code plugin runs it before compacting (see [Use with relay](#use-with-relay)). [docs/decisions.md](docs/decisions.md) records why it's built this way.

## Install

The skill is installed with the [`skills` CLI](https://github.com/vercel-labs/skills). From a checkout of this repository:

```sh
pnpm dlx skills add "$PWD" --skill saving-session-state --agent claude-code universal --global --yes
```

Or install from GitHub without a checkout:

```sh
pnpm dlx skills add chrisvaillancourt/saving-session-state --skill saving-session-state --agent claude-code universal --global --yes
```

Where Socket Firewall is required, prefix the command with `sfw`. `npx --yes skills add …` works the same way, and so does a bare `skills add …` when the CLI is installed.

Name both agents. `universal` puts the skill in `~/.agents/skills/saving-session-state`, the directory omp and Codex read. `claude-code` then symlinks it into `~/.claude/skills`, so all three harnesses share one copy. With `--agent claude-code` alone, the CLI (1.7.0, local source) copies the skill only into `~/.claude/skills`, and omp never sees it. For another harness, add its identifier from `skills add --help`.

Editing this checkout doesn't change the installed copy. Run the same command again after a change. Check the install with:

```sh
pnpm dlx skills list --global
```

Start a new session after installing. A session that's already running may not see new skills.

## Use

Say you're at a stopping point ("I'm done for today; save the session state", "update the notes with what we did before I close this") or invoke it by name:

| Harness | Command |
|---|---|
| Claude Code | `/saving-session-state` |
| omp | `/skill:saving-session-state` |
| Codex | `$saving-session-state` |

Add focus in your own words: "make sure the notes cover the migration plan".

## Preferences

Tell the skill where your notes live in `saving-session-state/preferences.md` under your config directory: `$XDG_CONFIG_HOME` when it's set, otherwise `~/.config`. It's plain Markdown and sits outside the skill, so reinstalling leaves it alone, and every harness reads the same file. It covers:

- the notes homes you keep (vaults, work logs, trackers), with absolute paths and the file that holds each one's rules;
- which work belongs in each, and how to tell;
- what never goes where, for example private note paths in shared repositories.

Without the file, the skill uses the repository's own docs and asks before creating a new home. [references/preferences.md](skills/saving-session-state/references/preferences.md) has an example.

## Use with relay

relay's `/relay` command saves, drafts a continuation prompt, compacts, then fills the prompt box. Its save turn has a `saveInstructions` option (from relay 0.3.0) that replaces the turn's first step. Set it to:

```text
Follow the saving-session-state skill.
```

Set it in `/config`, or in settings under `pluginConfigs["relay@relay"].options.saveInstructions` (the key is the plugin id). relay still asks for the handoff note inside `<handoff-note>` tags and saves it itself. The skill calls this **caller mode**: it asks no questions, always ends with the tagged note (even when nothing else needed saving), puts drafts awaiting your approval in the note, writes no note file of its own, and leaves in-progress code uncommitted.

Use relay 0.3.0 or later. It also takes the note from tags on their own lines, so a final message that mentions the tag names in prose can't be mistaken for the note.

The skill must stay model-invocable for this to work, because the save turn asks the model to load it.

## Repository layout

```text
skills/saving-session-state/      the installed skill
  SKILL.md                        the procedure, always read when the skill runs
  references/new-homes.md         read only when a gap has no existing home
  references/handoff-note.md      read only when a handoff note is needed
  references/preferences.md       read only when creating or changing preferences
scripts/check.sh                  offline checks: spec, disclosure, privacy, CLI discovery
evals/run.sh                      behavioral evals through a real harness (costs model calls)
evals/scenarios/, evals/fixtures/ the scripted sessions and the sandbox they run in
docs/decisions.md                 what was decided and why, with revisit triggers
docs/evals.md                     what each eval checks, and the latest results
docs/2026-10-15-reviews.md        the two independent reviews and what was done about each finding
```

## Verify

```sh
scripts/check.sh                 # free, about a second
evals/run.sh                     # seven scenarios through claude -p
USE_OMP_RUN=/path/to/run-omp.sh evals/run.sh --harness omp --model <provider/model>
```

[docs/evals.md](docs/evals.md) explains each scenario and records the latest results.

## License

[MIT](LICENSE).
