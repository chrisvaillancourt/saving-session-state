# The preferences file

Read this to create or change the preferences file, or to make sense of an unclear one.

The preferences file is plain Markdown at `saving-session-state/preferences.md` in the user's config directory: `$XDG_CONFIG_HOME` when it's set, otherwise `~/.config`. It sits outside the skill, so reinstalling the skill leaves it alone, and every agent harness reads the same file. It answers four questions the skill can't know by itself:

1. **Which notes homes exist?** Give the absolute path of each notes vault, work log or tracker, and the file that holds its own rules (for example its `AGENTS.md`).
2. **When does each apply?** Say which work belongs where, and how to tell: a session that runs inside the notes home, work tied to a ticket prefix or organization, a repository listed in a mapping table.
3. **What stays out?** List what never goes in a notes home or a repository: other people's personal data, private notes in shared repositories, kinds of note the home has retired.
4. **Where do gotchas about the user's own setup go?** Name the agent memory or note for gotchas about the environment, shell, harness, or a tool or skill installed from elsewhere, and where the user fixes such things at their source (a dotfiles repository, a tool's own repository).

Write rules, not habits the agent can find by looking: if the notes home's own instructions already say how notes are named, point at them instead of repeating them.

## Example

```markdown
# Session-state preferences

## Notes homes

- Work notes: `/home/sam/notes/work`. Rules in its `AGENTS.md`; read them before writing.
  - Use it when the session runs inside it, edits notes in it, or works on a repository that has a project note there: a note whose `repo:` field names the repository. A note that only mentions the repository doesn't count.
  - Status of shared work belongs in the ticket system, not in notes.
  - It retired session logs: update the project note's current state instead.
- Personal projects: no notes home. Keep their state in the repository.

## Gotchas

- Gotchas about my own setup go to `/home/sam/notes/work/agent-memory/`, which every harness reads. When the cause is in `/home/sam/dotfiles`, record the fix there as a next step instead of only noting the workaround.

## Privacy

- Never write paths or titles from the work notes into repositories, tickets or pull requests.
- Never write work notes into personal repositories, or the reverse.

## Committing

- Commit notes with the notes home's commit rules, then push.
```

## Checking it

After editing the file, start a session in a repository tied to each notes home and ask what the skill would do at a stopping point. The plan should name the right home for each kind of gap.
