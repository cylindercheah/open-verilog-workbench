# Architecture Overview — Issue 1

This document lists the modules documented under `results/issue-1/` and links to their
individual documentation pages.

## Modules

| Module | RTL | Documentation | Brief description |
|--------|-----|---------------|-------------------|
| `reed_solomon_ecc` | [`rtl/reed_solomon_ecc.v`](../rtl/reed_solomon_ecc.v) | [`docs/reed_solomon_ecc.md`](reed_solomon_ecc.md) | Parameterised RS ECC wrapper — GF(2⁸), T=2, supports 4–128-bit data widths |
| `true_random_generator` | [`rtl/true_random_generator.v`](../rtl/true_random_generator.v) | [`docs/true_random_generator.md`](true_random_generator.md) | TRNG combining ring-oscillator jitter with dual entropy pools and a Galois LFSR |

---

## `true_random_generator` — Design Summary

### Purpose and environment

`true_random_generator` produces `DATA_WIDTH`-bit random words by harvesting physical timing
jitter from a 6-stage on-chip ring oscillator, accumulating it through two independent
shift-register entropy pools, and mixing the result with a Galois LFSR.  It is intended as a
standalone entropy source IP core clocked by the system clock.

### Top-level ports (summary)

| Port | Dir | Width | Function |
|------|-----|-------|----------|
| `clk` | in | 1 | System clock |
| `rst_n` | in | 1 | Active-low synchronous reset |
| `enable` | in | 1 | Start entropy collection |
| `read_next` | in | 1 | Request next random word (re-arms collection) |
| `data_valid` | out | 1 | Valid flag (registered, 1-cycle delay from READY entry) |
| `random_data` | out | DATA_WIDTH | Mixed random output |
| `entropy_low` | out | 1 | Health warning: fewer than 32 samples collected |
| `test_failed` | out | 1 | Degenerate output detected (all-0s or all-1s) |

### FSM overview

```
IDLE ──(enable)──> COLLECTING ──(64 cycles)──> TEST ──> READY
                        │                                  │
                  (!enable)→IDLE                   (read_next)→COLLECTING
```

After `enable` is asserted, at least **66 clock cycles** elapse before `data_valid` asserts.

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 32 | Random output width (bits) |
| `USE_RINGOSCILLATOR` | 1 | `1` = ring-oscillator mode (hardware); `0` = LFSR fallback (simulation) |

See [`docs/true_random_generator.md`](true_random_generator.md) for full port, timing, and
instantiation details.

---

## `reed_solomon_ecc` — Design Summary

`reed_solomon_ecc` is a parameterised Reed-Solomon ECC wrapper (GF(2⁸), T=2, 4 parity bytes)
supporting data widths of 4, 8, 16, 32, 64, and 128 bits.  At elaboration time a `generate`
block selects the matching width-specific sub-module.

See [`docs/reed_solomon_ecc.md`](reed_solomon_ecc.md) for the full interface and functional
description.

---

## Directory Layout

```
results/issue-1/
  rtl/
    true_random_generator.v   – TRNG RTL
    reed_solomon_ecc.v        – RS ECC wrapper RTL
  tb/                         – testbenches (TBD)
  docs/
    ARCHITECTURE.md           – this file
    true_random_generator.md  – TRNG module documentation
    reed_solomon_ecc.md       – RS ECC module documentation
  build/                      – simulation outputs and VCDs
```
