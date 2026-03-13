# `reed_solomon_ecc` — Reed-Solomon ECC Wrapper

## Overview

`reed_solomon_ecc` is a parameterised **Reed-Solomon error-correction wrapper** that supports
data widths of 4, 8, 16, 32, 64, and 128 bits.  It targets the **GF(2⁸)** field with a correction
capability of **T = 2** (two-symbol errors), requiring **4 parity bytes**.

At elaboration time the `generate` block selects one of six width-specific sub-modules
(`reed_solomon_ecc_w4` … `reed_solomon_ecc_w128`).  The top-level codeword ports are held at a
fixed **160-bit** width (the maximum codeword size); the wrapper slices or zero-pads to match
each sub-module's actual width.

See the [Architecture Overview](ARCHITECTURE.md) for the system-level context.

---

## Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock — rising-edge triggered |
| `rst_n` | input | 1 | Asynchronous active-low reset |
| `encode_en` | input | 1 | Assert to start an RS encode operation |
| `decode_en` | input | 1 | Assert to start an RS decode / error-correct operation |
| `data_in` | input | `DATA_WIDTH` | Raw data word to encode, or received word for decode |
| `codeword_in` | input | 160 | Received codeword for decode (only the lower N bits are used; see table below) |
| `codeword_out` | output | 160 | Encoded codeword (lower N bits valid; upper bits driven to zero) |
| `data_out` | output | `DATA_WIDTH` | Corrected data word after decode |
| `error_detected` | output | 1 | At least one symbol error was detected in the codeword |
| `error_corrected` | output | 1 | Detected errors were successfully corrected (≤ T = 2 errors) |
| `valid_out` | output | 1 | Output (`data_out` / `codeword_out`) is valid |

---

## Parameters

| Parameter | Default | Allowed values | Description |
|-----------|---------|----------------|-------------|
| `DATA_WIDTH` | 8 | 4, 8, 16, 32, 64, 128 | Width of the data bus in bits. Any other value activates the `fallback` branch, which drives all outputs to zero. |

---

## Codeword Width Mapping

The wrapper exposes a uniform 160-bit codeword interface and internally maps to the appropriate
sub-module width:

| `DATA_WIDTH` | Data bytes | Parity bytes | Codeword bits | Active slice | Sub-module |
|:---:|:---:|:---:|:---:|:---:|:---|
| 4  | 1 | 4 | 40  | `[39:0]`   | `reed_solomon_ecc_w4`   |
| 8  | 1 | 4 | 40  | `[39:0]`   | `reed_solomon_ecc_w8`   |
| 16 | 2 | 4 | 48  | `[47:0]`   | `reed_solomon_ecc_w16`  |
| 32 | 4 | 4 | 64  | `[63:0]`   | `reed_solomon_ecc_w32`  |
| 64 | 8 | 4 | 96  | `[95:0]`   | `reed_solomon_ecc_w64`  |
| 128| 16| 4 | 160 | `[159:0]`  | `reed_solomon_ecc_w128` |

```
DATA_WIDTH=4/8  : codeword[39:0]   ↔ w4 / w8  (120 MSBs zeroed on output)
DATA_WIDTH=16   : codeword[47:0]   ↔ w16       (112 MSBs zeroed on output)
DATA_WIDTH=32   : codeword[63:0]   ↔ w32       ( 96 MSBs zeroed on output)
DATA_WIDTH=64   : codeword[95:0]   ↔ w64       ( 64 MSBs zeroed on output)
DATA_WIDTH=128  : codeword[159:0]  ↔ w128      (no padding needed)
```

---

## Functional Description

### Encode path

When `encode_en` is asserted, `data_in` is passed to the selected sub-module.  The sub-module
appends 4 bytes of GF(2⁸) RS parity to form the full codeword, which appears on `codeword_out`
when `valid_out` is asserted.

### Decode / correct path

When `decode_en` is asserted, the lower N bits of `codeword_in` are fed into the sub-module's
pipeline.  The sub-module:

1. Computes syndromes S₀ … S₃.
2. Runs the Berlekamp-Massey (or Euclidean) algorithm to find the error-locator polynomial.
3. Performs a Chien search to locate error positions.
4. Applies Forney's algorithm to compute error magnitudes and corrects the codeword.
5. Outputs corrected `data_out`, drives `error_detected` / `error_corrected`, and pulses
   `valid_out`.

### Reset behaviour

`rst_n` is **active-low** and **asynchronous**.  When `rst_n = 0`, all internal state and output
registers inside the sub-module are cleared.  The wrapper itself is purely combinational
(`generate` / `assign`), so its outputs follow the sub-module outputs immediately after
de-assertion.

### Fallback branch

If `DATA_WIDTH` is not one of the six supported values, the `fallback` `generate` branch drives
all outputs (`codeword_out`, `data_out`, `error_detected`, `error_corrected`, `valid_out`) to
zero.  This is a safe default; a synthesis tool may emit an informational warning.

---

## FSM / Control Flow

The wrapper itself contains no FSM — it is purely combinational glue.  The state machine for
syndrome computation, error localisation, and error correction resides inside each
`reed_solomon_ecc_wN` sub-module.  Refer to the sub-module implementations for state diagrams.

---

## Timing / Latency

- `encode_en` and `decode_en` are **level-sensitive** as seen by the sub-modules.
- Exact pipeline latency (clock cycles from `enable` assertion to `valid_out` pulse) depends on
  each `reed_solomon_ecc_wN` implementation.
- Treat `valid_out` as a **single-cycle pulse** unless the sub-module specification states
  otherwise.
- Do **not** assert both `encode_en` and `decode_en` simultaneously unless the target sub-module
  explicitly supports it.

---

## Instantiation Example

```verilog
// 8-bit data, GF(2^8) T=2
reed_solomon_ecc #(
    .DATA_WIDTH(8)
) u_rs_ecc (
    .clk             (clk),
    .rst_n           (rst_n),
    .encode_en       (enc_start),
    .decode_en       (dec_start),
    .data_in         (tx_byte),        // 8-bit input
    .codeword_in     (rx_codeword),    // 160-bit bus; only [39:0] used
    .codeword_out    (tx_codeword),    // [39:0] valid; [159:40] = 0
    .data_out        (rx_corrected),
    .error_detected  (err_det),
    .error_corrected (err_cor),
    .valid_out       (out_valid)
);
```

---

## Source Files

| Type | Path |
|------|------|
| RTL wrapper | [`results/issue-3/rtl/reed_solomon_ecc.v`](../rtl/reed_solomon_ecc.v) |
| Testbench | `results/issue-3/tb/reed_solomon_ecc_tb.sv` *(TBD)* |
| Architecture overview | [`results/issue-3/docs/ARCHITECTURE.md`](ARCHITECTURE.md) |
