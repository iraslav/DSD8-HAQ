// tb_cpu_mailbox.v -- self-checking testbench for the two-processor mailbox
// Owner: shared (security-enclave extension).
// Checks both directions independently: STATUS rx_valid / tx_full, data
// delivered once and in order, RX read empties the channel, RX of an empty
// channel reads 0x00, a write into a full channel is discarded and sets the
// sticky overflow bit, simultaneous traffic in both directions, address
// decode 0x60-0x63 only, never ready without a request, and reset.

`timescale 1ns/1ps

module tb_cpu_mailbox;

    reg        clk = 0, rst_n = 0;
    reg  [7:0] a_port = 0, a_wdata = 0, b_port = 0, b_wdata = 0;
    reg        a_rd = 0, a_wr = 0, b_rd = 0, b_wr = 0;
    wire [7:0] a_rdata, b_rdata;
    wire       a_ready, b_ready, a_sel, b_sel;

    cpu_mailbox #(.BASE(8'h60)) dut (.clk(clk), .rst_n(rst_n),
        .a_port(a_port), .a_wdata(a_wdata), .a_rd(a_rd), .a_wr(a_wr),
        .a_rdata(a_rdata), .a_ready(a_ready), .a_sel(a_sel),
        .b_port(b_port), .b_wdata(b_wdata), .b_rd(b_rd), .b_wr(b_wr),
        .b_rdata(b_rdata), .b_ready(b_ready), .b_sel(b_sel));

    always #5 clk = ~clk;

    integer errors = 0, k, p;
    reg [7:0] got;

    task fail(input [511:0] msg);
        begin errors = errors + 1; if (errors < 20) $display("  ERROR: %0s", msg); end
    endtask

    // single-cycle accesses (the mailbox is always ready)
    task a_write(input [7:0] pt, input [7:0] d);
        begin @(negedge clk); a_port = pt; a_wdata = d; a_wr = 1; #1;
              if (!a_ready) fail("A write not ready"); @(negedge clk); a_wr = 0; end
    endtask
    task b_write(input [7:0] pt, input [7:0] d);
        begin @(negedge clk); b_port = pt; b_wdata = d; b_wr = 1; #1;
              if (!b_ready) fail("B write not ready"); @(negedge clk); b_wr = 0; end
    endtask
    task a_read(input [7:0] pt, output [7:0] d);
        begin @(negedge clk); a_port = pt; a_rd = 1; #1; d = a_rdata;
              if (!a_ready) fail("A read not ready"); @(negedge clk); a_rd = 0; end
    endtask
    task b_read(input [7:0] pt, output [7:0] d);
        begin @(negedge clk); b_port = pt; b_rd = 1; #1; d = b_rdata;
              if (!b_ready) fail("B read not ready"); @(negedge clk); b_rd = 0; end
    endtask
    task expect_a(input [7:0] pt, input [7:0] e, input [511:0] what);
        begin a_read(pt, got); if (got !== e) begin fail(what); $display("     A got %02h expected %02h", got, e); end end
    endtask
    task expect_b(input [7:0] pt, input [7:0] e, input [511:0] what);
        begin b_read(pt, got); if (got !== e) begin fail(what); $display("     B got %02h expected %02h", got, e); end end
    endtask

    initial begin
        repeat (3) @(negedge clk); rst_n = 1;

        for (p = 0; p < 256; p = p + 1) begin
            a_port = p; b_port = p; #1;
            if (a_ready || b_ready) fail("ready without request");
            if (a_sel !== (p >= 8'h60 && p <= 8'h63)) fail("A sel decode");
            if (b_sel !== (p >= 8'h60 && p <= 8'h63)) fail("B sel decode");
        end

        expect_a(8'h62, 8'h00, "A status after reset");
        expect_b(8'h62, 8'h00, "B status after reset");
        expect_b(8'h61, 8'h00, "B RX of empty channel");

        // A -> B
        a_write(8'h60, 8'h4B);
        expect_a(8'h62, 8'h02, "A tx_full after send");
        expect_b(8'h62, 8'h01, "B rx_valid after A send");
        expect_b(8'h61, 8'h4B, "B receives A's byte");
        expect_b(8'h62, 8'h00, "B rx_valid cleared by read");
        expect_a(8'h62, 8'h00, "A tx_full cleared by B read");
        expect_b(8'h61, 8'h00, "byte delivered only once");

        // overflow: second write into a full channel is discarded
        a_write(8'h60, 8'h11);
        a_write(8'h60, 8'h22);
        expect_a(8'h62, 8'h06, "A overflow + tx_full");
        expect_b(8'h61, 8'h11, "first byte kept, second discarded");

        // B -> A, and both directions at the same time
        b_write(8'h60, 8'hC3);
        expect_a(8'h62, 8'h05, "A rx_valid (overflow still sticky)");
        expect_a(8'h61, 8'hC3, "A receives B's byte");
        fork
            a_write(8'h60, 8'h5A);
            b_write(8'h60, 8'hA5);
        join
        fork
            expect_b(8'h61, 8'h5A, "simultaneous A->B");
            expect_a(8'h61, 8'hA5, "simultaneous B->A");
        join

        // in-order stream of 50 bytes with polling, like the programs do
        for (k = 0; k < 50; k = k + 1) begin
            a_write(8'h60, k * 7);
            expect_b(8'h61, k * 7, "stream byte");
        end

        // reset clears data, flags and overflow
        a_write(8'h60, 8'h99);
        @(negedge clk); rst_n = 0; @(negedge clk); rst_n = 1;
        expect_a(8'h62, 8'h00, "A status after second reset");
        expect_b(8'h62, 8'h00, "B status after second reset");

        if (errors == 0) $display("TESTBENCH: PASS");
        else             $display("TESTBENCH: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
