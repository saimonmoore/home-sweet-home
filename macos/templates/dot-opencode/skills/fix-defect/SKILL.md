---
name: fix-defetct
description: Fix a bug, a regression in performance or misbehavior. Use when the user asks to fix a bug, address a defect, fix a problem in code.
---

# Fix defect

## Workflow

* Reproduce the problem or faulty behavior
  - if possible use a regression test otherwise at least produce a script, or documentation on how to reproduce
* Identify the cause of the failure
  * analyze the code
  - consider increasing the log-level
  * create hypotheses and test them one at a time
* Make the smallest possible fix that makes the test pass
* Now look for other instances of the same bug or a similar defect in the codebase and address those as well

## Output

* Describe the problems root-cause
* Explain the fix, and substantiate why the fix is sufficient
