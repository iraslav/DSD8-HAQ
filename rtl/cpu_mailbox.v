// cpu_mailbox.v -- byte mailbox between two DSD-8 processors (extension)
// (named cpu_mailbox because "mailbox" is a SystemVerilog keyword)
// Owner: shared (security-enclave extension; not part of the frozen DSD-8 core).
//
// Two one-byte channels, A->B and B->A. Each processor sees its own endpoint
// at the same port addresses (BASE = 0x60 by default):
//   +0 TX      w   send a byte to the other processor. Accepted only if the
//                  channel is empty; a write while full is discarded and sets
//                  the sticky overflow flag.
//   +1 RX      r   the received byte (0x00 if none); reading it empties the
//                  channel so the other side may send again
//   +2 STATUS  r   {5'b0, overflow, tx_full, rx_valid}
//   +3         -   reads 0x00
// Every access completes immediately (ready = request): the mailbox never
// stalls a processor, so waiting is done by polling STATUS (spec R21 forbids
// holding io_ready low indefinitely, and the partner may never send).

module cpu_mailbox #(
    parameter [7:0] BASE = 8'h60
) (
    input  wire       clk,
    input  wire       rst_n,
    // ---- endpoint A ----
    input  wire [7:0] a_port,
    input  wire [7:0] a_wdata,
    input  wire       a_rd,
    input  wire       a_wr,
    output wire [7:0] a_rdata,
    output wire       a_ready,
    output wire       a_sel,
    // ---- endpoint B ----
    input  wire [7:0] b_port,
    input  wire [7:0] b_wdata,
    input  wire       b_rd,
    input  wire       b_wr,
    output wire [7:0] b_rdata,
    output wire       b_ready,
    output wire       b_sel
);

    reg [7:0] ab_data, ba_data;          // A->B and B->A
    reg       ab_valid, ba_valid;
    reg       a_ovf, b_ovf;

    assign a_sel   = (a_port[7:2] == BASE[7:2]);
    assign b_sel   = (b_port[7:2] == BASE[7:2]);
    assign a_ready = a_sel & (a_rd | a_wr);
    assign b_ready = b_sel & (b_rd | b_wr);

    wire a_tx = a_ready & a_wr & (a_port[1:0] == 2'd0);
    wire a_rx = a_ready & a_rd & (a_port[1:0] == 2'd1);
    wire b_tx = b_ready & b_wr & (b_port[1:0] == 2'd0);
    wire b_rx = b_ready & b_rd & (b_port[1:0] == 2'd1);

    function [7:0] rmux(input [1:0] idx, input [7:0] rx_data, input rx_valid,
                        input tx_full, input ovf);
        case (idx)
            2'd1:    rmux = rx_valid ? rx_data : 8'h00;
            2'd2:    rmux = {5'b00000, ovf, tx_full, rx_valid};
            default: rmux = 8'h00;
        endcase
    endfunction

    assign a_rdata = (a_ready & a_rd) ? rmux(a_port[1:0], ba_data, ba_valid, ab_valid, a_ovf) : 8'h00;
    assign b_rdata = (b_ready & b_rd) ? rmux(b_port[1:0], ab_data, ab_valid, ba_valid, b_ovf) : 8'h00;

    always @(posedge clk) begin
        if (!rst_n) begin
            ab_data <= 8'h00;  ba_data <= 8'h00;
            ab_valid <= 1'b0;  ba_valid <= 1'b0;
            a_ovf <= 1'b0;     b_ovf <= 1'b0;
        end else begin
            // A -> B  (a write is accepted only into an empty channel and a
            //          read only empties a full one, so they never collide)
            if (a_tx) begin
                if (!ab_valid) begin ab_data <= a_wdata; ab_valid <= 1'b1; end
                else           a_ovf <= 1'b1;
            end else if (b_rx && ab_valid) begin
                ab_valid <= 1'b0;
            end
            // B -> A
            if (b_tx) begin
                if (!ba_valid) begin ba_data <= b_wdata; ba_valid <= 1'b1; end
                else           b_ovf <= 1'b1;
            end else if (a_rx && ba_valid) begin
                ba_valid <= 1'b0;
            end
        end
    end

endmodule
