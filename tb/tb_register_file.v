// tb_register_file.v -- self-checking unit testbench for register_file
// Owner: member B.  Spec §5.6, R1, R2, R14.
//
// Checks: (1) reset clears all eight registers; (2) every register is
// independently writable and readable on BOTH ports (R1, R2 -- R0 is not
// special); (3) we=0 writes nothing; (4) R14 -- a same-cycle write/read
// returns the OLD value, the new value is visible from the next cycle;
// (5) 2000 random write/read cycles against a shadow array; (6) a second
// reset in mid-run clears everything again.

`timescale 1ns/1ps

module tb_register_file;

    reg        clk = 0, rst_n = 0;
    reg  [2:0] ra1 = 0, ra2 = 0, wa = 0;
    reg        we = 0;
    reg  [7:0] wd = 0;
    wire [7:0] rd1, rd2;

    reg  [7:0] shadow [0:7];
    integer errors = 0, i, k;

    register_file dut (.clk(clk), .rst_n(rst_n), .ra1(ra1), .ra2(ra2),
                       .rd1(rd1), .rd2(rd2), .we(we), .wa(wa), .wd(wd));

    always #5 clk = ~clk;

    task expect_read(input [2:0] a1, input [2:0] a2, input [7:0] e1, input [7:0] e2,
                     input [127:0] what);
        begin
            ra1 = a1; ra2 = a2; #1;
            if (rd1 !== e1 || rd2 !== e2) begin
                errors = errors + 1;
                $display("  MISMATCH %0s: ra1=%0d rd1=%02h (exp %02h)  ra2=%0d rd2=%02h (exp %02h)",
                         what, a1, rd1, e1, a2, rd2, e2);
            end
        end
    endtask

    task write_reg(input [2:0] a, input [7:0] d);
        begin
            @(negedge clk); we = 1; wa = a; wd = d;
            @(negedge clk); we = 0;
        end
    endtask

    task do_reset;
        begin
            @(negedge clk); rst_n = 0; we = 1; wa = 3'd5; wd = 8'hEE;  // write must lose to reset
            @(negedge clk); @(negedge clk); rst_n = 1; we = 0;
        end
    endtask

    initial begin
        // dirty every register, then reset
        @(negedge clk); rst_n = 1;
        for (i = 0; i < 8; i = i + 1) write_reg(i[2:0], 8'hA0 + i[7:0]);
        do_reset;
        for (i = 0; i < 8; i = i + 1) expect_read(i[2:0], i[2:0], 8'h00, 8'h00, "after reset");

        // (2) every register independently, distinct values
        for (i = 0; i < 8; i = i + 1) write_reg(i[2:0], 8'h11 * (i[7:0] + 1));
        for (i = 0; i < 8; i = i + 1)
            expect_read(i[2:0], 3'd7 - i[2:0], 8'h11 * (i[7:0] + 1), 8'h11 * (8 - i[7:0]), "each reg");

        // (3) we=0 writes nothing
        @(negedge clk); we = 0; wa = 3'd0; wd = 8'h5A;
        @(negedge clk);
        expect_read(3'd0, 3'd0, 8'h11, 8'h11, "we=0");

        // (4) R14: same-cycle write and read of the same register
        @(negedge clk); we = 1; wa = 3'd3; wd = 8'hC3; ra1 = 3'd3; ra2 = 3'd3; #1;
        if (rd1 !== 8'h44 || rd2 !== 8'h44) begin
            errors = errors + 1;
            $display("  MISMATCH R14: during write cycle read %02h/%02h, expected old 44", rd1, rd2);
        end
        @(negedge clk); we = 0;
        expect_read(3'd3, 3'd3, 8'hC3, 8'hC3, "R14 next cycle");

        // (5) random traffic against a shadow model
        for (i = 0; i < 8; i = i + 1) shadow[i] = 8'h11 * (i[7:0] + 1);
        shadow[3] = 8'hC3;
        for (k = 0; k < 2000; k = k + 1) begin
            @(negedge clk);
            ra1 = $random; ra2 = $random; #1;
            if (rd1 !== shadow[ra1] || rd2 !== shadow[ra2]) begin
                errors = errors + 1;
                if (errors < 10) $display("  MISMATCH random k=%0d", k);
            end
            we = $random; wa = $random; wd = $random;
            @(posedge clk); #1;
            if (we) shadow[wa] = wd;
            we = 0;
        end

        // (6) reset again mid-run
        do_reset;
        for (i = 0; i < 8; i = i + 1) expect_read(i[2:0], i[2:0], 8'h00, 8'h00, "second reset");

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
