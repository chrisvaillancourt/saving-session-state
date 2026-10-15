---
name: saving-session-state
description: Saves a work session's state to durable homes before the session ends or its context is compacted. It updates the docs, notes, trackers and tickets the work touched with what was done, decisions, issues and workarounds, status and next steps, and writes a handoff note only for what has no other home. Use when the user reaches a stopping point, wraps up or pauses work, asks to update the notes or docs with what was done, or prepares to compact or hand off to a new session.
license: MIT
---

# Saving session state

The conversation is about to end or be compacted, and anything that lives only in it is lost. Move every fact the next session needs into a **durable home**: a file, note, tracker or ticket that outlives the session, in the place whoever picks the work up next will look first. Update existing homes before creating new ones, and record without advancing the work: the session's tasks stay where they stand.

## 1. Load preferences and instructions

Read the user's preferences file if it exists. It's `saving-session-state/preferences.md` under the user's config directory: `$XDG_CONFIG_HOME` when that's set (`echo "$XDG_CONFIG_HOME"` shows it), otherwise `~/.config`.

It names the user's **notes homes** (a notes vault, a work log, a tracker) and when each applies. Its rules win over this skill's defaults, except the sharing rules in step 4. A missing file means there are no notes homes beyond what your loaded instructions name. To create or change the file, read [references/preferences.md](references/preferences.md).

Done when you know every notes home that applies to this session, and the rules for each.

## 2. Inventory the session

List every place the session touched: repositories and directories, files created or edited, branches, commits, uncommitted changes, stashes and worktrees, pull requests, tickets, messages and other external writes, jobs or processes still running, and files left in temporary or scratch directories. Check each repository with `git status` and `git log`; memory of the session isn't evidence of its current state.

Done when each touched place is listed with its current state.

## 3. Find the gaps

A **gap** is a fact the next session needs that no durable home holds yet, or holds only in a stale form. Go through the conversation for each kind:

- What was done, and how it was verified (the command and its result).
- Work in progress, and exactly where it stands.
- Decisions and why, including approaches tried and dropped.
- Issues hit, gotchas, and the workarounds in place.
- Next steps, each with a disposition: do, defer, skip or drop.
- Open decisions and questions, and who decides each.
- Lessons that change how future work here should be done.

A fact already in a commit message, pull request, ticket, plan or doc is captured. It's a gap only if that record is now wrong or will read wrong later, such as a relative date. Leave a correct record as it is, even where you'd word it differently: rewording costs a review and a commit and saves nothing.

Done when each gap is a one-line statement. With no gaps, tell the user the session's artifacts already carry its state, list them, and go to step 7.

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

Before writing to a home, read and follow its instructions (the `AGENTS.md` or `CLAUDE.md` that governs it).

Sharing rules, which preferences can't relax:

- **Shared homes get shared facts.** A repository, ticket or pull request that others read gets only what helps them, never paths, filenames or content from private notes. Private notes may link to public artifacts freely.
- **Writes others see wait for approval.** Draft ticket comments, pull request edits and messages, and show them to the user. Send one only if the user already asked for it in this session.

When no existing home fits a gap that should outlive the handoff note, read [references/new-homes.md](references/new-homes.md) before creating anything.

Done when each gap has exactly one home and you know the rules for writing there.

## 5. Write

- **Update in place.** An entry point (a status section, a "resume here" block, a tracker's header) holds current state only: replace what's stale, and move superseded history to where that home keeps history, or drop it when git already keeps it.
- **Be concrete.** Paths, commands, branch names, ids, error text and absolute dates; "yesterday" and "the new approach" mean nothing next week.
- **Link instead of copying.** Point to the commit, pull request, ticket or doc that already holds the detail.
- **Leave out secrets:** keys, tokens, passwords and personal data.

Done when each gap from step 3 is written in its home or drafted for the user's approval.

## 6. Write a handoff note, only when needed

Write one when gaps remain that have no durable home, or when the caller asks for one. Read [references/handoff-note.md](references/handoff-note.md) for where it goes, what it holds, and how to return it to a caller that collects it.

When the caller needs this turn to finish, as when it asks for the note in tags, you can't wait for an answer: choose the default, carry on, and list the question under the note's open decisions.

## 7. Finish

1. Commit what you changed, following each repository's rules. Stage only files this session changed.
2. Check:
   - [ ] Every gap from step 3 is written, drafted for approval, or in the handoff note.
   - [ ] Every next step has a disposition.
   - [ ] No shared home holds a private path or detail.
   - [ ] `git status` in each repository you changed shows only changes you're leaving on purpose, and you said why.
3. Report to the user: each home you updated (path or link) with a one-line summary, the drafts awaiting approval, the questions waiting on them, and the first thing the next session should read.
