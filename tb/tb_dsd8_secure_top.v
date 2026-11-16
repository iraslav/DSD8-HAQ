// tb_dsd8_secure_top.v -- end-to-end test of the two-processor secure channel
// Owner: shared (security-enclave extension).
// Two DSD-8 processors in dsd8_secure_top running tests/secure/enclave_server.asm
// (A) and enclave_client.asm (B). Each has its own RSA key pair; each private-
// key low byte is programmed from its own switches (A: SW0-7, correct 0x71;
// B: SW8-14, correct 0x2B). Scenario:
//   1. A wrong (00), B right (2B)  -> channel stays closed: B LEDs 1, 7-seg EE
//   2. A right (71), B wrong (2A)  -> BTNC retry, still closed: B LEDs 2
//   3. both wrong (07, 25)         -> BTNC retry, still closed: B LEDs 3. This
//      pair makes the answer come back as 0x4Axx with a wrong low byte, so
//      only B's low-byte comparison rejects it
//   4. both right (71, 2B)         -> BTNC retry: keys match, channel opens,
//      A sends "DS" "D8" encrypted for B, B sends "OK" "!!" encrypted for A,
//      each side decrypts the other's data; both halt
// Monitored on every cycle:
//   * the only plaintext on the mailbox is the two public keys (first 4 bytes
//     each way); every later 16-bit word must differ from every plaintext
//     value used (challenges, verdict tokens, data words, private keys)
//   * no data word is sent while the keys do not match (exact word counts)
//   * no read of a private-key port (0x56/0x57) ever returns non-zero
//   * B never shows "channel open" while either key is wrong
// Run from the repository root (make test does).

