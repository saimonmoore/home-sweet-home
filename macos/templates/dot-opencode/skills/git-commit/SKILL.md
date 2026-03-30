---
name: git-commit
description: Draft, review, and execute Git commits from repository state. Use when the user asks to commit changes, write a commit message, summarize staged or unstaged diffs into a commit, split message subject/body, amend an existing commit, or check whether changes are ready to commit.
---

# Git Commit

## Determine change scopes

* Inspect the changed files and identify the conventional commit groupings

## Write the Message

* Add a commit for each identified group and stage only what belongs to that group
- Subject line first. Keep it specific and compact.
- Add a body only when it improves future understanding.
- Describe the behavioral or structural change, not just the edited files.
- Match repository conventions when they are visible in recent history.
- Use conventional commit prefixes

## Execute Safely

When creating the commit:

- Prefer non-interactive commands such as `git commit -m "subject"` or repeated `-m` flags for body paragraphs.
- Do not open an interactive editor unless the user explicitly wants it.
- Do not use `--amend`, `--no-verify`, force flags, or history-rewriting options unless the user asked.
- Respect repository or environment rules that require approval before Git write operations.

If the commit fails because hooks or signing rules reject it, report the failure clearly and include the exact blocker.

## Output 

* short git log of the commits
- any remaining unstaged or untracked changes that were left alone

