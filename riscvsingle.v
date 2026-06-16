module riscvsingle(input         clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output        MemWrite,
                   output [31:0] DataAdr,
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  // DataAdr = ALUResultM (M-stage, sincronizado con MemWriteM) ✓
  assign MemWrite = MemWriteM;

  // ---- Campos de InstrD (etapa D) → del datapath al controller ----
  wire [6:0]  OpD;
  wire [2:0]  Funct3D;
  wire        Funct7b5D;

  // ---- Control Unit: señales D ----
  wire [2:0]  ImmSrcD;

  // ---- Control Unit: señales E ----
  wire        ALUSrcE, PCTargetSrcE, RegWriteE, JumpE, BranchE;
  wire [1:0]  ResultSrcE;
  wire [3:0]  ALUControlE;

  // ---- Control Unit: señales M ----
  wire        RegWriteM, MemWriteM;
  wire [1:0]  ResultSrcM;

  // ---- Control Unit: señales W ----
  wire        RegWriteW;
  wire [1:0]  ResultSrcW;

  // ---- Hazard Unit: señales de estado ----
  wire [4:0]  Rs1D, Rs2D;
  wire [4:0]  Rs1E, Rs2E, RdE;
  wire [4:0]  RdM, RdW;
  wire        PCSrcE;

  // ---- Hazard Unit: señales de control ----
  wire        StallF, StallD, FlushD, FlushE;
  wire [1:0]  ForwardAE, ForwardBE;

  // ---- Datos de memoria ----
  wire [31:0] ALUResultM;   // M-stage ALU result → DataAdr
  assign DataAdr = ALUResultM;

  // ================================================================
  // Control Unit
  // Lee op/funct3/funct7b5 desde InstrD (etapa D) — correctamente staged
  // ================================================================
  controller c(
    .clk         (clk),
    .reset       (reset),
    .FlushE      (FlushE),
    .op          (OpD),
    .funct3      (Funct3D),
    .funct7b5    (Funct7b5D),
    .ResultSrcD  (),
    .MemWriteD   (),
    .ALUSrcD     (),
    .RegWriteD   (),
    .JumpD       (),
    .BranchD     (),
    .PCTargetSrcD(),
    .ImmSrcD     (ImmSrcD),
    .ALUControlD (),
    .ResultSrcE  (ResultSrcE),
    .MemWriteE   (),
    .ALUSrcE     (ALUSrcE),
    .RegWriteE   (RegWriteE),
    .JumpE       (JumpE),
    .BranchE     (BranchE),
    .PCTargetSrcE(PCTargetSrcE),
    .ALUControlE (ALUControlE),
    .ResultSrcM  (ResultSrcM),
    .MemWriteM   (MemWriteM),
    .RegWriteM   (RegWriteM),
    .ResultSrcW  (ResultSrcW),
    .RegWriteW   (RegWriteW)
  );

  // ================================================================
  // Datapath
  // ================================================================
  datapath dp(
    .clk         (clk),
    .reset       (reset),
    .ImmSrcD     (ImmSrcD),
    .ALUSrcE     (ALUSrcE),
    .PCTargetSrcE(PCTargetSrcE),
    .BranchE     (BranchE),
    .JumpE       (JumpE),
    .ALUControlE (ALUControlE),
    .RegWriteW   (RegWriteW),
    .ResultSrcW  (ResultSrcW),
    .StallF      (StallF),
    .StallD      (StallD),
    .FlushD      (FlushD),
    .FlushE      (FlushE),
    .ForwardAE   (ForwardAE),
    .ForwardBE   (ForwardBE),
    // Campos InstrD → controller
    .OpD         (OpD),
    .Funct3D     (Funct3D),
    .Funct7b5D   (Funct7b5D),
    // Hazard Unit: estado
    .Rs1D        (Rs1D),
    .Rs2D        (Rs2D),
    .Rs1E        (Rs1E),
    .Rs2E        (Rs2E),
    .RdE         (RdE),
    .RdM         (RdM),
    .RdW         (RdW),
    .PCSrcE      (PCSrcE),
    // Memorias
    .PC          (PC),
    .Instr       (Instr),
    .ALUResultM  (ALUResultM),  // M-stage → DataAdr ✓
    .WriteData   (WriteData),   // M-stage → dmem.wd ✓
    .ReadData    (ReadData)
  );

  // ================================================================
  // Hazard Unit
  // ================================================================
  hazard_unit hu(
    .Rs1D        (Rs1D),
    .Rs2D        (Rs2D),
    .Rs1E        (Rs1E),
    .Rs2E        (Rs2E),
    .RdE         (RdE),
    .RdM         (RdM),
    .RdW         (RdW),
    .RegWriteM   (RegWriteM),
    .RegWriteW   (RegWriteW),
    .ResultSrcEb0(ResultSrcE[0]),
    .PCSrcE      (PCSrcE),
    .StallF      (StallF),
    .StallD      (StallD),
    .FlushD      (FlushD),
    .FlushE      (FlushE),
    .ForwardAE   (ForwardAE),
    .ForwardBE   (ForwardBE)
  );

endmodule
