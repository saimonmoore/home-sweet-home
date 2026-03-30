---
name: implement-feature
description: Implement approved features incrementally with deterministic pre-review checks. Use when user asks to implement e full feature.
---

## Objective
Deliver a feature safely after sourcing approval while keeping artifacts and validation deterministic.


## Workflow
1. Create a feature branch to isolate
2. Clarify acceptance criteria are complete and clear. If user did not provide them, ask the user.
3. Apply TDD to drive the feature
   * Add UATs
   - Follow the `tdd-cycle` skill: write a failing test, make it pass, then refactor before moving on.

## Output Contract
- No transition to review without a passing quality gate.
* evidence paths are workspace-local 

## Guardrails
- Do not merge directly to main/master.
