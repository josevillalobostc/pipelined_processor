module datapath(input         clk, reset,

                // D-stage
                input  [2:0]  ImmSrcD,

                // E-stage control signals
                input         ALUSrcE, PCTargetSrcE, BranchE, JumpE,
                input  [3:0]  ALUControlE,

                // M/W-stage control signals
                input  [1:0]  ResultSrcM,
                input         RegWriteW,
                input  [1:0]  ResultSrcW,

                // Hazard Unit control signals
                input         StallF, StallD, FlushD, FlushE,
                input  [1:0]  ForwardAE, ForwardBE,

                // Controller inputs (decoded from instruction in D stage)
                output [6:0]  OpD,
                output [2:0]  Funct3D,
                output        Funct7b5D,

                // Hazard Unit state signals
                output [4:0]  Rs1D, Rs2D,
                output [4:0]  Rs1E, Rs2E, RdE,
                output [4:0]  RdM, RdW,
                output        PCSrcE,

                // Memory interface
                output [31:0] PC,
                input  [31:0] Instr,        // F-stage instruction
                output [31:0] ALUResultM, WriteDataM,
                input  [31:0] ReadDataM);

  localparam WIDTH = 32;

  // Internal wires
  wire [31:0] PCNext, PCPlus4F;
  wire [31:0] InstrD, PCD, PCPlus4D;
  wire [31:0] ImmExt;
  wire [31:0] RD1, RD2;
  wire [31:0] SrcAE;
  wire [31:0] SrcBE, SrcPC;
  wire [31:0] Result;
  wire [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
  wire [2:0]  Funct3E;
  wire [31:0] PCTargetE;
  wire [31:0] WriteDataE;
  wire [31:0] PCPlus4M;
  wire [31:0] ImmExtM;
  wire [31:0] PCPlus4W;
  wire [31:0] ALUResultW;
  wire [31:0] ReadDataW;
  wire [31:0] ImmExtW;
  wire [31:0] ALUResult;
  wire [4:0]  RdD;

  wire        ZeroE, NegativeE, OverflowE;

  // ─── FETCH STAGE ──────────────────────────────────────────────────────────

  // PC register with stall enable and no clear
  flop_encl #(WIDTH) pcreg(
    .clk   (clk),
    .reset (reset),
    .enable(~StallF),
    .clear (1'b0),
    .d     (PCNext),
    .q     (PC)
  );

  // PC+4 adder
  adder pcadd4(.a(PC), .b(32'd4), .y(PCPlus4F));

  // IF/ID pipeline register  (Instr=32, PC=32, PCPlus4=32 → 96 bits)
  flop_encl #(96) IFID_reg(
    .clk   (clk),
    .reset (reset),
    .enable(~StallD),
    .clear (FlushD),
    .d     ({Instr,   PC,   PCPlus4F}),
    .q     ({InstrD,  PCD,  PCPlus4D})
  );

  // ─── DECODE STAGE ─────────────────────────────────────────────────────────

  // Instruction field decode
  assign OpD       = InstrD[6:0];
  assign Funct3D   = InstrD[14:12];
  assign Funct7b5D = InstrD[30];

  // Register address decode
  assign Rs1D = InstrD[19:15];
  assign Rs2D = InstrD[24:20];
  assign RdD  = InstrD[11:7];

  // Register File  (write at posedge, read combinationally = 2nd half of cycle)
  regfile rf(
    .clk(clk),
    .we3(RegWriteW),
    .a1 (Rs1D),   .a2(Rs2D),   .a3(RdW),
    .wd3(Result),
    .rd1(RD1),    .rd2(RD2)
  );

  // Immediate extension
  extend ext(
    .instr  (InstrD[31:7]),
    .immsrc (ImmSrcD),
    .immext (ImmExt)
  );

  // ID/EX pipeline register
  // d: Rs1D(5)+Rs2D(5)+RdD(5)+Funct3(3)+PCD(32)+PCPlus4D(32)+ImmExt(32)+RD1(32)+RD2(32) = 178 bits
  flop_encl #(178) IDEX_data(
    .clk   (clk),
    .reset (reset),
    .enable(1'b1),
    .clear (FlushE),
    .d     ({Rs1D, Rs2D, RdD, InstrD[14:12],
             PCD,  PCPlus4D, ImmExt, RD1, RD2}),
    .q     ({Rs1E, Rs2E, RdE, Funct3E,
             PCE,  PCPlus4E, ImmExtE, RD1E, RD2E})
  );

  // ─── EXECUTE STAGE ────────────────────────────────────────────────────────

  // M-stage result mux for forwarding from MEM stage to EX stage
  // ResultSrcM encoding:  00=ALU, 01=ReadData(lw), 10=PCPlus4(jal/jalr), 11=ImmExt(lui)
  wire [31:0] ForwardDataM;
  mux4 #(WIDTH) fwdMmux(
    .d0(ALUResultM),
    .d1(ALUResultM),   // 01 = lw: data not yet available, stall handles this; forwarded as ALU addr
    .d2(PCPlus4M),     // 10 = jal/jalr return address
    .d3(ImmExtM),      // 11 = lui immediate
    .s (ResultSrcM),
    .y (ForwardDataM)
  );

  // Forwarding mux for SrcA
  mux3 #(WIDTH) fwdAmux(
    .d0(RD1E),         // 00 = no forward
    .d1(Result),       // 01 = forward from WB
    .d2(ForwardDataM), // 10 = forward from MEM
    .s (ForwardAE),
    .y (SrcAE)
  );

  // Forwarding mux for SrcB (also produces WriteDataE for stores)
  mux3 #(WIDTH) fwdBmux(
    .d0(RD2E),         // 00 = no forward
    .d1(Result),       // 01 = forward from WB
    .d2(ForwardDataM), // 10 = forward from MEM
    .s (ForwardBE),
    .y (WriteDataE)
  );

  // Branch/JALR PC adder source mux: jalr uses rs1, branches use PC
  mux2 #(WIDTH) pcaddsource(
    .d0(PCE),
    .d1(SrcAE),
    .s (PCTargetSrcE),
    .y (SrcPC)
  );

  // Branch/Jump target adder
  adder pcaddbranch(
    .a(SrcPC),
    .b(ImmExtE),
    .y(PCTargetE)
  );

  // ALU source B mux: register vs immediate
  mux2 #(WIDTH) srcbmux(
    .d0(WriteDataE),
    .d1(ImmExtE),
    .s (ALUSrcE),
    .y (SrcBE)
  );

  // ALU
  alu alu(
    .a         (SrcAE),
    .b         (SrcBE),
    .alucontrol(ALUControlE),
    .result    (ALUResult),
    .zero      (ZeroE),
    .neg       (NegativeE),
    .v         (OverflowE)
  );

  // Branch condition evaluation
  reg ValidBranch;
  always @* case(Funct3E)
    3'b000 : ValidBranch = BranchE &  ZeroE;                      // beq
    3'b001 : ValidBranch = BranchE & ~ZeroE;                      // bne
    3'b100 : ValidBranch = BranchE &  (NegativeE ^ OverflowE);    // blt
    3'b101 : ValidBranch = BranchE & ~(NegativeE ^ OverflowE);    // bge
    default: ValidBranch = 1'b0;
  endcase

  assign PCSrcE = ValidBranch | JumpE;

  // Next PC mux: PCPlus4F (sequential) or branch/jump target
  mux2 #(WIDTH) pcmux(
    .d0(PCPlus4F),
    .d1({PCTargetE[31:1], 1'b0}),  // force LSB=0 per RISC-V spec
    .s (PCSrcE),
    .y (PCNext)
  );

  // ─── EXECUTE/MEM PIPELINE REGISTERS ───────────────────────────────────────

  flopr #(32) EXMEM_aluResult(
    .clk  (clk), .reset(reset),
    .d    (ALUResult),
    .q    (ALUResultM)
  );

  flopr #(32) EXMEM_wdata(
    .clk  (clk), .reset(reset),
    .d    (WriteDataE),
    .q    (WriteDataM)
  );

  flopr #(32) EXMEM_pcPlus4(
    .clk  (clk), .reset(reset),
    .d    (PCPlus4E),
    .q    (PCPlus4M)
  );

  flopr #(32) EXMEM_immExt(
    .clk  (clk), .reset(reset),
    .d    (ImmExtE),
    .q    (ImmExtM)
  );

  flopr #(5) EXMEM_rd(
    .clk  (clk), .reset(reset),
    .d    (RdE),
    .q    (RdM)
  );

  // ─── MEM/WB PIPELINE REGISTERS ────────────────────────────────────────────

  flopr #(32) MEMWB_aluResult(
    .clk  (clk), .reset(reset),
    .d    (ALUResultM),
    .q    (ALUResultW)
  );

  flopr #(32) MEMWB_readData(
    .clk  (clk), .reset(reset),
    .d    (ReadDataM),
    .q    (ReadDataW)
  );

  flopr #(32) MEMWB_pcPlus4(
    .clk  (clk), .reset(reset),
    .d    (PCPlus4M),
    .q    (PCPlus4W)
  );

  flopr #(32) MEMWB_immExt(
    .clk  (clk), .reset(reset),
    .d    (ImmExtM),
    .q    (ImmExtW)
  );

  flopr #(5) MEMWB_rd(
    .clk  (clk), .reset(reset),
    .d    (RdM),
    .q    (RdW)
  );

  // ─── WRITEBACK STAGE ──────────────────────────────────────────────────────

  // Result mux: 00=ALU, 01=ReadData(lw), 10=PCPlus4(jal/jalr), 11=ImmExt(lui)
  mux4 #(WIDTH) resultmux(
    .d0(ALUResultW),
    .d1(ReadDataW),
    .d2(PCPlus4W),
    .d3(ImmExtW),
    .s (ResultSrcW),
    .y (Result)
  );

endmodule
