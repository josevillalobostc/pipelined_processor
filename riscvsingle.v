module riscvsingle(input         clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output        MemWrite,
                   output [31:0] DataAdr,
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  wire [31:0] ALUResult;
  assign DataAdr = ALUResult;
  assign MemWrite = MemWriteM;

  // ---- Campos de InstrD (etapa D) — del datapath al controller ----
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

  // ---- Hazard Unit: señales de estado (del datapath) ----
  wire [4:0]  Rs1D, Rs2D;
  wire [4:0]  Rs1E, Rs2E, RdE;
  wire [4:0]  RdM, RdW;
  wire        PCSrcE;

  // ---- Hazard Unit: señales de control (hacia controller y datapath) ----
  wire        StallF, StallD, FlushD, FlushE;
  wire [1:0]  ForwardAE, ForwardBE;

  // ================================================================
  // Control Unit
  // El controller lee op/funct3/funct7b5 desde InstrD (etapa D),
  // no desde la instrucción cruda de imem.
  // ================================================================
  controller c(
    .clk         (clk),
    .reset       (reset),
    .FlushE      (FlushE),
    .op          (OpD),          // ← InstrD[6:0]   (etapa D)
    .funct3      (Funct3D),      // ← InstrD[14:12] (etapa D)
    .funct7b5    (Funct7b5D),    // ← InstrD[30]    (etapa D)
    // Salidas D (ImmSrcD es la única que va al datapath directamente)
    .ResultSrcD  (),
    .MemWriteD   (),
    .ALUSrcD     (),
    .RegWriteD   (),
    .JumpD       (),
    .BranchD     (),
    .PCTargetSrcD(),
    .ImmSrcD     (ImmSrcD),
    .ALUControlD (),
    // Salidas E → datapath
    .ResultSrcE  (ResultSrcE),
    .MemWriteE   (),
    .ALUSrcE     (ALUSrcE),
    .RegWriteE   (RegWriteE),
    .JumpE       (JumpE),
    .BranchE     (BranchE),
    .PCTargetSrcE(PCTargetSrcE),
    .ALUControlE (ALUControlE),
    // Salidas M
    .ResultSrcM  (ResultSrcM),
    .MemWriteM   (MemWriteM),
    .RegWriteM   (RegWriteM),
    // Salidas W → datapath
    .ResultSrcW  (ResultSrcW),
    .RegWriteW   (RegWriteW)
  );

  // ================================================================
  // Datapath
  // ================================================================
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
    // Hazard Unit: control
    .StallF      (StallF),
    .StallD      (StallD),
    .FlushD      (FlushD),
    .FlushE      (FlushE),
    .ForwardAE   (ForwardAE),
    .ForwardBE   (ForwardBE),
    // Campos de InstrD → controller
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
    .ALUResult   (ALUResult),
    .WriteData   (WriteData),
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
    // Salidas de control
    .StallF      (StallF),
    .StallD      (StallD),   // → datapath: congela IF/ID
    .FlushD      (FlushD),   // → datapath: limpia IF/ID
    .FlushE      (FlushE),   // → datapath + controller: limpia ID/EX
    .ForwardAE   (ForwardAE),
    .ForwardBE   (ForwardBE)
  );

endmodule
