module datapath(input  clk, reset,
input  RegWriteW,
input  [1:0]  ResultSrcW,
input  MemWriteM,
input  PCSrcE,
input  [2:0]  ALUControlE,
input  ALUSrcE,
input  [1:0]  ImmSrcD, 
output ZeroE,
output [6:0] op,
output [2:0] funct3,
output funct7_5,
input StallF, StallD, 
input FlushD, FlushE, 
input [1:0] ForwardAE, ForwardBE,
output [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW);
localparam WIDTH = 32;

wire [31:0] PCF', PCF, PCD, PCE, PCTargetE;
wire [31:0] PCPlus4F, PCPlus4D, PCPlus4E, PCPlus4M, PCPlus4W;
wire [31:0] InstrF, InstrD, InstrE, InstrM, InstrW;
wire [4:0] A1=InstrD[19:15];
wire [4:0] A2=InstrD[24:20];
wire [31:0] RD1, RD1E, RD2, RD2E;
wire [4:0] Rs1D, Rs2D, RdD, Rs1E, Rs2E, RdE, RdM, RdW;
wire [24:0] Imm=InstrD[31:7];
wire [31:0] ImmExtD, ImmExtE;
wire [31:0] SrcAE, SrcBE; 
wire [31:0] WriteDataM;
wire [31:0] ALUResultE,ALUResultM,ALUResultW;
wire [31:0] ReadDataM,ReadDataW;
wire [31:0] ResultW;

reg  ValidBranch;
wire PCSrc;
always @* case(Instr[14:12])
3'b000 : ValidBranch = BranchE &  Zero; // beq
3'b001 : ValidBranch = BranchE & ~Zero; // bne
3'b100 : ValidBranch = BranchE &  (Negative ^ Overflow); // blt
3'b101 : ValidBranch = BranchE & ~(Negative ^ Overflow); // bge
default: ValidBranch = 1'b0;
endcase

assign PCSrc = ValidBranch | JumpE;

// Lógica de próximo PC
flopr #(WIDTH) pcreg(
.clk  (clk),
.reset(reset),
.d    (PCNext),
.q    (PC)
);
adder pcadd4(
.a(PC),
.b({WIDTH{1'b0}} + 4),
.y(PCPlus4)
);
mux2 pcaddsource(
.d0(PC),
.d1(SrcA),
.s (PCTargetSrcE),
.y (SrcPC)
);
adder pcaddbranch(
.a(SrcPC),
.b(ImmExt),
.y(PCTarget)
);
mux2 #(WIDTH) pcmux(
.d0(PCPlus4),
.d1({PCTarget[31:1], 1'b0}),
.s (PCSrc),
.y (PCNext)
);
regfile rf(
.clk(clk),
.we3(RegWriteW),
.a1 (Instr[19:15]),
.a2 (Instr[24:20]),
.a3 (Instr[11:7]),
.wd3(Result),
.rd1(SrcA),
.rd2(WriteData)
);
extend ext(
.instr  (Instr[31:7]),
.immsrc (ImmSrcD),
.immext (ImmExt)
);
mux2 #(WIDTH) srcbmux(
.d0(WriteData),
.d1(ImmExt),
.s (ALUSrcE),
.y (SrcB)
);
alu alu(
.a         (SrcA),
.b         (SrcB),
.alucontrol(ALUControlE),
.result    (ALUResult),
.zero      (Zero),
.neg       (Negative),
.v         (Overflow)
);
mux4 #(WIDTH) resultmux(
.d0(ALUResult),
.d1(ReadData),
.d2(PCPlus4),
.d3(ImmExt),
.s (ResultSrcW),
.y (Result)
);
endmodule