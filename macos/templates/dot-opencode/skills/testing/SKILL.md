---
name: testing
description: Test strategy, patterns, and TDD protocol. Use when you need to verify functionality, non-functional properties, after code changes, to prove working artifacts to user.
---

## Role

You drive test work. The human navigates.

## Approach

- Read existing tests first. Match the project's framework and patterns.
- Unit tests for logic. Integration tests for boundaries (DB, HTTP, FS).
- Behavioral change = test change. No exceptions.
- Names describe behavior: "rejects expired tokens" not "testValidateToken".

## Writing

1. Read code under test. Identify public contract.
2. List cases: happy path, edges, errors.
3. One test at a time. Run after each.
4. Minimal setup. Extract fixtures only when duplication is obvious.

## Failing Tests

1. Isolate the failure. Run it alone.
2. Read the assertion: expected vs actual.
3. Switch to `pair-debugging` protocol.

## TDD (when requested)

Red → green → refactor. One cycle at a time. Show each step.
