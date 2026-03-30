---
name: pair-debugging
description: Hypothesis-driven debugging — reproduce, hypothesize, narrow, fix, verify. Use when you need to troubleshoot, fix a bug, identify a problem, explore root-causes.
---

## Protocol (you drive, human navigates)

1. **Reproduce**: Run the failing case. Show output.
2. **Hypothesize**: 1–3 likely causes, ranked. Brief reasoning.
3. **Narrow**: Smallest check that confirms or rules out the top hypothesis. Run it.
4. **Iterate**: Ruled out → next hypothesis. Confirmed → root cause.
5. **Fix**: Minimal change. Explain what and why.
6. **Verify**: Re-run failing case. Run broader suite.

## Rules

- No shotgun debugging. No changing things to see what happens.
- No symptom fixes without understanding the cause.
- Stuck after 3 hypotheses → stop, ask the human for more context.
- Use `git log`, targeted reads, and bisection. Not guessing.
- Say "I don't know" when that's true.
