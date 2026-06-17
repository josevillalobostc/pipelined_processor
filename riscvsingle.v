module riscvsingle(input         clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output        MemWrite,
                   output [31:0] DataAdr,
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  // escritura en memoria
  assign MemWrite = MemWriteM;

  // campos de instrucción de etapa d
  wire [6:0]  OpD;
  wire [2:0]  Funct3D;
  wire        Funct7b5D;

  // señales etapa d
  wire [2:0]  ImmSrcD;

  // señales de control de la etapa e
  wire        ALUSrcE, PCTargetSrcE, RegWriteE, JumpE, BranchE;
  wire [1:0]  ResultSrcE;
  wire [3:0]  ALUControlE;

  // señales de etapa m
  wire        RegWriteM, MemWriteM;
  wire [1:0]  ResultSrcM;

  // señales de etapa w
  wire        RegWriteW;
  wire [1:0]  ResultSrcW;

  // señales de hazard
  wire [4:0]  Rs1D, Rs2D;
  wire [4:0]  Rs1E, Rs2E, RdE;
  wire [4:0]  RdM, RdW;
  wire        PCSrcE;

  wire        StallF, StallD, FlushD, FlushE;
  wire [1:0]  ForwardAE, ForwardBE;

  wire [31:0] ALUResultM;
  assign DataAdr = ALUResultM;

  wire ResultSrcEb0;
  assign ResultSrcEb0 = ResultSrcE[0];

  // controller
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

  // datapath
  datapath dp(
    .clk         (clk),
    .reset       (reset),
    .ImmSrcD     (ImmSrcD),
    .ALUSrcE     (ALUSrcE),
    .PCTargetSrcE(PCTargetSrcE),
    .BranchE     (BranchE),
    .JumpE       (JumpE),
    .ALUControlE (ALUControlE),
    .ResultSrcM  (ResultSrcM),
    .RegWriteW   (RegWriteW),
    .ResultSrcW  (ResultSrcW),
    .StallF      (StallF),
    .StallD      (StallD),
    .FlushD      (FlushD),
    .FlushE      (FlushE),
    .ForwardAE   (ForwardAE),
    .ForwardBE   (ForwardBE),
    .OpD         (OpD),
    .Funct3D     (Funct3D),
    .Funct7b5D   (Funct7b5D),
    .Rs1D        (Rs1D),
    .Rs2D        (Rs2D),
    .Rs1E        (Rs1E),
    .Rs2E        (Rs2E),
    .RdE         (RdE),
    .RdM         (RdM),
    .RdW         (RdW),
    .PCSrcE      (PCSrcE),
    .PC          (PC),
    .Instr       (Instr),
    .ALUResultM  (ALUResultM),
    .WriteDataM  (WriteData),
    .ReadDataM   (ReadData)
  );

  // hazard unit
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
    .ResultSrcEb0(ResultSrcEb0),
    .PCSrcE      (PCSrcE),
    .StallF      (StallF),
    .StallD      (StallD),
    .FlushD      (FlushD),
    .FlushE      (FlushE),
    .ForwardAE   (ForwardAE),
    .ForwardBE   (ForwardBE)
  );

endmodule
