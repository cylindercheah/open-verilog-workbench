# Issue templates

These templates help new contributors use this repo to:

- create documentation for Verilog RTL / testbenches
- generate testbenches based on existing RTL
- fix RTL / TB issues (compile errors, simulation failures, spec mismatches)

Use **New issue** and pick one of the templates in this folder.

## What to include for fastest turnaround

- **RTL/TB inputs**: attach source files (or a `.zip` if GitHub blocks the extension), or point to file paths in the repo (pasting small modules inline is also fine)
- **Tooling**: simulator/linter and version (e.g. Icarus Verilog, Verilator)
- **Expected behavior**: what should happen, including reset behavior and timing assumptions
- **Repro** (for bugs): exact commands + error logs

## Suggested labels to create in the repo

Templates apply labels for filtering. If labels don’t exist yet, create them in **Issues → Labels**:

- `docs`, `testbench`, `rtl`, `bug`, `help wanted`, `good first issue`
- (optional) `verification`, `refactor`, `question`
