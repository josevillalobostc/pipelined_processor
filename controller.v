module controller(input        clk, reset,
                  input        FlushE,       // señal de limpieza del pipeline desde hazard

                  // entradas de la etapa de decodificación (etapa d)
                  input  [6:0] op,
                  input  [2:0] funct3,
                  input        funct7b5,

                  // salidas de la etapa d
                  output [1:0] ResultSrcD,
                  output       MemWriteD,
                  output       ALUSrcD,
                  output       RegWriteD, JumpD, BranchD,
                  output       PCTargetSrcD,
                  output [2:0] ImmSrcD,
                  output [3:0] ALUControlD,

                  // salidas de la etapa e
                  output [1:0] ResultSrcE,
                  output       MemWriteE,
                  output       ALUSrcE,
                  output       RegWriteE, JumpE, BranchE,
                  output       PCTargetSrcE,
                  output [3:0] ALUControlE,

                  // salidas de la etapa m
                  output [1:0] ResultSrcM,
                  output       MemWriteM,
                  output       RegWriteM,

                  // salidas de la etapa w
                  output [1:0] ResultSrcW,
                  output       RegWriteW);

  wire [1:0] ALUOp;

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

  // registro de pipeline id/ex
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

  // registro de pipeline ex/mem
  wire [3:0] ctrlEM;

  flopr #(4) EXMEM_ctrl(
    .clk  (clk),
    .reset(reset),
    .d    ({RegWriteE, ResultSrcE, MemWriteE}),
    .q    (ctrlEM)
  );

  assign {RegWriteM, ResultSrcM, MemWriteM} = ctrlEM;

  // registro de pipeline mem/wb
  wire [2:0] ctrlMW;

  flopr #(3) MEMWB_ctrl(
    .clk  (clk),
    .reset(reset),
    .d    ({RegWriteM, ResultSrcM}),
    .q    (ctrlMW)
  );

  assign {RegWriteW, ResultSrcW} = ctrlMW;

endmodule
