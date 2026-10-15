# Design decisions

Each entry records what was decided, why, the alternatives, and when to revisit it. The skill was written on 2026-10-15 against the [Agent Skills specification](https://agentskills.io/specification), Anthropic's [skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), and the Claude Code, Codex and omp skill docs current then.

## Contents

1. [A standalone skill in its own repository](#1-a-standalone-skill-in-its-own-repository)
2. [The name](#2-the-name)
3. [What it keeps from earlier tools, and what it changes](#3-what-it-keeps-from-earlier-tools-and-what-it-changes)
4. [Personal routing lives in a preferences file](#4-personal-routing-lives-in-a-preferences-file)
5. [Model-invocable](#5-model-invocable)
6. [What SKILL.md holds and what is disclosed](#6-what-skillmd-holds-and-what-is-disclosed)
7. [Update in place; entry points hold current state](#7-update-in-place-entry-points-hold-current-state)
8. [A handoff note only for leftovers](#8-a-handoff-note-only-for-leftovers)
9. [Sharing rules that preferences can't relax](#9-sharing-rules-that-preferences-cant-relax)
10. [No questions when the caller needs the turn to end](#10-no-questions-when-the-caller-needs-the-turn-to-end)
11. [Composing with relay through `saveInstructions`](#11-composing-with-relay-through-saveinstructions)
12. [Spec-only frontmatter](#12-spec-only-frontmatter)
13. [Evals run the source skill in a sandbox](#13-evals-run-the-source-skill-in-a-sandbox)

## 1. A standalone skill in its own repository

**Decision:** The routine is an Agent Skill in its own repository, installed with the `skills` CLI. It isn't a Claude Code plugin, and it isn't part of a plugin marketplace.

**Why:** The user runs sessions in Claude Code and omp, and wants the same closeout in both. A skill in the open format is the one extension both read: omp and Codex load `~/.agents/skills`, and the CLI links the same copy into `~/.claude/skills`. Saving state is a model turn (read, decide, edit, commit), which a skill fully covers. The parts that need engine access (forking a side question, compacting, filling the prompt box) stay in the relay plugin, which calls this skill (decision 11). A repository of its own follows the user's other single-skill repositories and keeps it out of Claude-specific marketplaces that are due to be reworked.

**Alternatives:** A `/relay save` subcommand (Claude Code only, and tied to the plugin); a skill inside an existing Claude marketplace (the user is retiring those).

**Revisit if:** a harness the user adopts can't read Agent Skills, or the routine needs engine hooks a skill can't reach.

## 2. The name

**Decision:** `saving-session-state`.

**Why:** Anthropic's best practices recommend the gerund form (`processing-pdfs`); the open spec requires lowercase letters, digits and single hyphens, at most 64 characters, matching the directory. "State" covers both uses: closing a session at a stopping point, and checkpointing mid-session before compaction.

**Alternatives:** `closing-out-sessions` (wrong for relay's mid-session checkpoint); `writing-handoff-notes` and anything with "handoff" (the note is the fallback, not the job, and other `handoff` skills already exist); `saving-session-notes`, the earlier skill's name (it saves into docs, trackers and tickets, not only notes).

## 3. What it keeps from earlier tools, and what it changes

The skill starts from an earlier Claude Code skill, `saving-session-notes`, and also draws on relay's built-in save prompt, Matt Pocock's `handoff` skill and an end-of-day closeout checklist.

**Kept:**

- **Audit first.** List the session's artifacts, then find what isn't in them. Write nothing new when the artifacts already carry the state. (From `saving-session-notes`.)
- **Reference, don't summarize.** The handoff note points at artifacts instead of restating them. (From `saving-session-notes` and `handoff`.)
- **The gap kinds:** done, in progress, decisions, lessons, gotchas and workarounds, next steps with dispositions, open decisions. (From relay's save prompt and the user's routine.)
- **A closing checklist** before reporting. (From the closeout routine.)

**Changed:**

- **It does the updates.** `saving-session-notes` suggested where lasting lessons should go; this skill writes them, because the point is to close the session with nothing left to do.
- **It routes per gap**, among repository docs, notes homes, trackers and tickets. The earlier skill always wrote to one fixed notes folder, which misses work that lives only in a repository.
- **No fixed paths.** The earlier skill hard-coded a notes vault; this one reads the user's preferences (decision 4).
- **It handles greenfield sessions** through [references/new-homes.md](../skills/saving-session-state/references/new-homes.md).
- **It returns the note to a caller** instead of always writing a file (decision 11).

## 4. Personal routing lives in a preferences file

**Decision:** Which notes homes exist and when each applies lives in `${XDG_CONFIG_HOME:-$HOME/.config}/saving-session-state/preferences.md`, plain Markdown the agent reads in step 1. The skill itself names no paths.

**Why:**

- **Every harness reads the same file.** Claude Code loads `~/.claude/CLAUDE.md` and omp loads its own `AGENTS.md`, so routing in instruction files would have to be kept in step in two places.
- **Reinstalling leaves it alone.** The CLI replaces the skill directory on reinstall, so config kept inside the skill would be lost.
- **The skill stays publishable.** Paths to a private vault never enter the repository.
- **It's testable.** The evals point `XDG_CONFIG_HOME` at a sandbox (decision 13).
- **Markdown suits the reader.** The reader is an agent, so prose rules ("use the vault when the repository has a project note there") beat a schema.

**Alternatives:** routing in each harness's global instructions (duplicated, and not available to the skill's own logic); an environment variable (a path alone can't say when each home applies); hard-coding the user's vault in the skill (not publishable, and wrong for anyone else).

**Revisit if:** harnesses gain a shared user-instructions file, or the open spec adds per-user skill configuration.

## 5. Model-invocable

**Decision:** The skill has a trigger-bearing description and no `disable-model-invocation`.

**Why:** relay's save turn tells the model to follow the skill, so the model must be able to load it. People also say "wrap up" or "update the notes" without naming a skill. The cost is the description in every session's context (about 100 tokens).

**Revisit if:** relay stops calling it, and the always-loaded description proves to fire on the wrong prompts.

## 6. What SKILL.md holds and what is disclosed

**Decision:** SKILL.md holds the seven steps, the default routing table and the sharing rules: everything every run needs. Three reference files each hold one branch, reached by a pointer that names its condition:

| File | Read when |
|---|---|
| `references/new-homes.md` | a gap has no existing home (greenfield work) |
| `references/handoff-note.md` | step 6 calls for a note, or a caller asks for one |
| `references/preferences.md` | the user creates or changes preferences |

**Why:** The spec's progressive disclosure keeps SKILL.md small (under 500 lines and 5,000 tokens). The test for each piece is whether every run reaches it: routing and the sharing rules apply to every gap, so they stay inline. Greenfield work, notes and preference setup are branches. The sharing rules stay inline even though they're short reference, because a gotcha behind a pointer is missed when the agent doesn't recognize the trigger. References link to no other reference, per the one-level-deep rule.

**Revisit if:** evals show an agent skipping a reference it needed (sharpen the pointer first, then inline), or SKILL.md grows past about 150 lines.

## 7. Update in place; entry points hold current state

**Decision:** The skill edits existing homes instead of appending. A status section, "resume here" block or tracker header holds current state only, and superseded history moves to the home's history or is dropped when git keeps it.

**Why:** In the user's earlier notes system, status sections meant as current state piled up dated entries until the current state was hard to find, and session logs accumulated instead of being resolved into decisions, code or tickets. An append-only closeout would recreate both problems.

## 8. A handoff note only for leftovers

**Decision:** The note is written only when gaps remain with no durable home, or when a caller asks for one. There's one note per stream of work, and a new one replaces the old. The note says when it can be deleted.

**Why:** A note that restates the artifacts drifts from them and adds a second account to reconcile. In the earlier system, three handoff notes for one project overlapped. Notes without a retirement condition became logs.

## 9. Sharing rules that preferences can't relax

**Decision:** Two rules hold whatever the preferences say. Shared homes (repositories, tickets, pull requests) get only shared facts, never private note paths or content. Writes others can see are drafted for approval unless the user already asked for them in the session.

**Why:** A closeout touches both private notes and shared systems in one pass, which is where private paths leak into commits and pull requests. A ticket comment or message can't be unsent, and the user has a standing rule to approve them.

## 10. No questions when the caller needs the turn to end

**Decision:** When a calling tool needs the turn to finish (relay waits for the turn to end before it compacts), the skill picks the default, records the open question in the handoff note, and carries on.

**Why:** A question would end the turn without the tagged note, and relay would then stop the run with nothing saved for the next session. Recording the question keeps the decision with the user without blocking.

## 11. Composing with relay through `saveInstructions`

**Decision:** relay (0.3.0) has a `saveInstructions` option that replaces only the first step of its save prompt. The user sets it to "Follow the saving-session-state skill." relay keeps the rest: the tagged-note contract, the note's contents, and "don't start new work".

**Why:** relay needs the tagged note to draft its continuation prompt, so that contract stays in relay, where it's tested. The skill's handoff-note reference teaches the matching behavior: put the note in the tags and write no file. The option is generic, so the public plugin doesn't depend on this skill being installed.

**Alternatives:** relay calling the skill by name directly (couples a public plugin to one skill); the skill detecting relay's marker (couples the skill to one caller).

## 12. Spec-only frontmatter

**Decision:** The frontmatter has `name`, `description` and `license`, nothing harness-specific. There's no `agents/openai.yaml`.

**Why:** Claude Code ignores unknown fields, but claude.ai and the Skills API reject them at upload, and other harnesses vary. The defaults (implicit invocation on, name as the command) are what this skill wants everywhere, so it needs no harness-specific settings.

## 13. Evals run the source skill in a sandbox

**Decision:** `evals/run.sh` builds a fresh sandbox per scenario: a git repository, a notes home with its own history, and a preferences file reached through `XDG_CONFIG_HOME`. It links the source skill into the repository's `.claude/skills` and `.agents/skills`, runs a real harness headlessly (`claude -p` or omp through the `use-omp` wrapper), then checks files, commits and the final answer.

**Why:**

- Best practices call for evaluations built around real usage, and the risky behaviors here are routing decisions (which home, what stays out), which only a real agent run shows.
- Linking the source tests this checkout, not an installed copy.
- A sandbox keeps eval writes out of real notes: `claude -p` runs in `acceptEdits` mode, limited to the sandbox directories and a short list of shell commands.
- A scripted session summary stands in for a real transcript. It's synthetic, but it's the same for every run, so results can be compared.

**Revisit if:** a harness gains a way to seed a real conversation headlessly, or routing mistakes show up in real use that the scenarios don't cover (add a scenario).
