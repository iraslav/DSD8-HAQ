// btn_debounce.v -- synchroniser + debouncer for the five push buttons
// Owner: shared (board build only). Port 0x01 is specified as "already
// debounced" (spec §7.2), so dsd8_top debounces before the I/O bus sees it.
// A button's output changes only after its synchronised input has been
// stable for 2^CNT_BITS clock cycles (2^20 / 100 MHz ~ 10 ms).

module btn_debounce #(
    parameter integer WIDTH    = 5,
    parameter integer CNT_BITS = 20
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] raw,
    output reg  [WIDTH-1:0] clean
);

    reg [WIDTH-1:0] sync0, sync1;
    reg [CNT_BITS-1:0] cnt [0:WIDTH-1];
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            sync0 <= {WIDTH{1'b0}};
            sync1 <= {WIDTH{1'b0}};
            clean <= {WIDTH{1'b0}};
            for (i = 0; i < WIDTH; i = i + 1) cnt[i] <= {CNT_BITS{1'b0}};
        end else begin
            sync0 <= raw;
            sync1 <= sync0;
            for (i = 0; i < WIDTH; i = i + 1) begin
                if (sync1[i] == clean[i]) begin
                    cnt[i] <= {CNT_BITS{1'b0}};
                end else if (&cnt[i]) begin
                    clean[i] <= sync1[i];
                    cnt[i]   <= {CNT_BITS{1'b0}};
                end else begin
                    cnt[i] <= cnt[i] + 1'b1;
                end
            end
        end
    end

endmodule
