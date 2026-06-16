module datapath(input         clk, reset,

                // -- Etapa D: ImmSrc para Extend --
                input  [2:0]  ImmSrcD,

                // -- Etapa E: señales de control --
                input         ALUSrcE, PCTargetSrcE, BranchE, JumpE,
                input  [3:0]  ALUControlE,

                // -- Etapa W: señales de control --
                input         RegWriteW,
                input  [1:0]  ResultSrcW,

                // -- Hazard Unit: entradas de control --
                input         StallF, StallD, FlushD, FlushE,
                input  [1:0]  ForwardAE, ForwardBE,

                // -- Hacia el Controller: campos de InstrD --
                output [6:0]  OpD,
                output [2:0]  Funct3D,
                output        Funct7b5D,

                // -- Hacia Hazard Unit: registros fuente/destino --
                output [4:0]  Rs1D, Rs2D,
                output [4:0]  Rs1E, Rs2E, RdE,
                output [4:0]  RdM, RdW,
                output        PCSrcE,

                // -- Interfaz con memorias --
                output [31:0] PC,
                input  [31:0] Instr,         // instrucción de imem (etapa F)
                output [31:0] ALUResultM,    // dirección de memoria (etapa M)
                output [31:0] WriteData,     // dato a escribir en memoria (etapa M)
                input  [31:0] ReadData);

  localparam WIDTH = 32;

  // ==============================================================
  // Wires internos
  // ==============================================================

  // IF / F stage
  wire [31:0] PCNext, PCPlus4, PCTarget;

  // IF/ID outputs (etapa D)
  wire [31:0] InstrD, PCD, PCPlus4D;

  // D stage computation
  wire [31:0] ImmExt;           // inmediato extendido (D stage)
  wire [31:0] RD1, RD2;         // salidas crudas del regfile (D stage)

  // ID/EX data outputs (etapa E)
  wire [2:0]  Funct3E;
  wire [31:0] PCE, PCPlus4E, ImmExtE;
  wire [31:0] RD1E, RD2E;       // SrcA y WriteData originales (antes de forwarding)

  // E stage computation
  wire [31:0] SrcAFwd;          // SrcA tras forwarding → ALU.a y jalr
  wire [31:0] WriteDataFwdE;    // WriteData tras forwarding (antes de EX/MEM register)
  wire [31:0] SrcB, SrcPC;
  wire [31:0] ALUResult;        // E-stage ALU result (interno; NO es puerto)
  wire         Zero, Negative, Overflow;

  // EX/MEM data outputs (etapa M)
  // ALUResultM : puerto de salida (DataAdr)
  // WriteData  : puerto de salida (dmem.wd)
  wire [31:0] PCPlus4M, ImmExtM;

  // MEM/WB data outputs (etapa W)
  wire [31:0] ALUResultW, ReadDataW, PCPlus4W, ImmExtW;

  wire [31:0] Result;            // salida del result mux → regfile.wd3

  // ==============================================================
  // Registro IF/ID — 96 bits
  // d = {Instr(32), PC(32), PCPlus4(32)}
  // q = {InstrD,    PCD,    PCPlus4D  }
  // enable = ~StallD  → congela cuando hay load-use stall
  // clear  = FlushD   → limpia al tomar un branch/jump
  // ==============================================================
  enable_flipflop #(96) IFID_reg(
    .clk   (clk),
    .reset (reset),
    .enable(~StallD),
    .clear (FlushD),
    .d     ({Instr,  PC,  PCPlus4}),
    .q     ({InstrD, PCD, PCPlus4D})
  );

  // Campos de InstrD → al controller y a la hazard unit
  assign OpD       = InstrD[6:0];
  assign Funct3D   = InstrD[14:12];
  assign Funct7b5D = InstrD[30];
  assign Rs1D      = InstrD[19:15];
  assign Rs2D      = InstrD[24:20];

  // ==============================================================
  // PCSrcE — lógica branch/jump en etapa E
  // Usa Funct3E (correctamente en etapa E via ID/EX register)
  // ==============================================================
  reg ValidBranch;

  always @* case(Funct3E)
    3'b000 : ValidBranch = BranchE &  Zero;                   // beq
    3'b001 : ValidBranch = BranchE & ~Zero;                   // bne
    3'b100 : ValidBranch = BranchE &  (Negative ^ Overflow);  // blt (signed)
    3'b101 : ValidBranch = BranchE & ~(Negative ^ Overflow);  // bge (signed)
    default: ValidBranch = 1'b0;
  endcase

  assign PCSrcE = ValidBranch | JumpE;

  // ==============================================================
  // PC (etapa F) — enable_flipflop: StallF congela el PC
  // ==============================================================
  enable_flipflop #(WIDTH) pcreg(
    .clk   (clk),
    .reset (reset),
    .enable(~StallF),
    .clear (1'b0),
    .d     (PCNext),
    .q     (PC)
  );

  adder pcadd4(.a(PC), .b(32'd4), .y(PCPlus4));

  // Mux base de PCTarget:
  //   PCTargetSrcE=0 → PCE + ImmExtE  (jal, branches — usando PC de la instrucción en E)
  //   PCTargetSrcE=1 → SrcAFwd + ImmExtE (jalr)
  mux2 pcaddsource(
    .d0(PCE),       // jal/branch: base = PCE (PC de la instrucción en etapa E) ✓
    .d1(SrcAFwd),   // jalr:       base = rs1 forwardeado
    .s (PCTargetSrcE),
    .y (SrcPC)
  );

  adder pcaddbranch(
    .a(SrcPC),
    .b(ImmExtE),    // inmediato de etapa E (correctamente pipelineado) ✓
    .y(PCTarget)
  );

  mux2 #(WIDTH) pcmux(
    .d0(PCPlus4),
    .d1({PCTarget[31:1], 1'b0}),
    .s (PCSrcE),
    .y (PCNext)
  );

  // ==============================================================
  // Register File
  //   Lecturas: en etapa D con InstrD (rs1, rs2)
  //   Escritura: en etapa W con RdW y RegWriteW
  //   a3=RdW sincronizado con RegWriteW (ambos 3 ciclos de retraso desde D)
  // ==============================================================
  regfile rf(
    .clk(clk),
    .we3(RegWriteW),
    .a1 (InstrD[19:15]),  .a2(InstrD[24:20]),  .a3(RdW),
    .wd3(Result),
    .rd1(RD1),            .rd2(RD2)
  );

  extend ext(
    .instr  (InstrD[31:7]),
    .immsrc (ImmSrcD),
    .immext (ImmExt)
  );

  // ==============================================================
  // Registro ID/EX de DATOS — 178 bits
  // Rs1(5)+Rs2(5)+Rd(5)+Funct3(3)+PC(32)+PCPlus4(32)+ImmExt(32)+RD1(32)+RD2(32)
  // clear = FlushE: inserta burbuja (ceros → Rd=0 evita escrituras espurias)
  // ==============================================================
  enable_flipflop #(178) IDEX_data(
    .clk   (clk),
    .reset (reset),
    .enable(1'b1),
    .clear (FlushE),
    .d     ({InstrD[19:15], InstrD[24:20], InstrD[11:7], InstrD[14:12],
             PCD, PCPlus4D, ImmExt, RD1, RD2}),
    .q     ({Rs1E, Rs2E, RdE, Funct3E,
             PCE,  PCPlus4E, ImmExtE, RD1E, RD2E})
  );

  // ==============================================================
  // Forwarding muxes — etapa E
  //   d0 = valor original de E stage (RD1E/RD2E — regfile leído en D, registrado a E)
  //   d1 = ResultW  (etapa W, 2 ciclos atrás)
  //   d2 = ALUResultM (etapa M, 1 ciclo atrás)
  // ==============================================================
  mux3 #(WIDTH) fwdAmux(
    .d0(RD1E),        // sin forwarding
    .d1(Result),      // forward desde W
    .d2(ALUResultM),  // forward desde M
    .s (ForwardAE),
    .y (SrcAFwd)
  );

  mux3 #(WIDTH) fwdBmux(
    .d0(RD2E),        // sin forwarding
    .d1(Result),      // forward desde W
    .d2(ALUResultM),  // forward desde M
    .s (ForwardBE),
    .y (WriteDataFwdE)
  );

  // ==============================================================
  // ALU — etapa E
  // ==============================================================
  mux2 #(WIDTH) srcbmux(
    .d0(WriteDataFwdE),
    .d1(ImmExtE),     // inmediato de etapa E (correctamente pipelineado) ✓
    .s (ALUSrcE),
    .y (SrcB)
  );

  alu alu(
    .a         (SrcAFwd),
    .b         (SrcB),
    .alucontrol(ALUControlE),
    .result    (ALUResult),
    .zero      (Zero),
    .neg       (Negative),
    .v         (Overflow)
  );

  // ==============================================================
  // Registros EX/MEM de DATOS
  //   ALUResult     → ALUResultM  : dirección de memoria + forwarding desde M
  //   WriteDataFwdE → WriteData   : dato a escribir en memoria (puerto de salida)
  //   PCPlus4E      → PCPlus4M   : cadena hacia PCPlus4W
  //   ImmExtE       → ImmExtM    : cadena hacia ImmExtW
  //   RdE           → RdM        : detección de hazards
  // ==============================================================
  flopr #(32) EXMEM_aluResult(.clk(clk), .reset(reset), .d(ALUResult),      .q(ALUResultM));
  flopr #(32) EXMEM_wdata    (.clk(clk), .reset(reset), .d(WriteDataFwdE),  .q(WriteData));
  flopr #(32) EXMEM_pcplus4  (.clk(clk), .reset(reset), .d(PCPlus4E),       .q(PCPlus4M));
  flopr #(32) EXMEM_immext   (.clk(clk), .reset(reset), .d(ImmExtE),        .q(ImmExtM));
  flopr #(5)  EXMEM_rd       (.clk(clk), .reset(reset), .d(RdE),            .q(RdM));

  // ==============================================================
  // Registros MEM/WB de DATOS
  //   ALUResultM → ALUResultW : resultado ALU en etapa W (para result mux)
  //   ReadData   → ReadDataW  : dato leído de memoria en etapa W
  //   PCPlus4M   → PCPlus4W  : PC+4 en etapa W (return address jal/jalr)
  //   ImmExtM    → ImmExtW   : inmediato en etapa W (para lui)
  //   RdM        → RdW       : registro destino en etapa W
  // ==============================================================
  flopr #(32) MEMWB_aluResult(.clk(clk), .reset(reset), .d(ALUResultM),  .q(ALUResultW));
  flopr #(32) MEMWB_readdata (.clk(clk), .reset(reset), .d(ReadData),    .q(ReadDataW));
  flopr #(32) MEMWB_pcplus4  (.clk(clk), .reset(reset), .d(PCPlus4M),   .q(PCPlus4W));
  flopr #(32) MEMWB_immext   (.clk(clk), .reset(reset), .d(ImmExtM),    .q(ImmExtW));
  flopr #(5)  MEMWB_rd       (.clk(clk), .reset(reset), .d(RdM),         .q(RdW));

  // ==============================================================
  // Result mux — etapa W
  // Todos los valores están correctamente en etapa W:
  //   d0 = ALUResultW : R/I-type ALU results
  //   d1 = ReadDataW  : lw (load word)
  //   d2 = PCPlus4W   : jal/jalr (return address = PC+4 de la instrucción)
  //   d3 = ImmExtW    : lui
  // ==============================================================
  mux4 #(WIDTH) resultmux(
    .d0(ALUResultW),
    .d1(ReadDataW),
    .d2(PCPlus4W),
    .d3(ImmExtW),
    .s (ResultSrcW),
    .y (Result)
  );

endmodule
