module riscvsingle(input         clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output        MemWrite,    // conectado a MemWriteM del controller
                   output [31:0] DataAdr,
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  wire [31:0] ALUResult;

  // ---- Etapa D (solo ImmSrcD va al datapath) ----
  wire [2:0]  ImmSrcD;

  // ---- Etapa E ----
  wire        ALUSrcE, PCTargetSrcE, RegWriteE, JumpE, BranchE;
  wire [1:0]  ResultSrcE;
  wire [3:0]  ALUControlE;

  // ---- Etapa M ----
  wire        RegWriteM, MemWriteM;
  wire [1:0]  ResultSrcM;

  // ---- Etapa W ----
  wire        RegWriteW;
  wire [1:0]  ResultSrcW;

  // MemWrite (a la memoria de datos) toma el valor de etapa M
  assign DataAdr = ALUResult;
  assign MemWrite = MemWriteM;

  controller c(
    .clk         (clk),
    .reset       (reset),
    .op          (Instr[6:0]),
    .funct3      (Instr[14:12]),
    .funct7b5    (Instr[30]),
    // Salidas D (no conectan al datapath directamente; son internas al pipeline del controller)
    .ResultSrcD  (),
    .MemWriteD   (),
    .ALUSrcD     (),
    .RegWriteD   (),
    .JumpD       (),
    .BranchD     (),
    .PCTargetSrcD(),
    .ImmSrcD     (ImmSrcD),     // ← única señal D que usa el datapath (Extend)
    .ALUControlD (),
    // Salidas E → datapath
    .ResultSrcE  (ResultSrcE),
    .MemWriteE   (),            // no se usa en M todavía, el registro EX/MEM lo lleva
    .ALUSrcE     (ALUSrcE),
    .RegWriteE   (RegWriteE),
    .JumpE       (JumpE),
    .BranchE     (BranchE),
    .PCTargetSrcE(PCTargetSrcE),
    .ALUControlE (ALUControlE),
    // Salidas M
    .ResultSrcM  (ResultSrcM),
    .MemWriteM   (MemWriteM),   // → MemWrite de la memoria de datos
    .RegWriteM   (RegWriteM),
    // Salidas W → datapath
    .ResultSrcW  (ResultSrcW),
    .RegWriteW   (RegWriteW)
  );

  datapath dp(
    .clk         (clk),
    .reset       (reset),
    // Etapa D
    .ImmSrcD     (ImmSrcD),
    // Etapa E
    .ALUSrcE     (ALUSrcE),
    .PCTargetSrcE(PCTargetSrcE),
    .BranchE     (BranchE),
    .JumpE       (JumpE),
    .ALUControlE (ALUControlE),
    // Etapa W
    .RegWriteW   (RegWriteW),
    .ResultSrcW  (ResultSrcW),
    // Memorias
    .PC          (PC),
    .Instr       (Instr),
    .ALUResult   (ALUResult),
    .WriteData   (WriteData),
    .ReadData    (ReadData)
  );

endmodule
