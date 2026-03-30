---
name: tdd-cycle
description: Drive implementations with a failing test first, then make it pass, then refactor.
---

## Objective
Use test-driven development (TDD) to guide code changes and keep regression evidence deterministic.

## Workflow
1. Red (Failing Test)
   - Add or update a test that expresses the desired behavior.
   - Run tests to capture failure 
   - Do not change production code until the test fails for the expected reason.
2. Green (Minimal Implementation)
   - Modify production code just enough to satisfy the failing test.
   - Re-run the same tests to ensure pass
3. Refactor
   - Clean up the new code, keeping behavior intact.
   * Re-Run tests and all other quality gates available in the project
4. Evidence
   - Record the failing test command, the passing command, and any refactor adjustments in task annotations or PR notes.

## Guardrails
- Never skip the red step; every change must start from a failing test.
- Keep green changes minimal—avoid bundling refactors with behavior changes.
- Run the full all quality gates before handing off 
