---
name: saving-session-state
description: Saves a work session's state to durable homes at a stopping point. It updates the docs, notes, trackers and tickets the work touched with what was done, decisions, issues and workarounds, status and next steps, and writes a handoff note only for what has no other home. Use when the user wraps up or pauses work and wants the session recorded before closing it, or before compacting or handing off to a new session. Not for routine doc edits in the middle of a task.
license: MIT
---

# Saving session state

The conversation is about to end or be compacted, and anything that lives only in it is lost. Move every fact the next session needs into a **durable home**: a file, note, tracker (a document that tracks one piece of work) or ticket that outlives the session, in the place whoever picks the work up next will look first. Update existing homes before creating new ones. Record the work without advancing it: code and other in-progress work stay exactly as they are.

**Caller mode.** Sometimes a tool runs this skill as one step of its own flow and needs the turn to end with a handoff note in a set form, for example inside `<handoff-note>` tags that it collects. In caller mode:

- Ask no questions. Choose the default, carry on, and list the question under the note's open decisions.
- Always end with the note, even when there are no gaps.
- Put drafts awaiting the user's approval in the note, since the final report won't survive the caller's next step.
- Write the note where the caller says, and write no note file of your own.

## 1. Load preferences and instructions

Find the user's config directory by running `echo "$XDG_CONFIG_HOME"`. It's the printed directory, or `~/.config` when nothing prints. Read `saving-session-state/preferences.md` there. Expand the directory yourself: a file tool won't expand `$XDG_CONFIG_HOME`.

The preferences name the user's **notes homes** (a notes vault, a work log, a tracker) and when each applies. Their rules win over this skill's defaults, except the sharing rules in step 4. No file at that path means there are no notes homes beyond what your loaded instructions name. A file you can't read, for example after a refused permission, isn't the same as a missing one: say so, and keep the gaps that would have gone to a notes home for the handoff note. To create the file, change it, or make sense of an unclear one, read [references/preferences.md](references/preferences.md).

Done when you know every notes home that applies to this session, and the rules for each.

## 2. Inventory the session

List every place the session touched: repositories and directories, files created or edited, branches, commits, uncommitted changes, stashes and worktrees, pull requests, tickets, messages and other external writes, jobs or processes still running, and files left in temporary or scratch directories. Check each repository with `git status` and `git log`; memory of the session isn't evidence of its current state.

Done when each touched place is listed with its current state.

## 3. Find the gaps

A **gap** is a fact the next session needs that no durable home holds yet, or holds only in a stale form. Go through the conversation for each kind:

- What was done, and how it was verified (the command and its result).
- Work in progress, and exactly where it stands, including uncommitted files.
- Decisions and why, including approaches tried and dropped.
- Issues hit, gotchas, and the workarounds in place.
- Next steps, each with a disposition: do, defer, skip or drop.
- Open decisions and questions, and who decides each.
- Lessons that change how future work here should be done.

A fact already in a commit message, pull request, ticket, plan or doc is captured. It's a gap only if that record is now wrong or will read wrong later, such as a relative date. Leave a correct record as it is, even where you'd word it differently: rewording costs a review and a commit and saves nothing.

Done when each gap is a one-line statement. With no gaps, go to step 6 in caller mode, otherwise to step 7.

## 4. Choose a home for each gap

Give each gap one home, and link to it from anywhere else that needs it. Default homes, unless the preferences or the destination's own instructions say otherwise:

| Gap | Home |
|---|---|
| A rule, gotcha or convention for anyone working in the repository | its agent instructions (`AGENTS.md`, `CLAUDE.md`) or contributor docs |
| A change in behavior or usage | the README or user docs |
| A design decision and its reasoning | where the repository records decisions (decision log, plan, design doc), else the pull request or ticket |
| Status of shared work: progress, acceptance details, blockers | the ticket or pull request |
| Personal working context: in-flight state, private reasoning, next steps across sessions | the existing tracker or notes-home note for this work |
| A gap no home fits | the handoff note (step 6) |

A notes home that applies takes the personal rows. Facts that anyone working in the repository needs still go to the repository, even when the user keeps notes about it elsewhere.

Before writing to a home, read and follow its instructions (the `AGENTS.md` or `CLAUDE.md` that governs it).

Sharing rules, which preferences can't relax:

- **Shared homes get shared facts.** A repository, ticket or pull request that others can read, including any public repository, gets only what helps them, never paths, filenames or content from private notes. Private notes may link to public artifacts freely.
- **Writes others see wait for approval.** Draft ticket comments, pull request edits and messages, and show them to the user. Send one only if the user already asked for it in this session. Until it's sent, a draft is still a gap: keep its text in a private home or the handoff note.

When no existing home fits a gap that should outlive the handoff note, read [references/new-homes.md](references/new-homes.md) before creating anything.

Done when each gap has exactly one home and you know the rules for writing there.

## 5. Write

- **Update in place.** An entry point (a status section, a "resume here" block, a tracker's header) holds current state only: replace what's stale, and move superseded history to where that home keeps history, or drop it when git already keeps it.
- **Be concrete.** Paths, commands, branch names, ids, error text and absolute dates; "yesterday" and "the new approach" mean nothing next week.
- **Link instead of copying.** Point to the commit, pull request, ticket or doc that already holds the detail.
- **Leave out secrets:** keys, tokens, passwords and personal data.
- **A home you can't write to** (a refused permission, a sandbox limit) moves its gaps to the handoff note. Say what stayed unsaved, and why.

Done when each gap from step 3 is written in its home, kept with its draft, or set aside for the handoff note.

## 6. Write a handoff note, only when needed

Write one when gaps remain that have no durable home, or in caller mode. Read [references/handoff-note.md](references/handoff-note.md) for where it goes and what it holds.

## 7. Finish

1. Commit the docs and notes this save wrote, following each repository's rules, and stage only those files. Leave the session's in-progress work (code, tests, experiments) as it is and list it as uncommitted, unless the user asked you to commit it or their standing instructions say to commit their session's work; then follow those, and say so. In caller mode, leave it as it is regardless: the work carries on after the checkpoint.
2. Check:
   - [ ] Every gap from step 3 is written, kept with its draft, or in the handoff note.
   - [ ] Every next step has a disposition.
   - [ ] No shared home holds a private path or detail.
   - [ ] `git status` in each repository you touched shows only the in-progress work you listed.
3. Report to the user: each home you updated (path or link) with a one-line summary, the drafts awaiting approval, the questions waiting on them, anything left unsaved, and the first thing the next session should read. In caller mode, give this report before the note, so the note ends the message.
