# The handoff note

Read this when step 6 calls for a handoff note. The note is the bridge to the next session, not the record: it holds the gaps that have no durable home, and points at the homes that hold everything else. A note that only lists artifacts isn't needed; the final report covers that.

## Where it goes

1. **The caller's instructions win.** A tool that runs this skill may say where the note goes. When it asks for the note inside tags (for example "end with the handoff note inside `<handoff-note>` tags; it is saved for you"), make the tagged note the last thing in your final message and write no file yourself: the caller saves it.
2. **Otherwise, beside the work.** Use the tracker or notes-home note for this work, as a section or a sibling file, following the preferences file.
3. **Otherwise, ask** where to put it, offering the location you'd pick.

Keep one note per stream of work. Before writing, look for an earlier handoff note for the same work and replace it: overlapping notes leave the next session guessing which one is current.

## What it holds

Use this shape and drop any section with nothing in it:

```markdown
# <Work> handoff (<YYYY-MM-DD>)

Delete after the next session has folded this into durable homes.

## Read first
- <path or link>: <why it matters now>

## Where things stand
- Done: <outcome>, verified by <command or evidence>
- In progress: <task>: <exact state: branch, uncommitted files, running job id, open PR>

## Decisions and lessons not recorded elsewhere
- <decision or lesson>: <why>

## Issues and workarounds
- <issue>: <workaround in place, and what would remove it>

## Next steps
- <step> (do | defer | skip | drop): <why, and any precondition>

## Open decisions
- <question>: <options, and who decides>

## Files changed this session
- <path>
```

## Writing rules

- **Point, don't summarize.** "Review state is in PR 42" beats restating the review.
- **Leave out what goes stale fast,** such as approval counts or a ticket's status without context. Point to where the live value is instead.
- **List the "Read first" files in reading order,** the most important first. Use plain paths unless the caller asks for a mention syntax (some tools attach `@path` files).
