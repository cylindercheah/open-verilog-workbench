// Reed-Solomon ECC Testbench  –  issue-11
// DUT: reed_solomon_ecc wrapper (results/issue-11/rtl/reed_solomon_ecc.v)
// Tested DATA_WIDTH configurations: 4, 8, 16, 32, 64, 128
//
// Covered scenarios
//   S0   – Reset: all outputs held at 0 while rst_n=0
//   S1   – DUT8  encode 0xAB + decode round-trip (nominal)
//   S2   – DUT8  encode 0x00 (all-zero), decode all-zero codeword
//   S3   – DUT8  encode 0xFF round-trip
//   S4   – DUT8  error detection: corrupt parity byte (XOR flip byte 0)
//   S5   – DUT8  error detection: corrupt data byte 0 (XOR flip all bits)
//   S6   – DUT8  error_corrected is always 0 (RTL placeholder)
//   S7   – DUT8  back-to-back encodes (3 consecutive cycles)
//   S8   – DUT8  simultaneous encode_en + decode_en in same cycle
//   S9   – DUT8  async reset mid-operation: assert rst_n=0 then re-check
//   S10  – DUT4  encode 0xA (nibble) + decode round-trip
//   S10b – DUT4  error detection on corrupted codeword
//   S11  – DUT16 encode 0xBEEF + decode round-trip
//   S11b – DUT16 error detection on corrupted codeword
//   S12  – DUT32 encode 0xDEADBEEF + decode round-trip
//   S12b – DUT32 error detection
//   S13  – DUT64 encode 0xCAFEBABEDEAD1234 + decode round-trip
//   S13b – DUT64 error detection: corrupt data byte 0
//   S14  – DUT128 encode 128-bit pattern + decode round-trip
//   S14b – DUT128 error detection on corrupted codeword
//
// Compile (from repository root):
//   iverilog -g2012 -o results/issue-11/build/reed_solomon_ecc_tb.out \
//       results/issue-11/tb/reed_solomon_ecc_tb.sv \
//       results/issue-11/rtl/reed_solomon_ecc.v \
//       results/issue-11/rtl/reed_solomon_ecc_w4.v \
//       results/issue-11/rtl/reed_solomon_ecc_w8.v \
//       results/issue-11/rtl/reed_solomon_ecc_w16.v \
//       results/issue-11/rtl/reed_solomon_ecc_w32.v \
//       results/issue-11/rtl/reed_solomon_ecc_w64.v \
//       results/issue-11/rtl/reed_solomon_ecc_w128.v
// Run:
//   vvp results/issue-11/build/reed_solomon_ecc_tb.out

