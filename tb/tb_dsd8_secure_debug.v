// tb_dsd8_secure_debug.v -- the two-processor system with the mode selector
// set to DEBUG
// Owner: shared (security-enclave extension).
// BTNU is held while reset is released, so both enclaves boot in DEBUG mode.
// Each processor then runs the debug session from tests/secure/debug_session.inc
// on its own enclave (self-test, breakpoint, single-step, resume, trace,
// watchpoint, fault injection) and shows one bit per passed check.
// Checks: B LEDs = FF and 7-seg "dB"; A LEDs = 7F (its 7 visible bits);
// both halt; no byte ever crosses the mailbox (no secure communication in
// DEBUG mode); every debug check in the session passed on BOTH processors.
// Run from the repository root (make test does).

`timescale 1ns/1ps

module tb_dsd8_secure_debug;

    reg        clk = 0, rst_n = 0;
    reg  [4:0] buttons = 5'b10000;          // BTNU held = DEBUG mode selected
    always #5 clk = ~clk;

    wire [7:0] leds;  wire [6:0] seg, leds_a;  wire [3:0] an;  wire halted;

    dsd8_secure_top #(.IMAGE_A("tb/data/enclave_server.hex"), .IMAGE_B("tb/data/enclave_client.hex"),
                      .CLK_DIV(2), .DEBOUNCE_BITS(3), .REFRESH_BITS(4))
        dut (.clk(clk), .rst_n(rst_n), .switches(8'h71), .switches_b(7'h2B), .buttons(buttons),
             .leds(leds), .seg(seg), .an(an), .leds_a(leds_a), .halted(halted));

    integer errors = 0, mailbox_bytes = 0, t = 0;

    task fail(input [511:0] msg);
        begin errors = errors + 1; $display("  ERROR: %0s", msg); end
    endtask

    always @(posedge dut.cpu_clk) if (dut.cpu_rst_n) begin
        if ((dut.pwr_a && dut.pport_a == 8'h60) || (dut.pwr_b && dut.pport_b == 8'h60))
            mailbox_bytes = mailbox_bytes + 1;
    end

    initial begin
        repeat (20) @(posedge clk);
        rst_n = 1;                                     // reset released with BTNU held
        repeat (40) @(posedge clk);
        buttons = 5'b00000;                            // mode already latched
        while (!halted && t < 2000000) begin @(posedge clk); t = t + 1; end
        repeat (100) @(posedge clk);

        $display("  mode selector = %0s", dut.debug_mode ? "DEBUG" : "SECURE");
        $display("  B debug checks passed: %b (LEDs %02h), 7-seg %02h", leds, leds, dut.seg_value_b);
        $display("  A debug checks passed: %b (all 8: %02h)", leds_a, dut.leds_a_full);
        if (dut.debug_mode !== 1'b1)        fail("mode selector did not latch DEBUG");
        if (!halted)                        fail("debug sessions did not finish");
        if (leds !== 8'hFF)                 fail("processor B: not every debug check passed");
        if (dut.leds_a_full !== 8'hFF)      fail("processor A: not every debug check passed");
        if (dut.seg_value_b !== 8'hDB)      fail("7-seg should show dB");
        if (mailbox_bytes != 0)             fail("mailbox used in DEBUG mode");
        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
