// tb_instr_memory.v -- self-checking unit testbench for instr_memory
// Owner: member A.  Spec §5.4, R4.
// Loads tb/data/imem_pattern.hex (512 words, word[a] = (a*0x9E37 ^ 0x5A5A)
// mod 2^16, generated independently in Python) and checks every address,
// in order and then in a scrambled order, on the combinational read.
// Run from the repository root (make test does).

`timescale 1ns/1ps

module tb_instr_memory;

    reg        clk = 0;
    reg  [8:0] addr = 0;
    wire [15:0] data;
    integer errors = 0, a, k;
    reg [31:0] prod;

    instr_memory #(.IMAGE("tb/data/imem_pattern.hex")) dut (.clk(clk), .addr(addr), .data(data));

    function [15:0] expected(input integer x);
        begin
            prod = x * 32'h9E37;
            expected = prod[15:0] ^ 16'h5A5A;
        end
    endfunction

    initial begin
        for (a = 0; a < 512; a = a + 1) begin
            addr = a; #1;
            if (data !== expected(a)) begin
                errors = errors + 1;
                if (errors < 10) $display("  MISMATCH IMEM[%03h] = %04h expected %04h", a, data, expected(a));
            end
        end
        for (k = 0; k < 2000; k = k + 1) begin
            a = $random & 511; addr = a; #1;
            if (data !== expected(a)) errors = errors + 1;
        end
        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
