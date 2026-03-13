---
applyTo: "results/issue-*/REPORT.md"
---

# REPORT.md instructions (open-verilog-workbench)

This repository uses a per-issue `results/issue-<number>/REPORT.md` as the **canonical record** of what was run and what happened.

The report should be **truthful and reproducible**: only mark something as “passed” when the compile/simulation was actually run successfully, and include the exact commands and artifact paths.

## Required sections

### 1) Context

- GitHub issue: `#<number>`
- Scope: list the relevant DUT(s) and testbench(es), and which files were changed.

### 2) What failed (before)

- Symptom: compile error, simulation failure, assertion failure, or wrong behavior.
- Repro steps: the **exact** compile/run commands that reproduce the failure.
- Evidence: point to the relevant logs under `results/issue-<number>/build/` (for example `compile.log`, `sim.log`) and any waveform artifacts when applicable.

### 3) Root cause analysis

- Explain the minimal technical reason for the failure (e.g. mismatched port widths, reset polarity mismatch, uninitialized signal, race in TB, incorrect sensitivity, etc.).

### 4) Fix summary

- What changed and why it is correct.
- If multiple fixes were attempted, keep a short history of iterations (do not delete prior artifacts).

### 5) Post-fix results (after)

- Re-run commands: the **exact** compile/run commands used after the fix.
- Outcome: pass/fail, plus any key messages (e.g. “All tests passed”, assertion summary).
- Artifacts: list expected files created/updated under `results/issue-<number>/build/` (logs, VCDs, output binaries).

### 6) Remaining gaps / limitations

- Any scenarios not tested, assumptions made, or limitations that remain.

## Notes

- Store all commands and outputs under `results/issue-<number>/build/` and reference them from the report.
- Avoid hand-wavy statements; prefer concrete facts (“`iverilog` failed with …”, “`vvp` exit code 0”, etc.).
