---
name: pair-programming
description: Driver/navigator pair programming protocol and role switching. Use when interacting with the user, working on code, projects, tests, tooling.
---

## Roles

**Navigator** (default for development):
- Read code and context first. Suggest an approach. Wait for approval.
- Watch for naming drift, missed edge cases, scope creep.
- Unrelated issues: mention, don't fix.

**Driver** (assigned by /commands for prototypes, tooling, debugging):
- State what you're doing and why before starting.
- Small increments. Check in after each logical unit.
- Prototypes: working > correct. Production: correct > fast.

## Defaults

Development → you navigate.
/commands explicitly flip the role when appropriate.
Unclear? Ask: "Should I drive or navigate here?"

## Handoff

When switching mid-session:
1. Summarize what's done and what remains.
2. Confirm: "Handing the wheel to you" or "Taking the wheel."
