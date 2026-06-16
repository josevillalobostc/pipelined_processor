module datapath(input         clk, reset,
                // -- Señales de control etapa D (vienen del Control Unit) --
                input  [1:0]  ResultSrcD,
                input         ALUSrcD,
                input         PCTargetSrcD,
                input         RegWriteD,
                input         BranchD,          // antes salía del controller como señal interna
                input         JumpD,
                input  [2:0]  ImmSrcD,
                input  [3:0]  ALUControlD,
                // -- Interfaz con memorias --
                output [31:0] PC,
                input  [31:0] Instr,
                output [31:0] ALUResult, WriteData,
                input  [31:0] ReadData);

  localparam WIDTH = 32;

  wire [31:0] PCNext, PCPlus4, PCTarget;
  wire [31:0] ImmExt;
  wire [31:0] SrcA, SrcB, SrcPC;
  wire [31:0] Result;

  // -- Flags de la ALU (ya no salen al controller) --
  wire Zero, Negative, Overflow;

  // ----------------------------------------------------------------
  // Lógica de PCSrc — movida aquí desde el controller (etapa E)
  // Usa BranchD/JumpD del control y las flags de la ALU para decidir
  // si se toma el salto. Opción B: lógica extendida bne/blt/bge.
  // ----------------------------------------------------------------
  reg  ValidBranch;
  wire PCSrc;

  always @* case(Instr[14:12])   // funct3 selecciona el tipo de branch
    3'b000 : ValidBranch = BranchD &  Zero;                    // beq
    3'b001 : ValidBranch = BranchD & ~Zero;                    // bne
    3'b100 : ValidBranch = BranchD &  (Negative ^ Overflow);   // blt  (signed)
    3'b101 : ValidBranch = BranchD & ~(Negative ^ Overflow);   // bge  (signed)
    default: ValidBranch = 1'b0;
  endcase

  assign PCSrc = ValidBranch | JumpD;

  // ----------------------------------------------------------------
  // Lógica de próximo PC
  // ----------------------------------------------------------------
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

  // Mux: base del cálculo de PCTarget
  //   PCTargetSrcD=0 → PC+ImmExt  (jal, branch)
  //   PCTargetSrcD=1 → SrcA+ImmExt (jalr)
  mux2 pcaddsource(
    .d0(PC),
    .d1(SrcA),
    .s (PCTargetSrcD),
    .y (SrcPC)
  );

  adder pcaddbranch(
    .a(SrcPC),
    .b(ImmExt),
    .y(PCTarget)
  );

  // Bit 0 forzado a 0 para alinear a instrucción (jalr spec)
  mux2 #(WIDTH) pcmux(
    .d0(PCPlus4),
    .d1({PCTarget[31:1], 1'b0}),
    .s (PCSrc),
    .y (PCNext)
  );

  // ----------------------------------------------------------------
  // Register File
  // ----------------------------------------------------------------
  regfile rf(
    .clk(clk),
    .we3(RegWriteD),
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

  // ----------------------------------------------------------------
  // ALU
  // ----------------------------------------------------------------
  mux2 #(WIDTH) srcbmux(
    .d0(WriteData),
    .d1(ImmExt),
    .s (ALUSrcD),
    .y (SrcB)
  );

  alu alu(
    .a         (SrcA),
    .b         (SrcB),
    .alucontrol(ALUControlD),
    .result    (ALUResult),
    .zero      (Zero),       // se usa internamente para ValidBranch
    .neg       (Negative),   // idem
    .v         (Overflow)    // idem
  );

  // ----------------------------------------------------------------
  // Result mux (selecciona qué se escribe en el Register File)
  // ----------------------------------------------------------------
  mux4 #(WIDTH) resultmux(
    .d0(ALUResult),
    .d1(ReadData),
    .d2(PCPlus4),
    .d3(ImmExt),
    .s (ResultSrcD),
    .y (Result)
  );

endmodule
