// tb_control_unit.v -- self-checking unit testbench for control_unit
// Owner: member C.  Spec §6.1, §6.2 (control-signal table), §3.3, R8, R11,
// R17, R19, R22.  Reference: doc/m1/control_signal_table.md, re-typed here
// as a literal table (not derived from the RTL).
//
// For every opcode the instruction is held on the inputs (as the PC-holds
// scheme does) and the outputs are checked in every cycle:
//   - FETCH and EXECUTE: every output 0
//   - commit cycle: exactly the table row, retire = 1 exactly once
//   - IN/OUT: request held with all enables 0 for 0..9 stall cycles, then
//     commit in the io_ready cycle
//   - HLT: retires once, then halted = 1 and nothing else for 20 cycles
// Bcc: all 8 conditions x all 16 flag values against an independent model.
// Reset in the middle of an instruction returns the FSM to FETCH.

`timescale 1ns/1ps

module tb_control_unit;

    reg        clk = 0, rst_n = 0;
    reg  [3:0] opcode = 0, flags = 0;
    reg  [2:0] cond = 0;
    reg        io_ready = 0;
    wire       pc_en, pc_load, rf_we, mem_we, io_rd, io_wr, flags_we, halted, retire;
    wire [1:0] wb_sel;

    integer errors = 0, op, c, f, stall, k, retires;

    control_unit dut (.clk(clk), .rst_n(rst_n), .opcode(opcode), .cond(cond), .flags(flags),
                      .io_ready(io_ready), .pc_en(pc_en), .pc_load(pc_load), .rf_we(rf_we),
                      .mem_we(mem_we), .io_rd(io_rd), .io_wr(io_wr), .flags_we(flags_we),
                      .wb_sel(wb_sel), .halted(halted), .retire(retire));

    always #5 clk = ~clk;

    // {rf_we, mem_we, flags_we, pc_en, retire, halted, io_rd, io_wr}
    wire [7:0] outs = {rf_we, mem_we, flags_we, pc_en, retire, halted, io_rd, io_wr};

    // ---- the table, typed in from the spec (§6.2) ----
    // returns {rf_we, mem_we, flags_we, wb_sel[1:0], wb_care}
    function [5:0] row(input [3:0] o);
        case (o)
            4'h0: row = 6'b000_00_0;   // NOP
            4'h1: row = 6'b100_10_1;   // LDI   wb 2
            4'h2: row = 6'b100_01_1;   // LD    wb 1
            4'h3: row = 6'b010_00_0;   // ST
            4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'h9, 4'hA:
                  row = 6'b101_00_1;   // ALU ops, wb 0
            4'hB: row = 6'b001_00_0;   // CMP: flags only
            4'hC: row = 6'b000_00_0;   // JMP
            4'hD: row = 6'b000_00_0;   // Bcc
            4'hF: row = 6'b000_00_0;   // HLT
            default: row = 6'b000_00_0;
        endcase
    endfunction

    // independent branch model: index the flags by name, not by cond bits
    function exp_taken(input [2:0] cc, input [3:0] fl);
        reg z, n, cy, v;
        begin
            z = fl[3]; n = fl[2]; cy = fl[1]; v = fl[0];
            case (cc)
                3'd0: exp_taken = (z == 1);  3'd1: exp_taken = (z == 0);
                3'd2: exp_taken = (cy == 1); 3'd3: exp_taken = (cy == 0);
                3'd4: exp_taken = (n == 1);  3'd5: exp_taken = (n == 0);
                3'd6: exp_taken = (v == 1);  default: exp_taken = (v == 0);
            endcase
        end
    endfunction

    task fail(input [511:0] msg);
        begin
            errors = errors + 1;
            if (errors < 20) $display("  MISMATCH op=%h cond=%0d flags=%b: %0s (outs rf,mem,fl,pcen,ret,halt,iord,iowr=%b pc_load=%b wb=%0d)",
                                      opcode, cond, flags, msg, outs, pc_load, wb_sel);
        end
    endtask

    task do_reset;
        begin
            @(negedge clk); rst_n = 0; io_ready = 0;
            @(negedge clk); @(negedge clk); rst_n = 1;
        end
    endtask

    // check one non-I/O instruction from FETCH through its commit cycle
    task run_instr(input [3:0] o, input [2:0] cc, input [3:0] fl);
        reg [5:0] r;
        reg       e_load;
        begin
            opcode = o; cond = cc; flags = fl;  r = row(o);
            #1; if (outs !== 8'b0 || pc_load !== 1'b0) fail("FETCH not idle");
            @(negedge clk);
            #1; if (outs !== 8'b0 || pc_load !== 1'b0) fail("EXECUTE not idle");
            @(negedge clk);
            #1;   // commit cycle
            e_load = (o == 4'hC) || (o == 4'hD && exp_taken(cc, fl));
            if (rf_we !== r[5] || mem_we !== r[4] || flags_we !== r[3]) fail("enable mismatch");
            if (r[0] && wb_sel !== r[2:1]) fail("wb_sel mismatch");
            if (retire !== 1'b1) fail("no retire in commit cycle");
            if (pc_en !== (o != 4'hF)) fail("pc_en mismatch");
            if (pc_load !== e_load) fail("pc_load mismatch");
            if (io_rd !== 1'b0 || io_wr !== 1'b0 || halted !== 1'b0) fail("spurious io/halted");
            @(negedge clk);
        end
    endtask

    initial begin
        do_reset;

        // ---- every non-I/O opcode except HLT, flags = 0 ----
        for (op = 0; op < 16; op = op + 1)
            if (op != 4'hE && op != 4'hF) run_instr(op, 3'd0, 4'b0000);

        // ---- Bcc: 8 conditions x 16 flag values (R17) ----
        for (c = 0; c < 8; c = c + 1)
            for (f = 0; f < 16; f = f + 1)
                run_instr(4'hD, c, f);

        // ---- JMP ignores flags and cond ----
        for (f = 0; f < 16; f = f + 4) run_instr(4'hC, 3'd7, f);

        // ---- IN / OUT with 0..9 stall cycles (R11, R19) ----
        for (stall = 0; stall < 10; stall = stall + 1) begin
            opcode = 4'hE; cond = stall[2:0]; flags = 4'b1010;
            @(negedge clk);                                   // FETCH -> EXECUTE
            @(negedge clk);                                   // EXECUTE -> MEM_IO
            for (k = 0; k < stall; k = k + 1) begin
                io_ready = 0; #1;
                if (io_rd !== 1 || io_wr !== 1) fail("request dropped during stall");
                if (rf_we | mem_we | flags_we | pc_en | pc_load | retire | halted) fail("state change during stall");
                if (wb_sel !== 2'd3) fail("wb_sel not io during stall");
                @(negedge clk);
            end
            io_ready = 1; #1;
            if (io_rd !== 1 || io_wr !== 1 || rf_we !== 1 || pc_en !== 1 || retire !== 1 || wb_sel !== 2'd3)
                fail("I/O commit");
            if (mem_we | flags_we | pc_load | halted) fail("I/O spurious enable");
            @(negedge clk); io_ready = 0; #1;
            if (outs !== 8'b0) fail("not back in FETCH after I/O");
            @(negedge clk);   // finish this FETCH (next loop starts in EXECUTE... realign below)
            do_reset;
        end

        // ---- reset in the middle of an instruction ----
        opcode = 4'h4; @(negedge clk);                       // in EXECUTE
        do_reset;
        run_instr(4'h4, 3'd0, 4'b0000);                       // full 3-cycle sequence again

        // ---- HLT: retires once, then halted forever (R8, R9) ----
        do_reset;
        run_instr(4'hF, 3'd0, 4'b0000);
        retires = 0;
        for (k = 0; k < 20; k = k + 1) begin
            opcode = $random; flags = $random; io_ready = $random; #1;
            if (halted !== 1'b1) fail("halted not asserted");
            if (rf_we | mem_we | flags_we | pc_en | pc_load | retire | io_rd | io_wr) fail("activity after HLT");
            if (retire) retires = retires + 1;
            @(negedge clk);
        end
        do_reset; #1;
        if (halted !== 1'b0) fail("reset does not clear halted");

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
