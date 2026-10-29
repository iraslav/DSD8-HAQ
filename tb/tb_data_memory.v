// tb_data_memory.v -- self-checking unit testbench for data_memory
// Owner: member C.  Spec §5.9, R5, R6, R16.
// (1) every one of the 256 bytes reads 0x00 before any write (never X);
// (2) we = 0 writes nothing; (3) a write is visible on the combinational
// read from the next cycle, and the read in the write cycle is the old
// value; (4) 0x00 and 0xFF addresses; (5) 4000 random accesses vs a shadow.

`timescale 1ns/1ps

module tb_data_memory;

    reg        clk = 0, we = 0;
    reg  [7:0] addr = 0, wdata = 0;
    wire [7:0] rdata;
    reg  [7:0] shadow [0:255];
    integer errors = 0, i, k;

    data_memory dut (.clk(clk), .addr(addr), .we(we), .wdata(wdata), .rdata(rdata));

    always #5 clk = ~clk;

    initial begin
        // (1) all zero, never X
        for (i = 0; i < 256; i = i + 1) begin
            addr = i; #1;
            if (rdata !== 8'h00) begin
                errors = errors + 1;
                if (errors < 10) $display("  MISMATCH initial DMEM[%02h] = %02h", i, rdata);
            end
            shadow[i] = 8'h00;
        end
        // (2) we = 0
        @(negedge clk); addr = 8'h10; wdata = 8'hAA; we = 0;
        @(negedge clk); if (rdata !== 8'h00) begin errors = errors + 1; $display("  we=0 wrote"); end
        // (3) old value during the write cycle, new value afterwards; (4) ends
        @(negedge clk); addr = 8'hFF; wdata = 8'h5C; we = 1; #1;
        if (rdata !== 8'h00) begin errors = errors + 1; $display("  read during write not old"); end
        @(negedge clk); we = 0; #1;
        if (rdata !== 8'h5C) begin errors = errors + 1; $display("  DMEM[FF] = %02h", rdata); end
        shadow[255] = 8'h5C;
        @(negedge clk); addr = 8'h00; wdata = 8'hC5; we = 1;
        @(negedge clk); we = 0; #1;
        if (rdata !== 8'hC5) begin errors = errors + 1; $display("  DMEM[00] = %02h", rdata); end
        shadow[0] = 8'hC5;
        // (5) random
        for (k = 0; k < 4000; k = k + 1) begin
            @(negedge clk);
            addr = $random; #1;
            if (rdata !== shadow[addr]) begin
                errors = errors + 1;
                if (errors < 10) $display("  MISMATCH random read DMEM[%02h]=%02h exp %02h", addr, rdata, shadow[addr]);
            end
            we = $random; wdata = $random;
            @(posedge clk); #1;
            if (we) shadow[addr] = wdata;
            we = 0;
        end

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
