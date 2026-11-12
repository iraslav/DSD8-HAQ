// tb_dsd8_top.v -- board top-level smoke test (demonstration deliverable)
// Owner: shared.  Spec §5.1, §9.3 item 5.
// Three dsd8_top instances, scaled for simulation (CLK_DIV 2, short
// debounce/refresh counters):
//   A  runs T36 multiply  -> LEDs must show 0x5B and halted must rise
//   B  runs T38 bubble sort -> LEDs 0x01, 7-seg digit 0 shows '9', other
//      digits dark (SEG_ENABLE = 0x01)
//   C  runs a buttons->LEDs echo loop: a 2-cycle glitch must be filtered by
//      the debouncer, a held press must appear on the LEDs
// Run from the repository root (make test does).

`timescale 1ns/1ps

module tb_dsd8_top;

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    reg [4:0] btn = 5'b00000;

    wire [7:0] leds_a, leds_b, leds_c;
    wire [6:0] seg_a, seg_b, seg_c;
    wire [3:0] an_a, an_b, an_c;
    wire       halt_a, halt_b, halt_c;
    integer errors = 0, k, seen_digit0;

    dsd8_top #(.IMAGE("tb/data/t36_multiply.hex"), .CLK_DIV(2), .DEBOUNCE_BITS(3), .REFRESH_BITS(4))
        A (.clk(clk), .rst_n(rst_n), .switches(8'h00), .buttons(5'h00),
           .leds(leds_a), .seg(seg_a), .an(an_a), .halted(halt_a));
    dsd8_top #(.IMAGE("tb/data/t38_bubble_sort.hex"), .CLK_DIV(2), .DEBOUNCE_BITS(3), .REFRESH_BITS(4))
        B (.clk(clk), .rst_n(rst_n), .switches(8'h00), .buttons(5'h00),
           .leds(leds_b), .seg(seg_b), .an(an_b), .halted(halt_b));
    dsd8_top #(.IMAGE("tb/data/buttons_echo.hex"), .CLK_DIV(2), .DEBOUNCE_BITS(3), .REFRESH_BITS(4))
        C (.clk(clk), .rst_n(rst_n), .switches(8'h00), .buttons(btn),
           .leds(leds_c), .seg(seg_c), .an(an_c), .halted(halt_c));

    task fail(input [511:0] msg);
        begin errors = errors + 1; $display("  ERROR: %0s", msg); end
    endtask

    initial begin
        repeat (20) @(posedge clk);
        rst_n = 1;
        // ---- A: multiply ----
        fork : wait_a
            begin wait (halt_a); disable wait_a; end
            begin #2000000; disable wait_a; end
        join
        if (!halt_a) fail("A (multiply) did not halt");
        if (leds_a !== 8'h5B) fail("A: LEDs != 0x5B");
        if (an_a !== 4'b1111) fail("A: 7-seg should be blank (SEG_ENABLE never written)");
        // ---- B: bubble sort ----
        fork : wait_b
            begin wait (halt_b); disable wait_b; end
            begin #4000000; disable wait_b; end
        join
        if (!halt_b) fail("B (bubble sort) did not halt");
        if (leds_b !== 8'h01) fail("B: LEDs != 0x01 (smallest element)");
        seen_digit0 = 0;
        for (k = 0; k < 200; k = k + 1) begin
            @(posedge clk); #1;
            if (an_b == 4'b1110) begin
                seen_digit0 = 1;
                if (seg_b !== 7'b0010000) fail("B: digit 0 does not show 9");
            end else if (an_b !== 4'b1111) fail("B: a disabled digit is lit");
        end
        if (!seen_digit0) fail("B: digit 0 never driven");
        // ---- C: debounce ----
        @(posedge clk); btn = 5'b00001; @(posedge clk); @(posedge clk); btn = 5'b00000;   // glitch
        repeat (200) @(posedge clk);
        if (leds_c !== 8'h00) fail("C: glitch reached the LEDs");
        btn = 5'b10010;                                                                    // held press
        repeat (200) @(posedge clk);
        if (leds_c !== 8'h12) fail("C: held buttons not echoed to LEDs");
        $display("  top-level: A LEDs=%02h halted=%b | B LEDs=%02h | C LEDs=%02h", leds_a, halt_a, leds_b, leds_c);
        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
