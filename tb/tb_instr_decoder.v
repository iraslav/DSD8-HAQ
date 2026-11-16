// tb_instr_decoder.v -- self-checking unit testbench for instr_decoder
// Owner: member A.  Spec §5.5, Appendix A, worked encodings §3.5.
//
// Part 1: the eleven worked encodings from spec §3.5, checked field by field
//         against values written out by hand from the table (not computed).
// Part 2: exhaustive -- all 65 536 instruction words. Expected fields are
//         computed arithmetically (divide / modulo), an independent
//         statement of the bit positions from the DUT's part-selects.

`timescale 1ns/1ps

module tb_instr_decoder;

    reg  [15:0] instr;
    wire [3:0]  opcode;
    wire [2:0]  rd, rs1, rs2, cond;
    wire [7:0]  imm8, port;
    wire [8:0]  addr9;
    wire        io_dir;

    integer errors = 0;
    integer w;

    instr_decoder dut (
        .instr(instr), .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2),
        .imm8(imm8), .addr9(addr9), .cond(cond), .port(port), .io_dir(io_dir)
    );

    // check one worked encoding: only the fields that the format defines
    task worked(input [15:0] word, input [3:0] e_op, input [2:0] e_rd,
                input [2:0] e_rs1, input [2:0] e_rs2, input [7:0] e_imm,
                input [8:0] e_addr, input e_dir, input [127:0] name);
        begin
            instr = word; #1;
            if (opcode !== e_op || rd !== e_rd || rs1 !== e_rs1 || rs2 !== e_rs2 ||
                imm8 !== e_imm || addr9 !== e_addr || io_dir !== e_dir ||
                cond !== e_rd || port !== e_imm) begin
                errors = errors + 1;
                $display("  MISMATCH %0s (%04h): op=%h rd=%0d rs1=%0d rs2=%0d imm=%02h addr=%03h dir=%b",
                         name, word, opcode, rd, rs1, rs2, imm8, addr9, io_dir);
            end
        end
    endtask

    initial begin
        // ---- Part 1: spec §3.5 worked encodings ----
        //            word     op   rd    rs1   rs2   imm8   addr9  dir
        worked(16'h140D, 4'h1, 3'd2, 3'd0, 3'd1, 8'h0D, 9'h00D, 1'b0, "LDI R2,13");
        worked(16'h46C8, 4'h4, 3'd3, 3'd3, 3'd1, 8'hC8, 9'h0C8, 1'b0, "ADD R3,R3,R1");
        worked(16'h2AC0, 4'h2, 3'd5, 3'd3, 3'd0, 8'hC0, 9'h0C0, 1'b0, "LD R5,[R3]");
        worked(16'h30C0, 4'h3, 3'd0, 3'd3, 3'd0, 8'hC0, 9'h0C0, 1'b0, "ST [R3],R0");
        worked(16'hB0A8, 4'hB, 3'd0, 3'd2, 3'd5, 8'hA8, 9'h0A8, 1'b0, "CMP R2,R5");
        worked(16'hC004, 4'hC, 3'd0, 3'd0, 3'd0, 8'h04, 9'h004, 1'b0, "JMP 0x004");
        worked(16'hD00C, 4'hD, 3'd0, 3'd0, 3'd1, 8'h0C, 9'h00C, 1'b0, "BEQ 0x00C");
        worked(16'hD611, 4'hD, 3'd3, 3'd0, 3'd2, 8'h11, 9'h011, 1'b0, "BCC 0x011");
        worked(16'hE222, 4'hE, 3'd1, 3'd0, 3'd4, 8'h22, 9'h022, 1'b0, "IN R1,0x22");
        worked(16'hE702, 4'hE, 3'd3, 3'd4, 3'd0, 8'h02, 9'h102, 1'b1, "OUT 0x02,R3");
        worked(16'hF000, 4'hF, 3'd0, 3'd0, 3'd0, 8'h00, 9'h000, 1'b0, "HLT");

        // ---- Part 2: exhaustive, arithmetic reference ----
        for (w = 0; w < 65536; w = w + 1) begin
            instr = w[15:0]; #1;
            if (opcode !== (w / 4096) % 16 ||
                rd     !== (w / 512)  % 8  ||
                cond   !== (w / 512)  % 8  ||
                rs1    !== (w / 64)   % 8  ||
                rs2    !== (w / 8)    % 8  ||
                imm8   !== w % 256         ||
                port   !== w % 256         ||
                addr9  !== w % 512         ||
                io_dir !== (w / 256)  % 2) begin
                errors = errors + 1;
                if (errors < 10) $display("  MISMATCH exhaustive word %04h", w);
            end
        end
        $display("  checked 11 worked encodings + 65536 exhaustive words");

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
