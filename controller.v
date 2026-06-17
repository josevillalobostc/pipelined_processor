module controller(input        clk, reset,
                  input        FlushE,       // Pipeline clear signal from hazard unit

                  // Decode stage inputs (from instruction in D stage)
                  input  [6:0] op,
                  input  [2:0] funct3,
                  input        funct7b5,

                  // D-stage outputs (combinational from decoders)
                  output [1:0] ResultSrcD,
                  output       MemWriteD,
                  output       ALUSrcD,
                  output       RegWriteD, JumpD, BranchD,
                  output       PCTargetSrcD,
                  output [2:0] ImmSrcD,
                  output [3:0] ALUControlD,

                  // E-stage outputs (pipeline registered)
                  output [1:0] ResultSrcE,
                  output       MemWriteE,
                  output       ALUSrcE,
                  output       RegWriteE, JumpE, BranchE,
                  output       PCTargetSrcE,
                  output [3:0] ALUControlE,

                  // M-stage outputs (pipeline registered)
                  output [1:0] ResultSrcM,
                  output       MemWriteM,
                  output       RegWriteM,

                  // W-stage outputs (pipeline registered)
                  output [1:0] ResultSrcW,
                  output       RegWriteW);

  wire [1:0] ALUOp;

  // D-stage decoders (combinational)
  maindec md(
    .op          (op),
    .ResultSrcD  (ResultSrcD),
    .MemWriteD   (MemWriteD),
    .BranchD     (BranchD),
    .ALUSrcD     (ALUSrcD),
    .RegWriteD   (RegWriteD),
    .JumpD       (JumpD),
    .PCTargetSrcD(PCTargetSrcD),
    .ImmSrcD     (ImmSrcD),
    .ALUOp       (ALUOp)
  );

  aludec ad(
    .opb5       (op[5]),
    .funct3     (funct3),
    .funct7b5   (funct7b5),
    .ALUOp      (ALUOp),
    .ALUControlD(ALUControlD)
  );

  // ─── ID/EX pipeline register (control signals) ───────────────────────────
  // Bits: RegWriteD(1)+ResultSrcD(2)+MemWriteD(1)+JumpD(1)+BranchD(1)+
  //       ALUSrcD(1)+ALUControlD(4)+PCTargetSrcD(1) = 12 bits
  wire [11:0] ctrlDE;

  flop_encl #(12) IDEX_ctrl(
    .clk   (clk),
    .reset (reset),
    .enable(1'b1),
    .clear (FlushE),
    .d     ({RegWriteD, ResultSrcD, MemWriteD, JumpD,
             BranchD,  ALUSrcD,    ALUControlD, PCTargetSrcD}),
    .q     (ctrlDE)
  );

  assign {RegWriteE, ResultSrcE, MemWriteE, JumpE,
          BranchE,  ALUSrcE,    ALUControlE, PCTargetSrcE} = ctrlDE;

  // ─── EX/MEM pipeline register (control signals) ──────────────────────────
  // Bits: RegWriteE(1)+ResultSrcE(2)+MemWriteE(1) = 4 bits
  wire [3:0] ctrlEM;

  flopr #(4) EXMEM_ctrl(
    .clk  (clk),
    .reset(reset),
    .d    ({RegWriteE, ResultSrcE, MemWriteE}),
    .q    (ctrlEM)
  );

  assign {RegWriteM, ResultSrcM, MemWriteM} = ctrlEM;

  // ─── MEM/WB pipeline register (control signals) ──────────────────────────
  // Bits: RegWriteM(1)+ResultSrcM(2) = 3 bits
  wire [2:0] ctrlMW;

  flopr #(3) MEMWB_ctrl(
    .clk  (clk),
    .reset(reset),
    .d    ({RegWriteM, ResultSrcM}),
    .q    (ctrlMW)
  );

  assign {RegWriteW, ResultSrcW} = ctrlMW;

endmodule
