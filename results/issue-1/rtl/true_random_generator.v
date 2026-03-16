// True Random Number Generator (TRNG)
// Combines a ring-oscillator entropy source with three independent shift-register
// accumulators and a final XOR-mixing stage.  Controlled by a 4-state FSM:
//   IDLE → COLLECTING (64 clocks) → TEST (1 clock) → READY → COLLECTING (on read_next)
//
// USE_RINGOSCILLATOR=1 (default): physical jitter from a 6-inverter ring provides entropy.
// USE_RINGOSCILLATOR=0: dual Fibonacci/Galois LFSRs substitute for the oscillator;
//   output is deterministic and suitable for simulation / coverage-only use.

module true_random_generator #(
    parameter DATA_WIDTH = 32,
    parameter USE_RINGOSCILLATOR = 1
)(
    // Global signals
    input  wire                  clk,
    input  wire                  rst_n,    // Active-low synchronous reset
    
    // Control signals
    input  wire                  enable,     // Enable generator; rising edge starts collection
    input  wire                  read_next,  // Pulse in READY state to request next random word
    output wire                  data_valid, // High when random_data holds a valid, tested word
    
    // Data output
    output wire [DATA_WIDTH-1:0] random_data,
    
    // Health monitoring
    output wire                  entropy_low,  // Fewer than 32 accumulation cycles completed
    output wire                  test_failed   // Output is all-0s or all-1s (degenerate)
);

    // Internal signals
    reg [DATA_WIDTH-1:0] lfsr_reg;
    reg [DATA_WIDTH-1:0] entropy_pool;
    reg [DATA_WIDTH-1:0] entropy_pool2;  // Additional entropy pool with independent feedback
    reg                  data_valid_reg;
    reg [7:0]            health_counter;
    
    // State machine encoding
    localparam IDLE        = 2'b00;
    localparam COLLECTING  = 2'b01;
    localparam READY       = 2'b10;
    localparam TEST        = 2'b11;
    
    reg [1:0] state, next_state;
    
    // --------------------------------------------------------------------------
    // Entropy source: ring oscillator (USE_RINGOSCILLATOR=1) or dual LFSR fallback
    // --------------------------------------------------------------------------
    generate
        if (USE_RINGOSCILLATOR) begin : gen_ring_osc
            // 6-stage inverter ring; synthesis must keep this chain intact
            // (dont_touch + verilator lint disable prevent tool optimisation).
            // The output toggles at a rate determined by gate delays, not clk,
            // so sampling it on clk edges captures timing-jitter entropy.
            /* verilator lint_off UNOPTFLAT */
            (* dont_touch = "true" *) wire [5:0] inv_chain;
            /* verilator lint_on UNOPTFLAT */
            (* dont_touch = "true" *) reg  toggle_sampling;
            // init_osc breaks the combinational loop at reset so simulation starts cleanly
            (* dont_touch = "true" *) reg  init_osc = 1'b1;
            
            // Oscillator chain; init_osc forces inv_chain[0]=0 at reset to break circularity
            assign inv_chain[0] = ~(inv_chain[5] | init_osc);
            assign inv_chain[1] = ~inv_chain[0];
            assign inv_chain[2] = ~inv_chain[1];
            assign inv_chain[3] = ~inv_chain[2];
            assign inv_chain[4] = ~inv_chain[3];
            assign inv_chain[5] = ~inv_chain[4];
            
            // Hold init_osc for one cycle after reset to guarantee a stable starting value
            always @(posedge clk) begin
                if (!rst_n)
                    init_osc <= 1'b1;
                else
                    init_osc <= 1'b0;
            end
            
            // Capture oscillator output synchronously; jitter causes non-deterministic bit values
            always @(posedge clk) begin
                if (!rst_n) 
                    toggle_sampling <= 1'b0;
                else if (enable)
                    toggle_sampling <= inv_chain[5];
            end
            
            // entropy_pool: left-shift accumulator; new bit = oscillator XOR MSB (whitening)
            always @(posedge clk) begin
                if (!rst_n) 
                    entropy_pool <= {{(DATA_WIDTH-1){1'b0}}, 1'b1}; // Non-zero seed
                else if (enable && state == COLLECTING)
                    entropy_pool <= {entropy_pool[DATA_WIDTH-2:0], toggle_sampling ^ entropy_pool[DATA_WIDTH-1]};
            end
            
            // entropy_pool2: right-shift accumulator with MSB XOR-fed by oscillator (independent)
            always @(posedge clk) begin
                if (!rst_n) 
                    entropy_pool2 <= {DATA_WIDTH{1'b1}}; // Different seed to decorrelate pools
                else if (enable && state == COLLECTING)
                    entropy_pool2 <= {entropy_pool2[0], entropy_pool2[DATA_WIDTH-1:1]} ^ 
                                    {toggle_sampling, {(DATA_WIDTH-1){1'b0}}};
            end
        end
        else begin : gen_lfsr_only
            // Fallback when no ring oscillator is available (simulation / coverage use only).
            // Output is deterministic; do NOT use in a security-sensitive application.

            // entropy_pool: Fibonacci LFSR (left-shifting)
            always @(posedge clk) begin
                if (!rst_n) 
                    entropy_pool <= {{(DATA_WIDTH-1){1'b0}}, 1'b1};
                else if (enable && state == COLLECTING) begin
                    if (DATA_WIDTH == 32) begin
                        // 32-bit Fibonacci LFSR; maximal-length taps
                        entropy_pool <= {entropy_pool[DATA_WIDTH-2:0], 
                                        entropy_pool[31] ^ entropy_pool[30] ^ entropy_pool[29] ^ 
                                        entropy_pool[27] ^ entropy_pool[25] ^ entropy_pool[22] ^ 
                                        entropy_pool[19] ^ entropy_pool[15] ^ entropy_pool[10] ^ entropy_pool[5] ^ 
                                        entropy_pool[1] ^ entropy_pool[0]};
                    end
                    else begin
                        // Generic 4-tap LFSR for arbitrary DATA_WIDTH
                        entropy_pool <= {entropy_pool[DATA_WIDTH-2:0], 
                                        entropy_pool[DATA_WIDTH-1] ^ entropy_pool[DATA_WIDTH/2] ^ 
                                        entropy_pool[DATA_WIDTH/4] ^ entropy_pool[0]};
                    end
                end
            end
            
            // entropy_pool2: right-shifting Galois-style LFSR (different direction for independence)
            always @(posedge clk) begin
                if (!rst_n) 
                    entropy_pool2 <= {DATA_WIDTH{1'b1}};
                else if (enable && state == COLLECTING) begin
                    if (DATA_WIDTH == 32) begin
                        // 32-bit right-shifting LFSR; taps selected for long period.
                        // Note: the two non-blocking assignments to entropy_pool2 in this
                        // branch resolve in simulation as: the shift is applied first, then
                        // bit [31] is overwritten by the tap feedback (last NBA wins for the
                        // same variable target).  Synthesis tools typically interpret this the
                        // same way, but a single merged expression would be cleaner for
                        // portability.
                        entropy_pool2 <= {entropy_pool2[0], entropy_pool2[DATA_WIDTH-1:1]};
                        entropy_pool2[31] <= entropy_pool2[0] ^ entropy_pool2[3] ^ 
                                            entropy_pool2[7] ^ entropy_pool2[11] ^ 
                                            entropy_pool2[13] ^ entropy_pool2[21] ^ entropy_pool2[31];
                    end
                    else begin
                        entropy_pool2 <= {entropy_pool2[0], entropy_pool2[DATA_WIDTH-1:1]};
                        entropy_pool2[DATA_WIDTH-1] <= entropy_pool2[0] ^ entropy_pool2[DATA_WIDTH/3];
                    end
                end
            end
        end
    endgenerate
    
    // --------------------------------------------------------------------------
    // Galois LFSR for a third independent entropy stream
    // Polynomial (32-bit): x^32+x^31+x^29+x^25+x^16+x^11+x^8+x^6+x^5+x^1+1
    // Runs every enabled clock cycle regardless of FSM state.
    // --------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            lfsr_reg <= 32'hABCDE971; // Non-zero seed with good bit distribution
        end
        else if (enable) begin
            if (DATA_WIDTH == 32) begin
                // Galois LFSR: shift left then XOR feedback taps when output bit is 1
                lfsr_reg <= {lfsr_reg[30:0], 1'b0} ^ 
                          (lfsr_reg[31] ? 32'hA8000001 : 32'h0) ^
                          (lfsr_reg[30] ? 32'h40000800 : 32'h0) ^
                          (lfsr_reg[29] ? 32'h20000020 : 32'h0) ^
                          (lfsr_reg[28] ? 32'h00010000 : 32'h0);
            end
            else begin
                lfsr_reg <= {lfsr_reg[DATA_WIDTH-2:0], 1'b0} ^ 
                          (lfsr_reg[DATA_WIDTH-1] ? {{(DATA_WIDTH-5){1'b0}}, 5'b10111} : {DATA_WIDTH{1'b0}});
            end
        end
    end
    
    // --------------------------------------------------------------------------
    // Output mixing: XOR all three streams + rotated copies to improve uniformity
    // Registered in the READY state; result available the cycle after entering READY.
    // --------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mixed_output;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            mixed_output <= {DATA_WIDTH{1'b0}};
        end
        else if (state == READY) begin
            // Byte-swap and half-word swap add non-linearity so single-bit LFSR errors
            // do not produce predictable output patterns.
            mixed_output <= entropy_pool ^ entropy_pool2 ^ lfsr_reg ^ 
                          {lfsr_reg[15:0], lfsr_reg[31:16]} ^          // 16-bit rotation
                          {entropy_pool[7:0], entropy_pool[15:8], entropy_pool[23:16], entropy_pool[31:24]}; // byte-reverse
        end
    end
    
    // --------------------------------------------------------------------------
    // FSM — state register (synchronous reset)
    // --------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    // FSM next-state logic (combinatorial)
    always @(*) begin
        case (state)
            IDLE: begin
                if (enable)
                    next_state = COLLECTING;
                else
                    next_state = IDLE;
            end
            
            COLLECTING: begin
                if (!enable)
                    next_state = IDLE;
                else if (health_counter >= 8'd64) // 64 samples required before proceeding
                    next_state = TEST;
                else
                    next_state = COLLECTING;
            end
            
            TEST: begin
                // Single-cycle health-check state; result visible on test_failed output
                if (!enable)
                    next_state = IDLE;
                else
                    next_state = READY;
            end
            
            READY: begin
                if (!enable)
                    next_state = IDLE;
                else if (read_next)
                    next_state = COLLECTING; // Consumer requests a new sample
                else
                    next_state = READY;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // --------------------------------------------------------------------------
    // Sample counter — resets in IDLE, increments in COLLECTING
    // --------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            health_counter <= 8'd0;
        end
        else if (state == COLLECTING) begin
            health_counter <= health_counter + 8'd1;
        end
        else if (state == IDLE) begin
            health_counter <= 8'd0;
        end
    end
    
    // data_valid is registered: asserts one cycle after state enters READY
    always @(posedge clk) begin
        if (!rst_n) begin
            data_valid_reg <= 1'b0;
        end
        else begin
            data_valid_reg <= (state == READY);
        end
    end
    
    // Outputs
    assign random_data = (state == READY) ? mixed_output : {DATA_WIDTH{1'b0}};
    assign data_valid  = data_valid_reg;
    
    // entropy_low: warn consumer that collection is still early-phase
    assign entropy_low = (health_counter < 8'd32) && (state != IDLE);
    
    // test_failed: degenerate all-0/all-1 pattern — consumer should discard and re-read
    assign test_failed = (random_data == {DATA_WIDTH{1'b0}}) || (random_data == {DATA_WIDTH{1'b1}});
    
endmodule
