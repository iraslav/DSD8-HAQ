// dsd8_secure_top.v -- two DSD-8 processors with a secure (RSA-encrypted) channel
// Owner: shared (security-enclave extension). The frozen dsd8_top and every
// frozen core module are unchanged; this is a second, separate board top.
//
// Each processor has its own RSA enclave holding its own key pair (the
// private exponent is write-only and its low byte is programmed from that
// processor's switches) plus the other processor's public key. They talk
// through a byte mailbox:
//   1. exchange public keys (the only plaintext ever sent)
//   2. mutual key check: B -> A Enc_A(challenge), A -> B Enc_B(Dec_A(..)),
//      B checks, B -> A Enc_A(verdict). Until both private keys match their
//      public keys the channel stays closed and B shows the mismatch; BTNC
//      starts a new attempt.
//   3. channel open: A sends data encrypted for B, B decrypts it; B sends
//      data encrypted for A, A decrypts it. Then both halt.
//   (programs: tests/secure/enclave_server.asm = A, enclave_client.asm = B)
//
// MODE SELECTOR: both enclaves get the same boot strap `debug_mode`.
//   secure communication mode -> the protocol above
//   debug mode                -> each processor runs a debug session on its
//                                own enclave (BIST, breakpoints, single-step,
//                                watchpoint, register inspection, trace, fault
//                                injection) and reports the results
//
//   Peripheral side of each core's io_bus (ports >= 0x20):
//       0x50-0x5F  that core's rsa_enclave
//       0x60-0x63  that core's mailbox endpoint
//       others     unmapped: read 0x00, writes discarded, never stall
//
//   Board (Basys 3, fpga/basys3_secure.xdc):
//       switches   SW0-SW7  -> core A port 0x00 (A's private-key byte)
//       switches_b SW8-SW14 -> core B port 0x00 (B's private-key byte, 7 bits)
//       buttons    -> both cores, port 0x01 (debounced); BTNC = retry
//       BTNU held while SW15 (reset) goes up -> DEBUG mode (mode selector)
//       leds       <- core B LEDs  (failed attempts; 0xFF = channel open)
//       seg / an   <- core B 7-seg ("EE" = keys do not match; data from A)
//       leds_a     <- core A LEDs[6:0] (rounds served, then data from B)
//       halted     =  both cores halted

