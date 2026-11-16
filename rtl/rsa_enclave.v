// rsa_enclave.v -- RSA security enclave with a built-in debug unit (extension)
// Owner: shared (security-enclave extension; not part of the frozen DSD-8 core).
//
// Sits on the peripheral side of io_bus (ports >= 0x20 are forwarded there),
// in the range the spec leaves free for extensions (0x41-0xFF). The CPU is
// unchanged: it programs the key and runs operations with IN / OUT.
//
// ===== MODE SELECTOR =========================================================
// `dbg_strap` selects the mode. It is a boot strap: the board top latches it
// while reset is asserted, so the mode can only change through a reset -- and
// reset clears every key. A secret loaded in SECURE mode can therefore never
// be observed in DEBUG mode.
//   dbg_strap = 0  SECURE COMMUNICATION mode
//       private key D is write-only, the debug unit is locked (reads 0x00,
//       writes ignored, error code 5), RES reads stall until the result is ready
//   dbg_strap = 1  DEBUG mode
//       the debug unit is enabled; D can be read back (it can only be a debug
//       key); RES reads never stall (the engine may be halted by the debugger)
//
// ===== CRYPTO PORTS (BASE = 0x50) ============================================
//   +0/+1 MSG     r/w   message (must be < the modulus used)
//   +2/+3 N       r/w   own public modulus
//   +4/+5 E       r/w   own public exponent
//   +6/+7 D       w     own private exponent (readable only in DEBUG mode)
//   +8    CTRL    w     0x01 ENCRYPT       RES = MSG^E  mod N
//                       0x02 DECRYPT       RES = MSG^D  mod N
//                       0x03 ENCRYPT_PEER  RES = MSG^PE mod PN
//                       bit 7 LOCK: N, E, D read-only until reset
//                       (commands are ignored while busy -> error code 3)
//   +9    STATUS  r     {3'b0, debug_mode, locked, error, done, busy}
//   +A/+B RES     r     result (SECURE: a read while busy stalls, <= 530 cycles)
//   +C/+D PN      r/w   peer public modulus
//   +E/+F PE      r/w   peer public exponent (public data: not locked)
//
// ===== DEBUG PORTS (DBG_BASE = 0x70), DEBUG mode only =========================
//   +0 DBG_CTRL    w   bit0 HALT        stop the engine now
//                      bit1 RESUME      run again (clears breakpoint/watchpoint hit)
//                      bit2 STEP        run exactly one engine clock, then halt
//                      bit3 RUN_BIST    built-in self-test: 8 known-answer vectors
//                      bit4 CLEAR_TRACE
//                      bit5 DEPOSIT     write DEP value into register REG_SEL
//                                       (3 res, 4 b, 5 exponent; only while halted)
//                      bit6 CLEAR_ERR
//   +1 DBG_STATUS  r   {bist_done, bist_running, wp_hit, bp_hit,
//                       fault_armed, halted, engine_busy, debug_mode}
//   +2 BP_CTRL     r/w bit0 breakpoint on exponent bit   (halt when the engine
//                           reaches CHECK with bits_left == BP_BIT)
//                      bit1 watchpoint on res            (halt after a multiply
//                           writes res == WP)
//                      bit4 FAULT INJECT: stuck-at-0 on multiplier output bit 0
//   +3 BP_BIT      r/w exponent bits remaining at which to break (16..0)
//   +4/+5 WP       r/w watch value for res
//   +6 REG_SEL     r/w internal register to inspect / deposit:
//                      0 state  1 bits_left  2 steps_left  3 res  4 b  5 exponent
//                      6 mx  7 my  8 mr  9 modulus  10 cycle count  11 multiply
//                      count  12 last error code  13 BIST vector index
//   +7/+8 REG      r   selected register (lo / hi);  w: deposit value (lo / hi)
//   +9 TRACE_IDX   r/w trace entry 0..7 (circular buffer of multiply results)
//   +A/+B TRACE    r   trace entry value (lo / hi)
//   +C TRACE_CNT   r   multiplies recorded since the last start (saturates at 255)
//   +D BIST_PASS   r   bit i = vector i passed
//   +E BIST_FAIL   r   bit i = vector i failed
//   +F ERR_CODE    r   last error: 1 modulus < 2, 2 message >= modulus,
//                      3 command while busy, 4 key write while locked,
//                      5 debug access in SECURE mode, 6 deposit while running
//
// Bus side: same request/ready protocol as spec §7.1. ready is never high
// without a request (R20); rdata is 0x00 unless this block is being read.

