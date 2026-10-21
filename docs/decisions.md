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
10. [Caller mode](#10-caller-mode)
11. [Composing with relay through `saveInstructions`](#11-composing-with-relay-through-saveinstructions)
12. [Spec-only frontmatter](#12-spec-only-frontmatter)
13. [Evals run the source skill in a sandbox](#13-evals-run-the-source-skill-in-a-sandbox)
14. [A save commits only what it wrote](#14-a-save-commits-only-what-it-wrote)
15. [A correct record stays as written](#15-a-correct-record-stays-as-written)
16. [Repository gotchas go to the repository; fixes are recorded, not made](#16-repository-gotchas-go-to-the-repository-fixes-are-recorded-not-made)

## 1. A standalone skill in its own repository

**Decision:** The routine is an Agent Skill in its own repository, installed with the `skills` CLI. It isn't a Claude Code plugin, and it isn't part of a plugin marketplace.

**Why:** The user runs sessions in Claude Code and omp, and wants the same closeout in both. A skill in the open format is the one extension both read: omp and Codex load `~/.agents/skills`, and the CLI, given both the `universal` and `claude-code` agents, symlinks the same copy into `~/.claude/skills` (verified at install on 2026-10-15: `claude-code` alone copied it only into `~/.claude/skills`, where omp doesn't look). Saving state is a model turn (read, decide, edit, commit), which a skill fully covers. The parts that need engine access (forking a side question, compacting, filling the prompt box) stay in the relay plugin, which calls this skill (decision 11). A repository of its own follows the user's other single-skill repositories and keeps it out of Claude-specific marketplaces that are due to be reworked.

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

**Decision:** Which notes homes exist and when each applies lives in `saving-session-state/preferences.md` under the user's config directory (`$XDG_CONFIG_HOME`, else `~/.config`), plain Markdown the agent reads in step 1. The skill itself names no paths.

**Why:**

- **Every harness reads the same file.** Claude Code loads `~/.claude/CLAUDE.md` and omp loads its own `AGENTS.md`, so routing in instruction files would have to be kept in step in two places.
- **Reinstalling leaves it alone.** The CLI replaces the skill directory on reinstall, so config kept inside the skill would be lost.
- **The skill stays publishable.** Paths to a private vault never enter the repository.
- **It's testable.** The evals point `XDG_CONFIG_HOME` at a sandbox (decision 13).
- **Markdown suits the reader.** The reader is an agent, so prose rules ("use the vault when the repository has a project note there") beat a schema.

**Alternatives:** routing in each harness's global instructions (duplicated, and not available to the skill's own logic); an environment variable (a path alone can't say when each home applies); hard-coding the user's vault in the skill (not publishable, and wrong for anyone else).

**How the agent finds the file:** step 1 tells the agent to run `printenv XDG_CONFIG_HOME` and write out the directory itself. Three eval runs shaped that wording:

- The first draft gave `cat "${XDG_CONFIG_HOME:-$HOME/.config}/…"`. Claude Code's bash safety check refused it ("A variable in braces in this command can't be checked before it runs"), and the agent fell back to `~/.config`.
- The second draft said "`$XDG_CONFIG_HOME` when that's set (`echo "$XDG_CONFIG_HOME"` shows it)". gpt-6-luna in omp passed `$XDG_CONFIG_HOME/…` to its read tool literally, got "not found", then read the user's real `~/.config` file from inside an eval sandbox. Step 1 now makes the command the first action and says a file tool won't expand the variable. Every eval with a notes home checks that the agent read the sandbox's file and not the user's.
- A third run (2026-10-21) found Claude joining the `echo` to other commands (`echo "$XDG_CONFIG_HOME"; git status; …`). The safety check refused the joined command ("A variable in this command can't be checked before it runs"), and the agent fell back to `~/.config` and read the user's real file from the sandbox, in 2 of 8 scenarios. Step 1 then said to run the `echo` as a command of its own, and that a refused command means the directory is unknown. The final run failed with that wording: Claude Code 2.1.306 refuses even a standalone `echo "$XDG_CONFIG_HOME"`, so the agent treated the preferences as unreadable. Step 1 now runs `printenv XDG_CONFIG_HOME`, which names the variable without expanding it. **Untested** as of 2026-10-21; see [evals.md](evals.md#results). The joined form also appeared in real relay saves.

A file the agent can't read (a refused permission) is reported, not treated as missing. Treating it as missing would quietly route everything to the defaults.

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

Any public repository counts as shared, including one a single person owns. A draft stays a gap until it's sent, so its text is kept in a private home or the handoff note.

**Why:** A closeout touches both private notes and shared systems in one pass, which is where private paths leak into commits and pull requests. A ticket comment or message can't be unsent, and the user has a standing rule to approve them.

## 10. Caller mode

**Decision:** When a tool runs the skill as one step and needs the turn to end with the note in a set form (relay's `<handoff-note>` tags), the skill runs in caller mode. It asks no questions, records them under the note's open decisions, and always ends with the note, even when nothing else needed saving. Drafts awaiting approval go in the note, and the agent writes no note file of its own. The rule sits in SKILL.md's introduction because it changes steps 3, 4, 6 and 7.

**Why:**

- **No questions:** a question ends the turn without the note, and relay then compacts with nothing useful saved.
- **Always a note:** the first draft's "no gaps, go to step 7" skipped the note. Both reviews found that relay would then save the whole final answer as the note.
- **Drafts in the note:** relay compacts right after the turn and keeps only the tagged note, so a draft shown only in the report is lost. The omp review reproduced this with relay's own `extractNote`.
- **A named mode:** it was a sentence inside step 6. The Opus review recommended naming it, so one rule covers every step it touches.

## 11. Composing with relay through `saveInstructions`

**Decision:** relay (0.3.0) has a `saveInstructions` option that replaces only the first step of its save prompt. The user sets it to "Follow the saving-session-state skill." relay keeps the rest: the tagged-note contract, the note's contents, and "don't start new work".

**Why:** relay needs the tagged note to draft its continuation prompt, so that contract stays in relay, where it's tested. The skill's handoff-note reference teaches the matching behavior: put the note in the tags and write no file. The option is generic, so the public plugin doesn't depend on this skill being installed.

relay 0.3.0 also takes the note from tags on their own lines, the last such block. A model following the skill may quote the tag names in its report before the note, and the old first-match extraction returned that prose (found in review).

**Alternatives:** relay calling the skill by name directly (couples a public plugin to one skill); the skill detecting relay's marker (couples the skill to one caller).

## 12. Spec-only frontmatter

**Decision:** The frontmatter has `name`, `description` and `license`, nothing harness-specific. There's no `agents/openai.yaml`.

**Why:** Claude Code ignores unknown fields, but claude.ai and the Skills API reject them at upload, and other harnesses vary. The defaults (implicit invocation on, name as the command) are what this skill wants everywhere, so it needs no harness-specific settings.

## 13. Evals run the source skill in a sandbox

**Decision:** `evals/run.sh` builds a fresh sandbox per scenario: a git repository, a notes home with its own history, and a preferences file reached through `XDG_CONFIG_HOME`. It places a copy of the source skill, stamped with a per-sandbox provenance marker, in the repository's `.claude/skills` and `.agents/skills`. It runs a real harness headlessly (`claude -p`, or omp through the `use-omp` wrapper), then checks the harness's own verdict, the provenance, files, commits and the final answer.

**Why:**

- **Real runs:** best practices call for evaluations built around real usage. The risky behaviors here are routing decisions (which home, what stays out), which only a real agent run shows.
- **The provenance marker** proves which copy loaded. Claude Code ranks personal skills above project skills, so once the skill is installed, a run could load the installed copy. The check accepts that only when the installed copy is identical to the source.
- **The harness verdict counts:** a run that errors or hits a limit fails, even if its files happen to pass the other checks.
- **A canary string in the private notes fixture** must never reach the repository's files or commit messages.
- **A scripted session summary** stands in for a real transcript. It's synthetic, but identical every run, so results can be compared.

**Limits, stated plainly:** the sandbox is fixture-based, not OS-contained. `claude -p` runs in `acceptEdits` mode with `--tools` limited, MCP servers off, writes limited to the sandbox directories and a short shell allowlist, but it still loads the user's global `CLAUDE.md`. Isolating that through `CLAUDE_CONFIG_DIR` loses authentication. omp runs with its normal tools and config. Results partly reflect each harness's user configuration. Checks are keyword-based, not semantic. Compare the user's notes with `git status` before and after an omp run.

**Revisit if:** a harness can seed a real conversation headlessly or run with isolated config and working authentication, routing mistakes show up in real use that the scenarios don't cover (add a scenario), or keyword checks prove too loose (add a model-graded rubric).

## 14. A save commits only what it wrote

**Decision:** Step 7 commits the docs and notes the save wrote. It leaves the session's in-progress work (code, tests, experiments) uncommitted and lists it, unless the user asked to commit it or their standing instructions say to commit their session's work. In caller mode it leaves that work alone regardless.

**Why:** "Commit what you changed" covered the whole session's files. At a relay checkpoint mid-task, that commits half-done code, possibly onto `main`, which contradicts "record without advancing the work". Found by the Opus review.

The standing-instructions exception came from an eval. In `notes-home`, Claude committed the session's finished test because the user's global instructions say to commit your own edits before finishing. It said so in its report. A user's own rule should win at a closeout. It doesn't apply at relay's checkpoint, where the task isn't finished, so caller mode keeps the work uncommitted. The evals check that the test is intact everywhere, and still uncommitted in `relay-caller`.

## 15. A correct record stays as written

**Decision:** A fact already captured is a gap only if the record is wrong or will read wrong later (a relative date). A correct record stays as written, even where the agent would word it differently.

**Why:** In the first `already-captured` eval, the agent rewrote "tomorrow" to an absolute date, which was right, and also reworded correct sentences, which created churn and a commit for nothing. The fixture now uses absolute dates, and the scenario requires no changes at all.

## 16. Repository gotchas go to the repository; fixes are recorded, not made

**Decision:** A copy of a fact in a personal home (an agent's memory, the user's private notes) doesn't capture a fact that belongs in a shared home: a repository's gotcha or convention is still a gap for the repository (step 3). Gotchas about the user's own setup (environment, shell, harness, or a tool or skill installed from elsewhere) have their own row in step 4: the agent memory or notes home the preferences name for them, else the handoff note. A gotcha with a personal trigger but a workaround in the repository's code, tests or commands is a repository gotcha. When a gotcha's cause can be changed, the save records the gotcha and its workaround in its home and adds the fix as a next step that names where it belongs, drafted as a ticket, issue or pull request description when that's a shared or another tool's repository. The save leaves the cause unchanged. The sharing rule now says a repository fact that also sits in private notes is a shared fact, so moving it into the repository isn't a leak of private content.

**Why:**

- **Found in a live relay trial (2026-10-15):** Claude Code's own memory saved a repository gotcha mid-conversation. At the checkpoint, the skill counted that memory file as captured, so the gotcha never reached `AGENTS.md`. That memory is read by one harness, for one checkout path, by one user.
- **Found in an audit of real saves (2026-10-21):** a test-runner gotcha caused by a repository's own config (a flag in its default test options) sat in private notes across several sessions and never reached the repository. It had recurred in several sessions, so fixing the config would remove it.
- **"Record without advancing the work" still holds.** Making the fix during a save would change code at a checkpoint. Recording it as a next step, or as a draft others approve, keeps the save a record.

**Alternatives:** leave memory out of the rules and rely on step 4's "facts that anyone working in the repository needs still go to the repository" (that sentence existed, and the trial still missed); have the save make small fixes (contradicts step 7 and caller mode).

**Evidence, and its limits:** the evidence is the live trial and the audit above, both observational. The `personal-copy` eval is a regression guard, not a reproduction: every check passed in all 11 runs against the pre-change skill (Claude and omp, including 2 Claude runs with the gotcha in Claude Code's real auto-memory directory, and 4 with the shell-alias checks). So it doesn't meet AGENTS.md's "fails without it" rule, recorded here as an exception: the scripted sandbox didn't reproduce the trial's miss, and the models already keep a shell alias out of the repository. "Record the fix as a next step" has no check at all. See [evals.md](evals.md#results).

**Revisit if:** an eval or real save puts a personal-setup gotcha in a shared repository; a real save records a fixable gotcha's workaround with no fix as a next step (add a check then); saves start drafting fixes nobody asked for; or someone wants a variant whose preferences route setup gotchas to an agent memory, the realistic way a repository gotcha could be mistaken for a setup one.