module dsd8_secure_top #(
    parameter         IMAGE_A       = "enclave_server.hex",
    parameter         IMAGE_B       = "enclave_client.hex",
    parameter integer CLK_DIV       = 4,
    parameter integer DEBOUNCE_BITS = 20,
    parameter integer REFRESH_BITS  = 17
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] switches,      // core A
    input  wire [6:0] switches_b,    // core B
    input  wire [4:0] buttons,
    output wire [7:0] leds,
    output wire [6:0] seg,
    output wire [3:0] an,
    output wire [6:0] leds_a,
    output wire       halted
);

    // ---- reset synchroniser and core clock (same scheme as dsd8_top, D7) ----
    reg rst_s0 = 1'b0, rst_s1 = 1'b0;
    always @(posedge clk) begin
        rst_s0 <= rst_n;
        rst_s1 <= rst_s0;
    end
    wire rst_board_n = rst_s1;

    wire [31:0] half_m1_w = CLK_DIV / 2 - 1;
    wire [15:0] half_m1   = half_m1_w[15:0];
    reg  [15:0] div_cnt = 16'd0;
    reg         cpu_clk = 1'b0;
    always @(posedge clk) begin                 // free-running: see bug log #6
        if (div_cnt == half_m1) begin
            div_cnt <= 16'd0;
            cpu_clk <= ~cpu_clk;
        end else begin
            div_cnt <= div_cnt + 16'd1;
        end
    end
    reg cpu_rst_s0 = 1'b0, cpu_rst_n = 1'b0;
    always @(posedge cpu_clk) begin
        cpu_rst_s0 <= rst_board_n;
        cpu_rst_n  <= cpu_rst_s0;
    end

    // ---- MODE SELECTOR (boot strap): hold BTNU while reset is released ----
    // Sampled continuously while the board is in reset and frozen when reset
    // is released, so the mode can only change through a reset -- which also
    // clears every key in both enclaves.  0 = secure communication, 1 = debug.
    reg btnu_s0 = 1'b0, btnu_s1 = 1'b0, debug_mode = 1'b0;
    always @(posedge clk) begin
        btnu_s0 <= buttons[4];
        btnu_s1 <= btnu_s0;
        if (!rst_board_n) debug_mode <= btnu_s1;
    end

    wire [4:0] buttons_clean;
    btn_debounce #(.WIDTH(5), .CNT_BITS(DEBOUNCE_BITS)) u_deb (
        .clk(clk), .rst_n(rst_board_n), .raw(buttons), .clean(buttons_clean));

    // =====================================================================
    // Core A and core B: identical wiring, different programs
    // =====================================================================
    wire [8:0]  imem_addr_a, imem_addr_b;
    wire [15:0] imem_data_a, imem_data_b;
    wire [7:0]  io_port_a, io_wdata_a, io_rdata_a, io_port_b, io_wdata_b, io_rdata_b;
    wire        io_rd_a, io_wr_a, io_ready_a, io_rd_b, io_wr_b, io_ready_b;
    wire        halted_a, halted_b;
    wire [7:0]  leds_a_full, leds_b, seg_value_b, seg_enable_b;
    wire [7:0]  pport_a, pwdata_a, prdata_a, pport_b, pwdata_b, prdata_b;
    wire        prd_a, pwr_a, pready_a, prd_b, pwr_b, pready_b;

    /* verilator lint_off UNUSEDSIGNAL */
    // trace outputs and core A's display are unused on the board
    wire        ret_a, ret_rfwe_a, ret_memwe_a, ret_b, ret_rfwe_b, ret_memwe_b;
    wire [8:0]  ret_pc_a, ret_pc_b;
    wire [15:0] ret_ir_a, ret_ir_b;
    wire [2:0]  ret_rfaddr_a, ret_rfaddr_b;
    wire [7:0]  ret_rfdata_a, ret_memaddr_a, ret_memdata_a, ret_rfdata_b, ret_memaddr_b, ret_memdata_b;
    wire [3:0]  ret_flags_a, ret_flags_b;
    wire [7:0]  seg_value_a, seg_enable_a;
    /* verilator lint_on UNUSEDSIGNAL */

    dsd8_cpu u_cpu_a (
        .clk(cpu_clk), .rst_n(cpu_rst_n),
        .imem_addr(imem_addr_a), .imem_data(imem_data_a),
        .io_port(io_port_a), .io_wdata(io_wdata_a), .io_rdata(io_rdata_a),
        .io_rd(io_rd_a), .io_wr(io_wr_a), .io_ready(io_ready_a),
        .halted(halted_a), .retire(ret_a), .retire_pc(ret_pc_a), .retire_ir(ret_ir_a),
        .retire_rf_we(ret_rfwe_a), .retire_rf_addr(ret_rfaddr_a), .retire_rf_data(ret_rfdata_a),
        .retire_mem_we(ret_memwe_a), .retire_mem_addr(ret_memaddr_a), .retire_mem_data(ret_memdata_a),
        .retire_flags(ret_flags_a));

    dsd8_cpu u_cpu_b (
        .clk(cpu_clk), .rst_n(cpu_rst_n),
        .imem_addr(imem_addr_b), .imem_data(imem_data_b),
        .io_port(io_port_b), .io_wdata(io_wdata_b), .io_rdata(io_rdata_b),
        .io_rd(io_rd_b), .io_wr(io_wr_b), .io_ready(io_ready_b),
        .halted(halted_b), .retire(ret_b), .retire_pc(ret_pc_b), .retire_ir(ret_ir_b),
        .retire_rf_we(ret_rfwe_b), .retire_rf_addr(ret_rfaddr_b), .retire_rf_data(ret_rfdata_b),
        .retire_mem_we(ret_memwe_b), .retire_mem_addr(ret_memaddr_b), .retire_mem_data(ret_memdata_b),
        .retire_flags(ret_flags_b));

    instr_memory #(.IMAGE(IMAGE_A)) u_imem_a (.clk(cpu_clk), .addr(imem_addr_a), .data(imem_data_a));
    instr_memory #(.IMAGE(IMAGE_B)) u_imem_b (.clk(cpu_clk), .addr(imem_addr_b), .data(imem_data_b));

    io_bus u_io_a (
        .clk(cpu_clk), .rst_n(cpu_rst_n),
        .io_port(io_port_a), .io_wdata(io_wdata_a), .io_rdata(io_rdata_a),
        .io_rd(io_rd_a), .io_wr(io_wr_a), .io_ready(io_ready_a),
        .switches(switches), .buttons(buttons_clean),
        .leds(leds_a_full), .seg_value(seg_value_a), .seg_enable(seg_enable_a),
        .periph_port(pport_a), .periph_wdata(pwdata_a), .periph_rdata(prdata_a),
        .periph_rd(prd_a), .periph_wr(pwr_a), .periph_ready(pready_a));

    io_bus u_io_b (
        .clk(cpu_clk), .rst_n(cpu_rst_n),
        .io_port(io_port_b), .io_wdata(io_wdata_b), .io_rdata(io_rdata_b),
        .io_rd(io_rd_b), .io_wr(io_wr_b), .io_ready(io_ready_b),
        .switches({1'b0, switches_b}), .buttons(buttons_clean),
        .leds(leds_b), .seg_value(seg_value_b), .seg_enable(seg_enable_b),
        .periph_port(pport_b), .periph_wdata(pwdata_b), .periph_rdata(prdata_b),
        .periph_rd(prd_b), .periph_wr(pwr_b), .periph_ready(pready_b));

    // ---- peripherals: one enclave per core, one shared mailbox ----
    wire [7:0] enc_rdata_a, enc_rdata_b, mb_rdata_a, mb_rdata_b;
    wire       enc_ready_a, enc_ready_b, mb_ready_a, mb_ready_b;
    wire       enc_sel_a, enc_sel_b, mb_sel_a, mb_sel_b;

    rsa_enclave #(.BASE(8'h50), .DBG_BASE(8'h70)) u_enc_a (
        .clk(cpu_clk), .rst_n(cpu_rst_n), .dbg_strap(debug_mode), .port(pport_a), .wdata(pwdata_a),
        .rd(prd_a), .wr(pwr_a), .rdata(enc_rdata_a), .ready(enc_ready_a), .sel(enc_sel_a));

    rsa_enclave #(.BASE(8'h50), .DBG_BASE(8'h70)) u_enc_b (
        .clk(cpu_clk), .rst_n(cpu_rst_n), .dbg_strap(debug_mode), .port(pport_b), .wdata(pwdata_b),
        .rd(prd_b), .wr(pwr_b), .rdata(enc_rdata_b), .ready(enc_ready_b), .sel(enc_sel_b));

    cpu_mailbox #(.BASE(8'h60)) u_mbox (
        .clk(cpu_clk), .rst_n(cpu_rst_n),
        .a_port(pport_a), .a_wdata(pwdata_a), .a_rd(prd_a), .a_wr(pwr_a),
        .a_rdata(mb_rdata_a), .a_ready(mb_ready_a), .a_sel(mb_sel_a),
        .b_port(pport_b), .b_wdata(pwdata_b), .b_rd(prd_b), .b_wr(pwr_b),
        .b_rdata(mb_rdata_b), .b_ready(mb_ready_b), .b_sel(mb_sel_b));

    // unmapped external ports complete immediately with 0x00 (R21)
    assign prdata_a = enc_rdata_a | mb_rdata_a;
    assign prdata_b = enc_rdata_b | mb_rdata_b;
    assign pready_a = enc_ready_a | mb_ready_a | ((prd_a | pwr_a) & ~enc_sel_a & ~mb_sel_a);
    assign pready_b = enc_ready_b | mb_ready_b | ((prd_b | pwr_b) & ~enc_sel_b & ~mb_sel_b);

    // ---- board outputs ----
    assign leds   = leds_b;
    assign leds_a = leds_a_full[6:0];
    assign halted = halted_a & halted_b;

    seg7_driver #(.REFRESH_BITS(REFRESH_BITS)) u_seg (
        .clk(clk), .rst_n(rst_board_n), .value(seg_value_b), .enable(seg_enable_b),
        .seg(seg), .an(an));

    /* verilator lint_off UNUSEDSIGNAL */
    wire unused_sec = &{1'b0, half_m1_w[31:16], leds_a_full[7]};
    /* verilator lint_on UNUSEDSIGNAL */

endmodule
