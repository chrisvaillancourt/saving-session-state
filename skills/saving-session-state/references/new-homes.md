# Creating a new home

Read this when a gap that should outlive the handoff note has no existing home. A new home is a commitment: someone has to find it, keep it current, and eventually retire it. Create as few as possible, and make each one easy to find.

## Pick the home

Work through these in order and stop at the first that fits:

1. **The work lives in a repository you or the user own, alone.** Put rules and gotchas in its agent instructions, creating `AGENTS.md` when there are none. Put a plan or tracker for multi-session work in `docs/<topic>.md`, or wherever the repository keeps docs.
2. **The work lives in a shared repository.** Facts that help everyone go in as a doc change that goes through the repository's normal review: propose it, don't push it. Personal working context goes to a notes home (next item), not into the repository.
3. **A notes home applies.** Follow the preferences file and the notes home's own instructions for where a new note goes and how it's named. Usually that means a project note named for the work: the ticket key, repository or topic, not the date.
4. **Nothing applies,** for example a scratch-directory session with no notes home. Ask the user where the work's notes should live. Until they answer, the handoff note carries the gaps.

## Ask once

Propose a single location and say why ("No tracker exists for this migration; I'd create `docs/migration.md` in the repository, since it's yours alone"). Ask once for all new homes together, not once per gap. When the caller needs the turn to finish, don't wait: record the proposal under the handoff note's open decisions and leave the new home uncreated.

## Make it findable and finite

- Link the new home from where the user will look first: the notes home's project index, the repository's README or `AGENTS.md`, or the ticket.
- Say near the top what it's for and when to retire it ("Delete after the migration ships; move lasting decisions to the decision log first"). Working notes without a retirement condition pile up into logs nobody reads.
- Name it for the work, so the next session can find it again for the same work instead of starting a second one.
