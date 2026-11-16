// tb_rsa_enclave.v -- self-checking testbench for the RSA enclave peripheral
// Owner: shared (security-enclave extension).
// Drives the bus exactly like io_bus does (request held until ready) and checks:
//   * sel / ready only for ports 0x50-0x5F (crypto) and 0x70-0x7F (debug),
//     never ready without a request (R20)
//   * SECURE mode (dbg_strap = 0): every debug port reads 0x00 and a debug
//     HALT write has no effect -- the debugger is locked out
//   * N, E, MSG read back; D_LO / D_HI ALWAYS read 0x00 (key never leaves)
//   * ENCRYPT / DECRYPT results for the demo key (N=0xEC4B, E=0x11, D=0xA571)
//   * a RES read while busy is stalled (ready low) and completes when done,
//     within the latency bound; STATUS busy/done/error bits
//   * commands ignored while busy; m >= n and n < 2 raise the error bit
//   * LOCK: N/E/D writes ignored afterwards, operations still work, reset clears it
//   * peer public key PN/PE (0x5C-0x5F): read-back, ENCRYPT_PEER (0x03)
//     uses PN/PE and not N/E, m >= PN is an error, peer key is not locked

`timescale 1ns/1ps

module tb_rsa_enclave;

    reg        clk = 0, rst_n = 0;
    reg  [7:0] port = 0, wdata = 0;
    reg        rd = 0, wr = 0;
    wire [7:0] rdata;
    wire       ready, sel;

    rsa_enclave #(.BASE(8'h50)) dut (.clk(clk), .rst_n(rst_n), .dbg_strap(1'b0), .port(port), .wdata(wdata),
        .rd(rd), .wr(wr), .rdata(rdata), .ready(ready), .sel(sel));

    always #5 clk = ~clk;

    integer errors = 0, p, stall, max_stall = 0;
    reg [7:0] got, lo, hi;

    task fail(input [511:0] msg);
        begin errors = errors + 1; if (errors < 20) $display("  ERROR: %0s (port %02h)", msg, port); end
    endtask

    // one bus write: request held until ready, like the CPU does
    task bus_wr(input [7:0] pt, input [7:0] d);
        begin
            @(negedge clk); port = pt; wdata = d; wr = 1; #1;
            while (!ready) begin @(negedge clk); #1; end
            @(negedge clk); wr = 0;
        end
    endtask

    task bus_rd(input [7:0] pt, output [7:0] d);
        begin
            @(negedge clk); port = pt; rd = 1; #1;
            stall = 0;
            while (!ready && stall < 1000) begin @(negedge clk); #1; stall = stall + 1; end
            if (stall > max_stall) max_stall = stall;
            d = rdata;
            @(negedge clk); rd = 0;
        end
    endtask

    task expect_rd(input [7:0] pt, input [7:0] exp, input [511:0] what);
        begin bus_rd(pt, got); if (got !== exp) begin fail(what); $display("     got %02h expected %02h", got, exp); end end
    endtask

    task program_key;
        begin
            bus_wr(8'h52, 8'h4B); bus_wr(8'h53, 8'hEC);      // N = 0xEC4B (60491)
            bus_wr(8'h54, 8'h11); bus_wr(8'h55, 8'h00);      // E = 17
            bus_wr(8'h56, 8'h71); bus_wr(8'h57, 8'hA5);      // D = 0xA571 (42353)
        end
    endtask

    initial begin
        repeat (3) @(negedge clk); rst_n = 1;

        // ---- address decode and R20 ----
        for (p = 0; p < 256; p = p + 1) begin
            port = p; rd = 0; wr = 0; #1;
            if (ready !== 1'b0) fail("ready without request");
            if (sel !== ((p >= 8'h50 && p <= 8'h5F) || (p >= 8'h70 && p <= 8'h7F))) fail("sel decode");
            rd = 1; #1;
            if (ready !== sel) fail("ready != request for idle enclave");
            if (!sel && rdata !== 8'h00) fail("rdata not 0 for foreign port");
            rd = 0;
        end

        // ---- SECURE mode: the debug unit is locked ----
        for (p = 8'h70; p <= 8'h7F; p = p + 1) expect_rd(p, 8'h00, "debug port readable in SECURE mode");

        // ---- key programming and read-back ----
        program_key;
        expect_rd(8'h52, 8'h4B, "N_LO readback");
        expect_rd(8'h53, 8'hEC, "N_HI readback");
        expect_rd(8'h54, 8'h11, "E_LO readback");
        expect_rd(8'h55, 8'h00, "E_HI readback");
        expect_rd(8'h56, 8'h00, "D_LO must read 0 (write-only)");
        expect_rd(8'h57, 8'h00, "D_HI must read 0 (write-only)");
        expect_rd(8'h5C, 8'h00, "PN after reset");

        // ---- peer public key (processor B's key: PN = 0xD987, PE = 19) ----
        bus_wr(8'h5C, 8'h87); bus_wr(8'h5D, 8'hD9); bus_wr(8'h5E, 8'h13); bus_wr(8'h5F, 8'h00);
        expect_rd(8'h5C, 8'h87, "PN_LO readback");
        expect_rd(8'h5D, 8'hD9, "PN_HI readback");
        expect_rd(8'h5E, 8'h13, "PE_LO readback");
        expect_rd(8'h5F, 8'h00, "PE_HI readback");
        // ENCRYPT_PEER 0x4A0B -> 0x1BB1 (Python: pow(0x4A0B, 19, 55687)); own N/E untouched
        bus_wr(8'h50, 8'h0B); bus_wr(8'h51, 8'h4A); bus_wr(8'h58, 8'h03);
        bus_rd(8'h5A, lo); bus_rd(8'h5B, hi);
        if ({hi, lo} !== 16'h1BB1) begin fail("ENCRYPT_PEER result"); $display("     got %02h%02h", hi, lo); end
        // m >= PN (0xD987) but < N (0xEC4B): error only for the peer key
        bus_wr(8'h50, 8'h00); bus_wr(8'h51, 8'hE0); bus_wr(8'h58, 8'h03);
        bus_rd(8'h5A, lo);
        expect_rd(8'h59, 8'h06, "STATUS error for m >= PN");
        bus_wr(8'h58, 8'h01);                               // same m with own key is legal
        bus_rd(8'h5A, lo);
        expect_rd(8'h59, 8'h02, "own-key ENCRYPT of m < N is not an error");

        // ---- encrypt 0x4A01 -> 0x0F61 (Python: pow(0x4A01, 17, 60491)) ----
        bus_wr(8'h50, 8'h01); bus_wr(8'h51, 8'h4A);
        expect_rd(8'h50, 8'h01, "MSG_LO readback");
        bus_wr(8'h58, 8'h01);
        expect_rd(8'h59, 8'h01, "STATUS busy right after ENCRYPT");
        bus_wr(8'h58, 8'h02);                          // ignored: busy
        bus_rd(8'h5A, lo);                             // stalls until done
        if (max_stall == 0) fail("RES read did not stall while busy");
        bus_rd(8'h5B, hi);
        if ({hi, lo} !== 16'h0F61) begin fail("ENCRYPT result"); $display("     got %02h%02h", hi, lo); end
        expect_rd(8'h59, 8'h02, "STATUS done after ENCRYPT");

        // ---- a debug HALT in SECURE mode must not stop the engine ----
        bus_wr(8'h72, 8'h01); bus_wr(8'h73, 8'h08);        // try to arm a breakpoint
        bus_wr(8'h58, 8'h01); bus_wr(8'h70, 8'h01);         // encrypt, then try to HALT
        bus_rd(8'h5A, lo); bus_rd(8'h5B, hi);
        if ({hi, lo} !== 16'h0F61) fail("debug writes affected the engine in SECURE mode");

        // ---- decrypt 0x0F61 -> 0x4A01 ----
        bus_wr(8'h50, 8'h61); bus_wr(8'h51, 8'h0F); bus_wr(8'h58, 8'h02);
        bus_rd(8'h5A, lo); bus_rd(8'h5B, hi);
        if ({hi, lo} !== 16'h4A01) begin fail("DECRYPT result"); $display("     got %02h%02h", hi, lo); end

        // ---- error: message >= modulus ----
        bus_wr(8'h50, 8'hFF); bus_wr(8'h51, 8'hFF); bus_wr(8'h58, 8'h01);
        bus_rd(8'h5A, lo);
        expect_rd(8'h59, 8'h06, "STATUS error+done for m >= n");
        if (lo !== 8'h00) fail("error result not 0");

        // ---- lock ----
        bus_wr(8'h58, 8'h80);
        expect_rd(8'h59, 8'h0E, "STATUS locked");
        bus_wr(8'h52, 8'h00); bus_wr(8'h53, 8'h00); bus_wr(8'h54, 8'h03); bus_wr(8'h56, 8'h00);
        expect_rd(8'h52, 8'h4B, "N changed after lock");
        bus_wr(8'h5E, 8'h05);
        expect_rd(8'h5E, 8'h05, "peer key must stay writable after lock");
        expect_rd(8'h54, 8'h11, "E changed after lock");
        bus_wr(8'h50, 8'h61); bus_wr(8'h51, 8'h0F); bus_wr(8'h58, 8'h02);   // D unchanged?
        bus_rd(8'h5A, lo); bus_rd(8'h5B, hi);
        if ({hi, lo} !== 16'h4A01) fail("DECRYPT after lock (D was modified?)");

        // ---- reset clears the key and the lock ----
        @(negedge clk); rst_n = 0; @(negedge clk); @(negedge clk); rst_n = 1;
        expect_rd(8'h59, 8'h00, "STATUS after reset");
        expect_rd(8'h52, 8'h00, "N after reset");
        bus_wr(8'h50, 8'h05); bus_wr(8'h58, 8'h01);   // n = 0 -> error
        bus_rd(8'h5A, lo);
        expect_rd(8'h59, 8'h06, "STATUS error for n = 0");

        $display("  longest RES-read stall: %0d cycles (bound 530)", max_stall);
        if (max_stall > 531) fail("stall exceeded engine latency bound");
        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
