---
name: software-design
description: General software design — simplicity, coupling, cohesion, boundaries, error handling, naming, API design. Use when discussing design options, during pair programming sessions, when features are changed or added.
---

## Principles (in priority order)

1. **Simplicity**: Simplest design that satisfies known requirements. No speculative generalization.
2. **Naming**: If a name needs a comment, the name is wrong. Names are documentation.
3. **Single responsibility**: One reason to change per module/function/type. Can't describe it without "and"? Split it.
4. **Coupling & cohesion**: Things that change together live together. Things that change independently stay apart. Minimize module surface area.
5. **Composition over inheritance**: Combine small parts. Prefer interfaces/protocols over class hierarchies.
6. **Explicit dependencies**: Declare what you need. No hidden globals, no service locators.
7. **Error handling**: Pick a strategy per boundary (return, throw, result type). Be consistent within it. Handle where you have context to act.
8. **API design**: Public interfaces are contracts. Small surface. Easy to use correctly, hard to misuse.

## When These Aren't Enough

When the domain has distinct subdomains with different rules, complex entity lifecycles, or code/team language mismatch — load the `ddd` skill. DDD addresses modeling complexity that these principles don't cover.

## In Review

1. Name the principle that's violated or could be improved.
2. State the tradeoff: what improves, what it costs, when it matters.
3. Suggest the smallest change that addresses it.
4. Justify any pattern with the specific problem it solves here, not in the abstract.
