// dsd8_top.v -- system top level
// Owner: shared (whole team integrates this together)
// Spec: Section 5.1. Port list is FROZEN -- do not rename or resize.
//
// Board build (demonstration deliverable, spec §9.3 item 5). Not used by
// the conformance harness, which instantiates dsd8_cpu directly.
//   * CLK_DIV: the core runs from clk divided by CLK_DIV (default 4, i.e.
//     25 MHz from a 100 MHz board clock). In this multi-cycle design the
//     PC -> IMEM -> decoder -> register file -> ALU -> write-back path is
//     still one combinational path between registers, so it is given a
//     slower clock rather than a multicycle constraint (doc/design_report.md
//     decision D7). fpga/basys3.xdc declares the generated clock.
//   * rst_n is synchronised (two flops) before use; the board-level reset
//     is a slide switch (see fpga/basys3.xdc).
//   * Ports >= 0x20 (UART, timer, SLOW_ECHO) exist only as simulation
//     models (sim/peripherals.v); on the board they behave as unmapped
//     ports: read 0x00, writes discarded, never stall.

module dsd8_top #(
    parameter        IMAGE        = "program.hex",  // program for the demo
    parameter integer CLK_DIV     = 4,              // core clock = clk / CLK_DIV (even, >= 2)
    parameter integer DEBOUNCE_BITS = 20,
    parameter integer REFRESH_BITS  = 17
) (
    input  wire       clk,
    input  wire       rst_n,       // synchronous, active low
    input  wire [7:0] switches,    // board slide switches  -> port 0x00
    input  wire [4:0] buttons,     // {btnU,btnD,btnL,btnR,btnC} -> port 0x01
    output wire [7:0] leds,        // board LEDs             <- port 0x02
    output wire [6:0] seg,         // seven-segment segments <- port 0x10
    output wire [3:0] an,          // seven-segment digit enables
    output wire       halted       // asserted after HLT retires
);

    // ---- reset synchroniser (board clock domain) ----
    reg rst_s0 = 1'b0, rst_s1 = 1'b0;
    always @(posedge clk) begin
        rst_s0 <= rst_n;
        rst_s1 <= rst_s0;
    end
    wire rst_board_n = rst_s1;

    // ---- core clock: clk / CLK_DIV ----
    // (sliced from a wire, not a parameter: older Icarus versions cannot
    //  part-select a parameter)
    wire [31:0] half_m1_w = CLK_DIV / 2 - 1;
    wire [15:0] HALF_M1   = half_m1_w[15:0];
    // The divider is deliberately NOT reset: the core clock must keep
    // running while reset is asserted, or the core never sees rst_n low on
    // a core-clock edge (R7) -- doc/bug_log.md #6. Initial values are
    // honoured by simulation and by FPGA configuration.
    reg [15:0] div_cnt = 16'd0;
    reg        cpu_clk = 1'b0;
    always @(posedge clk) begin
        if (div_cnt == HALF_M1) begin
            div_cnt <= 16'd0;
            cpu_clk <= ~cpu_clk;
        end else begin
            div_cnt <= div_cnt + 16'd1;
        end
    end
    // reset into the core clock domain (held for several core cycles, R7)
    reg cpu_rst_s0 = 1'b0, cpu_rst_n = 1'b0;
    always @(posedge cpu_clk) begin
        cpu_rst_s0 <= rst_board_n;
        cpu_rst_n  <= cpu_rst_s0;
    end

    // ---- buttons: synchronised and debounced (port 0x01 is "already debounced") ----
    wire [4:0] buttons_clean;
    btn_debounce #(.WIDTH(5), .CNT_BITS(DEBOUNCE_BITS)) u_deb (
        .clk(clk), .rst_n(rst_board_n), .raw(buttons), .clean(buttons_clean));

    // ---- core, program ROM, I/O bus ----
    wire [8:0]  imem_addr;
    wire [15:0] imem_data;
    wire [7:0]  io_port, io_wdata, io_rdata;
    wire        io_rd, io_wr, io_ready;
    wire [7:0]  seg_value, seg_enable;
    wire [7:0]  periph_port, periph_wdata;
    wire        periph_rd, periph_wr;

    // trace outputs are for simulation only; unused on the board
    /* verilator lint_off UNUSEDSIGNAL */
    wire        retire, retire_rf_we, retire_mem_we;
    wire [8:0]  retire_pc;
    wire [15:0] retire_ir;
    wire [2:0]  retire_rf_addr;
    wire [7:0]  retire_rf_data, retire_mem_addr, retire_mem_data;
    wire [3:0]  retire_flags;
    /* verilator lint_on UNUSEDSIGNAL */

    dsd8_cpu u_cpu (
        .clk             (cpu_clk),
        .rst_n           (cpu_rst_n),
        .imem_addr       (imem_addr),
        .imem_data       (imem_data),
        .io_port         (io_port),
        .io_wdata        (io_wdata),
        .io_rdata        (io_rdata),
        .io_rd           (io_rd),
        .io_wr           (io_wr),
        .io_ready        (io_ready),
        .halted          (halted),
        .retire          (retire),
        .retire_pc       (retire_pc),
        .retire_ir       (retire_ir),
        .retire_rf_we    (retire_rf_we),
        .retire_rf_addr  (retire_rf_addr),
        .retire_rf_data  (retire_rf_data),
        .retire_mem_we   (retire_mem_we),
        .retire_mem_addr (retire_mem_addr),
        .retire_mem_data (retire_mem_data),
        .retire_flags    (retire_flags)
    );

    instr_memory #(.IMAGE(IMAGE)) u_imem (
        .clk  (cpu_clk),
        .addr (imem_addr),
        .data (imem_data)
    );

    io_bus u_io (
        .clk          (cpu_clk),
        .rst_n        (cpu_rst_n),
        .io_port      (io_port),
        .io_wdata     (io_wdata),
        .io_rdata     (io_rdata),
        .io_rd        (io_rd),
        .io_wr        (io_wr),
        .io_ready     (io_ready),
        .switches     (switches),
        .buttons      (buttons_clean),
        .leds         (leds),
        .seg_value    (seg_value),
        .seg_enable   (seg_enable),
        .periph_port  (periph_port),
        .periph_wdata (periph_wdata),
        .periph_rdata (8'h00),                  // no UART/timer/SLOW_ECHO on the board
        .periph_rd    (periph_rd),
        .periph_wr    (periph_wr),
        .periph_ready (periph_rd | periph_wr)   // complete immediately, like an unmapped port
    );

    seg7_driver #(.REFRESH_BITS(REFRESH_BITS)) u_seg (
        .clk    (clk),
        .rst_n  (rst_board_n),
        .value  (seg_value),
        .enable (seg_enable),
        .seg    (seg),
        .an     (an)
    );

    /* verilator lint_off UNUSEDSIGNAL */
    wire unused_periph = &{1'b0, periph_port, periph_wdata, half_m1_w[31:16]};
    /* verilator lint_on UNUSEDSIGNAL */

    // verilator lint_off UNUSEDSIGNAL
    wire unused_top = &{1'b0, clk, rst_n, switches, buttons};
    // verilator lint_on UNUSEDSIGNAL

endmodule
