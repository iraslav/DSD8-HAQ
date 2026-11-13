// tb_flags_reg.v -- self-checking unit testbench for flags_reg
// Owner: Hitesh Kumar.  Spec §5.8, R3, R6.
// Reset clears ZNCV; flags change only when flags_we = 1; bit order {Z,N,C,V}
// is preserved; 3000 random cycles against a reference register.

`timescale 1ns/1ps

module tb_flags_reg;

    reg        clk = 0, rst_n = 0, flags_we = 0;
    reg  [3:0] flags_in = 4'hF;
    wire [3:0] flags_out;
    reg  [3:0] model;
    integer errors = 0, k;

    flags_reg dut (.clk(clk), .rst_n(rst_n), .flags_we(flags_we),
                   .flags_in(flags_in), .flags_out(flags_out));

    always #5 clk = ~clk;

    task check(input [3:0] e, input [127:0] what);
        begin
            if (flags_out !== e) begin
                errors = errors + 1;
                $display("  MISMATCH %0s: flags=%b expected %b", what, flags_out, e);
            end
        end
    endtask

    initial begin
        flags_we = 1;                                   // reset must win over a write
        @(posedge clk); #1; check(4'b0000, "reset");
        rst_n = 1; flags_we = 0; flags_in = 4'b1111;
        @(posedge clk); #1; check(4'b0000, "we=0 holds");
        flags_we = 1; flags_in = 4'b1000;               // Z only -> bit 3
        @(posedge clk); #1; check(4'b1000, "Z in bit 3");
        flags_in = 4'b0001;                             // V only -> bit 0
        @(posedge clk); #1; check(4'b0001, "V in bit 0");
        flags_we = 0; flags_in = 4'b0110;
        @(posedge clk); #1; check(4'b0001, "hold after write");

        model = flags_out;
        for (k = 0; k < 3000; k = k + 1) begin
            @(negedge clk);
            rst_n = ($random & 31) != 0; flags_we = $random; flags_in = $random;
            @(posedge clk); #1;
            if (!rst_n) model = 4'b0000; else if (flags_we) model = flags_in;
            if (flags_out !== model) begin
                errors = errors + 1;
                if (errors < 10) $display("  MISMATCH random k=%0d", k);
            end
        end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
