module riscvsingle(input         clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output        MemWrite,    // = MemWriteD (sin registros pipeline aún)
                   output [31:0] DataAdr,
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  wire [31:0] ALUResult;

  // -- Señales de etapa D (salen del Control Unit) --
  wire        ALUSrcD, PCTargetSrcD, RegWriteD, JumpD, BranchD;
  wire [1:0]  ResultSrcD;
  wire [2:0]  ImmSrcD;
  wire [3:0]  ALUControlD;
  // MemWriteD conectado directamente al puerto MemWrite del módulo
  // (en el pipeline completo esto pasaría por registros hasta etapa M)

  assign DataAdr = ALUResult;

  controller c(
    .op          (Instr[6:0]),
    .funct3      (Instr[14:12]),
    .funct7b5    (Instr[30]),
    // -- Salidas D --
    .ResultSrcD  (ResultSrcD),
    .MemWriteD   (MemWrite),       // puerto externo MemWrite toma el valor de MemWriteD
    .ALUSrcD     (ALUSrcD),
    .RegWriteD   (RegWriteD),
    .JumpD       (JumpD),
    .BranchD     (BranchD),
    .PCTargetSrcD(PCTargetSrcD),
    .ImmSrcD     (ImmSrcD),
    .ALUControlD (ALUControlD)
  );

  datapath dp(
    .clk         (clk),
    .reset       (reset),
    // -- Señales de control D --
    .ResultSrcD  (ResultSrcD),
    .ALUSrcD     (ALUSrcD),
    .PCTargetSrcD(PCTargetSrcD),
    .RegWriteD   (RegWriteD),
    .BranchD     (BranchD),
    .JumpD       (JumpD),
    .ImmSrcD     (ImmSrcD),
    .ALUControlD (ALUControlD),
    // -- Interfaz con memorias --
    .PC          (PC),
    .Instr       (Instr),
    .ALUResult   (ALUResult),
    .WriteData   (WriteData),
    .ReadData    (ReadData)
  );

endmodule