module rsa_enclave #(
    parameter [7:0] BASE     = 8'h50,
    parameter [7:0] DBG_BASE = 8'h70
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       dbg_strap,     // mode selector: 0 secure communication, 1 debug
    input  wire [7:0] port,
    input  wire [7:0] wdata,
    input  wire       rd,
    input  wire       wr,
    output wire [7:0] rdata,
    output wire       ready,
    output wire       sel           // this block owns `port`
);

    // =====================================================================
    // Crypto registers
    // =====================================================================
    reg  [15:0] msg, n, e, d, pn, pe;
    reg         locked;
    reg         start;
    reg  [15:0] start_exp, start_mod;
    reg  [3:0]  err_code;

    // =====================================================================
    // Debug-unit registers
    // =====================================================================
    reg         halted, run_one, skip;
    reg         bp_hit, wp_hit;
    reg  [7:0]  bp_ctrl;
    reg  [4:0]  bp_bit;
    reg  [15:0] wp, dep;
    reg  [3:0]  reg_sel;
    reg  [2:0]  trace_idx, trace_wr;
    reg  [15:0] trace0, trace1, trace2, trace3, trace4, trace5, trace6, trace7;
    reg  [7:0]  trace_cnt;
    reg  [15:0] cycle_cnt;
    reg  [7:0]  mul_cnt;
    // built-in self-test
    reg         bist_running, bist_done, bist_start;
    reg  [1:0]  bist_phase;                  // 0 issue, 1 arm, 2 wait
    reg  [2:0]  bist_idx;
    reg  [7:0]  bist_pass, bist_fail;

    wire dbg_mode = dbg_strap;

    // =====================================================================
    // Engine
    // =====================================================================
    wire        eng_busy, eng_done, eng_error;
    wire [15:0] result;
    wire [1:0]  e_state;
    wire [4:0]  e_bits, e_steps;
    wire [15:0] e_res, e_b, e_ex, e_mx, e_my, e_mr, e_n;
    wire        ev_mul, ev_to_res;
    wire [15:0] ev_value;

    // BIST known-answer vectors (expected results from Python pow())
    reg  [15:0] bv_m, bv_e, bv_n, bv_r;
    reg         bv_err;
    always @(*) begin
        case (bist_idx)
            3'd0: begin bv_m = 16'h4A0B; bv_e = 16'h0011; bv_n = 16'hEC4B; bv_r = 16'h8404; bv_err = 1'b0; end // demo key A, encrypt
            3'd1: begin bv_m = 16'h8404; bv_e = 16'hA571; bv_n = 16'hEC4B; bv_r = 16'h4A0B; bv_err = 1'b0; end // demo key A, decrypt
            3'd2: begin bv_m = 16'h4A0B; bv_e = 16'h0013; bv_n = 16'hD987; bv_r = 16'h1BB1; bv_err = 1'b0; end // demo key B, encrypt
            3'd3: begin bv_m = 16'h1BB1; bv_e = 16'h662B; bv_n = 16'hD987; bv_r = 16'h4A0B; bv_err = 1'b0; end // demo key B, decrypt
            3'd4: begin bv_m = 16'h1234; bv_e = 16'hFFFF; bv_n = 16'hFFFF; bv_r = 16'hEAA6; bv_err = 1'b0; end // all exponent bits
            3'd5: begin bv_m = 16'h0002; bv_e = 16'h8000; bv_n = 16'hFFF1; bv_r = 16'h0100; bv_err = 1'b0; end // single top bit
            3'd6: begin bv_m = 16'h7FFF; bv_e = 16'h0003; bv_n = 16'h8001; bv_r = 16'h7FF9; bv_err = 1'b0; end // even-ish modulus
            default: begin bv_m = 16'h0005; bv_e = 16'h0003; bv_n = 16'h0001; bv_r = 16'h0000; bv_err = 1'b1; end // illegal modulus
        endcase
    end

    // ---- run control: breakpoint / watchpoint / halt / step ----
    wire bp_cond    = bp_ctrl[0] && eng_busy && (e_state == 2'd1) && (e_bits == bp_bit);
    wire bp_trigger = dbg_mode && bp_cond && !skip && !halted;
    wire hold       = dbg_mode && ((halted && !run_one) || bp_trigger);
    wire wp_trigger = dbg_mode && bp_ctrl[1] && ev_mul && ev_to_res && (ev_value == wp);

    wire        eng_start = start | bist_start;
    wire [15:0] eng_base  = bist_running ? bv_m : msg;
    wire [15:0] eng_exp   = bist_running ? bv_e : start_exp;
    wire [15:0] eng_mod   = bist_running ? bv_n : start_mod;

    // deposit request (decoded below) -- only honoured while halted
    reg         dep_req;

    rsa_modexp #(.W(16)) u_engine (
        .clk(clk), .rst_n(rst_n), .start(eng_start),
        .base_in(eng_base), .exp_in(eng_exp), .mod_in(eng_mod),
        .busy(eng_busy), .done(eng_done), .error(eng_error), .result(result),
        .hold(hold), .fault(dbg_mode & bp_ctrl[4]),
        .dep_en(dep_req), .dep_sel(reg_sel == 4'd3 ? 2'd1 : reg_sel == 4'd4 ? 2'd2 : 2'd3), .dep_val(dep),
        .dbg_state(e_state), .dbg_bits_left(e_bits), .dbg_steps_left(e_steps),
        .dbg_res(e_res), .dbg_b(e_b), .dbg_ex(e_ex), .dbg_mx(e_mx), .dbg_my(e_my),
        .dbg_mr(e_mr), .dbg_n(e_n), .ev_mul(ev_mul), .ev_to_res(ev_to_res), .ev_value(ev_value)
    );

    // `start` is registered, so the cycle between the CTRL write and the
    // engine picking it up already counts as busy (and not done).
    wire busy = eng_busy | eng_start | bist_running;
    wire done = eng_done & ~eng_start & ~bist_running;

    // =====================================================================
    // Bus decode
    // =====================================================================
    wire sel_crypto = (port[7:4] == BASE[7:4]);
    wire sel_dbg    = (port[7:4] == DBG_BASE[7:4]);
    assign sel = sel_crypto | sel_dbg;
    wire [3:0] reg_idx = port[3:0];
    wire       is_res  = sel_crypto && ((reg_idx == 4'hA) || (reg_idx == 4'hB));
    wire       request = sel & (rd | wr);

    // SECURE mode: a result read waits for the engine. DEBUG mode: never wait
    // (the debugger may have halted the engine). Everything else is immediate.
    assign ready = request & ~(rd & is_res & busy & ~dbg_mode);

    reg [15:0] reg_view;
    always @(*) begin
        case (reg_sel)
            4'd0:    reg_view = {14'd0, e_state};
            4'd1:    reg_view = {11'd0, e_bits};
            4'd2:    reg_view = {11'd0, e_steps};
            4'd3:    reg_view = e_res;
            4'd4:    reg_view = e_b;
            4'd5:    reg_view = e_ex;
            4'd6:    reg_view = e_mx;
            4'd7:    reg_view = e_my;
            4'd8:    reg_view = e_mr;
            4'd9:    reg_view = e_n;
            4'd10:   reg_view = cycle_cnt;
            4'd11:   reg_view = {8'd0, mul_cnt};
            4'd12:   reg_view = {12'd0, err_code};
            4'd13:   reg_view = {13'd0, bist_idx};
            default: reg_view = 16'h0000;
        endcase
    end

    reg [15:0] trace_view;
    always @(*) begin
        case (trace_idx)
            3'd0: trace_view = trace0;  3'd1: trace_view = trace1;
            3'd2: trace_view = trace2;  3'd3: trace_view = trace3;
            3'd4: trace_view = trace4;  3'd5: trace_view = trace5;
            3'd6: trace_view = trace6;  default: trace_view = trace7;
        endcase
    end

    reg [7:0] crypto_mux, dbg_mux;
    always @(*) begin
        case (reg_idx)
            4'h0:    crypto_mux = msg[7:0];
            4'h1:    crypto_mux = msg[15:8];
            4'h2:    crypto_mux = n[7:0];
            4'h3:    crypto_mux = n[15:8];
            4'h4:    crypto_mux = e[7:0];
            4'h5:    crypto_mux = e[15:8];
            4'h6:    crypto_mux = dbg_mode ? d[7:0]  : 8'h00;   // write-only in SECURE mode
            4'h7:    crypto_mux = dbg_mode ? d[15:8] : 8'h00;
            4'h9:    crypto_mux = {3'b000, dbg_mode, locked, eng_error & done, done, busy};
            4'hA:    crypto_mux = result[7:0];
            4'hB:    crypto_mux = result[15:8];
            4'hC:    crypto_mux = pn[7:0];
            4'hD:    crypto_mux = pn[15:8];
            4'hE:    crypto_mux = pe[7:0];
            4'hF:    crypto_mux = pe[15:8];
            default: crypto_mux = 8'h00;
        endcase
        case (reg_idx)
            4'h1:    dbg_mux = {bist_done, bist_running, wp_hit, bp_hit,
                                bp_ctrl[4], halted, eng_busy, dbg_mode};
            4'h2:    dbg_mux = bp_ctrl;
            4'h3:    dbg_mux = {3'b000, bp_bit};
            4'h4:    dbg_mux = wp[7:0];
            4'h5:    dbg_mux = wp[15:8];
            4'h6:    dbg_mux = {4'h0, reg_sel};
            4'h7:    dbg_mux = reg_view[7:0];
            4'h8:    dbg_mux = reg_view[15:8];
            4'h9:    dbg_mux = {5'b00000, trace_idx};
            4'hA:    dbg_mux = trace_view[7:0];
            4'hB:    dbg_mux = trace_view[15:8];
            4'hC:    dbg_mux = trace_cnt;
            4'hD:    dbg_mux = bist_pass;
            4'hE:    dbg_mux = bist_fail;
            4'hF:    dbg_mux = {4'h0, err_code};
            default: dbg_mux = 8'h00;
        endcase
    end
    assign rdata = (rd & ready) ? (sel_crypto ? crypto_mux : (dbg_mode ? dbg_mux : 8'h00)) : 8'h00;

    wire do_write  = wr & ready;
    wire crypto_wr = do_write & sel_crypto;
    wire dbg_wr    = do_write & sel_dbg & dbg_mode;

    // =====================================================================
    // Register updates
    // =====================================================================
    always @(*) dep_req = dbg_wr && (reg_idx == 4'h0) && wdata[5] && halted &&
                          (reg_sel == 4'd3 || reg_sel == 4'd4 || reg_sel == 4'd5);

    always @(posedge clk) begin
        if (!rst_n) begin
            msg <= 16'h0000;  n <= 16'h0000;  e <= 16'h0000;  d <= 16'h0000;
            pn <= 16'h0000;   pe <= 16'h0000;
            locked <= 1'b0;   start <= 1'b0;  start_exp <= 16'h0000;  start_mod <= 16'h0000;
            err_code <= 4'd0;
            halted <= 1'b0;  run_one <= 1'b0;  skip <= 1'b0;  bp_hit <= 1'b0;  wp_hit <= 1'b0;
            bp_ctrl <= 8'h00;  bp_bit <= 5'd0;  wp <= 16'h0000;  dep <= 16'h0000;
            reg_sel <= 4'd0;  trace_idx <= 3'd0;  trace_wr <= 3'd0;  trace_cnt <= 8'd0;
            trace0 <= 16'h0; trace1 <= 16'h0; trace2 <= 16'h0; trace3 <= 16'h0;
            trace4 <= 16'h0; trace5 <= 16'h0; trace6 <= 16'h0; trace7 <= 16'h0;
            cycle_cnt <= 16'd0;  mul_cnt <= 8'd0;
            bist_running <= 1'b0;  bist_done <= 1'b0;  bist_start <= 1'b0;  bist_phase <= 2'd0;
            bist_idx <= 3'd0;  bist_pass <= 8'h00;  bist_fail <= 8'h00;
        end else begin
            start      <= 1'b0;
            bist_start <= 1'b0;
            run_one    <= 1'b0;
            if (!hold) skip <= 1'b0;                  // skip lasts one running cycle

            // ---------------- crypto port writes ----------------
            if (crypto_wr) begin
                case (reg_idx)
                    4'h0: msg[7:0]  <= wdata;
                    4'h1: msg[15:8] <= wdata;
                    4'h2: if (!locked) n[7:0]  <= wdata; else err_code <= 4'd4;
                    4'h3: if (!locked) n[15:8] <= wdata; else err_code <= 4'd4;
                    4'h4: if (!locked) e[7:0]  <= wdata; else err_code <= 4'd4;
                    4'h5: if (!locked) e[15:8] <= wdata; else err_code <= 4'd4;
                    4'h6: if (!locked) d[7:0]  <= wdata; else err_code <= 4'd4;
                    4'h7: if (!locked) d[15:8] <= wdata; else err_code <= 4'd4;
                    4'h8: begin
                        if (wdata[7]) locked <= 1'b1;
                        if (wdata[1:0] != 2'b00) begin
                            if (busy) err_code <= 4'd3;
                            else begin
                                start <= 1'b1;
                                case (wdata[1:0])
                                    2'b01:   begin start_exp <= e;  start_mod <= n;  end
                                    2'b10:   begin start_exp <= d;  start_mod <= n;  end
                                    default: begin start_exp <= pe; start_mod <= pn; end
                                endcase
                                if ((wdata[1:0] == 2'b11 ? pn : n) < 16'd2)       err_code <= 4'd1;
                                else if (msg >= (wdata[1:0] == 2'b11 ? pn : n))   err_code <= 4'd2;
                            end
                        end
                    end
                    4'hC: pn[7:0]  <= wdata;
                    4'hD: pn[15:8] <= wdata;
                    4'hE: pe[7:0]  <= wdata;
                    4'hF: pe[15:8] <= wdata;
                    default: ;                   // 0x59-0x5B are read-only
                endcase
            end

            // ---------------- debug port access ----------------
            if (request && sel_dbg && !dbg_mode) err_code <= 4'd5;   // locked in SECURE mode

            if (dbg_wr) begin
                case (reg_idx)
                    4'h0: begin                                          // DBG_CTRL
                        if (wdata[0]) halted <= 1'b1;
                        if (wdata[1]) begin halted <= 1'b0; skip <= 1'b1; bp_hit <= 1'b0; wp_hit <= 1'b0; end
                        if (wdata[2] && halted) begin run_one <= 1'b1; skip <= 1'b1; end
                        if (wdata[3] && !busy) begin
                            bist_running <= 1'b1;  bist_done <= 1'b0;  bist_phase <= 2'd0;
                            bist_idx <= 3'd0;      bist_pass <= 8'h00; bist_fail <= 8'h00;
                        end
                        if (wdata[4]) begin trace_cnt <= 8'd0; trace_wr <= 3'd0; end
                        if (wdata[5] && !dep_req) err_code <= 4'd6;
                        if (wdata[6]) err_code <= 4'd0;
                    end
                    4'h2: bp_ctrl   <= wdata;
                    4'h3: bp_bit    <= wdata[4:0];
                    4'h4: wp[7:0]   <= wdata;
                    4'h5: wp[15:8]  <= wdata;
                    4'h6: reg_sel   <= wdata[3:0];
                    4'h7: dep[7:0]  <= wdata;
                    4'h8: dep[15:8] <= wdata;
                    4'h9: trace_idx <= wdata[2:0];
                    default: ;
                endcase
            end

            // ---------------- breakpoint / watchpoint ----------------
            if (bp_trigger) begin halted <= 1'b1; bp_hit <= 1'b1; end
            if (wp_trigger) begin halted <= 1'b1; wp_hit <= 1'b1; end

            // ---------------- counters and trace ----------------
            if (eng_start) begin
                cycle_cnt <= 16'd0;  mul_cnt <= 8'd0;
                trace_cnt <= 8'd0;   trace_wr <= 3'd0;
            end else begin
                if (eng_busy && !hold) cycle_cnt <= cycle_cnt + 16'd1;
                if (ev_mul) begin
                    mul_cnt <= mul_cnt + 8'd1;
                    if (trace_cnt != 8'hFF) trace_cnt <= trace_cnt + 8'd1;
                    trace_wr <= trace_wr + 3'd1;
                    case (trace_wr)
                        3'd0: trace0 <= ev_value;  3'd1: trace1 <= ev_value;
                        3'd2: trace2 <= ev_value;  3'd3: trace3 <= ev_value;
                        3'd4: trace4 <= ev_value;  3'd5: trace5 <= ev_value;
                        3'd6: trace6 <= ev_value;  default: trace7 <= ev_value;
                    endcase
                end
            end

            // ---------------- built-in self-test ----------------
            if (bist_running) begin
                case (bist_phase)
                    2'd0: begin bist_start <= 1'b1; bist_phase <= 2'd1; end     // issue vector
                    2'd1: bist_phase <= 2'd2;                                   // engine takes start
                    default: if (!eng_busy && !hold) begin                      // vector finished
                        if (bv_err ? eng_error : (!eng_error && result == bv_r))
                            bist_pass[bist_idx] <= 1'b1;
                        else
                            bist_fail[bist_idx] <= 1'b1;
                        if (bist_idx == 3'd7) begin
                            bist_running <= 1'b0;  bist_done <= 1'b1;
                        end else begin
                            bist_idx   <= bist_idx + 3'd1;
                            bist_phase <= 2'd0;
                        end
                    end
                endcase
            end
        end
    end

endmodule
