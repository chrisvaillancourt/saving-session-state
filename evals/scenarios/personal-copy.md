[relay] Checkpoint before compaction. The conversation will be compacted after this turn, and the next session starts from what you leave now.

1. Follow the saving-session-state skill.
2. Then, after your last tool call, end with the handoff note inside <handoff-note> and </handoff-note> tags, each on its own line. What's inside the tags is saved to RELAY_NOTE_PATH for the next session; don't write that file yourself.
3. In the note, record what is done; what is in progress, exactly where it stands (branches, uncommitted changes, running jobs, open PRs); decisions and why; what you learned; issues, gotchas and workarounds; next steps, each with a disposition (do / skip / defer); and the files you wrote or updated this session.
4. Link to what's already durable instead of repeating it.

Don't start new work.
