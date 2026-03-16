# `true_random_generator` — True Random Number Generator

## Overview

`true_random_generator` is a parameterised **True Random Number Generator (TRNG)** that derives
entropy from physical timing jitter in an on-chip ring oscillator, conditioned through two
independent shift-register accumulators and a Galois LFSR.  All three streams are XOR-mixed
before output to improve bit uniformity.

A lightweight 4-state FSM controls the collection, testing, and readout flow.  An optional
fallback mode (`USE_RINGOSCILLATOR=0`) replaces the ring oscillator with a second LFSR, making
the output deterministic and suitable for functional simulation only.

See the architecture overview: [`ARCHITECTURE.md`](ARCHITECTURE.md)

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 32 | Width of the random output bus in bits. All internal accumulators are also `DATA_WIDTH` wide. |
| `USE_RINGOSCILLATOR` | 1 | `1` = use 6-stage ring-oscillator entropy source (hardware); `0` = LFSR-only fallback (simulation/coverage use only — deterministic). |

---

## Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock. All registers are rising-edge triggered. |
| `rst_n` | input | 1 | Active-low **synchronous** reset. All state is cleared on the next rising edge after `rst_n` is de-asserted low. |
| `enable` | input | 1 | Enables the generator. Transitioning from low to high starts entropy collection. Deasserting `enable` from any state returns the FSM to IDLE. |
| `read_next` | input | 1 | When asserted in the READY state, signals that the consumer has read the current word and a new collection cycle should begin. |
| `data_valid` | output | 1 | Registered flag: high when a valid, tested random word is available on `random_data`. Asserts one clock cycle after the FSM enters READY. |
| `random_data` | output | DATA_WIDTH | Mixed random output word. Valid only when `data_valid` is high and `state == READY`. Reads as zero in all other states. |
| `entropy_low` | output | 1 | Asserted when `health_counter < 32` and the FSM is not IDLE. Indicates that fewer than 32 accumulation cycles have completed; output quality may be reduced. |
| `test_failed` | output | 1 | Asserted when `random_data` is all-zeros or all-ones (degenerate pattern). Consumer should assert `read_next` to request re-collection. |

---

## Functional Description

### Entropy architecture

Three independent entropy streams are accumulated and then XOR-combined:

| Stream | Register | Mechanism |
|--------|----------|-----------|
| Ring-oscillator pool | `entropy_pool` | 6-stage inverter ring sampled on `clk`; jitter provides non-deterministic bits. Left-shift accumulator: `{pool[N-2:0], osc_bit ^ pool[N-1]}`. |
| Independent pool | `entropy_pool2` | Same oscillator sample, but right-shift accumulator with a different seed. |
| Galois LFSR | `lfsr_reg` | 32-bit Galois LFSR running every enabled clock. Polynomial: x³²+x³¹+x²⁹+x²⁵+x¹⁶+x¹¹+x⁸+x⁶+x⁵+x¹+1 (maximal period). |

The final `mixed_output` register is computed in the READY state:

```
mixed_output = entropy_pool
             ^ entropy_pool2
             ^ lfsr_reg
             ^ rotate16(lfsr_reg)        // 16-bit half-word swap
             ^ byte_reverse(entropy_pool) // byte order reversal
```

The non-linear rotations and swaps prevent single-bit LFSR artifacts from producing visible output patterns.

### Ring oscillator (USE_RINGOSCILLATOR=1)

The 6-stage inverter chain (`inv_chain[5:0]`) is marked `(* dont_touch = "true" *)` and
`UNOPTFLAT` lint is suppressed to prevent synthesis or simulation tools from optimising it away.
An `init_osc` register forces `inv_chain[0]` low during reset to break the combinational loop for
simulation and ensure a defined starting point.

> **Synthesis note:** Ring oscillator behaviour is highly tool- and device-specific.  In practice,
> target-specific structural primitives or hard-macro wrappers are recommended for production ASIC
> or FPGA implementations.  The `dont_touch` attribute must be respected by the synthesiser for the
> jitter source to remain intact.

