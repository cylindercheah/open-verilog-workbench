---
applyTo: "rtl/**/*.v,tb/**/*.v,tb/**/*.sv"
---

Follow these conventions for RTL and unit testbenches in this repository.

## RTL (`rtl/*.v`)

- Keep modules **synthesizable** unless the file is explicitly a testbench.
- Use a **single clock** and **active-low reset** named `rst_n` unless the architecture specifies otherwise.
- Prefer clear, explicit state machines (one-hot or encoded is fine) with readable state names.
- Avoid `#delay` in synthesizable code.
- Keep port naming consistent with `docs/ARCHITECTURE.md`.

## Testbenches (`tb/*_tb.v`)

- Testbenches must compile/run with **Icarus Verilog** using:
  - `iverilog -g2012 -o build/<module>.out tb/<module>_tb.v rtl/<module>.v` (or `.sv` TBs)
  - `vvp build/<module>.out`
- Include:
  - Clock generation
  - Reset sequencing
  - Directed stimulus that covers nominal + at least a couple of corner cases
  - Self-checks (assertions or explicit checks with `$fatal`)
- Waveform dumping (VCD) to a predictable location (e.g. `build/` or `results/`)
- A simulation log written to a predictable location (e.g. `build/` or `results/`)

## Results + gating

- Keep results honest: set “passed” only if you actually ran the sim successfully.
- If you use `results/` JSON status files, keep them machine-readable and accurate.

