---
name: fix-bug
description: Fix bugs with reproduce-first workflow and deterministic regression evidence.
---

## Objective
Resolve defects with minimal scope while preventing regressions.

## Workflow
1. Reproduce the issue.
   - Add a failing test first when feasible.
   - Keep the test around to prevent regressions.
3. Apply the minimal fix.
4. Validate correction and regression safety.
   * Run quality gates in the project
5. Search for similar instance of the same or related bug in the code base. Bugs tend to come in clusters. Repeat fixes for those.

## Output Contract
- Regression test path is documented in task annotations.
* Report full status to user

## Guardrails
- Avoid scope expansion while fixing bugs.
- Escalate to architecture review when structural behavior changes.
