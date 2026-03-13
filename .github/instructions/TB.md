---
applyTo: "tb/**/*.v,tb/**/*.sv,results/issue-*/tb/**/*.v,results/issue-*/tb/**/*.sv"
---

# Testbench instructions (open-verilog-workbench)

This file defines how **testbenches** should look and behave for this repository. It complements `.github/instructions/verilog.instructions.md` and `.github/copilot-instructions.md`.

## Goals

- Make testbenches **deterministic**, **self-checking**, and easy to run with **Icarus Verilog**.
- Keep expectations consistent across:
  - `tb/<module>_tb.{v,sv}` in the root repo, and
  - `results/issue-<number>/tb/*.v` / `*.sv` for per-issue workspaces.

## Required structure

- One top-level testbench module per file, typically named `<module>_tb`.
- Instantiate exactly one DUT (design-under-test) per testbench file, unless the issue explicitly calls for a multi-DUT integration test.
- Group signals logically:
  - clock/reset
  - inputs to DUT
  - outputs from DUT

## Clock and reset

- Provide a **single primary clock** unless the design clearly needs more.
- Use an **active-low reset** named `rst_n` by default (match the RTL if it differs).
- Hold reset active for a few cycles at the start of simulation, then deassert it cleanly on a clock edge.

## Stimulus and checking

- Prefer **directed stimulus** that covers:
  - nominal / “happy path” operation, and
  - at least a couple of important edge or corner cases described in the issue.
- Make tests **self-checking**:
  - Use SystemVerilog assertions when available, or
  - Use explicit checks with `$fatal`, `$error`, or `$display` + final pass/fail summary.
- Avoid purely waveform-inspection testbenches that rely on a human to decide pass/fail.

## Comments and coverage hints

- Add **brief, targeted comments** in the testbench to clarify:
  - the intent of non-obvious stimulus sequences,
  - why particular corner cases are included,
  - any protocol/timing assumptions that are not obvious from the signals alone.
- When evaluating or updating a testbench, call out in the PR/issue description:
  - which behaviors and corner cases are currently covered by the testbench,
  - any important scenarios that are **not yet covered** (gaps/limitations),
  - whether additional coverage mechanisms (e.g. functional coverage, extra scenarios) are recommended.

## Waveforms and logs

- Dump a VCD (or similar) waveform to a predictable location, for example:
  - `build/<module>_tb.vcd`, or
  - `results/issue-<number>/build/<module>_tb.vcd`.
- Print clear log messages for:
  - start/end of simulation,
  - key scenario boundaries,
  - any detected failures.

All compilation/simulation artifacts for a given issue should be kept under `results/issue-<number>/build/` and **not deleted**, so that future maintainers can see what actually ran. Typical files include:

- `<module>.out` / `a.out` (Icarus Verilog output binaries),
- `<module>_tb.vcd` (or similar) waveform files,
- `compile.log` and `sim.log` (text logs capturing the exact commands and their output).

## Compile and run commands

- Testbenches must compile and run with **Icarus Verilog**. A typical flow is:

  - `iverilog -g2012 -o build/<module>.out tb/<module>_tb.sv rtl/<module>.v`
  - `vvp build/<module>.out`

- For per-issue workspaces, adjust paths accordingly, for example:

  - `iverilog -g2012 -o results/issue-<number>/build/<module>.out results/issue-<number>/tb/<module>_tb.sv results/issue-<number>/rtl/<module>.v`
  - `vvp results/issue-<number>/build/<module>.out`

When you run these commands for an issue, copy/paste the **exact** invocations and their outcomes into `results/issue-<number>/REPORT.md` (see below), and ensure the corresponding artifacts are present under `results/issue-<number>/build/`.

## REPORT.md for each issue

For every issue that involves testbench work, maintain a `results/issue-<number>/REPORT.md` file with, at minimum:

- **DUTs and testbenches**: list each DUT module and its associated testbench file(s).
- **How to run**: the exact `iverilog` / `vvp` commands used (matching the artifacts in `build/`).
- **Results**: pass/fail status for each testbench and any notable error messages.
- **Coverage description**: a short description of which behaviors, edge cases, and corner cases are exercised by each testbench.
- **Gaps/limitations**: important scenarios that are not yet covered, or any assumptions/manual checks that remain.

Keep `REPORT.md` up to date whenever you add or modify testbenches or re-run simulations, so that anyone can understand what was tested and how to reproduce it from the persisted artifacts.

## Guidance for Copilot/agents

- Treat the **issue body + attachments** as the source of truth for:
  - which module(s) to test,
  - what behaviors and corner cases matter,
  - any specific timing, reset, or protocol requirements.
- When users attach standalone files, place new/updated testbenches under:
  - `tb/` if they are meant to become part of the main repo, or
  - `results/issue-<number>/tb/` if they are per-issue artifacts.
- When improving an existing testbench:
  - preserve working behavior,
  - make checking stricter and more explicit rather than looser,
  - keep names and structure consistent with the existing RTL and docs.