`timescale 1ns/1ps

module tb_dsd8_secure_top;

    reg        clk = 0, rst_n = 0;
    reg  [7:0] sw_a = 8'h00;
    reg  [6:0] sw_b = 7'h00;
    reg  [4:0] buttons = 5'h00;
    always #5 clk = ~clk;

    wire [7:0] leds;  wire [6:0] seg, leds_a;  wire [3:0] an;  wire halted;

    dsd8_secure_top #(.IMAGE_A("tb/data/enclave_server.hex"), .IMAGE_B("tb/data/enclave_client.hex"),
                      .CLK_DIV(2), .DEBOUNCE_BITS(3), .REFRESH_BITS(4))
        dut (.clk(clk), .rst_n(rst_n), .switches(sw_a), .switches_b(sw_b), .buttons(buttons),
             .leds(leds), .seg(seg), .an(an), .leds_a(leds_a), .halted(halted));

    integer errors = 0, step = 0, i;
    integer n_ab = 0, n_ba = 0;           // bytes A->B and B->A
    reg [7:0] ab [0:255];
    reg [7:0] ba [0:255];
    reg [15:0] w;

    task fail(input [511:0] msg);
        begin errors = errors + 1; $display("  ERROR (step %0d): %0s", step, msg); end
    endtask

    // every plaintext value that must never appear on the mailbox after the key exchange
    function is_plaintext(input [15:0] x);
        begin
            is_plaintext = (x == 16'h4A0B || x == 16'h4A11 || x == 16'h4A19 || x == 16'h4A28 ||
                            x == 16'h4A38 || x == 16'h4A54 || x == 16'h4A6C || x == 16'h4A72 ||
                            x == 16'h600D || x == 16'h0BAD ||
                            x == 16'h4453 || x == 16'h4438 || x == 16'h4F4B || x == 16'h2121 ||
                            x == 16'hA571 || x == 16'h662B);
        end
    endfunction

    // ---- monitors (core clock domain) ----
    always @(posedge dut.cpu_clk) if (dut.cpu_rst_n) begin
        if (dut.pwr_a && dut.pready_a && dut.pport_a == 8'h60) begin
            ab[n_ab[7:0]] = dut.pwdata_a;
            n_ab = n_ab + 1;
            if (n_ab > 4 && n_ab % 2 == 0) begin
                w = {ab[n_ab - 1], ab[n_ab - 2]};
                if (is_plaintext(w)) begin fail("plaintext word sent A->B"); $display("     word %04h", w); end
            end
        end
        if (dut.pwr_b && dut.pready_b && dut.pport_b == 8'h60) begin
            ba[n_ba[7:0]] = dut.pwdata_b;
            n_ba = n_ba + 1;
            if (n_ba > 4 && n_ba % 2 == 0) begin
                w = {ba[n_ba - 1], ba[n_ba - 2]};
                if (is_plaintext(w)) begin fail("plaintext word sent B->A"); $display("     word %04h", w); end
            end
        end
        if (dut.prd_a && dut.pready_a && (dut.pport_a == 8'h56 || dut.pport_a == 8'h57) && dut.prdata_a !== 8'h00)
            fail("A's private key readable");
        if (dut.prd_b && dut.pready_b && (dut.pport_b == 8'h56 || dut.pport_b == 8'h57) && dut.prdata_b !== 8'h00)
            fail("B's private key readable");
        if (leds == 8'hFF && (sw_a != 8'h71 || sw_b != 7'h2B)) fail("channel opened with a wrong key");
        if (dut.debug_mode !== 1'b0) fail("mode selector should be SECURE (BTNU not held at reset)");
        if (dut.prd_a && dut.pport_a[7:4] == 4'h7 && dut.prdata_a !== 8'h00) fail("debug port readable in SECURE mode");
    end

    task press_btnc;
        begin
            buttons = 5'b00001; repeat (200) @(posedge clk);
            buttons = 5'b00000; repeat (200) @(posedge clk);
        end
    endtask

    // wait until B reports `n` failed attempts or opens the channel
    task wait_result(input [7:0] n);
        integer t;
        begin
            t = 0;
            while (leds !== n && leds !== 8'hFF && t < 600000) begin @(posedge clk); t = t + 1; end
            if (leds === 8'hFF)                       // channel open: let the data exchange finish
                while (!halted && t < 600000) begin @(posedge clk); t = t + 1; end
            repeat (300) @(posedge clk);
            $display("  step %0d: key A = %02h, key B = %02h  ->  B LEDs = %02h, 7-seg = %02h  -> %0s",
                     step, sw_a, sw_b, leds, dut.seg_value_b,
                     (leds == 8'hFF) ? "KEYS MATCH: channel opened, encrypted data exchanged"
                                     : "MISMATCH: channel closed, no data sent (BTNC = retry)");
        end
    endtask

    initial begin
        $display("  A: N=EC4B E=0011 D=A5xx (xx = SW0-7, correct 71)   B: N=D987 E=0013 D=66xx (xx = SW8-14, correct 2B)");
        repeat (20) @(posedge clk);

        step = 1; sw_a = 8'h00; sw_b = 7'h2B;
        rst_n = 1;
        wait_result(8'd1);
        if (leds !== 8'd1)             fail("A's wrong key not rejected");
        if (dut.seg_value_b !== 8'hEE) fail("7-seg should show EE");
        if (n_ab !== 4 + 2 || n_ba !== 4 + 4) fail("traffic after round 1 is not keys + 1 round");
        if (ab[0] !== 8'h4B || ab[1] !== 8'hEC || ab[2] !== 8'h11 || ab[3] !== 8'h00) fail("A's public key not sent first");
        if (ba[0] !== 8'h87 || ba[1] !== 8'hD9 || ba[2] !== 8'h13 || ba[3] !== 8'h00) fail("B's public key not sent first");
        repeat (3000) @(posedge clk);
        if (leds !== 8'd1)             fail("retried without BTNC");

        step = 2; sw_a = 8'h71; sw_b = 7'h2A;
        press_btnc;
        wait_result(8'd2);
        if (leds !== 8'd2)             fail("B's wrong key not rejected");

        step = 3; sw_a = 8'h07; sw_b = 7'h25;
        press_btnc;
        wait_result(8'd3);
        if (leds !== 8'd3)             fail("two wrong keys not rejected");
        if (n_ab !== 4 + 3 * 2 || n_ba !== 4 + 3 * 4) fail("data sent while the keys did not match");

        step = 4; sw_a = 8'h71; sw_b = 7'h2B;
        press_btnc;
        wait_result(8'hFF);
        repeat (20000) @(posedge clk);
        if (leds !== 8'hFF)            fail("correct keys: channel did not open");
        if (!halted)                   fail("both processors should halt after the exchange");
        if (n_ab !== 4 + 4 * 2 + 4 || n_ba !== 4 + 4 * 4 + 4) fail("wrong number of data bytes");
        // what each side decrypted and stored (DMEM 0x20..0x23)
        if ({dut.u_cpu_b.u_dmem.mem[8'h21], dut.u_cpu_b.u_dmem.mem[8'h20]} !== 16'h4453 ||
            {dut.u_cpu_b.u_dmem.mem[8'h23], dut.u_cpu_b.u_dmem.mem[8'h22]} !== 16'h4438)
            fail("B did not decrypt A's data \"DS\" \"D8\"");
        if ({dut.u_cpu_a.u_dmem.mem[8'h21], dut.u_cpu_a.u_dmem.mem[8'h20]} !== 16'h4F4B ||
            {dut.u_cpu_a.u_dmem.mem[8'h23], dut.u_cpu_a.u_dmem.mem[8'h22]} !== 16'h2121)
            fail("A did not decrypt B's data \"OK\" \"!!\"");
        if (dut.seg_value_b !== 8'h38) fail("B's 7-seg should show the last data byte from A (38)");
        if (leds_a !== 7'h21)          fail("A's LEDs should show the last data byte from B (21)");

        $display("  data A->B on the mailbox (encrypted): %02h%02h %02h%02h -> B decrypted: %02h%02h %02h%02h (\"DS\" \"D8\")",
                 ab[13], ab[12], ab[15], ab[14],
                 dut.u_cpu_b.u_dmem.mem[8'h21], dut.u_cpu_b.u_dmem.mem[8'h20],
                 dut.u_cpu_b.u_dmem.mem[8'h23], dut.u_cpu_b.u_dmem.mem[8'h22]);
        $display("  data B->A on the mailbox (encrypted): %02h%02h %02h%02h -> A decrypted: %02h%02h %02h%02h (\"OK\" \"!!\")",
                 ba[21], ba[20], ba[23], ba[22],
                 dut.u_cpu_a.u_dmem.mem[8'h21], dut.u_cpu_a.u_dmem.mem[8'h20],
                 dut.u_cpu_a.u_dmem.mem[8'h23], dut.u_cpu_a.u_dmem.mem[8'h22]);
        $display("  mailbox bytes: A->B %0d, B->A %0d; halted = %b", n_ab, n_ba, halted);
        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
