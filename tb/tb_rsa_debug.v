// tb_rsa_debug.v -- self-checking testbench for the enclave's DEBUG mode
// Owner: shared (security-enclave extension).
// The enclave is strapped into DEBUG mode (dbg_strap = 1) and every debugger
// feature is exercised over the bus, exactly as a processor would. Expected
// internal values come from Python (m = 0x4A0B, e = 0x11, n = 0xEC4B):
//   after 8 exponent bits: res = m^17 = 8404, b = m^256 = E381, exponent = 0
//   final result 8404; 18 multiplies; 305 busy cycles = 17 + 16*(16 + 2)
//   last two multiplies: m^(2^15) = 3ABC, m^(2^16) = 673D
// Checks:
//   D1  mode selector visible (STATUS bit 4, DBG_STATUS bit 0)
//   D2  private key readable in DEBUG mode
//   D3  built-in self-test: 8 known-answer vectors pass
//   D4  breakpoint on exponent bit 8: halts there; registers inspected;
//       a RES read never stalls in DEBUG mode
//   D5  single-step: 3 steps = 3 engine cycles, exact state afterwards
//   D6  resume to completion: result, cycle count, multiply count, trace
//   D7  watchpoint on res == 8404: halts right after that multiply; a
//       value that only b ever takes (E381) must not trigger it
//   D8  deposit (register write) while halted changes the result; deposit
//       while running is refused with error code 6
//   D9  HALT command freezes the engine; RESUME completes correctly
//   D10 fault injection makes the self-test fail; removing it passes again
//   D11 error codes 1, 2, 3, 4 and CLEAR_ERR

