// tb_prog_counter.v -- self-checking unit testbench for prog_counter
// Owner: Abdul Qadeer.  Spec §5.3, R6, R7, R8; §3.4 (PC + 1 wraps in 9 bits).
//
// A cycle-by-cycle reference model of the PC runs beside the DUT on random
// pc_en / pc_load / branch_addr / rst_n stimulus (5000 cycles), after a set
// of directed checks: reset value, hold, increment, wrap 0x1FF -> 0x000,
// load, pc_load ignored when pc_en = 0, and reset taking priority.

`timescale 1ns/1ps

module tb_prog_counter;

    reg        clk = 0, rst_n = 0, pc_en = 0, pc_load = 0;
    reg  [8:0] branch_addr = 0;
    wire [8:0] pc;
    reg  [8:0] model;
    integer errors = 0, k;

    prog_counter dut (.clk(clk), .rst_n(rst_n), .pc_en(pc_en), .pc_load(pc_load),
                      .branch_addr(branch_addr), .pc(pc));

    always #5 clk = ~clk;

    task step_check(input [8:0] expected, input [127:0] what);
        begin
            @(posedge clk); #1;
            if (pc !== expected) begin
                errors = errors + 1;
                $display("  MISMATCH %0s: pc=%03h expected %03h", what, pc, expected);
            end
        end
    endtask

    initial begin
        // reset (with enables active: reset must win)
        pc_en = 1; pc_load = 1; branch_addr = 9'h155;
        step_check(9'h000, "reset priority");
        step_check(9'h000, "reset held");
        rst_n = 1; pc_en = 0; pc_load = 1;
        step_check(9'h000, "hold, pc_load ignored without pc_en");
        pc_load = 0;
        step_check(9'h000, "hold");
        pc_en = 1;
        step_check(9'h001, "increment");
        step_check(9'h002, "increment");
        pc_load = 1; branch_addr = 9'h1FE;
        step_check(9'h1FE, "load");
        pc_load = 0;
        step_check(9'h1FF, "increment to last");
        step_check(9'h000, "wrap 0x1FF -> 0x000");
        pc_load = 1; branch_addr = 9'h000;
        step_check(9'h000, "load 0x000");
        pc_en = 0; pc_load = 0;
        step_check(9'h000, "hold (HLT)");
        step_check(9'h000, "hold (HLT)");

        // random against a reference model
        model = pc;
        for (k = 0; k < 5000; k = k + 1) begin
            @(negedge clk);
            rst_n = ($random & 63) != 0;
            pc_en = $random; pc_load = $random; branch_addr = $random;
            @(posedge clk); #1;
            if (!rst_n)       model = 9'h000;
            else if (pc_en)   model = pc_load ? branch_addr : model + 9'd1;
            if (pc !== model) begin
                errors = errors + 1;
                if (errors < 10) $display("  MISMATCH random k=%0d pc=%03h model=%03h", k, pc, model);
            end
        end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
