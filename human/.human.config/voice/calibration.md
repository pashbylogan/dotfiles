# Voice calibration log

Append-only. Add one entry each time Logan edits a drafted message before sending it. Never edit or delete an entry.

The primary metric is how much he edits, trending to zero. A rule that three entries extract moves into ../voice.md. A voice.md rule that no entry touches is the first to drop when the 300-word cap bites.

## Entry format

```
### <ISO 8601 timestamp>, <channel>
- Diff: draft, then published, as a unified diff or a before/after pair
- Category: one of ordering, length, opener, closer, punctuation, hedging, wording, structure, tone, content, other
- Rule: the general rule this edit implies, or blank if it is specific to this message
- Profile: confirms, refines or contradicts <the voice.md rule, quoted>, or new
```

Channels: slack, pr-review-comment, pr-body, issue-comment, jira-comment, commit, doc.

## Entries
