// tb_io_bus.v -- self-checking unit testbench for io_bus
// Owner: member C.  Spec §7.1, §7.2, R19, R20, R21.
// A small behavioural peripheral, local to this testbench, stands in for
// sim/peripherals.v so the bus is tested on its own: it answers on any port
// >= 0x20 after a programmable number of wait cycles and returns ~port.
// Checks: SWITCHES / BUTTONS read; LEDS / SEG_VALUE / SEG_ENABLE latch on
// write and only on write; unmapped low ports read 0x00 and never stall;
// io_ready never asserted without a request (R20); external requests are
// forwarded only for ports >= 0x20 and io_ready follows the peripheral;
// no local register changes during an external access.

`timescale 1ns/1ps

module tb_io_bus;

    reg        clk = 0, rst_n = 0;
    reg  [7:0] io_port = 0, io_wdata = 0;
    reg        io_rd = 0, io_wr = 0;
    wire [7:0] io_rdata;
    wire       io_ready;
    reg  [7:0] switches = 8'h3C;
    reg  [4:0] buttons  = 5'b10101;
    wire [7:0] leds, seg_value, seg_enable;
    wire [7:0] periph_port, periph_wdata;
    reg  [7:0] periph_rdata;
    wire       periph_rd, periph_wr;
    reg        periph_ready;

    integer errors = 0, k, wait_cycles, cnt, p;

    io_bus dut (.clk(clk), .rst_n(rst_n), .io_port(io_port), .io_wdata(io_wdata),
                .io_rdata(io_rdata), .io_rd(io_rd), .io_wr(io_wr), .io_ready(io_ready),
                .switches(switches), .buttons(buttons), .leds(leds),
                .seg_value(seg_value), .seg_enable(seg_enable),
                .periph_port(periph_port), .periph_wdata(periph_wdata),
                .periph_rdata(periph_rdata), .periph_rd(periph_rd),
                .periph_wr(periph_wr), .periph_ready(periph_ready));

    always #5 clk = ~clk;

    // ---- behavioural external peripheral: ready after wait_cycles ----
    always @(posedge clk) begin
        if (!(periph_rd | periph_wr)) cnt <= 0;
        else if (cnt < wait_cycles)   cnt <= cnt + 1;
    end
    always @(*) begin
        periph_ready = (periph_rd | periph_wr) && (cnt >= wait_cycles);
        periph_rdata = ~periph_port;
    end

    task fail(input [511:0] msg);
        begin errors = errors + 1; if (errors < 20) $display("  MISMATCH port=%02h: %0s", io_port, msg); end
    endtask

    // one complete local read, must finish in the request cycle
    task local_read(input [7:0] port, input [7:0] expected);
        begin
            @(negedge clk); io_port = port; io_rd = 1; #1;
            if (io_ready !== 1'b1) fail("local read stalled");
            if (io_rdata !== expected) fail("local read data");
            if (periph_rd !== 1'b0) fail("local read forwarded");
            @(negedge clk); io_rd = 0;
        end
    endtask

    task local_write(input [7:0] port, input [7:0] data);
        begin
            @(negedge clk); io_port = port; io_wdata = data; io_wr = 1; #1;
            if (io_ready !== 1'b1) fail("local write stalled");
            if (periph_wr !== 1'b0) fail("local write forwarded");
            @(negedge clk); io_wr = 0;
        end
    endtask

    initial begin
        wait_cycles = 0; cnt = 0;
        @(negedge clk); @(negedge clk); rst_n = 1;
        if (leds !== 0 || seg_value !== 0 || seg_enable !== 0) fail("reset values");

        // R20: no request -> no ready, for every port
        for (p = 0; p < 256; p = p + 1) begin
            io_port = p; #1;
            if (io_ready !== 1'b0) fail("io_ready without request");
        end

        local_read(8'h00, 8'h3C);                    // SWITCHES
        local_read(8'h01, 8'h15);                    // BUTTONS {000, 10101}
        local_read(8'h02, 8'h00);                    // LEDS is write-only
        local_read(8'h05, 8'h00);                    // unmapped
        local_read(8'h1F, 8'h00);

        local_write(8'h02, 8'hA5);
        if (leds !== 8'hA5) fail("LEDS not latched");
        local_write(8'h10, 8'h3E);
        if (seg_value !== 8'h3E) fail("SEG_VALUE not latched");
        local_write(8'h11, 8'h0F);
        if (seg_enable !== 8'h0F) fail("SEG_ENABLE not latched");
        local_write(8'h03, 8'hFF);                   // unmapped: discarded
        local_write(8'h00, 8'hFF);                   // read-only port: discarded
        if (leds !== 8'hA5 || seg_value !== 8'h3E || seg_enable !== 8'h0F) fail("unmapped write changed a register");
        // a READ of LEDS must not write it
        @(negedge clk); io_port = 8'h02; io_wdata = 8'h00; io_rd = 1; @(negedge clk); io_rd = 0;
        if (leds !== 8'hA5) fail("read of LEDS changed it");

        // external ports with 0..7 wait cycles: forwarded, ready follows peripheral
        for (k = 0; k < 16; k = k + 1) begin
            wait_cycles = k % 8;
            @(negedge clk); io_port = 8'h20 + k * 13; io_wdata = k; io_rd = k[0]; io_wr = ~k[0];
            #1;
            if (periph_rd !== io_rd || periph_wr !== io_wr) fail("external request not forwarded");
            if (periph_port !== io_port || periph_wdata !== io_wdata) fail("external port/data not forwarded");
            p = 0;
            while (io_ready !== 1'b1 && p < 20) begin
                if (leds !== 8'hA5) fail("LEDs changed during external access");
                @(negedge clk); p = p + 1; #1;
            end
            if (p !== wait_cycles) fail("io_ready did not follow peripheral");
            if (io_rd && io_rdata !== ~io_port) fail("external read data");
            @(negedge clk); io_rd = 0; io_wr = 0;
        end

        // reset clears the output registers
        @(negedge clk); rst_n = 0; @(negedge clk); rst_n = 1;
        if (leds !== 0 || seg_value !== 0 || seg_enable !== 0) fail("second reset");

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
