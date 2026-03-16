// true_random_generator Testbench — issue #3
// DUT: results/issue-3/rtl/true_random_generator.v
//
// Scenarios covered:
//   S0  — Reset: all outputs de-asserted while rst_n=0
//   S1  — DUT-A (LFSR-only):  enable → wait data_valid → capture first value
//   S2  — DUT-A:              read_next → re-collect → second value differs from first
//   S3  — DUT-A:              disable in READY state → returns to IDLE
//   S4  — DUT-A:              disable mid-collection → returns to IDLE
//   S5  — DUT-A:              re-enable after disable → fresh collection succeeds
//   S6  — DUT-B (Ring-Osc):   enable → wait data_valid → check test_failed flag
//   S7  — DUT-B:              read_next → new collection cycle → new value
//   S8  — Both DUTs:          synchronous reset mid-operation → clean return to IDLE
//
// Compile (from repo root):
//   iverilog -g2012 -o results/issue-3/build/true_random_generator_tb.out \
//       results/issue-3/tb/true_random_generator_tb.sv \
//       results/issue-3/rtl/true_random_generator.v
// Run:
//   vvp results/issue-3/build/true_random_generator_tb.out

`timescale 1ns/1ps

module true_random_generator_tb;

    // ----------------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------------
    localparam DATA_WIDTH = 32;
    localparam CLK_HALF   = 5;    // 10 ns period → 100 MHz
    localparam MAX_WAIT   = 150;  // cycle budget for data_valid to rise
                                  // (~1 IDLE→COLLECTING + 64 COLLECTING + 1 TEST + 1 READY + 1 lag = ~68 cycles)

    // ----------------------------------------------------------------
    // Clock and shared active-low reset
    // ----------------------------------------------------------------
    reg clk = 1'b0;
    reg rst_n;

    always #CLK_HALF clk = ~clk;

    // ----------------------------------------------------------------
    // DUT-A: USE_RINGOSCILLATOR=0 — deterministic LFSR-only mode
    // ----------------------------------------------------------------
    reg  a_enable    = 1'b0;
    reg  a_read_next = 1'b0;
    wire a_data_valid;
    wire [DATA_WIDTH-1:0] a_random_data;
    wire a_entropy_low;
    wire a_test_failed;

    true_random_generator #(
        .DATA_WIDTH      (DATA_WIDTH),
        .USE_RINGOSCILLATOR (0)
    ) dut_a (
        .clk         (clk),
        .rst_n       (rst_n),
        .enable      (a_enable),
        .read_next   (a_read_next),
        .data_valid  (a_data_valid),
        .random_data (a_random_data),
        .entropy_low (a_entropy_low),
        .test_failed (a_test_failed)
    );

    // ----------------------------------------------------------------
    // DUT-B: USE_RINGOSCILLATOR=1 — ring-oscillator + LFSR mode
    // ----------------------------------------------------------------
    reg  b_enable    = 1'b0;
    reg  b_read_next = 1'b0;
    wire b_data_valid;
    wire [DATA_WIDTH-1:0] b_random_data;
    wire b_entropy_low;
    wire b_test_failed;

    true_random_generator #(
        .DATA_WIDTH      (DATA_WIDTH),
        .USE_RINGOSCILLATOR (1)
    ) dut_b (
        .clk         (clk),
        .rst_n       (rst_n),
        .enable      (b_enable),
        .read_next   (b_read_next),
        .data_valid  (b_data_valid),
        .random_data (b_random_data),
        .entropy_low (b_entropy_low),
        .test_failed (b_test_failed)
    );

    // ----------------------------------------------------------------
    // VCD waveform dump
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("results/issue-3/build/true_random_generator_tb.vcd");
        $dumpvars(0, true_random_generator_tb);
    end

    // ----------------------------------------------------------------
    // Pass / fail counters and check helper
    // ----------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    task automatic check;
        input string label;
        input logic  ok;
    begin
        if (ok) begin
            $display("  PASS  %s", label);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL  %s", label);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // ----------------------------------------------------------------
    // Wait helpers — poll for data_valid up to MAX_WAIT posedges
    // ----------------------------------------------------------------
    task automatic wait_a_valid(output reg timed_out);
        integer n;
    begin
        timed_out = 1'b0;
        n = 0;
        while (n < MAX_WAIT && !a_data_valid) begin
            @(posedge clk);
            n = n + 1;
        end
        if (!a_data_valid) timed_out = 1'b1;
    end
    endtask

    task automatic wait_b_valid(output reg timed_out);
        integer n;
    begin
        timed_out = 1'b0;
        n = 0;
        while (n < MAX_WAIT && !b_data_valid) begin
            @(posedge clk);
            n = n + 1;
        end
        if (!b_data_valid) timed_out = 1'b1;
    end
    endtask

    // ----------------------------------------------------------------
    // Watchdog — abort if simulation hangs
    // Headroom: 9 scenarios × MAX_WAIT cycles per scenario × 10 ns period × 3× safety margin
    // ----------------------------------------------------------------
    initial begin
        #(MAX_WAIT * 9 * CLK_HALF * 2 * 3);
        $fatal(1, "WATCHDOG: simulation exceeded maximum allowed time");
    end

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    reg [DATA_WIDTH-1:0] val1, val2;
    reg timed_out;

    initial begin
        // ------------------------------------------------------------
        // Initialise — hold reset, all enables low
        // ------------------------------------------------------------
        rst_n      = 1'b0;
        a_enable   = 1'b0; a_read_next = 1'b0;
        b_enable   = 1'b0; b_read_next = 1'b0;

        $display("=== true_random_generator_tb ===");

        // ============================================================
        // S0: Reset — all outputs must be de-asserted
        // ============================================================
        $display("");
        $display("[S0] Reset: all outputs de-asserted while rst_n=0");
        repeat(4) @(posedge clk);
        check("A data_valid=0 in reset",   !a_data_valid);
        check("A random_data=0 in reset",   a_random_data == {DATA_WIDTH{1'b0}});
        // test_failed is purely combinatorial: it trips whenever random_data==0 or all-1s.
        // During reset, random_data=0 (state!=READY), so test_failed=1 is expected and correct.
        check("A test_failed=1 in reset (random_data==0)", a_test_failed);
        check("B data_valid=0 in reset",   !b_data_valid);
        check("B random_data=0 in reset",   b_random_data == {DATA_WIDTH{1'b0}});
        check("B test_failed=1 in reset (random_data==0)", b_test_failed);

        // Deassert reset cleanly on a clock edge
        @(posedge clk); rst_n = 1'b1; @(posedge clk);

        // ============================================================
        // S1: DUT-A normal operation (LFSR mode)
        //     enable → COLLECTING → TEST → READY → data_valid=1
        // ============================================================
        $display("");
        $display("[S1] DUT-A (LFSR mode): enable -> wait data_valid");
        a_enable = 1'b1;

        // entropy_low should be asserted while health_counter < 32
        repeat(10) @(posedge clk);
        check("A entropy_low=1 early in collection",   a_entropy_low);
        check("A data_valid=0 still collecting",      !a_data_valid);

        wait_a_valid(timed_out);
        check("A data_valid rises within MAX_WAIT",   !timed_out);

        val1 = a_random_data;
        $display("  A first value = 0x%08X", val1);
        check("A random_data != all-zeros",            val1 != {DATA_WIDTH{1'b0}});
        check("A random_data != all-ones",             val1 != {DATA_WIDTH{1'b1}});
        // entropy_low clears once health_counter >= 32 (counter is ~65+ here)
        check("A entropy_low=0 after full collection", !a_entropy_low);
        // test_failed must agree with the actual output value
        check("A test_failed consistent with output",
              a_test_failed == (val1 == {DATA_WIDTH{1'b0}} || val1 == {DATA_WIDTH{1'b1}}));

        // ============================================================
        // S2: DUT-A read_next — request second value
        // ============================================================
        $display("");
        $display("[S2] DUT-A: read_next -> re-collect -> new value");

        // Pulse read_next for one cycle; DUT transitions READY -> COLLECTING
        a_read_next = 1'b1;
        @(posedge clk);
        a_read_next = 1'b0;

        // data_valid_reg is registered one cycle behind state, so allow two
        // posedges for it to reflect the COLLECTING state
        @(posedge clk);
        @(posedge clk);
        check("A data_valid=0 after read_next (re-collecting)", !a_data_valid);

        wait_a_valid(timed_out);
        check("A data_valid rises again after read_next", !timed_out);

        val2 = a_random_data;
        $display("  A second value = 0x%08X", val2);
        // Deterministic LFSR guarantees a different value on each collection pass
        check("A second value differs from first",  val2 != val1);

        // ============================================================
        // S3: DUT-A disable in READY state → returns to IDLE
        // ============================================================
        $display("");
        $display("[S3] DUT-A: disable in READY state -> IDLE");
        a_enable = 1'b0;
        // a_enable is set in the Active region AFTER the current posedge, so the DUT picks
        // it up one clock later; allow 3 posedges for data_valid_reg to fully de-assert.
        repeat(3) @(posedge clk);
        check("A data_valid=0 after disable",      !a_data_valid);
        check("A random_data=0 after disable",      a_random_data == {DATA_WIDTH{1'b0}});

        // ============================================================
        // S4: DUT-A disable mid-collection → returns to IDLE
        // ============================================================
        $display("");
        $display("[S4] DUT-A: disable mid-collection -> IDLE");
        a_enable = 1'b1;
        // Allow 20 cycles — well inside the 64-cycle collection window
        repeat(20) @(posedge clk);
        check("A still collecting (data_valid=0)",  !a_data_valid);
        a_enable = 1'b0;
        repeat(2) @(posedge clk);
        check("A data_valid=0 after mid-collect disable", !a_data_valid);

        // ============================================================
        // S5: DUT-A re-enable after disable → fresh collection succeeds
        // ============================================================
        $display("");
        $display("[S5] DUT-A: re-enable after disable -> fresh collection");
        a_enable = 1'b1;
        wait_a_valid(timed_out);
        check("A data_valid rises after re-enable", !timed_out);
        $display("  A third value = 0x%08X", a_random_data);
        a_enable = 1'b0;

        // ============================================================
        // S6: DUT-B normal operation (ring-oscillator mode)
        // ============================================================
        $display("");
        $display("[S6] DUT-B (ring-osc mode): enable -> wait data_valid");
        b_enable = 1'b1;
        wait_b_valid(timed_out);
        check("B data_valid rises within MAX_WAIT",  !timed_out);

        val1 = b_random_data;
        $display("  B first value = 0x%08X", val1);
        // test_failed must agree with the actual output
        check("B test_failed consistent with output",
              b_test_failed == (val1 == {DATA_WIDTH{1'b0}} || val1 == {DATA_WIDTH{1'b1}}));

        // ============================================================
        // S7: DUT-B read_next — new collection cycle
        // ============================================================
        $display("");
        $display("[S7] DUT-B: read_next -> new value");
        b_read_next = 1'b1;
        @(posedge clk);
        b_read_next = 1'b0;
        @(posedge clk);
        @(posedge clk);
        check("B data_valid=0 after read_next (re-collecting)", !b_data_valid);

        wait_b_valid(timed_out);
        check("B data_valid rises again after read_next", !timed_out);
        val2 = b_random_data;
        $display("  B second value = 0x%08X", val2);
        b_enable = 1'b0;

        // ============================================================
        // S8: Synchronous reset mid-operation — both DUTs must recover
        // ============================================================
        $display("");
        $display("[S8] Synchronous reset mid-operation (both DUTs)");
        a_enable = 1'b1;
        b_enable = 1'b1;
        repeat(30) @(posedge clk); // Partially through collection
        rst_n = 1'b0;              // Assert reset
        repeat(2) @(posedge clk);
        check("A data_valid=0 after mid-op reset",   !a_data_valid);
        check("A random_data=0 after reset",          a_random_data == {DATA_WIDTH{1'b0}});
        check("B data_valid=0 after mid-op reset",   !b_data_valid);
        check("B random_data=0 after reset",          b_random_data == {DATA_WIDTH{1'b0}});
        rst_n = 1'b1;
        a_enable = 1'b0;
        b_enable = 1'b0;
        @(posedge clk);

        // ============================================================
        // Final summary
        // ============================================================
        $display("");
        $display("=== Simulation complete: %0d passed, %0d failed ===",
                 pass_count, fail_count);
        if (fail_count != 0)
            $fatal(1, "TESTBENCH FAILED: %0d check(s) failed", fail_count);
        else
            $display("ALL CHECKS PASSED");

        $finish;
    end

endmodule
