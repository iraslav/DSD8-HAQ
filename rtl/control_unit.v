// control_unit.v -- the FSM that sequences every instruction
// Owner: member C -- this is YOUR module; you are individually examined
// on it at the oral defence, and it is the heart of your microarchitecture
// choice (Section 4.3).
// Spec: Section 6. Port list is FROZEN.
//
// Microarchitecture: multi-cycle FSM, 3 cycles per instruction plus any
// io_ready stall cycles for IN/OUT (doc/m1/microarchitecture.md).
// Verified by tb/tb_control_unit.v and the conformance suite.
//
// What every implementation must guarantee, regardless of style
// (Section 8.2, R22): instructions retire in program order, and
// `retire` pulses exactly once per retired instruction -- never zero,
// never twice.

module control_unit (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] opcode,
    input  wire [2:0] cond,
    input  wire [3:0] flags,      // {Z,N,C,V}
    input  wire       io_ready,
    output reg        pc_en,
    output reg        pc_load,
    output reg        rf_we,
    output reg        mem_we,
    output reg        io_rd,
    output reg        io_wr,
    output reg        flags_we,
    output reg  [1:0] wb_sel,     // 0=ALU 1=DMEM 2=imm8 3=io_rdata
    output reg        halted,
    output reg        retire
);

    // =====================================================================
    // Multi-cycle FSM, three-process style (state register / next state /
    // outputs). See doc/m1/microarchitecture.md for the diagram and
    // doc/m1/control_signal_table.md for the full table.
    //
    //   FETCH -> EXECUTE -> WRITEBACK -> FETCH          every non-I/O instr
    //   FETCH -> EXECUTE -> MEM_IO (stall) -> FETCH     IN / OUT
    //   ... WRITEBACK (HLT) -> HALTED (forever)
    //
    // The PC is held on the executing instruction until its commit cycle,
    // so the decoder's fields are valid in every state. All enables are 0
    // except in the commit cycle; retire is 1 in exactly that cycle.
    // =====================================================================

    localparam [2:0] S_FETCH   = 3'd0,
                     S_EXECUTE = 3'd1,
                     S_WB      = 3'd2,
                     S_MEMIO   = 3'd3,
                     S_HALTED  = 3'd4;

    // (opcodes 0x0 NOP and 0x5-0x9 need no name: they only appear inside
    //  the ADD..SHR / ADD..CMP ranges below or produce no enables at all)
    localparam [3:0] OP_LDI = 4'h1, OP_LD  = 4'h2, OP_ST  = 4'h3, OP_ADD = 4'h4,
                     OP_SHR = 4'hA, OP_CMP = 4'hB, OP_JMP = 4'hC, OP_BCC = 4'hD,
                     OP_IO  = 4'hE, OP_HLT = 4'hF;

    reg [2:0] state, next_state;

    // ---- process 1: state register (synchronous, active-low reset) ----
    always @(posedge clk) begin
        if (!rst_n) state <= S_FETCH;
        else        state <= next_state;
    end

    // ---- branch decision: one flag selected by cond (§3.3, R17) ----
    wire flag_z = flags[3];
    wire flag_n = flags[2];
    wire flag_c = flags[1];
    wire flag_v = flags[0];
    reg  taken;
    always @(*) begin
        case (cond)
            3'b000:  taken =  flag_z;   // BEQ
            3'b001:  taken = ~flag_z;   // BNE
            3'b010:  taken =  flag_c;   // BCS  (C = 1: no borrow, unsigned >=)
            3'b011:  taken = ~flag_c;   // BCC
            3'b100:  taken =  flag_n;   // BMI
            3'b101:  taken = ~flag_n;   // BPL
            3'b110:  taken =  flag_v;   // BVS
            default: taken = ~flag_v;   // BVC (3'b111)
        endcase
    end

    // ---- instruction classes ----
    wire writes_reg  = (opcode == OP_LDI) || (opcode == OP_LD) ||
                       (opcode >= OP_ADD && opcode <= OP_SHR);         // not CMP
    wire sets_flags  = (opcode >= OP_ADD && opcode <= OP_CMP);         // the eight (R3)
    wire is_io       = (opcode == OP_IO);

    // ---- process 2: next-state logic ----
    always @(*) begin
        case (state)
            S_FETCH:   next_state = S_EXECUTE;
            S_EXECUTE: next_state = is_io ? S_MEMIO : S_WB;
            S_WB:      next_state = (opcode == OP_HLT) ? S_HALTED : S_FETCH;
            S_MEMIO:   next_state = io_ready ? S_FETCH : S_MEMIO;  // stall while not ready
            S_HALTED:  next_state = S_HALTED;
            default:   next_state = S_FETCH;
        endcase
    end

    // ---- process 3: output logic (combinational, assigned on every path) ----
    always @(*) begin
        pc_en    = 1'b0;
        pc_load  = 1'b0;
        rf_we    = 1'b0;
        mem_we   = 1'b0;
        io_rd    = 1'b0;
        io_wr    = 1'b0;
        flags_we = 1'b0;
        wb_sel   = 2'd0;
        halted   = 1'b0;
        retire   = 1'b0;

        case (state)
            S_WB: begin                       // commit cycle, non-I/O
                retire   = 1'b1;
                pc_en    = (opcode != OP_HLT);
                pc_load  = (opcode == OP_JMP) || ((opcode == OP_BCC) && taken);
                rf_we    = writes_reg;
                mem_we   = (opcode == OP_ST);
                flags_we = sets_flags;
                case (opcode)
                    OP_LDI:  wb_sel = 2'd2;   // imm8
                    OP_LD:   wb_sel = 2'd1;   // DMEM
                    default: wb_sel = 2'd0;   // ALU
                endcase
            end
            S_MEMIO: begin                    // I/O request held until io_ready (R11, R19)
                // No io_dir input on the frozen port list: request both
                // directions; dsd8_cpu keeps the one io_dir selects and
                // suppresses rf_we for OUT (glue 3).
                io_rd  = 1'b1;
                io_wr  = 1'b1;
                wb_sel = 2'd3;                // io_rdata
                rf_we  = io_ready;            // commit only when the transfer completes
                pc_en  = io_ready;
                retire = io_ready;
            end
            S_HALTED: begin
                halted = 1'b1;                // and nothing else, ever (R8, R9)
            end
            default: ;                        // FETCH, EXECUTE: nothing commits
        endcase
    end

endmodule
