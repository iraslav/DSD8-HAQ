// rsa_modexp.v -- modular exponentiation engine: result = base^exp mod n
// Owner: shared (security-enclave extension; not part of the frozen DSD-8 core).
//
// Algorithm: right-to-left binary exponentiation. For each of the W exponent
// bits, LSB first:   if (bit) res = res*b mod n;   b = b*b mod n.
// Each modular multiplication is bit-serial "interleaved" (MSB of the second
// operand first), one bit per clock:
//     r = 2r;      if (r >= n) r -= n;
//     if (y_bit)   r += x;   if (r >= n) r -= n;
// Because r < n and x < n, every intermediate fits in W+1 bits and one
// conditional subtraction per step is enough -- no divider, no multiplier.
//
// Latency: at most W * (2*W + 1) + 2 cycles from start to done (W = 16: 530).
// Operands are captured at `start`, so the caller may change its registers
// while the engine runs.
//
// Error (done = 1, error = 1, result = 0, no computation) if n < 2 or
// base >= n -- RSA requires the message to be smaller than the modulus.
//
// Debug hooks (driven by the enclave's debug unit; all inactive = 0 in
// normal operation):
//   hold     freezes every register for this cycle (halt / breakpoint)
//   fault    fault injection: forces bit 0 of every multiplier step to 0
//            (a stuck-at-0 fault, used to prove the self-test catches faults)
//   dep_*    deposit a value into res (1), b (2) or the exponent (3)
//   dbg_*    live view of every internal register
//   ev_mul   one-cycle event: a multiplication finishes this cycle with
//            ev_value; ev_to_res = 1 if it goes to res, 0 if to b

module rsa_modexp #(
    parameter integer W = 16
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,       // one-cycle pulse; ignored while busy
    input  wire [W-1:0] base_in,
    input  wire [W-1:0] exp_in,
    input  wire [W-1:0] mod_in,
    output reg          busy,
    output reg          done,        // result valid (stays high until next start)
    output reg          error,
    output reg  [W-1:0] result,
    // ---- debug hooks ----
    input  wire         hold,
    input  wire         fault,
    input  wire         dep_en,
    input  wire [1:0]   dep_sel,     // 1 res, 2 b, 3 exponent
    input  wire [W-1:0] dep_val,
    output wire [1:0]   dbg_state,   // 0 idle, 1 check, 2 multiply
    output wire [4:0]   dbg_bits_left,
    output wire [4:0]   dbg_steps_left,
    output wire [W-1:0] dbg_res,
    output wire [W-1:0] dbg_b,
    output wire [W-1:0] dbg_ex,
    output wire [W-1:0] dbg_mx,
    output wire [W-1:0] dbg_my,
    output wire [W-1:0] dbg_mr,
    output wire [W-1:0] dbg_n,
    output wire         ev_mul,
    output wire         ev_to_res,
    output wire [W-1:0] ev_value
);

    localparam [1:0] S_IDLE = 2'd0, S_CHECK = 2'd1, S_MUL = 2'd2;
    // bit / step counters (W <= 31); sliced from a wire, not a parameter,
    // for older Icarus versions
    wire [31:0] w_int = W;
    wire [4:0]  W5    = w_int[4:0];

    reg  [1:0]   state;
    reg  [W-1:0] n, res, b, ex;
    reg  [4:0]   bits_left;                   // exponent bits still to process
    // multiplier
    reg  [W-1:0] mx, my, mr;
    reg  [4:0]   steps_left;
    reg          mul_dest_res;                // 1: product -> res, 0: product -> b

    // ---- one step of the interleaved modular multiplication ----
    wire [W:0]   n_ext = {1'b0, n};
    wire [W:0]   dbl   = {mr, 1'b0};
    wire [W:0]   dbl_r = (dbl >= n_ext) ? dbl - n_ext : dbl;
    wire [W:0]   acc   = my[W-1] ? dbl_r + {1'b0, mx} : dbl_r;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [W:0]   acc_r = (acc >= n_ext) ? acc - n_ext : acc;    // < n, so bit W is 0
    wire [31:0]  w_int_unused = w_int;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [W-1:0] step_out = fault ? {acc_r[W-1:1], 1'b0} : acc_r[W-1:0];

    assign dbg_state      = state;
    assign dbg_bits_left  = bits_left;
    assign dbg_steps_left = steps_left;
    assign dbg_res = res;  assign dbg_b  = b;   assign dbg_ex = ex;
    assign dbg_mx  = mx;   assign dbg_my = my;  assign dbg_mr = mr;  assign dbg_n = n;
    assign ev_mul    = (state == S_MUL) && (steps_left == 5'd1) && !hold;
    assign ev_to_res = mul_dest_res;
    assign ev_value  = step_out;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;  busy <= 1'b0;  done <= 1'b0;  error <= 1'b0;
            result <= {W{1'b0}};
            n <= {W{1'b0}};  res <= {W{1'b0}};  b <= {W{1'b0}};  ex <= {W{1'b0}};
            mx <= {W{1'b0}}; my <= {W{1'b0}};  mr <= {W{1'b0}};
            bits_left <= 5'd0;  steps_left <= 5'd0;  mul_dest_res <= 1'b0;
        end else if (hold) begin
            if (dep_en) begin                         // deposits only while halted
                case (dep_sel)
                    2'd1:    res <= dep_val;
                    2'd2:    b   <= dep_val;
                    2'd3:    ex  <= dep_val;
                    default: ;
                endcase
            end
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        if (mod_in < 2 || base_in >= mod_in) begin
                            error  <= 1'b1;
                            done   <= 1'b1;
                            result <= {W{1'b0}};
                        end else begin
                            error     <= 1'b0;
                            busy      <= 1'b1;
                            n         <= mod_in;
                            res       <= {{(W-1){1'b0}}, 1'b1};
                            b         <= base_in;
                            ex        <= exp_in;
                            bits_left <= W5;
                            state     <= S_CHECK;
                        end
                    end
                end

                S_CHECK: begin
                    if (bits_left == 5'd0) begin
                        result <= res;
                        busy   <= 1'b0;
                        done   <= 1'b1;
                        state  <= S_IDLE;
                    end else begin
                        // multiply res*b if this exponent bit is 1, else square b
                        mul_dest_res <= ex[0];
                        mx           <= ex[0] ? res : b;
                        my           <= b;
                        mr           <= {W{1'b0}};
                        steps_left   <= W5;
                        state        <= S_MUL;
                    end
                end

                S_MUL: begin
                    mr         <= step_out;
                    my         <= {my[W-2:0], 1'b0};
                    steps_left <= steps_left - 5'd1;
                    if (steps_left == 5'd1) begin           // last step: product = step_out
                        if (mul_dest_res) begin
                            res          <= step_out;          // then square b
                            mul_dest_res <= 1'b0;
                            mx           <= b;
                            my           <= b;
                            mr           <= {W{1'b0}};
                            steps_left   <= W5;
                        end else begin
                            b         <= step_out;
                            ex        <= {1'b0, ex[W-1:1]};
                            bits_left <= bits_left - 5'd1;
                            state     <= S_CHECK;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
