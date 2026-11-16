// tb_dsd8_cpu.v -- system-level protocol checker for the integrated core
// Owner: shared.  Spec §5.2, §7.1, §8.2, R8, R9, R11, R19, R22, R23.
//
// Runs tests/conformance/T34 (assembled into tb/data/t34_slow_echo.hex: 32
// SLOW_ECHO round trips with 0-7 random stall cycles) on dsd8_cpu +
// instr_memory + io_bus + the reference peripherals, and checks on EVERY
// cycle -- independently of the golden trace:
//   * retire never during reset, never twice for one instruction, never
//     after HLT; HLT retires exactly once; halted stays high (R8, R22)
//   * the PC never changes except in a retire cycle (one commit per instr)
//   * while an I/O request waits for io_ready: io_port, io_wdata, io_rd/io_wr
//     are stable and no register/flag/memory write happens (R11, R19)
//   * no X in any retire_* field; stale fields are zero (R23)
//   * cycles per instruction: exactly 3 for non-I/O, 3 + stall for I/O
//   * a shadow register file rebuilt only from retire_* matches the final
//     state the golden model reports (R1 3C, R2 C3, R5 C3, R6 C3, R7 00)
// Run from the repository root (make test does).

`timescale 1ns/1ps

module tb_dsd8_cpu;

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    wire [8:0]  imem_addr;  wire [15:0] imem_data;
    wire [7:0]  io_port, io_wdata, io_rdata;  wire io_rd, io_wr, io_ready;
    wire        halted, retire, retire_rf_we, retire_mem_we;
    wire [8:0]  retire_pc;  wire [15:0] retire_ir;  wire [2:0] retire_rf_addr;
    wire [7:0]  retire_rf_data, retire_mem_addr, retire_mem_data;  wire [3:0] retire_flags;
    wire [7:0]  leds, seg_value, seg_enable, periph_port, periph_wdata, periph_rdata;
    wire        periph_rd, periph_wr, periph_ready;

    dsd8_cpu uut (.clk(clk), .rst_n(rst_n), .imem_addr(imem_addr), .imem_data(imem_data),
        .io_port(io_port), .io_wdata(io_wdata), .io_rdata(io_rdata), .io_rd(io_rd), .io_wr(io_wr),
        .io_ready(io_ready), .halted(halted), .retire(retire), .retire_pc(retire_pc),
        .retire_ir(retire_ir), .retire_rf_we(retire_rf_we), .retire_rf_addr(retire_rf_addr),
        .retire_rf_data(retire_rf_data), .retire_mem_we(retire_mem_we),
        .retire_mem_addr(retire_mem_addr), .retire_mem_data(retire_mem_data),
        .retire_flags(retire_flags));
    instr_memory #(.IMAGE("tb/data/t34_slow_echo.hex")) imem (.clk(clk), .addr(imem_addr), .data(imem_data));
    io_bus iob (.clk(clk), .rst_n(rst_n), .io_port(io_port), .io_wdata(io_wdata), .io_rdata(io_rdata),
        .io_rd(io_rd), .io_wr(io_wr), .io_ready(io_ready), .switches(8'h3C), .buttons(5'h00),
        .leds(leds), .seg_value(seg_value), .seg_enable(seg_enable), .periph_port(periph_port),
        .periph_wdata(periph_wdata), .periph_rdata(periph_rdata), .periph_rd(periph_rd),
        .periph_wr(periph_wr), .periph_ready(periph_ready));
    dsd8_ref_peripherals per (.clk(clk), .rst_n(rst_n), .periph_port(periph_port),
        .periph_wdata(periph_wdata), .periph_rdata(periph_rdata), .periph_rd(periph_rd),
        .periph_wr(periph_wr), .periph_ready(periph_ready));

    integer errors = 0, cycles_since = 0, n_retired = 0, n_stall = 0, n_io = 0, max_stall = 0;
    integer cyc = 0, i;
    reg     seen_hlt = 0, waiting = 0, prev_retire = 0;
    reg [8:0]  last_pc;
    reg [7:0]  w_port, w_wdata;  reg w_rd, w_wr;
    reg [7:0]  shadow [0:7];

    task fail(input [511:0] msg);
        begin errors = errors + 1; if (errors < 20) $display("  ERROR cycle %0d pc=%03h: %0s", cyc, uut.imem_addr, msg); end
    endtask

    initial for (i = 0; i < 8; i = i + 1) shadow[i] = 8'h00;

    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (!rst_n) begin
            if (retire) fail("retire during reset");
        end else begin
            cycles_since = cycles_since + 1;
            // ---- stall checks (R11, R19) ----
            if ((io_rd | io_wr) && !io_ready) begin
                n_stall = n_stall + 1;
                if (retire || uut.rf_we || uut.mem_we || uut.flags_we || uut.pc_en) fail("commit while stalled");
                if (waiting && (io_port !== w_port || io_wdata !== w_wdata || io_rd !== w_rd || io_wr !== w_wr))
                    fail("bus not stable while waiting");
                waiting = 1; w_port = io_port; w_wdata = io_wdata; w_rd = io_rd; w_wr = io_wr;
            end else waiting = 0;
            if (io_rd && io_wr) fail("io_rd and io_wr together");
            // ---- PC only moves at a retire ----
            // (the PC changes at the edge that ENDS the retire cycle, so a
            //  change seen now must have been preceded by a retire cycle)
            if (imem_addr !== last_pc && !prev_retire && cyc > 6) fail("PC moved without retire");
            if (retire) begin
                n_retired = n_retired + 1;
                if (seen_hlt) fail("retire after HLT");
                if (^{retire_pc, retire_ir, retire_flags, retire_rf_we, retire_rf_addr, retire_rf_data,
                      retire_mem_we, retire_mem_addr, retire_mem_data} === 1'bx) fail("X in trace");
                if (!retire_rf_we && (retire_rf_addr !== 0 || retire_rf_data !== 0)) fail("stale rf fields");
                if (!retire_mem_we && (retire_mem_addr !== 0 || retire_mem_data !== 0)) fail("stale mem fields");
                if (retire_ir[15:12] == 4'hE) begin
                    n_io = n_io + 1;
                    if (cycles_since < 3 || cycles_since > 3 + 8) fail("I/O CPI out of range");
                    if (cycles_since - 3 > max_stall) max_stall = cycles_since - 3;
                end else if (cycles_since != 3) fail("non-I/O CPI is not 3");
                if (retire_ir == 16'hF000) seen_hlt = 1;
                if (retire_rf_we) shadow[retire_rf_addr] = retire_rf_data;
                cycles_since = 0;
            end
            if (seen_hlt && !retire && !halted) fail("halted not asserted after HLT");
        end
        last_pc <= imem_addr;
        prev_retire <= retire & rst_n;
    end

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1;
        wait (halted);
        repeat (30) @(posedge clk);                  // halted must stay quiet
        $display("  retired %0d instructions, %0d I/O transfers, %0d stall cycles (max %0d per transfer)",
                 n_retired, n_io, n_stall, max_stall);
        if (n_retired != 241) fail("instruction count differs from golden model (241)");
        if (n_stall == 0) fail("SLOW_ECHO never stalled -- handshake not exercised");
        if (shadow[1] !== 8'h3C || shadow[2] !== 8'hC3 || shadow[5] !== 8'hC3 ||
            shadow[6] !== 8'hC3 || shadow[7] !== 8'h00) fail("shadow register file != golden final state");
        if (!halted) fail("not halted");
        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin #5000000; $display("  TIMEOUT"); $display("TESTBENCH: FAIL (timeout)"); $finish; end

endmodule
