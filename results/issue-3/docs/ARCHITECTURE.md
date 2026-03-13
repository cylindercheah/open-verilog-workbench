# Architecture Overview — Issue 3

## Purpose

This workspace documents the **Reed-Solomon ECC wrapper** (`reed_solomon_ecc`) delivered in
[issue #3](https://github.com/mini-bicasl/open-verilog-workbench/issues/3).

The design implements a parameterised Reed-Solomon error-correction engine over **GF(2⁸)** with a
correction capability of **T = 2** (two-symbol errors, four parity bytes).  It is intended for
use as a memory/link-layer ECC block in synthesisable RTL.

---

## Top-Level RTL: `reed_solomon_ecc`

**File:** [`results/issue-3/rtl/reed_solomon_ecc.v`](../rtl/reed_solomon_ecc.v)

### Parameter

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 8 | Data bus width in bits. Supported values: 4, 8, 16, 32, 64, 128. |

### External Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock (rising-edge triggered) |
| `rst_n` | input | 1 | Asynchronous active-low reset |
| `encode_en` | input | 1 | Start an RS encode operation |
| `decode_en` | input | 1 | Start an RS decode / error-correct operation |
| `data_in` | input | `DATA_WIDTH` | Raw data word to encode, or received data word for decode |
| `codeword_in` | input | 160 | Received codeword (only lower N bits used; see sub-module table) |
| `codeword_out` | output | 160 | Encoded codeword (upper unused bits are zero) |
| `data_out` | output | `DATA_WIDTH` | Corrected data word after decode |
| `error_detected` | output | 1 | At least one symbol error was detected |
| `error_corrected` | output | 1 | Detected errors were successfully corrected |
| `valid_out` | output | 1 | Output data is valid |

### Clock / Reset

- **Single clock domain** — all sequential logic is driven by `clk`.
- **Active-low asynchronous reset** — `rst_n = 0` clears all sub-module state.
- The wrapper itself contains only combinational `generate`/`assign` logic.

---

## Sub-Module Breakdown

The wrapper uses a `generate` block to select and instantiate one width-specific sub-module at
elaboration time:

| `DATA_WIDTH` | Data bytes | Parity bytes | Codeword bits | Sub-module |
|:---:|:---:|:---:|:---:|:---|
| 4  | 1 | 4 | 40  | `reed_solomon_ecc_w4`   |
| 8  | 1 | 4 | 40  | `reed_solomon_ecc_w8`   |
| 16 | 2 | 4 | 48  | `reed_solomon_ecc_w16`  |
| 32 | 4 | 4 | 64  | `reed_solomon_ecc_w32`  |
| 64 | 8 | 4 | 96  | `reed_solomon_ecc_w64`  |
| 128| 16| 4 | 160 | `reed_solomon_ecc_w128` |

If `DATA_WIDTH` is not one of the six supported values, a `fallback` branch drives all outputs
to zero.

For full module documentation see
[`results/issue-3/docs/reed_solomon_ecc.md`](reed_solomon_ecc.md).

---

## Directory Layout

```
results/
  issue-3/
    rtl/    – reed_solomon_ecc.v (top-level wrapper)
    tb/     – testbenches (TBD)
    docs/   – this file + reed_solomon_ecc.md
    build/  – compiled simulation outputs (TBD)
```

---

## External Standards

Reed-Solomon codes over GF(2⁸) with T = 2 correction are widely used in:

- JEDEC NAND Flash ECC
- Various RAID-6 and storage controller implementations

Reference: S. B. Wicker & V. K. Bhargava, *Reed-Solomon Codes and Their Applications*,
IEEE Press, 1994.
