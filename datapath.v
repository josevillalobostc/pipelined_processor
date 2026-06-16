module datapath(input         clk, reset,

                // -- Etapa D: ImmSrc para el módulo Extend --
                input  [2:0]  ImmSrcD,

                // -- Etapa E: señales de control --
                input         ALUSrcE,
                input         PCTargetSrcE,
                input         BranchE,
                input         JumpE,
                input  [3:0]  ALUControlE,

                // -- Etapa W: señales de control --
                input         RegWriteW,
                input  [1:0]  ResultSrcW,

                // -- Hazard Unit: entradas de control --
                input         StallF,       // congela PC
                input         StallD,       // congela registro IF/ID
                input         FlushD,       // limpia registro IF/ID (branch tomado)
                input         FlushE,       // limpia registro ID/EX
                input  [1:0]  ForwardAE,    // forwarding mux para SrcA
                input  [1:0]  ForwardBE,    // forwarding mux para SrcB / WriteData

                // -- Hacia el Controller (campos de InstrD para decodificación) --
                output [6:0]  OpD,          // InstrD[6:0]
                output [2:0]  Funct3D,      // InstrD[14:12]
                output        Funct7b5D,    // InstrD[30]

                // -- Hazard Unit: salidas de estado --
                output [4:0]  Rs1D, Rs2D,   // registros fuente en etapa D
                output [4:0]  Rs1E, Rs2E,   // registros fuente en etapa E
                output [4:0]  RdE,          // registro destino en etapa E
                output [4:0]  RdM,          // registro destino en etapa M
                output [4:0]  RdW,          // registro destino en etapa W
                output        PCSrcE,       // señal de salto tomado

                // -- Interfaz con memorias --
                output [31:0] PC,
                input  [31:0] Instr,        // instrucción cruda de imem (etapa F)
                output [31:0] ALUResult, WriteData,
                input  [31:0] ReadData);

  localparam WIDTH = 32;

  wire [31:0] PCNext, PCPlus4, PCTarget;
  wire [31:0] InstrD;       // instrucción registrada en etapa D (tras IF/ID)
  wire [31:0] ImmExt;
  wire [31:0] RD1, RD2;    // salidas crudas del Register File (sin forwarding)
  wire [31:0] SrcAFwd;     // SrcA post-forwarding → ALU y jalr
  wire [31:0] SrcB, SrcPC;
  wire [31:0] Result;
  wire [31:0] ALUResultM;  // ALUResult retrasado 1 ciclo para forwarding desde M

  wire         Zero, Negative, Overflow;

  // ----------------------------------------------------------------
  // Registro IF/ID — pipelina instrucción de F → D
  // enable_flipflop:
  //   enable = ~StallD  → si StallD=1, la instrucción en D no avanza
  //   clear  = FlushD   → si FlushD=1, inserta NOP (instrucción = 0)
  // ----------------------------------------------------------------
  enable_flipflop #(32) IFID_reg(
    .clk   (clk),
    .reset (reset),
    .enable(~StallD),
    .clear (FlushD),
    .d     (Instr),     // instrucción de imem (etapa F)
    .q     (InstrD)     // instrucción decodificada (etapa D)
  );

  // Campos de InstrD → salen al controller
  assign OpD       = InstrD[6:0];
  assign Funct3D   = InstrD[14:12];
  assign Funct7b5D = InstrD[30];

  // Registros fuente en etapa D → hazard unit
  assign Rs1D = InstrD[19:15];
  assign Rs2D = InstrD[24:20];

  // ----------------------------------------------------------------
  // PCSrcE — lógica de branch/jump en etapa E (opción B extendida)
  // funct3 de InstrD (D stage); se actualizará a InstrE[14:12]
  // cuando se agregue el registro ID/EX de datos completo.
  // ----------------------------------------------------------------
  reg ValidBranch;

  always @* case(InstrD[14:12])
    3'b000 : ValidBranch = BranchE &  Zero;
    3'b001 : ValidBranch = BranchE & ~Zero;
    3'b100 : ValidBranch = BranchE &  (Negative ^ Overflow);   // blt
    3'b101 : ValidBranch = BranchE & ~(Negative ^ Overflow);   // bge
    default: ValidBranch = 1'b0;
  endcase

  assign PCSrcE = ValidBranch | JumpE;

  // ----------------------------------------------------------------
  // PC — enable_flipflop: StallF congela el PC
  // ----------------------------------------------------------------
  enable_flipflop #(WIDTH) pcreg(
    .clk   (clk),
    .reset (reset),
    .enable(~StallF),
    .clear (1'b0),
    .d     (PCNext),
    .q     (PC)
  );

  adder pcadd4(
    .a(PC),
    .b({WIDTH{1'b0}} + 4),
    .y(PCPlus4)
  );

  // Mux base de PCTarget:
  //   PCTargetSrcE=0 → PC + ImmExt  (jal / branches)
  //   PCTargetSrcE=1 → SrcAFwd + ImmExt (jalr)
  mux2 pcaddsource(
    .d0(PC),
    .d1(SrcAFwd),
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
    .s (PCSrcE),
    .y (PCNext)
  );

  // ----------------------------------------------------------------
  // Register File
  //   a1, a2  → leen registros fuente de InstrD (etapa D)
  //   a3, we3 → escriben usando RdW y RegWriteW (etapa W)
  //             ambas señales están sincronizadas con la instrucción
  //             en Writeback (3 ciclos de pipeline después de D)
  // ----------------------------------------------------------------
  regfile rf(
    .clk(clk),
    .we3(RegWriteW),
    .a1 (InstrD[19:15]),  // rs1 en etapa D
    .a2 (InstrD[24:20]),  // rs2 en etapa D
    .a3 (RdW),            // rd en etapa W (sincronizado con RegWriteW)
    .wd3(Result),
    .rd1(RD1),
    .rd2(RD2)
  );

  extend ext(
    .instr  (InstrD[31:7]),   // usa InstrD, no Instr cruda
    .immsrc (ImmSrcD),
    .immext (ImmExt)
  );

  // ----------------------------------------------------------------
  // Registro ID/EX de DATOS — pipelina números de registro D → E
  // enable_flipflop: FlushE inserta burbuja (Rd=0 evita escrituras espurias)
  // Width = Rs1(5) + Rs2(5) + Rd(5) = 15 bits
  // ----------------------------------------------------------------
  enable_flipflop #(15) IDEX_regNumbers(
    .clk   (clk),
    .reset (reset),
    .enable(1'b1),
    .clear (FlushE),
    .d     ({InstrD[19:15], InstrD[24:20], InstrD[11:7]}),
    .q     ({Rs1E,          Rs2E,          RdE})
  );

  // ----------------------------------------------------------------
  // Registros EX/MEM de DATOS
  //   ALUResult → ALUResultM : forwarding desde etapa M
  //   RdE → RdM              : hazard detection
  // ----------------------------------------------------------------
  flopr #(32) EXMEM_aluResult(
    .clk  (clk),
    .reset(reset),
    .d    (ALUResult),
    .q    (ALUResultM)
  );

  flopr #(5) EXMEM_rd(
    .clk  (clk),
    .reset(reset),
    .d    (RdE),
    .q    (RdM)
  );

  // ----------------------------------------------------------------
  // Registro MEM/WB de DATOS
  //   RdM → RdW : hazard detection en etapa W
  // ----------------------------------------------------------------
  flopr #(5) MEMWB_rd(
    .clk  (clk),
    .reset(reset),
    .d    (RdM),
    .q    (RdW)
  );

  // ----------------------------------------------------------------
  // Forwarding mux para SrcA (entrada A de la ALU + jalr)
  //   00 → RD1        (sin forwarding, valor del regfile)
  //   01 → Result     (ResultW: writeback 2 ciclos atrás)
  //   10 → ALUResultM (forwarding desde M, 1 ciclo atrás)
  // ----------------------------------------------------------------
  mux3 #(WIDTH) fwdAmux(
    .d0(RD1),
    .d1(Result),
    .d2(ALUResultM),
    .s (ForwardAE),
    .y (SrcAFwd)
  );

  // ----------------------------------------------------------------
  // Forwarding mux para SrcB / WriteData
  //   00 → RD2, 01 → Result, 10 → ALUResultM
  //   Salida: WriteData (puerto → memoria y srcbmux)
  // ----------------------------------------------------------------
  mux3 #(WIDTH) fwdBmux(
    .d0(RD2),
    .d1(Result),
    .d2(ALUResultM),
    .s (ForwardBE),
    .y (WriteData)
  );

  // ----------------------------------------------------------------
  // ALU — etapa E
  // ----------------------------------------------------------------
  mux2 #(WIDTH) srcbmux(
    .d0(WriteData),
    .d1(ImmExt),
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

  // ----------------------------------------------------------------
  // Result mux — etapa W
  // ----------------------------------------------------------------
  mux4 #(WIDTH) resultmux(
    .d0(ALUResult),
    .d1(ReadData),
    .d2(PCPlus4),
    .d3(ImmExt),
    .s (ResultSrcW),
    .y (Result)
  );

endmodule
