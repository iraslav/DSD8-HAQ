// data_memory.v -- 256 x 8 read/write memory
// Owner: member C -- this is YOUR module; you are individually examined
// on it at the oral defence.
// Spec: Section 5.9. Port list is FROZEN -- note that it has no rst_n
// of its own, unlike every other stateful module in this design.
//
// R16: all 256 bytes shall clear to 0x00 by reset, so a read of a
// never-written location returns 0x00, not X. Test T09 checks this
// deliberately.
//
// Because this module has no reset input, "cleared by reset" has to
// come from somewhere else -- that is a genuine design decision worth
// recording in your design report (Section 9.3, item 4). Two
// legitimate answers: (a) initialise the memory array so it starts
// zeroed (works in every simulator, and on FPGA targets whose block
// RAM honours an initial value), or (b) have control_unit sequence 256
// writes of 0x00 through the ordinary we/addr/wdata ports before
// fetching the first real instruction. This stub does neither yet --
// choose one and implement it.

module data_memory (
    input  wire       clk,
    input  wire [7:0] addr,
    input  wire       we,
    input  wire [7:0] wdata,
    output wire [7:0] rdata     // combinational read
);

    reg [7:0] mem [0:255];
    integer i;

    // R16 / R6 -- "cleared by reset" without a reset port: design decision
    // (a) from the stub. The array is initialised to 0x00 at time zero,
    // which every simulator honours and which FPGA block/distributed RAM
    // honours as its configuration value. Recorded in doc/design_report.md
    // (decision D3) together with its limitation: a second reset during a
    // run does not re-clear the memory.
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            mem[i] = 8'h00;
        end
    end

    // synchronous write (ST commits at the rising edge ending its commit cycle)
    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= wdata;
        end
    end

    // combinational read, so LD completes in the cycle its address is valid
    assign rdata = mem[addr];

endmodule
