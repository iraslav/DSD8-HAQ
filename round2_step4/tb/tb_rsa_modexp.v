// tb_rsa_modexp.v -- self-checking testbench for the modular-exponentiation engine
// Owner: shared (security-enclave extension).
// 400 vectors from scripts/gen_rsa_vectors.py (Python pow() reference): the
// demo key (encrypt and decrypt round trips), corner exponents 0/1/0xFFFF,
// moduli 2 / 0xFFFF / even, illegal moduli 0 and 1, m >= n, and random cases.
// Also checks: busy/done protocol, start ignored while busy, operands
// captured at start, and the worst-case latency bound (530 cycles).
// Run from the repository root (make test does).

`timescale 1ns/1ps

module tb_rsa_modexp;

    reg         clk = 0, rst_n = 0, start = 0;
    reg  [15:0] base_in = 0, exp_in = 0, mod_in = 0;
    wire        busy, done, error;
    wire [15:0] result;

    rsa_modexp #(.W(16)) dut (.clk(clk), .rst_n(rst_n), .start(start), .base_in(base_in),
        .exp_in(exp_in), .mod_in(mod_in), .busy(busy), .done(done), .error(error), .result(result),
        .hold(1'b0), .fault(1'b0), .dep_en(1'b0), .dep_sel(2'd0), .dep_val(16'h0000),
        .dbg_state(), .dbg_bits_left(), .dbg_steps_left(), .dbg_res(), .dbg_b(), .dbg_ex(),
        .dbg_mx(), .dbg_my(), .dbg_mr(), .dbg_n(), .ev_mul(), .ev_to_res(), .ev_value());

    always #5 clk = ~clk;

    reg [79:0] vec [0:399];
    integer errors = 0, i, cycles, max_cycles = 0;
    reg [15:0] m, e, n, r;
    reg        flag;

    task fail(input [511:0] msg);
        begin errors = errors + 1; if (errors < 15) $display("  MISMATCH vector %0d (m=%04h e=%04h n=%04h): %0s", i, m, e, n, msg); end
    endtask

    initial begin
        $readmemh("tb/data/rsa_vectors.hex", vec);
        repeat (3) @(negedge clk); rst_n = 1;
        if (busy !== 0 || done !== 0) fail("not idle after reset");

        for (i = 0; i < 400; i = i + 1) begin
            {flag, m, e, n, r} = {vec[i][64], vec[i][63:0]};
            @(negedge clk);
            base_in = m; exp_in = e; mod_in = n; start = 1;
            @(negedge clk); start = 0;
            // scramble the inputs: the engine must have captured them
            base_in = ~m; exp_in = ~e; mod_in = 16'h0003;
            cycles = 1;
            // a second start while busy must be ignored
            if (busy) begin start = 1; @(negedge clk); start = 0; cycles = cycles + 1; end
            while (!done && cycles < 2000) begin @(negedge clk); cycles = cycles + 1; end
            if (cycles > max_cycles) max_cycles = cycles;
            if (!done) fail("never finished");
            else if (flag) begin
                if (error !== 1'b1 || result !== 16'h0000) fail("error case not flagged");
            end else begin
                if (error !== 1'b0) fail("spurious error");
                if (result !== r) begin
                    errors = errors + 1;
                    if (errors < 15) $display("  MISMATCH vector %0d: %04h^%04h mod %04h = %04h, expected %04h", i, m, e, n, result, r);
                end
            end
            if (busy) fail("busy together with done");
        end
        $display("  %0d vectors, worst-case latency %0d cycles (bound 530 + 2 handshake)", i, max_cycles);
        if (max_cycles > 532) fail("latency bound exceeded");
        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
