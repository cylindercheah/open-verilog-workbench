# Issue #3 — Testbench Report: `true_random_generator`

## 1) Context

- **GitHub issue:** [#3](https://github.com/cylindercheah/open-verilog-workbench/issues/3)
- **Scope:** Testbench generation for the `true_random_generator` module.
- **Files changed / added:**
  - `results/issue-3/rtl/true_random_generator.v` — RTL from issue attachment
  - `results/issue-3/tb/true_random_generator_tb.sv` — new self-checking testbench
  - `results/issue-3/build/compile.log` — iverilog compile output
  - `results/issue-3/build/sim.log` — vvp simulation output
  - `results/issue-3/build/true_random_generator_tb.out` — compiled simulation binary
  - `results/issue-3/build/true_random_generator_tb.vcd` — waveform dump

---

## 2) What failed (before)

No pre-existing testbench existed. The issue requested one be created.

---

## 3) Root cause analysis

N/A — this is a new testbench, not a fix. See §6 for design notes discovered during testbench
development.

---

## 4) Testbench summary

### DUT and testbench list

| DUT module              | Testbench file                                    | Instance |
|-------------------------|---------------------------------------------------|----------|
| `true_random_generator` | `results/issue-3/tb/true_random_generator_tb.sv` | `dut_a`  |
| `true_random_generator` | `results/issue-3/tb/true_random_generator_tb.sv` | `dut_b`  |

Two instances are exercised in the same testbench:
- **DUT-A** — `USE_RINGOSCILLATOR=0` (deterministic LFSR-only mode; all 32-bit output values are reproducible across simulator runs).
- **DUT-B** — `USE_RINGOSCILLATOR=1` (ring-oscillator + LFSR mode; entropy pool seeding differs from simulation to simulation due to oscillator phase).

Both use `DATA_WIDTH=32`.

---

## 5) How to run

From the repository root:

```sh
# Compile
iverilog -g2012 \
    -o results/issue-3/build/true_random_generator_tb.out \
    results/issue-3/tb/true_random_generator_tb.sv \
    results/issue-3/rtl/true_random_generator.v

# Simulate
vvp results/issue-3/build/true_random_generator_tb.out
```

Waveform is written to `results/issue-3/build/true_random_generator_tb.vcd`.

---

## 6) Post-fix results (after)

### Compile

```
# See results/issue-3/build/compile.log
iverilog -g2012 -o ... true_random_generator_tb.sv true_random_generator.v
Exit code: 0   (zero warnings)
```

### Simulation

```
=== Simulation complete: 29 passed, 0 failed ===
ALL CHECKS PASSED
```

**Overall status: PASS** — all 29 checks passed for both DUT instances.

### Scenario coverage

| ID  | Scenario                                              | DUT   | Result |
|-----|-------------------------------------------------------|-------|--------|
| S0  | Reset: `data_valid=0`, `random_data=0` while `rst_n=0`; `test_failed=1` (expected, output=0) | A + B | PASS |
| S1  | Normal enable → COLLECTING → TEST → READY → `data_valid` rises | A (LFSR) | PASS |
| S1  | `entropy_low=1` early (<32 cycles collected), `=0` after full collection | A | PASS |
| S1  | First random value is non-zero and not all-ones | A | PASS |
| S1  | `test_failed` consistent with actual output | A | PASS |
| S2  | `read_next` pulse → DUT re-enters COLLECTING → `data_valid` drops then rises again | A | PASS |
| S2  | Second value differs from first (LFSR advances) | A | PASS |
| S3  | Disable in READY state → DUT returns to IDLE, outputs de-asserted | A | PASS |
| S4  | Disable mid-collection (after 20 of 64 cycles) → DUT returns to IDLE | A | PASS |
| S5  | Re-enable after disable → fresh collection succeeds | A | PASS |
| S6  | Ring-oscillator mode: normal enable → `data_valid` rises | B (RingOsc) | PASS |
| S6  | `test_failed` consistent with actual output | B | PASS |
| S7  | `read_next` → new collection cycle → `data_valid` drops then rises | B | PASS |
| S8  | Synchronous reset mid-operation (both DUTs) → all outputs de-asserted | A + B | PASS |

### Notable design observation — `test_failed` during reset

`test_failed` is a purely combinatorial flag: it asserts whenever `random_data == 0` or
`random_data == ~0`. Because `random_data` is driven to zero whenever the FSM is not in the READY
state, `test_failed` is legitimately 1 during reset and during collection. Users of this module
should gate `test_failed` with `data_valid` to distinguish a genuine statistical failure from
expected quiescent behaviour.

---

## 7) Remaining gaps / limitations

| Gap | Notes |
|-----|-------|
| `DATA_WIDTH` parameterisation | Only `DATA_WIDTH=32` is exercised. The RTL has special-cased logic for `DATA_WIDTH==32`; other widths use a generic LFSR path that is not tested. |
| Ring-oscillator entropy quality | In simulation, the 6-inverter ring chain is effectively static (resolves to a fixed bit) due to zero-delay combinatorial loops; the oscillator's true metastable entropy is not observable in simulation. |
| `test_failed` assertion (genuine failure) | No test injects an all-zero or all-ones output while `data_valid=1` to verify `test_failed=1` in a meaningful context — this would require LFSR seed manipulation beyond the RTL's parameterisation. |
| Concurrent enable toggling | Back-to-back or rapid enable/disable cycles are not tested beyond S4/S5. |
| Statistical randomness | The testbench only checks that consecutive outputs differ and are non-degenerate; no NIST statistical tests are performed (not feasible in a simple iverilog flow). |
| RTL quirk in `gen_lfsr_only` block | The `entropy_pool2` right-shift and the subsequent `entropy_pool2[31]` bit-select are both non-blocking assignments in the same always block (lines 121-124 of the RTL). Verilog's NBA semantics make the bit-select win for bit 31, which is the intended feedback insertion. This is deterministic but fragile; a cleaner encoding would combine both into one concatenation assignment. The testbench validates the overall output without depending on the exact internal encoding. |
