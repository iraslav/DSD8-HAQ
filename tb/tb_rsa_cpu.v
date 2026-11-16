// tb_rsa_cpu.v -- one DSD-8 driving one rsa_enclave through io_bus
// Owner: shared (security-enclave extension).
// Runs tests/secure/S01_enclave_selftest.asm (tb/data/S01_enclave_selftest.hex):
// nine checks executed BY THE PROCESSOR (program key, read-back, write-only
// private key, encrypt, decrypt, wrong key, m >= n, lock). The program shows
// 0x01 on the LEDs on success or 0xE1..0xE9 = the failing check.
// The testbench also checks, cycle by cycle, that the CPU really waits on the
// enclave (io_ready low during RES reads) and that a read of D_LO / D_HI
// never returns anything but 0x00.
// Run from the repository root (make test does).

`timescale 1ns/1ps

module tb_rsa_cpu;

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    wire [8:0]  imem_addr;  wire [15:0] imem_data;
    wire [7:0]  io_port, io_wdata, io_rdata;  wire io_rd, io_wr, io_ready;
    wire        halted;
    wire [7:0]  leds, seg_value, seg_enable, pport, pwdata, prdata;
    wire        prd, pwr, pready, enc_ready, enc_sel;
    wire [7:0]  enc_rdata;

    /* trace outputs, unused here */
    wire ret, rfwe, memwe; wire [8:0] rpc; wire [15:0] rir; wire [2:0] rfa;
    wire [7:0] rfd, mema, memd; wire [3:0] rfl;

    dsd8_cpu cpu (.clk(clk), .rst_n(rst_n), .imem_addr(imem_addr), .imem_data(imem_data),
        .io_port(io_port), .io_wdata(io_wdata), .io_rdata(io_rdata), .io_rd(io_rd), .io_wr(io_wr),
        .io_ready(io_ready), .halted(halted), .retire(ret), .retire_pc(rpc), .retire_ir(rir),
        .retire_rf_we(rfwe), .retire_rf_addr(rfa), .retire_rf_data(rfd), .retire_mem_we(memwe),
        .retire_mem_addr(mema), .retire_mem_data(memd), .retire_flags(rfl));
    instr_memory #(.IMAGE("tb/data/S01_enclave_selftest.hex")) imem (.clk(clk), .addr(imem_addr), .data(imem_data));
    io_bus iob (.clk(clk), .rst_n(rst_n), .io_port(io_port), .io_wdata(io_wdata), .io_rdata(io_rdata),
        .io_rd(io_rd), .io_wr(io_wr), .io_ready(io_ready), .switches(8'h00), .buttons(5'h00),
        .leds(leds), .seg_value(seg_value), .seg_enable(seg_enable), .periph_port(pport),
        .periph_wdata(pwdata), .periph_rdata(prdata), .periph_rd(prd), .periph_wr(pwr),
        .periph_ready(pready));
    rsa_enclave #(.BASE(8'h50)) enc (.clk(clk), .rst_n(rst_n), .dbg_strap(1'b0), .port(pport), .wdata(pwdata),
        .rd(prd), .wr(pwr), .rdata(enc_rdata), .ready(enc_ready), .sel(enc_sel));

    assign prdata = enc_rdata;
    assign pready = enc_ready | ((prd | pwr) & ~enc_sel);

    integer errors = 0, stall_cycles = 0, cyc = 0;

    always @(posedge clk) if (rst_n) begin
        cyc = cyc + 1;
        if ((io_rd | io_wr) && !io_ready) stall_cycles = stall_cycles + 1;
        if (io_rd && io_ready && (io_port == 8'h56 || io_port == 8'h57) && io_rdata !== 8'h00) begin
            errors = errors + 1; $display("  ERROR: private key byte leaked on port %02h: %02h", io_port, io_rdata);
        end
    end

    initial begin
        repeat (4) @(posedge clk); rst_n = 1;
        fork : run
            begin wait (halted); disable run; end
            begin #2000000; disable run; end
        join
        repeat (5) @(posedge clk);
        $display("  self-test LEDs = %02h after %0d cycles, %0d cycles stalled waiting for the enclave",
                 leds, cyc, stall_cycles);
        if (!halted) begin errors = errors + 1; $display("  ERROR: program did not halt"); end
        if (leds !== 8'h01) begin errors = errors + 1; $display("  ERROR: self-test failed at check %02h", leds); end
        if (stall_cycles == 0) begin errors = errors + 1; $display("  ERROR: CPU never waited on the enclave"); end
        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
