// dsd8_cpu.v -- the processor core: fetch, decode, execute, writeback
// Owner: shared (whole team integrates this together)
// Spec: Section 5.2. Port list is FROZEN -- tb_dsd8.v binds to these
// exact names to extract the execution trace (Section 8.3). Renaming
// any of them means the harness will not compile against your design.
//
// retire_* are not debug decoration -- they are how your processor is
// graded (Section 8.2). Get them right early.

module dsd8_cpu (
    input  wire        clk,
    input  wire        rst_n,

    // ---- instruction fetch interface ----
    output wire [8:0]  imem_addr,   // program counter
    input  wire [15:0] imem_data,   // instruction word, valid combinationally

    // ---- I/O bus (Section 7) ----
    output wire [7:0]  io_port,     // port number from IR[7:0]
    output wire [7:0]  io_wdata,    // data for OUT
    input  wire [7:0]  io_rdata,    // data for IN
    output wire        io_rd,       // asserted for one access during IN
    output wire        io_wr,       // asserted for one access during OUT
    input  wire        io_ready,    // peripheral ready; low stalls the CPU

    // ---- status and trace ----
    output wire        halted,
    output wire        retire,          // one pulse per retired instruction
    output wire [8:0]  retire_pc,       // PC of the instruction just retired
    output wire [15:0] retire_ir,       // its instruction word
    output wire        retire_rf_we,    // did it write a register?
    output wire [2:0]  retire_rf_addr,
    output wire [7:0]  retire_rf_data,
    output wire        retire_mem_we,   // did it write data memory?
    output wire [7:0]  retire_mem_addr,
    output wire [7:0]  retire_mem_data,
    output wire [3:0]  retire_flags     // {Z,N,C,V} after the instruction
);

    // =====================================================================
    // Core integration. instr_memory and io_bus live one level up (tb_dsd8
    // for simulation, dsd8_top for the board); everything else is here,
    // plus four pieces of glue that belong to no single module
    // (doc/m1/microarchitecture.md):
    //   glue 1  write-back multiplexer
    //   glue 2  register read-port-2 select (ST / OUT data in bits 11:9)
    //   glue 3  IN / OUT qualification by io_dir
    //   glue 4  retire_* shaping (commit-cycle scheme, zero-forcing,
    //           flags bypass so field 10 shows the flags AFTER the instr)
    // =====================================================================

    localparam [3:0] OP_ST = 4'h3, OP_IO = 4'hE;

    // ---- decoder fields ----
    wire [3:0] opcode;
    wire [2:0] rd, rs1, rs2, cond;
    wire [7:0] imm8, port;
    wire [8:0] addr9;
    wire       io_dir;

    // ---- control ----
    wire       pc_en, pc_load, cu_rf_we, mem_we, cu_io_rd, cu_io_wr, flags_we;
    wire [1:0] wb_sel;
    wire       cu_retire;

    // ---- datapath ----
    wire [8:0] pc;
    wire [2:0] ra2;
    wire [7:0] rd1, rd2;
    reg  [7:0] wd;
    wire       rf_we;
    wire [7:0] alu_result;
    wire       alu_z, alu_n, alu_c, alu_v;
    wire [3:0] alu_flags = {alu_z, alu_n, alu_c, alu_v};
    wire [3:0] flags_out;
    wire [7:0] dmem_rdata;

    // ---------------------------------------------------------------- fetch
    prog_counter u_pc (
        .clk         (clk),
        .rst_n       (rst_n),
        .pc_en       (pc_en),
        .pc_load     (pc_load),
        .branch_addr (addr9),
        .pc          (pc)
    );
    assign imem_addr = pc;

    instr_decoder u_dec (
        .instr  (imem_data),
        .opcode (opcode),
        .rd     (rd),
        .rs1    (rs1),
        .rs2    (rs2),
        .imm8   (imm8),
        .addr9  (addr9),
        .cond   (cond),
        .port   (port),
        .io_dir (io_dir)
    );

    // ---------------------------------------------------------------- control
    control_unit u_cu (
        .clk      (clk),
        .rst_n    (rst_n),
        .opcode   (opcode),
        .cond     (cond),
        .flags    (flags_out),
        .io_ready (io_ready),
        .pc_en    (pc_en),
        .pc_load  (pc_load),
        .rf_we    (cu_rf_we),
        .mem_we   (mem_we),
        .io_rd    (cu_io_rd),
        .io_wr    (cu_io_wr),
        .flags_we (flags_we),
        .wb_sel   (wb_sel),
        .halted   (halted),
        .retire   (cu_retire)
    );

    // ---------------------------------------------------------------- execute
    // glue 2: read port 2 is rs2 for R-format, rd for ST and OUT (R18)
    assign ra2 = ((opcode == OP_ST) || (opcode == OP_IO)) ? rd : rs2;

    // glue 3: control_unit cannot see io_dir -- keep the right request, and
    // never write a register for OUT
    wire is_out = (opcode == OP_IO) && io_dir;
    assign io_rd = cu_io_rd & ~io_dir;
    assign io_wr = cu_io_wr &  io_dir;
    assign rf_we = cu_rf_we & ~is_out;

    register_file u_rf (
        .clk   (clk),
        .rst_n (rst_n),
        .ra1   (rs1),
        .ra2   (ra2),
        .rd1   (rd1),
        .rd2   (rd2),
        .we    (rf_we),
        .wa    (rd),
        .wd    (wd)
    );

    alu u_alu (
        .a      (rd1),
        .b      (rd2),
        .op     (opcode),
        .result (alu_result),
        .flag_z (alu_z),
        .flag_n (alu_n),
        .flag_c (alu_c),
        .flag_v (alu_v)
    );

    flags_reg u_flags (
        .clk       (clk),
        .rst_n     (rst_n),
        .flags_we  (flags_we),
        .flags_in  (alu_flags),
        .flags_out (flags_out)
    );

    data_memory u_dmem (
        .clk   (clk),
        .addr  (rd1),          // address = contents of rs1, never the register number
        .we    (mem_we),
        .wdata (rd2),          // data = R[rd] through ra2 select
        .rdata (dmem_rdata)
    );

    // glue 1: write-back multiplexer (encoding fixed by control_unit.wb_sel)
    always @(*) begin
        case (wb_sel)
            2'd0:    wd = alu_result;
            2'd1:    wd = dmem_rdata;
            2'd2:    wd = imm8;
            default: wd = io_rdata;
        endcase
    end

    // ---------------------------------------------------------------- I/O bus
    assign io_port  = port;
    assign io_wdata = rd2;     // R[rd] for OUT

    // ---------------------------------------------------------------- retire (glue 4)
    // Commit-cycle scheme: retire is high in the cycle whose rising edge
    // commits the instruction; PC and imem_data still describe it, so all
    // ten trace values are taken live in that cycle.
    assign retire          = cu_retire;
    assign retire_pc       = pc;
    assign retire_ir       = imem_data;
    assign retire_rf_we    = rf_we;
    assign retire_rf_addr  = rf_we  ? rd   : 3'd0;     // R23 zero-forcing
    assign retire_rf_data  = rf_we  ? wd   : 8'h00;
    assign retire_mem_we   = mem_we;
    assign retire_mem_addr = mem_we ? rd1  : 8'h00;
    assign retire_mem_data = mem_we ? rd2  : 8'h00;
    // flags_reg updates at the same edge the trace is sampled, so show the
    // ALU's new flags when this instruction writes them
    assign retire_flags    = flags_we ? alu_flags : flags_out;

endmodule
