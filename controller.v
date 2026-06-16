module controller(input        clk, reset,
                  input  [6:0] op,
                  input  [2:0] funct3,
                  input        funct7b5,

                  // ---- Etapa D (Decode) — salen de maindec / aludec ----
                  output [1:0] ResultSrcD,
                  output       MemWriteD,
                  output       ALUSrcD,
                  output       RegWriteD, JumpD, BranchD,
                  output       PCTargetSrcD,
                  output [2:0] ImmSrcD,
                  output [3:0] ALUControlD,

                  // ---- Etapa E (Execute) — tras registro ID/EX ----
                  output [1:0] ResultSrcE,
                  output       MemWriteE,
                  output       ALUSrcE,
                  output       RegWriteE, JumpE, BranchE,
                  output       PCTargetSrcE,
                  output [3:0] ALUControlE,

                  // ---- Etapa M (Memory) — tras registro EX/MEM ----
                  output [1:0] ResultSrcM,
                  output       MemWriteM,
                  output       RegWriteM,

                  // ---- Etapa W (Writeback) — tras registro MEM/WB ----
                  output [1:0] ResultSrcW,
                  output       RegWriteW);

  wire [1:0] ALUOp;

  // ============================================================
  // Etapa D: maindec + aludec generan las señales originales
  // ============================================================
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

  // ============================================================
  // Registro ID/EX — D → E
  // Bundle (12 bits):
  //   RegWriteD(1) + ResultSrcD(2) + MemWriteD(1) + JumpD(1)
  //   + BranchD(1) + ALUSrcD(1) + ALUControlD(4) + PCTargetSrcD(1)
  // ============================================================
  wire [11:0] ctrlDE;

  flopr #(12) IDEX_ctrl(
    .clk  (clk),
    .reset(reset),
    .d    ({RegWriteD, ResultSrcD, MemWriteD, JumpD,
            BranchD,  ALUSrcD,    ALUControlD, PCTargetSrcD}),
    .q    (ctrlDE)
  );

  assign {RegWriteE, ResultSrcE, MemWriteE, JumpE,
          BranchE,  ALUSrcE,    ALUControlE, PCTargetSrcE} = ctrlDE;

  // ============================================================
  // Registro EX/MEM — E → M
  // Bundle (4 bits):
  //   RegWriteE(1) + ResultSrcE(2) + MemWriteE(1)
  // (JumpE, BranchE, ALUSrcE, ALUControlE, PCTargetSrcE solo
  //  se usan en etapa E y se descartan aquí)
  // ============================================================
  wire [3:0] ctrlEM;

  flopr #(4) EXMEM_ctrl(
    .clk  (clk),
    .reset(reset),
    .d    ({RegWriteE, ResultSrcE, MemWriteE}),
    .q    (ctrlEM)
  );

  assign {RegWriteM, ResultSrcM, MemWriteM} = ctrlEM;

  // ============================================================
  // Registro MEM/WB — M → W
  // Bundle (3 bits):
  //   RegWriteM(1) + ResultSrcM(2)
  // (MemWriteM solo se usa en etapa M)
  // ============================================================
  wire [2:0] ctrlMW;

  flopr #(3) MEMWB_ctrl(
    .clk  (clk),
    .reset(reset),
    .d    ({RegWriteM, ResultSrcM}),
    .q    (ctrlMW)
  );

  assign {RegWriteW, ResultSrcW} = ctrlMW;

endmodule
