// alu.v -- arithmetic, logic, shifts, and the four flag outputs
// Ownwer: Hitesh Kumar
// requires a constrained-random self-checking testbench for.
// Spec: Section 5.7 and Section 2.3. Purely combinational. Port list
// is FROZEN. `op` is the instruction opcode directly (R15) -- no
// separate ALU-control encoding needed.
//
// Verified by tb/tb_alu_example.v (directed) and tb/tb_alu_random.v
// (96 000 constrained-random pairs with corner coverage, R24/R25).

module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [3:0] op,     // instruction opcode: 0x4 ADD .. 0xB CMP
    output wire [7:0] result,
    output wire       flag_z,
    output wire       flag_n,
    output wire       flag_c,
    output wire       flag_v
);

    // ---- opcode decode (op is the instruction opcode directly, R15) ----
    localparam [3:0] OP_ADD = 4'h4, OP_SUB = 4'h5, OP_AND = 4'h6, OP_OR  = 4'h7,
                     OP_XOR = 4'h8, OP_SHL = 4'h9, OP_SHR = 4'hA, OP_CMP = 4'hB;

    // ---- the single 9-bit adder shared by ADD, SUB and CMP (R15, §2.3.1) ----
    //   ADD:      {carry, sum} = a + b    + 0
    //   SUB/CMP:  {carry, sum} = a + (~b) + 1     -> carry = 1 means NO borrow
    wire       subtract = (op == OP_SUB) || (op == OP_CMP);
    wire [7:0] b_eff    = subtract ? ~b : b;
    wire [8:0] sum9     = {1'b0, a} + {1'b0, b_eff} + {8'h00, subtract};

    // overflow (§2.3.2): operands of the same effective sign, result of the
    // other sign. Using b_eff covers both rows of the spec's table at once:
    //   ADD: a[7]==b[7]  && r[7]!=a[7]      SUB: a[7]!=b[7] && r[7]!=a[7]
    wire       add_ovf  = (a[7] == b_eff[7]) && (sum9[7] != a[7]);

    reg  [7:0] res;
    reg        c, v;

    always @(*) begin
        res = 8'h00;
        c   = 1'b0;
        v   = 1'b0;
        case (op)
            OP_ADD, OP_SUB, OP_CMP: begin
                res = sum9[7:0];
                c   = sum9[8];
                v   = add_ovf;
            end
            OP_AND: res = a & b;                       // C = V = 0
            OP_OR:  res = a | b;
            OP_XOR: res = a ^ b;
            OP_SHL: begin res = {a[6:0], 1'b0}; c = a[7]; end   // V = 0
            OP_SHR: begin res = {1'b0, a[7:1]}; c = a[0]; end   // logical: 0 into bit 7
            default: begin res = 8'h00; c = 1'b0; v = 1'b0; end // not an ALU op: don't care
        endcase
    end

    assign result = res;
    assign flag_z = (res == 8'h00);
    assign flag_n = res[7];
    assign flag_c = c;
    assign flag_v = v;

endmodule