`timescale 1ns/1ps

module tb_rsa_debug;

    reg        clk = 0, rst_n = 0;
    reg  [7:0] port = 0, wdata = 0;
    reg        rd = 0, wr = 0;
    wire [7:0] rdata;
    wire       ready, sel;

    rsa_enclave #(.BASE(8'h50), .DBG_BASE(8'h70)) dut (.clk(clk), .rst_n(rst_n), .dbg_strap(1'b1),
        .port(port), .wdata(wdata), .rd(rd), .wr(wr), .rdata(rdata), .ready(ready), .sel(sel));

    always #5 clk = ~clk;

    integer errors = 0, t, check = 0;
    reg [7:0]  got, lo, hi;
    reg [15:0] v, c0;

    task fail(input [511:0] msg);
        begin errors = errors + 1; if (errors < 30) $display("  ERROR (D%0d): %0s", check, msg); end
    endtask

    task bus_wr(input [7:0] pt, input [7:0] dd);
        begin
            @(negedge clk); port = pt; wdata = dd; wr = 1; #1;
            t = 0; while (!ready && t < 100) begin @(negedge clk); #1; t = t + 1; end
            if (t != 0) fail("write stalled");
            @(negedge clk); wr = 0;
        end
    endtask
    task bus_rd(input [7:0] pt, output [7:0] dd);
        begin
            @(negedge clk); port = pt; rd = 1; #1;
            t = 0; while (!ready && t < 1000) begin @(negedge clk); #1; t = t + 1; end
            if (t != 0) fail("read stalled in DEBUG mode");
            dd = rdata;
            @(negedge clk); rd = 0;
        end
    endtask
    task expect8(input [7:0] pt, input [7:0] e, input [511:0] what);
        begin bus_rd(pt, got); if (got !== e) begin fail(what); $display("     got %02h expected %02h", got, e); end end
    endtask
    task read_reg(input [3:0] idx, output [15:0] val);
        begin bus_wr(8'h76, {4'h0, idx}); bus_rd(8'h77, lo); bus_rd(8'h78, hi); val = {hi, lo}; end
    endtask
    task expect_reg(input [3:0] idx, input [15:0] e, input [511:0] what);
        begin read_reg(idx, v); if (v !== e) begin fail(what); $display("     REG %0d = %04h expected %04h", idx, v, e); end end
    endtask
    task wait_dbg(input [7:0] mask, input [511:0] what);      // wait for DBG_STATUS & mask
        begin
            got = 0; t = 0;
            while ((got & mask) != mask && t < 200) begin bus_rd(8'h71, got); t = t + 1; end
            if ((got & mask) != mask) fail(what);
        end
    endtask
    task wait_done;
        begin
            got = 0; t = 0;
            while (!got[1] && t < 400) begin bus_rd(8'h59, got); t = t + 1; end
            if (!got[1]) fail("operation never finished");
        end
    endtask
    task encrypt_4a0b;
        begin bus_wr(8'h50, 8'h0B); bus_wr(8'h51, 8'h4A); bus_wr(8'h58, 8'h01); end
    endtask

    initial begin
        repeat (3) @(negedge clk); rst_n = 1;
        // debug key = demo key A
        bus_wr(8'h52, 8'h4B); bus_wr(8'h53, 8'hEC); bus_wr(8'h54, 8'h11); bus_wr(8'h55, 8'h00);
        bus_wr(8'h56, 8'h71); bus_wr(8'h57, 8'hA5);

        check = 1;
        bus_rd(8'h59, got); if (got[4] !== 1'b1) fail("STATUS bit 4 (debug mode) not set");
        bus_rd(8'h71, got); if (got[0] !== 1'b1) fail("DBG_STATUS bit 0 (debug mode) not set");

        check = 2;
        expect8(8'h56, 8'h71, "D_LO not readable in DEBUG mode");
        expect8(8'h57, 8'hA5, "D_HI not readable in DEBUG mode");

        check = 3;
        bus_wr(8'h70, 8'h08);                                // RUN_BIST
        wait_dbg(8'h80, "BIST never finished");
        expect8(8'h7D, 8'hFF, "BIST pass mask");
        expect8(8'h7E, 8'h00, "BIST fail mask");

        check = 4;
        bus_wr(8'h73, 8'd8); bus_wr(8'h72, 8'h01);           // break at 8 exponent bits left
        encrypt_4a0b;
        wait_dbg(8'h14, "breakpoint not hit (halted + bp_hit)");
        expect_reg(4'd0, 16'h0001, "state should be CHECK");
        expect_reg(4'd1, 16'd8,    "bits_left at breakpoint");
        expect_reg(4'd3, 16'h8404, "res at breakpoint = m^17");
        expect_reg(4'd4, 16'hE381, "b at breakpoint = m^256");
        expect_reg(4'd5, 16'h0000, "remaining exponent at breakpoint");
        expect_reg(4'd9, 16'hEC4B, "modulus register");
        bus_rd(8'h5A, got);                                   // must not stall (checked in bus_rd)
        bus_rd(8'h59, got); if (got[0] !== 1'b1) fail("STATUS busy should stay 1 while halted");

        check = 5;
        read_reg(4'd10, c0);
        repeat (3) bus_wr(8'h70, 8'h04);                      // STEP x3
        expect_reg(4'd10, c0 + 16'd3, "3 steps should advance 3 engine cycles");
        expect_reg(4'd0, 16'h0002, "state after 3 steps should be MULTIPLY");
        expect_reg(4'd2, 16'd14,   "steps_left after 3 steps");
        bus_rd(8'h71, got); if (got[2] !== 1'b1) fail("not halted after stepping");

        check = 6;
        bus_wr(8'h72, 8'h00); bus_wr(8'h70, 8'h02);           // disable breakpoint, RESUME
        wait_done;
        expect8(8'h5A, 8'h04, "final result lo"); expect8(8'h5B, 8'h84, "final result hi");
        expect_reg(4'd10, 16'd305, "total busy cycles");
        expect_reg(4'd11, 16'd18,  "multiply count");
        expect8(8'h7C, 8'd18, "trace count");
        bus_wr(8'h79, 8'd1); expect8(8'h7A, 8'h3D, "trace[1] lo = m^(2^16)"); expect8(8'h7B, 8'h67, "trace[1] hi");
        bus_wr(8'h79, 8'd0); expect8(8'h7A, 8'hBC, "trace[0] lo = m^(2^15)"); expect8(8'h7B, 8'h3A, "trace[0] hi");

        check = 7;
        bus_wr(8'h74, 8'h04); bus_wr(8'h75, 8'h84); bus_wr(8'h72, 8'h02);  // watch res == 8404
        encrypt_4a0b;
        wait_dbg(8'h24, "watchpoint not hit (halted + wp_hit)");
        expect_reg(4'd3, 16'h8404, "res at watchpoint");
        expect_reg(4'd1, 16'd12,   "bits_left at watchpoint (exponent bit 4)");
        bus_wr(8'h72, 8'h00); bus_wr(8'h70, 8'h02);
        wait_done;
        expect8(8'h5B, 8'h84, "result after watchpoint resume");
        // the watchpoint is on res only: E381 = m^256 is a value of b, never
        // of res, so watching it must NOT halt the engine
        bus_wr(8'h74, 8'h81); bus_wr(8'h75, 8'hE3); bus_wr(8'h72, 8'h02);
        encrypt_4a0b;
        wait_done;
        bus_rd(8'h71, got); if (got[5] !== 1'b0 || got[2] !== 1'b0) fail("watchpoint fired on a write to b");
        bus_wr(8'h72, 8'h00);

        check = 8;
        bus_wr(8'h70, 8'h40);                                  // CLEAR_ERR
        bus_wr(8'h73, 8'd8); bus_wr(8'h72, 8'h01);
        encrypt_4a0b;
        wait_dbg(8'h14, "breakpoint for deposit");
        bus_wr(8'h76, 8'd3); bus_wr(8'h77, 8'h01); bus_wr(8'h78, 8'h00);   // REG_SEL res, value 0001
        bus_wr(8'h70, 8'h20);                                   // DEPOSIT
        expect_reg(4'd3, 16'h0001, "deposit into res");
        bus_wr(8'h72, 8'h00); bus_wr(8'h70, 8'h02);
        wait_done;
        expect8(8'h5A, 8'h01, "result after deposit (res forced to 1, no exponent bits left)");
        expect8(8'h5B, 8'h00, "result hi after deposit");
        bus_wr(8'h76, 8'd3); bus_wr(8'h70, 8'h20);             // deposit while NOT halted
        expect8(8'h7F, 8'd6, "error code 6: deposit while running");

        check = 9;
        encrypt_4a0b; bus_wr(8'h70, 8'h01);                     // HALT
        read_reg(4'd10, c0); repeat (20) @(negedge clk);
        expect_reg(4'd10, c0, "engine kept running while halted");
        bus_wr(8'h70, 8'h02);
        wait_done;
        expect8(8'h5B, 8'h84, "result after HALT/RESUME");

        check = 10;
        bus_wr(8'h72, 8'h10);                                   // FAULT INJECT
        bus_wr(8'h70, 8'h08); wait_dbg(8'h80, "BIST with fault never finished");
        bus_rd(8'h7E, got); if (got == 8'h00) fail("injected fault not detected by BIST");
        $display("  fault injection: BIST pass mask %02h, fail mask %02h", ~got, got);
        bus_wr(8'h72, 8'h00);
        bus_wr(8'h70, 8'h08); wait_dbg(8'h80, "BIST after fault removal");
        expect8(8'h7D, 8'hFF, "BIST passes again after removing the fault");

        check = 11;
        bus_wr(8'h70, 8'h40);
        bus_wr(8'h50, 8'hFF); bus_wr(8'h51, 8'hFF); bus_wr(8'h58, 8'h01); wait_done;
        expect8(8'h7F, 8'd2, "error code 2: message >= modulus");
        bus_wr(8'h5C, 8'h01); bus_wr(8'h5D, 8'h00);               // peer modulus 1
        bus_wr(8'h50, 8'h00); bus_wr(8'h51, 8'h00); bus_wr(8'h58, 8'h03); wait_done;
        expect8(8'h7F, 8'd1, "error code 1: modulus < 2");
        bus_wr(8'h73, 8'd4); bus_wr(8'h72, 8'h01); encrypt_4a0b;
        wait_dbg(8'h14, "breakpoint for busy test");
        bus_wr(8'h58, 8'h02);                                   // command while busy
        expect8(8'h7F, 8'd3, "error code 3: command while busy");
        bus_wr(8'h72, 8'h00); bus_wr(8'h70, 8'h02); wait_done;
        bus_wr(8'h58, 8'h80); bus_wr(8'h52, 8'h00);              // lock, then write N
        expect8(8'h7F, 8'd4, "error code 4: key write while locked");
        bus_wr(8'h70, 8'h40);
        expect8(8'h7F, 8'd0, "CLEAR_ERR");

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