`timescale 1ns/1ps

module reed_solomon_ecc_tb;

    // ----------------------------------------------------------------
    // Clock and shared reset
    // ----------------------------------------------------------------
    reg clk;
    reg rst_n;

    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz (10 ns period)

    // ----------------------------------------------------------------
    // DUT #1 – DATA_WIDTH = 8
    //   RS(5,1): 1 data byte + 4 parity bytes = 40-bit codeword
    //   Wrapper exposes 160-bit bus; codeword_out[39:0] is meaningful.
    // ----------------------------------------------------------------
    reg        enc_en8, dec_en8;
    reg  [7:0] din8;
    reg [159:0] cw_in8;
    wire [159:0] cw_out8;
    wire  [7:0] dout8;
    wire        err_det8, err_cor8, vld8;

    reed_solomon_ecc #(.DATA_WIDTH(8)) dut8 (
        .clk(clk),           .rst_n(rst_n),
        .encode_en(enc_en8), .decode_en(dec_en8),
        .data_in(din8),      .codeword_in(cw_in8),
        .codeword_out(cw_out8),
        .data_out(dout8),
        .error_detected(err_det8),
        .error_corrected(err_cor8),
        .valid_out(vld8)
    );

    // ----------------------------------------------------------------
    // DUT #2 – DATA_WIDTH = 4
    //   RS(5,1): 1 data nibble (zero-extended byte) + 4 parity bytes = 40-bit codeword
    //   Wrapper codeword_out[39:0] is meaningful; upper 120 bits are 0.
    // ----------------------------------------------------------------
    reg        enc_en4, dec_en4;
    reg  [3:0] din4;
    reg [159:0] cw_in4;
    wire [159:0] cw_out4;
    wire  [3:0] dout4;
    wire        err_det4, err_cor4, vld4;

    reed_solomon_ecc #(.DATA_WIDTH(4)) dut4 (
        .clk(clk),           .rst_n(rst_n),
        .encode_en(enc_en4), .decode_en(dec_en4),
        .data_in(din4),      .codeword_in(cw_in4),
        .codeword_out(cw_out4),
        .data_out(dout4),
        .error_detected(err_det4),
        .error_corrected(err_cor4),
        .valid_out(vld4)
    );

    // ----------------------------------------------------------------
    // DUT #3 – DATA_WIDTH = 16
    //   RS(6,2): 2 data bytes + 4 parity bytes = 48-bit codeword
    //   Wrapper codeword_out[47:0] is meaningful; upper 112 bits are 0.
    // ----------------------------------------------------------------
    reg        enc_en16, dec_en16;
    reg [15:0] din16;
    reg [159:0] cw_in16;
    wire [159:0] cw_out16;
    wire [15:0] dout16;
    wire        err_det16, err_cor16, vld16;

    reed_solomon_ecc #(.DATA_WIDTH(16)) dut16 (
        .clk(clk),            .rst_n(rst_n),
        .encode_en(enc_en16), .decode_en(dec_en16),
        .data_in(din16),      .codeword_in(cw_in16),
        .codeword_out(cw_out16),
        .data_out(dout16),
        .error_detected(err_det16),
        .error_corrected(err_cor16),
        .valid_out(vld16)
    );

    // ----------------------------------------------------------------
    // DUT #4 – DATA_WIDTH = 32
    //   RS(8,4): 4 data bytes + 4 parity bytes = 64-bit codeword
    //   Wrapper codeword_out[63:0] is meaningful; upper 96 bits are 0.
    // ----------------------------------------------------------------
    reg        enc_en32, dec_en32;
    reg [31:0] din32;
    reg [159:0] cw_in32;
    wire [159:0] cw_out32;
    wire [31:0] dout32;
    wire        err_det32, err_cor32, vld32;

    reed_solomon_ecc #(.DATA_WIDTH(32)) dut32 (
        .clk(clk),            .rst_n(rst_n),
        .encode_en(enc_en32), .decode_en(dec_en32),
        .data_in(din32),      .codeword_in(cw_in32),
        .codeword_out(cw_out32),
        .data_out(dout32),
        .error_detected(err_det32),
        .error_corrected(err_cor32),
        .valid_out(vld32)
    );

    // ----------------------------------------------------------------
    // DUT #5 – DATA_WIDTH = 64
    //   RS(12,8): 8 data bytes + 4 parity bytes = 96-bit codeword
    //   Wrapper codeword_out[95:0] is meaningful; upper 64 bits are 0.
    // ----------------------------------------------------------------
    reg        enc_en64, dec_en64;
    reg [63:0] din64;
    reg [159:0] cw_in64;
    wire [159:0] cw_out64;
    wire [63:0] dout64;
    wire        err_det64, err_cor64, vld64;

    reed_solomon_ecc #(.DATA_WIDTH(64)) dut64 (
        .clk(clk),            .rst_n(rst_n),
        .encode_en(enc_en64), .decode_en(dec_en64),
        .data_in(din64),      .codeword_in(cw_in64),
        .codeword_out(cw_out64),
        .data_out(dout64),
        .error_detected(err_det64),
        .error_corrected(err_cor64),
        .valid_out(vld64)
    );

    // ----------------------------------------------------------------
    // DUT #6 – DATA_WIDTH = 128
    //   RS(20,16): 16 data bytes + 4 parity bytes = 160-bit codeword
    //   Wrapper codeword_out[159:0] is meaningful (full bus used).
    // ----------------------------------------------------------------
    reg         enc_en128, dec_en128;
    reg [127:0] din128;
    reg [159:0] cw_in128;
    wire [159:0] cw_out128;
    wire [127:0] dout128;
    wire         err_det128, err_cor128, vld128;

    reed_solomon_ecc #(.DATA_WIDTH(128)) dut128 (
        .clk(clk),             .rst_n(rst_n),
        .encode_en(enc_en128), .decode_en(dec_en128),
        .data_in(din128),      .codeword_in(cw_in128),
        .codeword_out(cw_out128),
        .data_out(dout128),
        .error_detected(err_det128),
        .error_corrected(err_cor128),
        .valid_out(vld128)
    );

    // ----------------------------------------------------------------
    // Failure counter and VCD dump
    // ----------------------------------------------------------------
    integer fail_count;

    initial begin
        $dumpfile("results/issue-11/build/reed_solomon_ecc_tb.vcd");
        $dumpvars(0, reed_solomon_ecc_tb);
    end

    // ----------------------------------------------------------------
    // Helper task: check a condition; print and count failures.
    // ----------------------------------------------------------------
    task automatic chk;
        input        cond;
        input [127:0] tag;   // ASCII label (up to 16 chars)
    begin
        if (!cond) begin
            $display("  FAIL [%s]", tag);
            fail_count = fail_count + 1;
        end else begin
            $display("  pass [%s]", tag);
        end
    end
    endtask

    // ----------------------------------------------------------------
    // Temporary storage for codeword round-trip tests
    // ----------------------------------------------------------------
    reg [39:0]  saved_cw4;
    reg [39:0]  saved_cw8;
    reg [47:0]  saved_cw16;
    reg [63:0]  saved_cw32;
    reg [95:0]  saved_cw64;
    reg [159:0] saved_cw128;

    // ================================================================
    // Main stimulus
    // All signal changes happen at @(negedge clk) to avoid race
    // conditions with the DUT's posedge-triggered always block.
    // Outputs are sampled at the negedge following the capturing
    // posedge (one half-period after registered outputs update).
    // ================================================================
    initial begin
        fail_count = 0;

        // Initialise all DUT inputs
        rst_n      = 0;
        enc_en8    = 0; dec_en8    = 0; din8    = 0; cw_in8    = 0;
        enc_en4    = 0; dec_en4    = 0; din4    = 0; cw_in4    = 0;
        enc_en16   = 0; dec_en16   = 0; din16   = 0; cw_in16   = 0;
        enc_en32   = 0; dec_en32   = 0; din32   = 0; cw_in32   = 0;
        enc_en64   = 0; dec_en64   = 0; din64   = 0; cw_in64   = 0;
        enc_en128  = 0; dec_en128  = 0; din128  = 0; cw_in128  = 0;

        $display("=== Reed-Solomon ECC Testbench START (issue-11) ===");

        // ============================================================
        // S0 – RESET CHECK
        //   Hold active-low reset for 4 clock cycles.
        //   All registered outputs must remain zero.
        // ============================================================
        $display("--- S0: Reset check ---");
        repeat(4) @(posedge clk);
        @(negedge clk);
        chk(vld8     === 1'b0,    "S0 vld8=0");
        chk(err_det8 === 1'b0,    "S0 err8=0");
        chk((|cw_out8) === 1'b0,  "S0 cw_out8=0");
        chk(vld4     === 1'b0,    "S0 vld4=0");
        chk(vld16    === 1'b0,    "S0 vld16=0");
        chk(vld32    === 1'b0,    "S0 vld32=0");
        chk(vld64    === 1'b0,    "S0 vld64=0");
        chk(vld128   === 1'b0,    "S0 vld128=0");

        // Deassert reset; one idle posedge before first operation.
        rst_n = 1;
        @(posedge clk);

        // ============================================================
        // S1 – DUT8: ENCODE + DECODE ROUND-TRIP (nominal data 0xAB)
        //   Assert encode_en for exactly one cycle.  RTL has 1-cycle
        //   latency; outputs are stable at the negedge after capturing
        //   posedge.
        // ============================================================
        $display("--- S1: DUT8 encode 0xAB, decode round-trip ---");
        @(negedge clk);  enc_en8 = 1; din8 = 8'hAB;
        @(posedge clk);                 // P1: captures encode_en=1
        @(negedge clk);                 // N1: outputs stable
        chk(vld8 === 1'b1,           "S1 vld after enc");
        chk(cw_out8[7:0] === 8'hAB,  "S1 data byte preserved");
        saved_cw8 = cw_out8[39:0];
        enc_en8 = 0;
        $display("    codeword[39:0] = 0x%010X", saved_cw8);

        // valid_out must deassert on the next idle cycle.
        @(posedge clk);
        @(negedge clk);
        chk(vld8 === 1'b0, "S1 vld deasserts");

        // Feed the clean codeword back for decode.
        @(negedge clk);  dec_en8 = 1; cw_in8 = {120'b0, saved_cw8};
        @(posedge clk);
        @(negedge clk);
        chk(vld8     === 1'b1,  "S1 vld after dec");
        chk(dout8    === 8'hAB, "S1 decoded data=AB");
        chk(err_det8 === 1'b0,  "S1 no error on clean cw");
        dec_en8 = 0;

        // ============================================================
        // S2 – DUT8: ALL-ZERO DATA → ALL-ZERO CODEWORD
        //   GF multiply by zero is zero; all parity bytes must be 0.
        // ============================================================
        $display("--- S2: DUT8 encode 0x00 (all-zero) ---");
        @(negedge clk);  enc_en8 = 1; din8 = 8'h00;
        @(posedge clk);
        @(negedge clk);
        chk(vld8 === 1'b1,             "S2 vld");
        chk(cw_out8[39:0] === 40'h0,   "S2 zero-cw");
        enc_en8 = 0;

        // Decode the all-zero codeword: syndromes must all be zero.
        @(negedge clk);  dec_en8 = 1; cw_in8 = 160'h0;
        @(posedge clk);
        @(negedge clk);
        chk(err_det8 === 1'b0,  "S2 no error on zero cw");
        chk(dout8    === 8'h00, "S2 decoded data=00");
        dec_en8 = 0;

        // ============================================================
        // S3 – DUT8: ALL-ONES DATA ROUND-TRIP (0xFF)
        // ============================================================
        $display("--- S3: DUT8 encode 0xFF round-trip ---");
        @(negedge clk);  enc_en8 = 1; din8 = 8'hFF;
        @(posedge clk);
        @(negedge clk);
        chk(vld8 === 1'b1, "S3 vld after enc");
        saved_cw8 = cw_out8[39:0];
        enc_en8 = 0;
        $display("    codeword[39:0] = 0x%010X", saved_cw8);

        @(negedge clk);  dec_en8 = 1; cw_in8 = {120'b0, saved_cw8};
        @(posedge clk);
        @(negedge clk);
        chk(dout8    === 8'hFF, "S3 decoded data=FF");
        chk(err_det8 === 1'b0,  "S3 no error on clean 0xFF cw");
        dec_en8 = 0;

        // ============================================================
        // S4 – DUT8: ERROR DETECTION – CORRUPT PARITY BYTE
        //   Re-encode 0xAB; flip all bits of parity byte 0 (cw[15:8]).
        //   error_detected must be asserted.
        // ============================================================
        $display("--- S4: DUT8 error detect – corrupt parity byte ---");
        @(negedge clk);  enc_en8 = 1; din8 = 8'hAB;
        @(posedge clk);
        @(negedge clk);
        saved_cw8 = cw_out8[39:0];
        enc_en8 = 0;

        // XOR-flip parity byte 0 (bits [15:8] of the 40-bit codeword).
        @(negedge clk);
        dec_en8 = 1;
        cw_in8  = {120'b0, saved_cw8 ^ 40'h00_0000_FF00};
        @(posedge clk);
        @(negedge clk);
        chk(err_det8 === 1'b1, "S4 error detected");
        dec_en8 = 0;

        // ============================================================
        // S5 – DUT8: ERROR DETECTION – CORRUPT DATA BYTE
        //   Flip all bits of data byte 0 (cw[7:0]).
        // ============================================================
        $display("--- S5: DUT8 error detect – corrupt data byte ---");
        @(negedge clk);
        dec_en8 = 1;
        cw_in8  = {120'b0, saved_cw8 ^ 40'h00_0000_00FF};
        @(posedge clk);
        @(negedge clk);
        chk(err_det8 === 1'b1, "S5 error detected");
        dec_en8 = 0;

        // ============================================================
        // S6 – DUT8: error_corrected IS ALWAYS 0 (RTL placeholder)
        //   Even on a corrupted codeword, the RTL never asserts this.
        // ============================================================
        $display("--- S6: DUT8 error_corrected=0 (placeholder) ---");
        // Reuse the corrupt codeword from S4.
        @(negedge clk);
        dec_en8 = 1;
        cw_in8  = {120'b0, saved_cw8 ^ 40'h00_0000_FF00};
        @(posedge clk);
        @(negedge clk);
        chk(err_cor8 === 1'b0, "S6 err_corrected=0");
        dec_en8 = 0;

        // ============================================================
        // S7 – DUT8: BACK-TO-BACK ENCODES (3 consecutive cycles)
        //   Each cycle: assert encode_en with a new data value.
        //   Each codeword is expected to be independently valid.
        // ============================================================
        $display("--- S7: DUT8 back-to-back encodes ---");
        // Cycle 1
        @(negedge clk);  enc_en8 = 1; din8 = 8'h11;
        @(posedge clk);
        @(negedge clk);
        chk(vld8 === 1'b1, "S7 bb enc c1 vld");
        // Cycle 2 – previous outputs registered; codeword changes on this posedge.
        din8 = 8'h22;
        @(posedge clk);
        @(negedge clk);
        chk(vld8 === 1'b1,          "S7 bb enc c2 vld");
        chk(cw_out8[7:0] === 8'h22, "S7 bb enc c2 data");
        // Cycle 3
        din8 = 8'h33;
        @(posedge clk);
        @(negedge clk);
        chk(vld8 === 1'b1,          "S7 bb enc c3 vld");
        chk(cw_out8[7:0] === 8'h33, "S7 bb enc c3 data");
        enc_en8 = 0;

        // ============================================================
        // S8 – DUT8: SIMULTANEOUS encode_en + decode_en
        //   When both are asserted in the same cycle the RTL registers
        //   both encode and decode outputs (both branches fire).
        //   Verify valid_out is asserted (either path suffices).
        // ============================================================
        $display("--- S8: DUT8 simultaneous encode+decode ---");
        @(negedge clk);  enc_en8 = 1; dec_en8 = 1;
                         din8  = 8'h5A;
                         cw_in8 = {120'b0, saved_cw8};  // reuse last good cw
        @(posedge clk);
        @(negedge clk);
        chk(vld8 === 1'b1, "S8 vld on sim enc+dec");
        enc_en8 = 0; dec_en8 = 0;

        // ============================================================
        // S9 – DUT8: ASYNC RESET MID-OPERATION
        //   Start an encode then pulse rst_n low asynchronously.
        //   After re-asserting rst_n, outputs must clear immediately
        //   (async reset), then a new encode should work normally.
        // ============================================================
        $display("--- S9: DUT8 async reset mid-operation ---");
        @(negedge clk);  enc_en8 = 1; din8 = 8'hAB;
        @(posedge clk);  // capture encode
        // Assert reset asynchronously (not on a clock edge).
        #3 rst_n = 0;
        @(negedge clk);  // sample after async reset
        chk(vld8 === 1'b0,        "S9 vld=0 after rst");
        chk((|cw_out8) === 1'b0,  "S9 cw=0 after rst");
        enc_en8 = 0;

        // Restore reset and verify normal operation resumes.
        @(negedge clk);  rst_n = 1;
        @(posedge clk);
        @(negedge clk);  enc_en8 = 1; din8 = 8'hCD;
        @(posedge clk);
        @(negedge clk);
        chk(vld8 === 1'b1,          "S9 vld after re-rst");
        chk(cw_out8[7:0] === 8'hCD, "S9 data after re-rst");
        enc_en8 = 0;

        // ============================================================
        // S10 – DUT4: ENCODE + DECODE ROUND-TRIP (nibble 0xA)
        //   DATA_WIDTH=4: data_in is a 4-bit nibble; the sub-module
        //   zero-extends it to a full byte before GF arithmetic.
        //   Codeword layout: [3:0] hold the nibble, [7:4] should be 0.
        // ============================================================
        $display("--- S10: DUT4 encode 0xA (nibble), decode round-trip ---");
        @(negedge clk);  enc_en4 = 1; din4 = 4'hA;
        @(posedge clk);
        @(negedge clk);
        chk(vld4 === 1'b1,             "S10 vld after enc");
        chk(cw_out4[3:0] === 4'hA,     "S10 data nibble preserved");
        chk(cw_out4[7:4] === 4'h0,     "S10 upper nibble zero");
        saved_cw4 = cw_out4[39:0];
        enc_en4 = 0;
        $display("    codeword[39:0] = 0x%010X", saved_cw4);

        @(negedge clk);  dec_en4 = 1; cw_in4 = {120'b0, saved_cw4};
        @(posedge clk);
        @(negedge clk);
        chk(vld4     === 1'b1, "S10 vld after dec");
        chk(dout4    === 4'hA, "S10 decoded nibble=A");
        chk(err_det4 === 1'b0, "S10 no error on clean cw");
        dec_en4 = 0;

        // ============================================================
        // S10b – DUT4: ERROR DETECTION on corrupted codeword
        // ============================================================
        $display("--- S10b: DUT4 error detect on corrupted codeword ---");
        @(negedge clk);
        dec_en4 = 1;
        cw_in4  = {120'b0, saved_cw4 ^ 40'h00_0000_FF00};  // flip parity byte 0
        @(posedge clk);
        @(negedge clk);
        chk(err_det4 === 1'b1, "S10b error detected");
        dec_en4 = 0;

        // ============================================================
        // S11 – DUT16: ENCODE + DECODE ROUND-TRIP (0xBEEF)
        //   DATA_WIDTH=16: 2 data bytes + 4 parity bytes = 48-bit CW.
        // ============================================================
        $display("--- S11: DUT16 encode 0xBEEF, decode round-trip ---");
        @(negedge clk);  enc_en16 = 1; din16 = 16'hBEEF;
        @(posedge clk);
        @(negedge clk);
        chk(vld16 === 1'b1,              "S11 vld after enc");
        chk(cw_out16[15:0] === 16'hBEEF, "S11 data bytes preserved");
        saved_cw16 = cw_out16[47:0];
        enc_en16 = 0;
        $display("    codeword[47:0] = 0x%012X", saved_cw16);

        @(negedge clk);  dec_en16 = 1; cw_in16 = {112'b0, saved_cw16};
        @(posedge clk);
        @(negedge clk);
        chk(vld16     === 1'b1,       "S11 vld after dec");
        chk(dout16    === 16'hBEEF,   "S11 decoded=BEEF");
        chk(err_det16 === 1'b0,       "S11 no error clean");
        dec_en16 = 0;

        // ============================================================
        // S11b – DUT16: ERROR DETECTION ON CORRUPTED CODEWORD
        //   Flip all bits in parity byte 1 (cw[23:16]).
        // ============================================================
        $display("--- S11b: DUT16 error detect ---");
        @(negedge clk);
        dec_en16 = 1;
        cw_in16  = {112'b0, saved_cw16 ^ 48'h00_0000_FF0000};
        @(posedge clk);
        @(negedge clk);
        chk(err_det16 === 1'b1, "S11b error detected");
        dec_en16 = 0;

        // ============================================================
        // S12 – DUT32: ENCODE + DECODE ROUND-TRIP (0xDEADBEEF)
        //   DATA_WIDTH=32: 4 data bytes + 4 parity bytes = 64-bit CW.
        // ============================================================
        $display("--- S12: DUT32 encode 0xDEADBEEF, decode round-trip ---");
        @(negedge clk);  enc_en32 = 1; din32 = 32'hDEADBEEF;
        @(posedge clk);
        @(negedge clk);
        chk(vld32 === 1'b1,                    "S12 vld after enc");
        chk(cw_out32[31:0] === 32'hDEADBEEF,   "S12 data bytes preserved");
        saved_cw32 = cw_out32[63:0];
        enc_en32 = 0;
        $display("    codeword[63:0] = 0x%016X", saved_cw32);

        @(negedge clk);  dec_en32 = 1; cw_in32 = {96'b0, saved_cw32};
        @(posedge clk);
        @(negedge clk);
        chk(vld32     === 1'b1,          "S12 vld after dec");
        chk(dout32    === 32'hDEADBEEF,  "S12 decoded=DEADBEEF");
        chk(err_det32 === 1'b0,          "S12 no error clean");
        dec_en32 = 0;

        // ============================================================
        // S12b – DUT32: ERROR DETECTION
        //   Flip all bits in data byte 1 (cw[15:8]).
        // ============================================================
        $display("--- S12b: DUT32 error detect ---");
        @(negedge clk);
        dec_en32 = 1;
        cw_in32  = {96'b0, saved_cw32 ^ 64'h0000_0000_0000_FF00};
        @(posedge clk);
        @(negedge clk);
        chk(err_det32 === 1'b1, "S12b error detected");
        dec_en32 = 0;

        // ============================================================
        // S13 – DUT64: ENCODE + DECODE ROUND-TRIP (64-bit pattern)
        //   DATA_WIDTH=64: 8 data bytes + 4 parity bytes = 96-bit CW.
        // ============================================================
        $display("--- S13: DUT64 encode 0xCAFEBABEDEAD1234, decode ---");
        @(negedge clk);  enc_en64 = 1; din64 = 64'hCAFEBABEDEAD1234;
        @(posedge clk);
        @(negedge clk);
        chk(vld64 === 1'b1,                         "S13 vld after enc");
        chk(cw_out64[63:0] === 64'hCAFEBABEDEAD1234, "S13 data preserved");
        saved_cw64 = cw_out64[95:0];
        enc_en64 = 0;
        $display("    codeword[95:0] = 0x%024X", saved_cw64);

        @(negedge clk);  dec_en64 = 1; cw_in64 = {64'b0, saved_cw64};
        @(posedge clk);
        @(negedge clk);
        chk(vld64     === 1'b1,                   "S13 vld after dec");
        chk(dout64    === 64'hCAFEBABEDEAD1234,   "S13 decoded correctly");
        chk(err_det64 === 1'b0,                   "S13 no error clean");
        dec_en64 = 0;

        // ============================================================
        // S13b – DUT64: ERROR DETECTION – CORRUPT DATA BYTE 0
        // ============================================================
        $display("--- S13b: DUT64 error detect – corrupt data byte 0 ---");
        @(negedge clk);
        dec_en64 = 1;
        cw_in64  = {64'b0, saved_cw64 ^ 96'h0000_0000_0000_0000_0000_00FF};
        @(posedge clk);
        @(negedge clk);
        chk(err_det64 === 1'b1, "S13b error detected");
        dec_en64 = 0;

        // ============================================================
        // S14 – DUT128: ENCODE + DECODE ROUND-TRIP (128-bit pattern)
        //   DATA_WIDTH=128: 16 data bytes + 4 parity bytes = 160-bit CW.
        //   Full 160-bit bus is meaningful; no zero-padding on output.
        // ============================================================
        $display("--- S14: DUT128 encode 128-bit pattern, decode ---");
        @(negedge clk);
        enc_en128 = 1;
        din128 = 128'hDEAD_BEEF_CAFE_BABE_1234_5678_9ABC_DEF0;
        @(posedge clk);
        @(negedge clk);
        chk(vld128 === 1'b1, "S14 vld after enc");
        chk(cw_out128[127:0] === 128'hDEAD_BEEF_CAFE_BABE_1234_5678_9ABC_DEF0,
            "S14 data preserved");
        saved_cw128 = cw_out128;
        enc_en128 = 0;
        $display("    codeword[159:128] (parity) = 0x%08X", saved_cw128[159:128]);

        @(negedge clk);  dec_en128 = 1; cw_in128 = saved_cw128;
        @(posedge clk);
        @(negedge clk);
        chk(vld128     === 1'b1, "S14 vld after dec");
        chk(dout128    === 128'hDEAD_BEEF_CAFE_BABE_1234_5678_9ABC_DEF0,
            "S14 decoded correctly");
        chk(err_det128 === 1'b0, "S14 no error clean");
        dec_en128 = 0;

        // ============================================================
        // S14b – DUT128: ERROR DETECTION ON CORRUPTED CODEWORD
        //   Flip one parity byte (bit 128..135 = first parity byte).
        // ============================================================
        $display("--- S14b: DUT128 error detect on corrupted codeword ---");
        @(negedge clk);
        dec_en128 = 1;
        // Flip parity byte 0 (bits [135:128] in the 160-bit codeword).
        cw_in128  = saved_cw128 ^ (160'h1 << 128);
        @(posedge clk);
        @(negedge clk);
        chk(err_det128 === 1'b1, "S14b error detected");
        dec_en128 = 0;

        // ============================================================
        // Final pass/fail summary
        // ============================================================
        @(negedge clk);
        $display("=== Reed-Solomon ECC Testbench END (issue-11) ===");
        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d TEST(S) FAILED", fail_count);

        $finish;
    end

endmodule
