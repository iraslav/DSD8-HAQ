// tb_alu_random.v -- constrained-random, self-checking ALU testbench
// Owner: Hitesh Kumar.  Spec §8.5 R24 and R25, §2.3 flag definitions.
//
// R24: >= 10 000 operand pairs against a behavioural reference, all eight
//      ALU operations.  Here: 12 000 pairs PER operation = 96 000 pairs.
// R25: the corner values 0x00, 0x01, 0x7F, 0x80, 0xFF must occur as BOTH
//      operands, reported as coverage evidence. The coverage table printed
//      at the end is that evidence (counts, not a claim).
//
// Constraint: each operand is a corner value with probability 3/8 and a
// uniformly random byte otherwise, so corners and their cross products are
// hit often while the whole operand space is still sampled.
//
// The reference model is deliberately written in a different style from the
// RTL and from tb_alu_example.v: it uses integer arithmetic and signed
// range checks (like tools/dsd8sim.py) rather than a 9-bit adder and sign
// bits, so a misunderstanding cannot be copied from one into the other.

`timescale 1ns/1ps

module tb_alu_random;

    parameter integer PAIRS_PER_OP = 12000;
    parameter integer SEED         = 20261029;

    reg  [7:0] a, b;
    reg  [3:0] op;
    wire [7:0] result;
    wire       flag_z, flag_n, flag_c, flag_v;

    alu dut (.a(a), .b(b), .op(op), .result(result),
             .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v));

    integer seed;
    integer errors = 0, total = 0;
    integer oi, n, ci, cj;

    // ---- coverage counters ----
    // 1-D arrays indexed [op*N + bin] (Icarus 0.9.x has no 2-D arrays)
    integer cov_a   [0:39];          // [op*5 + corner]  corner value seen as operand a
    integer cov_b   [0:39];          // [op*5 + corner]  corner value seen as operand b
    integer cov_x   [0:199];         // [op*25 + 5*ia+ib] corner x corner cross
    integer cov_f1  [0:31];          // [op*4 + flag Z,N,C,V] flag observed = 1
    integer cov_f0  [0:31];          // [op*4 + flag]  flag observed = 0

    reg [7:0] corners [0:4];
    reg [3:0] ops     [0:7];
    reg [8*4-1:0] opname [0:7];

    // ---- behavioural reference (integer style) ----
    integer ia, ib, ires, sa, sb, sres;
    reg [7:0] e_res;
    reg       e_z, e_n, e_c, e_v;

    task reference(input [7:0] xa, input [7:0] xb, input [3:0] xop);
        begin
            ia = xa; ib = xb;
            sa = (ia > 127) ? ia - 256 : ia;
            sb = (ib > 127) ? ib - 256 : ib;
            e_c = 0; e_v = 0;
            case (xop)
                4'h4: begin ires = ia + ib; e_c = (ires > 255);
                            sres = sa + sb; e_v = (sres > 127) || (sres < -128); end
                4'h5, 4'hB: begin ires = ia - ib; e_c = (ia >= ib);   // C = 1 means NO borrow
                            sres = sa - sb; e_v = (sres > 127) || (sres < -128); end
                4'h6: ires = ia & ib;
                4'h7: ires = ia | ib;
                4'h8: ires = ia ^ ib;
                4'h9: begin ires = ia * 2; e_c = (ia >= 128); end
                4'hA: begin ires = ia / 2; e_c = ia % 2; end            // logical: zero into bit 7
                default: ires = 0;
            endcase
            e_res = (ires < 0) ? ires + 256 : ires % 256;     // ires is in -255 .. 510
            e_z = (e_res == 0);
            e_n = (e_res >= 128);
        end
    endtask

    function integer corner_index(input [7:0] v);
        integer q;
        begin
            corner_index = -1;
            for (q = 0; q < 5; q = q + 1) if (v == corners[q]) corner_index = q;
        end
    endfunction

    function [7:0] pick(input integer dummy);
        integer r;
        begin
            r = $random(seed);
            if ((r & 7) < 3) pick = corners[(($random(seed) & 32'h7fffffff) % 5)];
            else             pick = $random(seed);
        end
    endfunction

    initial begin
        seed = SEED;
        corners[0] = 8'h00; corners[1] = 8'h01; corners[2] = 8'h7F; corners[3] = 8'h80; corners[4] = 8'hFF;
        ops[0] = 4'h4; ops[1] = 4'h5; ops[2] = 4'h6; ops[3] = 4'h7;
        ops[4] = 4'h8; ops[5] = 4'h9; ops[6] = 4'hA; ops[7] = 4'hB;
        opname[0] = "ADD"; opname[1] = "SUB"; opname[2] = "AND"; opname[3] = "OR ";
        opname[4] = "XOR"; opname[5] = "SHL"; opname[6] = "SHR"; opname[7] = "CMP";
        for (oi = 0; oi < 8; oi = oi + 1) begin
            for (ci = 0; ci < 5; ci = ci + 1) begin cov_a[(oi)*5+(ci)] = 0; cov_b[(oi)*5+(ci)] = 0; end
            for (ci = 0; ci < 25; ci = ci + 1) cov_x[(oi)*25+(ci)] = 0;
            for (ci = 0; ci < 4; ci = ci + 1) begin cov_f1[(oi)*4+(ci)] = 0; cov_f0[(oi)*4+(ci)] = 0; end
        end

        for (oi = 0; oi < 8; oi = oi + 1) begin
            for (n = 0; n < PAIRS_PER_OP; n = n + 1) begin
                a = pick(0); b = pick(0); op = ops[oi];
                #1;
                reference(a, b, op);
                total = total + 1;
                if (result !== e_res || flag_z !== e_z || flag_n !== e_n ||
                    flag_c !== e_c || flag_v !== e_v) begin
                    errors = errors + 1;
                    if (errors <= 10)
                        $display("  MISMATCH %0s a=%02h b=%02h: got %02h ZNCV=%b%b%b%b exp %02h ZNCV=%b%b%b%b",
                                 opname[oi], a, b, result, flag_z, flag_n, flag_c, flag_v,
                                 e_res, e_z, e_n, e_c, e_v);
                end
                // coverage sampling
                ci = corner_index(a); cj = corner_index(b);
                if (ci >= 0) cov_a[(oi)*5+(ci)] = cov_a[(oi)*5+(ci)] + 1;
                if (cj >= 0) cov_b[(oi)*5+(cj)] = cov_b[(oi)*5+(cj)] + 1;
                if (ci >= 0 && cj >= 0) cov_x[(oi)*25+(5*ci+cj)] = cov_x[(oi)*25+(5*ci+cj)] + 1;
                if (flag_z) cov_f1[(oi)*4+(0)] = cov_f1[(oi)*4+(0)] + 1; else cov_f0[(oi)*4+(0)] = cov_f0[(oi)*4+(0)] + 1;
                if (flag_n) cov_f1[(oi)*4+(1)] = cov_f1[(oi)*4+(1)] + 1; else cov_f0[(oi)*4+(1)] = cov_f0[(oi)*4+(1)] + 1;
                if (flag_c) cov_f1[(oi)*4+(2)] = cov_f1[(oi)*4+(2)] + 1; else cov_f0[(oi)*4+(2)] = cov_f0[(oi)*4+(2)] + 1;
                if (flag_v) cov_f1[(oi)*4+(3)] = cov_f1[(oi)*4+(3)] + 1; else cov_f0[(oi)*4+(3)] = cov_f0[(oi)*4+(3)] + 1;
            end
        end

        // ---- coverage report (R25 evidence) ----
        $display("");
        $display("  ALU constrained-random test: %0d operand pairs (%0d per op), seed %0d, %0d mismatches",
                 total, PAIRS_PER_OP, SEED, errors);
        $display("  Corner-operand coverage: hits as operand a / operand b");
        $display("  op  |  0x00      |  0x01      |  0x7F      |  0x80      |  0xFF      | corner x corner bins hit");
        for (oi = 0; oi < 8; oi = oi + 1) begin
            n = 0;
            for (ci = 0; ci < 25; ci = ci + 1) if (cov_x[(oi)*25+(ci)] > 0) n = n + 1;
            $display("  %0s | %4d/%4d  | %4d/%4d  | %4d/%4d  | %4d/%4d  | %4d/%4d  | %0d/25",
                     opname[oi], cov_a[(oi)*5+(0)], cov_b[(oi)*5+(0)], cov_a[(oi)*5+(1)], cov_b[(oi)*5+(1)],
                     cov_a[(oi)*5+(2)], cov_b[(oi)*5+(2)], cov_a[(oi)*5+(3)], cov_b[(oi)*5+(3)],
                     cov_a[(oi)*5+(4)], cov_b[(oi)*5+(4)], n);
            for (ci = 0; ci < 5; ci = ci + 1) if (cov_a[(oi)*5+(ci)] == 0 || cov_b[(oi)*5+(ci)] == 0) begin
                errors = errors + 1;
                $display("  COVERAGE HOLE: %0s corner %02h not seen as both operands", opname[oi], corners[ci]);
            end
            for (ci = 0; ci < 25; ci = ci + 1) if (cov_x[(oi)*25+(ci)] == 0) begin
                errors = errors + 1;
                $display("  COVERAGE HOLE: %0s cross bin %0d", opname[oi], ci);
            end
        end
        $display("  Flag coverage: times each flag was observed 1 / 0");
        $display("  op  |  Z          |  N          |  C          |  V");
        for (oi = 0; oi < 8; oi = oi + 1)
            $display("  %0s | %5d/%5d | %5d/%5d | %5d/%5d | %5d/%5d", opname[oi],
                     cov_f1[(oi)*4+(0)], cov_f0[(oi)*4+(0)], cov_f1[(oi)*4+(1)], cov_f0[(oi)*4+(1)],
                     cov_f1[(oi)*4+(2)], cov_f0[(oi)*4+(2)], cov_f1[(oi)*4+(3)], cov_f0[(oi)*4+(3)]);
        $display("  (C and V are architecturally 0 for AND/OR/XOR, V is 0 for SHL/SHR, N is 0 for SHR: their '1' column must read 0)");
        if (cov_f1[(6)*4+(1)] != 0) begin errors = errors + 1; $display("  N set for SHR -- arithmetic shift?"); end
        for (oi = 2; oi < 7; oi = oi + 1) begin
            if (cov_f1[(oi)*4+(3)] != 0) begin errors = errors + 1; $display("  V set for %0s", opname[oi]); end
            if (oi <= 4 && cov_f1[(oi)*4+(2)] != 0) begin errors = errors + 1; $display("  C set for %0s", opname[oi]); end
        end
        // every flag that CAN be both values must have been seen both ways
        for (oi = 0; oi < 8; oi = oi + 1)
            for (ci = 0; ci < 4; ci = ci + 1)
                // unreachable by definition: C,V for AND/OR/XOR; V for SHL/SHR;
                // N for SHR (a logical right shift always puts 0 in bit 7)
                if (!((oi >= 2 && oi <= 4 && ci >= 2) || ((oi == 5 || oi == 6) && ci == 3) ||
                      (oi == 6 && ci == 1)))
                    if (cov_f1[(oi)*4+(ci)] == 0 || cov_f0[(oi)*4+(ci)] == 0) begin
                        errors = errors + 1;
                        $display("  COVERAGE HOLE: %0s flag %0d not seen both ways", opname[oi], ci);
                    end
        $display("");

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