### LFSR-only fallback (USE_RINGOSCILLATOR=0)

When the ring oscillator is unavailable (e.g., during functional simulation), `entropy_pool` is
driven by a 32-bit Fibonacci LFSR and `entropy_pool2` by a right-shifting Galois-style LFSR with
independent taps.  The output is fully deterministic and **must not** be used as a security-grade
entropy source.

### FSM

```
         enable                   health_counter >= 64
  IDLE ──────────> COLLECTING ──────────────────────> TEST ──> READY
   ^                   |                                          |
   |   !enable         |  !enable                    read_next   |
   └───────────────────┴──────────────────────────────────────── ┘
                                        !enable → IDLE from any state
```

| State | Encoding | Description |
|-------|----------|-------------|
| IDLE | `2'b00` | Waiting for `enable`. All counters held at zero. |
| COLLECTING | `2'b01` | Entropy pools shift on every clock. `health_counter` increments each cycle. Exits after 64 cycles. |
| TEST | `2'b11` | Single-cycle pass-through; `test_failed` is evaluated on the subsequent READY output. |
| READY | `2'b10` | `random_data` holds the mixed output. `data_valid` is high. Waits for `read_next` or `!enable`. |

### Timing and latency

- After `enable` is asserted: **≥ 66 clock cycles** before `data_valid` asserts (64 increments of COLLECTING = 65 COLLECTING cycles due to the 1-cycle state-entry delay, + 1 TEST cycle + 1 cycle for `data_valid_reg` to register).
- `data_valid` is a **registered** output; it asserts one cycle after the FSM enters READY.
- `mixed_output` is also registered; it is recomputed on the first clock in READY, so `random_data` becomes stable in that same cycle.
- `test_failed` and `entropy_low` are **combinatorial** outputs from `random_data` and `health_counter`.
- Deasserting `enable` at any time returns the FSM to IDLE synchronously on the next clock.

### Health monitoring

| Signal | Condition | Recommended action |
|--------|-----------|--------------------|
| `entropy_low` | `health_counter < 32` and not IDLE | Wait; collection is still early-phase. |
| `test_failed` | Output is all-0s or all-1s | Assert `read_next` to discard and re-collect. |

---

## Reset Behaviour

`rst_n` is **active-low and synchronous**.  All `always @(posedge clk)` blocks check
`if (!rst_n)` as the first priority.  On reset:

- `state` → IDLE
- `health_counter` → 0
- `entropy_pool` → `{(DATA_WIDTH-1){1'b0}, 1'b1}` (non-zero seed)
- `entropy_pool2` → `{DATA_WIDTH{1'b1}}` (all-ones seed, decorrelated from pool 1)
- `lfsr_reg` → `32'hABCDE971`
- `mixed_output` → 0
- `data_valid_reg` → 0

---

## Instantiation Example

```verilog
// 32-bit output, ring-oscillator entropy enabled
true_random_generator #(
    .DATA_WIDTH      (32),
    .USE_RINGOSCILLATOR (1)
) u_trng (
    .clk         (sys_clk),
    .rst_n       (sys_rst_n),
    .enable      (trng_en),
    .read_next   (trng_read),
    .data_valid  (trng_valid),
    .random_data (trng_out),
    .entropy_low (trng_entropy_low),
    .test_failed (trng_test_fail)
);

// Typical usage: wait for data_valid, read random_data, then pulse read_next
always @(posedge sys_clk) begin
    if (trng_valid && !trng_test_fail) begin
        my_random_word <= trng_out;
        trng_read      <= 1'b1;
    end else begin
        trng_read <= 1'b0;
    end
end
```

---

## Source Files

| Type | Path |
|------|------|
| RTL | [`results/issue-1/rtl/true_random_generator.v`](../rtl/true_random_generator.v) |
| Architecture overview | [`results/issue-1/docs/ARCHITECTURE.md`](ARCHITECTURE.md) |
