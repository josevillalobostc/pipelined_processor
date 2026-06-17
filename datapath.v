module datapath(input         clk, reset,

                // etapa d
                input  [2:0]  ImmSrcD,

                // señales de control de la etapa e
                input         ALUSrcE, PCTargetSrcE, BranchE, JumpE,
                input  [3:0]  ALUControlE,

                // señales de control de la etapa m/w
                input  [1:0]  ResultSrcM,
                input         RegWriteW,
                input  [1:0]  ResultSrcW,

                // señales de control de la unidad de hazard
                input         StallF, StallD, FlushD, FlushE,
                input  [1:0]  ForwardAE, ForwardBE,

                // entradas del controlador (decodificadas de la instrucción en la etapa d)
                output [6:0]  OpD,
                output [2:0]  Funct3D,
                output        Funct7b5D,

                // señales de estado de la unidad de hazard
                output [4:0]  Rs1D, Rs2D,
                output [4:0]  Rs1E, Rs2E, RdE,
                output [4:0]  RdM, RdW,
                output        PCSrcE,

                // interfaz de memoria
                output [31:0] PC,
                input  [31:0] Instr,        // instrucción de la etapa f
                output [31:0] ALUResultM, WriteDataM,
                input  [31:0] ReadDataM);

  localparam WIDTH = 32;

  // cables internos
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

  // etapa fetch

  // registro pc con habilitación de parada y sin limpieza
  flop_encl #(WIDTH) pcreg(
    .clk   (clk),
    .reset (reset),
    .enable(~StallF),
    .clear (1'b0),
    .d     (PCNext),
    .q     (PC)
  );

  // sumador pc+4
  adder pcadd4(.a(PC), .b(32'd4), .y(PCPlus4F));

  // registro de pipeline if/id (instr=32, pc=32, pcplus4=32 → 96 bits)
  flop_encl #(96) IFID_reg(
    .clk   (clk),
    .reset (reset),
    .enable(~StallD),
    .clear (FlushD),
    .d     ({Instr,   PC,   PCPlus4F}),
    .q     ({InstrD,  PCD,  PCPlus4D})
  );

  // etapa decode

  // decodificación de campos de la instrucción
  assign OpD       = InstrD[6:0];
  assign Funct3D   = InstrD[14:12];
  assign Funct7b5D = InstrD[30];

  // decodificación de direcciones de registros
  assign Rs1D = InstrD[19:15];
  assign Rs2D = InstrD[24:20];
  assign RdD  = InstrD[11:7];

  // archivo de registros (escritura en flanco de subida, lectura combinacional = segunda mitad del ciclo)
  regfile rf(
    .clk(clk),
    .we3(RegWriteW),
    .a1 (Rs1D),   .a2(Rs2D),   .a3(RdW),
    .wd3(Result),
    .rd1(RD1),    .rd2(RD2)
  );

  // extensión inmediata
  extend ext(
    .instr  (InstrD[31:7]),
    .immsrc (ImmSrcD),
    .immext (ImmExt)
  );

  // registro de pipeline id/ex
  // d: rs1d(5)+rs2d(5)+rdd(5)+funct3(3)+pcd(32)+pcplus4d(32)+immext(32)+rd1(32)+rd2(32) = 178 bits
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

  // etapa execute

  // multiplexor de forwarding de etapa M a E
  // codificación de resultsrcm:  00=alu, 01=readdata(lw), 10=pcplus4(jal/jalr), 11=immext(lui)
  wire [31:0] ForwardDataM;
  mux4 #(WIDTH) fwdMmux(
    .d0(ALUResultM),
    .d1(ALUResultM),   // 01 = lw
    .d2(PCPlus4M),     // 10 = dirección de retorno de jal/jalr
    .d3(ImmExtM),      // 11 = inmediate de lui
    .s (ResultSrcM),
    .y (ForwardDataM)
  );

  // multiplexor para forwarding de a
  mux3 #(WIDTH) fwdAmux(
    .d0(RD1E),         // 00 = sin reenvío
    .d1(Result),       // 01 = reenvío desde wb
    .d2(ForwardDataM), // 10 = reenvío desde mem
    .s (ForwardAE),
    .y (SrcAE)
  );

  // multiplexor para forwardinb de b
  mux3 #(WIDTH) fwdBmux(
    .d0(RD2E),         // 00 = sin reenvío
    .d1(Result),       // 01 = reenvío desde wb
    .d2(ForwardDataM), // 10 = reenvío desde mem
    .s (ForwardBE),
    .y (WriteDataE)
  );

  // multiplexor de origen del sumador pc para branch/jalr: jalr usa rs1, branches usan pc
  mux2 #(WIDTH) pcaddsource(
    .d0(PCE),
    .d1(SrcAE),
    .s (PCTargetSrcE),
    .y (SrcPC)
  );

  // sumador de destino de branch/jump
  adder pcaddbranch(
    .a(SrcPC),
    .b(ImmExtE),
    .y(PCTargetE)
  );

  mux2 #(WIDTH) srcbmux(
    .d0(WriteDataE),
    .d1(ImmExtE),
    .s (ALUSrcE),
    .y (SrcBE)
  );

  // alu
  alu alu(
    .a         (SrcAE),
    .b         (SrcBE),
    .alucontrol(ALUControlE),
    .result    (ALUResult),
    .zero      (ZeroE),
    .neg       (NegativeE),
    .v         (OverflowE)
  );

  // evaluación de condición de branch
  reg ValidBranch;
  always @* case(Funct3E)
    3'b000 : ValidBranch = BranchE &  ZeroE;                      // beq
    3'b001 : ValidBranch = BranchE & ~ZeroE;                      // bne
    3'b100 : ValidBranch = BranchE &  (NegativeE ^ OverflowE);    // blt
    3'b101 : ValidBranch = BranchE & ~(NegativeE ^ OverflowE);    // bge
    default: ValidBranch = 1'b0;
  endcase

  assign PCSrcE = ValidBranch | JumpE;

  // multiplexor de PCNext
  mux2 #(WIDTH) pcmux(
    .d0(PCPlus4F),
    .d1({PCTargetE[31:1], 1'b0}),  
    .s (PCSrcE),
    .y (PCNext)
  );

  // registros de pipeline execute/mem

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

  // registros de pipeline mem/wb

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

  // etapa writeback

  // multiplexor de resultado: 00=alu, 01=readdata(lw), 10=pcplus4(jal/jalr), 11=immext(lui)
  mux4 #(WIDTH) resultmux(
    .d0(ALUResultW),
    .d1(ReadDataW),
    .d2(PCPlus4W),
    .d3(ImmExtW),
    .s (ResultSrcW),
    .y (Result)
  );

endmodule
