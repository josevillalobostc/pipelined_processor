module controller(input  [6:0] op,
                  input  [2:0] funct3,
                  input        funct7b5,
                  // -- Señales de salida etapa D (Decode) --
                  output [1:0] ResultSrcD,
                  output       MemWriteD,
                  output       ALUSrcD,
                  output       RegWriteD, JumpD, BranchD,
                  output       PCTargetSrcD,
                  output [2:0] ImmSrcD,
                  output [3:0] ALUControlD);

  // PCSrc ya NO se genera aquí. Se calcula en el datapath (etapa E)
  // usando BranchD, JumpD y las flags de la ALU (Zero, Negative, Overflow).
  // Zero/Negative/Overflow ya no son entradas del controller.

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

endmodule
