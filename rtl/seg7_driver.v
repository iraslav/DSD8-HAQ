// seg7_driver.v -- four-digit multiplexed seven-segment driver (board only)
// Owner: shared (part of the dsd8_top board build; not used by conformance).
// Shows SEG_VALUE (port 0x10) in hexadecimal: digit 0 = low nibble,
// digit 1 = high nibble, digits 2 and 3 show 0. SEG_ENABLE (port 0x11)
// bit n enables digit n; 0x00 blanks the display (spec §7.2).
// Outputs are active low (common-anode displays, e.g. Basys 3).

module seg7_driver #(
    parameter integer REFRESH_BITS = 17      // 2^17 / 100 MHz ~ 1.3 ms per digit
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] value,
    input  wire [7:0] enable,
    output reg  [6:0] seg,                   // {g,f,e,d,c,b,a}, active low
    output reg  [3:0] an                     // digit enables, active low
);

    reg [REFRESH_BITS-1:0] refresh;
    always @(posedge clk) begin
        if (!rst_n) refresh <= {REFRESH_BITS{1'b0}};
        else        refresh <= refresh + 1'b1;
    end

    wire [1:0] digit = refresh[REFRESH_BITS-1:REFRESH_BITS-2];

    reg [3:0] nibble;
    always @(*) begin
        case (digit)
            2'd0:    nibble = value[3:0];
            2'd1:    nibble = value[7:4];
            default: nibble = 4'h0;
        endcase
    end

    always @(*) begin
        an = 4'b1111;
        if (enable[{1'b0, digit}]) an[digit] = 1'b0;
    end

    always @(*) begin
        case (nibble)                          //  gfedcba
            4'h0: seg = 7'b1000000;  4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;  4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;  4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;  4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;  4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;  4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;  4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;  default: seg = 7'b0001110;  // F
        endcase
    end

    // verilator lint_off UNUSEDSIGNAL
    wire unused_enable_hi = &{1'b0, enable[7:4]};
    // verilator lint_on UNUSEDSIGNAL

endmodule
