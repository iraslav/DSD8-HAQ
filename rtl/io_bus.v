// io_bus.v -- port address decode and the io_ready handshake
// Owner: member C -- this is YOUR module; you are individually examined
// on it at the oral defence.
// Spec: Section 7. The CPU-facing side of this module (the six signals
// wired to dsd8_cpu) is frozen by Section 7.1's signal table. The
// board/peripheral-facing side below is NOT dictated verbatim by the
// spec excerpts this template was built from -- treat those ports as a
// starting design, confirm them against your own course's Section 5.11
// if one exists, and adjust freely; unlike dsd8_cpu, no external
// testbench binds to io_bus's peripheral-facing ports by name.
//
// What is required (Section 7.1, R19-R21): decode io_port into the
// right peripheral, forward io_rd/io_wr and stall the CPU (by holding
// io_ready low) until the addressed peripheral is ready. Ports 0x00 to
// 0x3F are reserved and behave exactly per Section 7.2's table; reads
// of an unmapped port return 0x00, writes to one are discarded, and no
// port may ever hold io_ready low indefinitely.

module io_bus (
    input  wire        clk,
    input  wire        rst_n,

    // ---- CPU-facing side: matches dsd8_cpu's io_* ports exactly ----
    input  wire [7:0]  io_port,
    input  wire [7:0]  io_wdata,
    output wire [7:0]  io_rdata,
    input  wire        io_rd,
    input  wire        io_wr,
    output wire        io_ready,

    // ---- board-facing side (Section 7.2 standard port map) ----
    input  wire [7:0]  switches,     // port 0x00
    input  wire [4:0]  buttons,      // port 0x01
    output reg  [7:0]  leds,         // port 0x02
    output reg  [7:0]  seg_value,    // port 0x10
    output reg  [7:0]  seg_enable,   // port 0x11

    // ---- forwarded to sim/peripherals.v for UART / timer / SLOW_ECHO ----
    output wire [7:0]  periph_port,
    output wire [7:0]  periph_wdata,
    input  wire [7:0]  periph_rdata,
    output wire        periph_rd,
    output wire        periph_wr,
    input  wire        periph_ready
);


    // Ports 0x00-0x1F are decoded here (switches, buttons, LEDs, 7-seg);
    // every port from 0x20 up is forwarded to the peripheral side
    // (sim/peripherals.v in simulation: UART 0x20-0x22, timer 0x30-0x31,
    // SLOW_ECHO 0x40; unmapped ports there read 0x00 and never stall).
    wire request = io_rd | io_wr;
    wire is_ext  = (io_port >= 8'h20);

    // ---- forwarded requests: only for the external range ----
    assign periph_port  = io_port;
    assign periph_wdata = io_wdata;
    assign periph_rd    = io_rd & is_ext;
    assign periph_wr    = io_wr & is_ext;

    // ---- local read data (unmapped / write-only ports read 0x00, R21) ----
    reg [7:0] local_rdata;
    always @(*) begin
        case (io_port)
            8'h00:   local_rdata = switches;
            8'h01:   local_rdata = {3'b000, buttons};
            default: local_rdata = 8'h00;
        endcase
    end

    // ---- handshake (R19-R21) ----
    // Local ports complete in the cycle they are requested; external ports
    // complete when the peripheral says so. io_ready is never asserted
    // without an active request (R20), and no local port ever stalls.
    assign io_ready = is_ext ? (request & periph_ready) : request;
    assign io_rdata = (io_rd & io_ready) ? (is_ext ? periph_rdata : local_rdata) : 8'h00;

    // ---- latched output registers: written at the edge that completes OUT ----
    wire local_write = io_wr & ~is_ext;   // local ports are always ready
    always @(posedge clk) begin
        if (!rst_n) begin
            leds       <= 8'h00;
            seg_value  <= 8'h00;
            seg_enable <= 8'h00;
        end else if (local_write) begin
            case (io_port)
                8'h02:   leds       <= io_wdata;
                8'h10:   seg_value  <= io_wdata;
                8'h11:   seg_enable <= io_wdata;
                default: ;                       // write to unmapped port: discarded
            endcase
        end
    end

endmodule
