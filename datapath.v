module datapath(input         clk, reset,

                // -- Etapa D: solo ImmSrc (Extend vive en Decode) --
                input  [2:0]  ImmSrcD,

                // -- Etapa E: señales de control para la ALU y salto --
                input         ALUSrcE,
                input         PCTargetSrcE,
                input         BranchE,
                input         JumpE,
                input  [3:0]  ALUControlE,

                // -- Etapa W: señales de control para el Register File y result mux --
                input         RegWriteW,
                input  [1:0]  ResultSrcW,

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

  // -- Flags de la ALU (internas, ya no van al controller) --
  wire Zero, Negative, Overflow;

  // ----------------------------------------------------------------
  // PCSrc — lógica de salto en etapa E
  // Usa BranchE/JumpE del controller y las flags de la ALU.
  // Opción B: lógica extendida beq/bne/blt/bge.
  // NOTA: funct3 se toma de Instr[14:12] (instrucción en D stage).
  // Cuando se agreguen los registros de datos del pipeline, se debe
  // reemplazar por InstrE[14:12] del registro ID/EX de datos.
  // ----------------------------------------------------------------
  reg  ValidBranch;
  wire PCSrc;

  always @* case(Instr[14:12])
    3'b000 : ValidBranch = BranchE &  Zero;                    // beq
    3'b001 : ValidBranch = BranchE & ~Zero;                    // bne
    3'b100 : ValidBranch = BranchE &  (Negative ^ Overflow);   // blt (signed)
    3'b101 : ValidBranch = BranchE & ~(Negative ^ Overflow);   // bge (signed)
    default: ValidBranch = 1'b0;
  endcase

  assign PCSrc = ValidBranch | JumpE;

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

  // Mux base de PCTarget:
  //   PCTargetSrcE=0 → PC + ImmExt  (jal, branches)
  //   PCTargetSrcE=1 → SrcA + ImmExt (jalr)
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

  // Bit 0 forzado a 0 (jalr spec)
  mux2 #(WIDTH) pcmux(
    .d0(PCPlus4),
    .d1({PCTarget[31:1], 1'b0}),
    .s (PCSrc),
    .y (PCNext)
  );

  // ----------------------------------------------------------------
  // Register File — escribe en etapa W con RegWriteW
  // ----------------------------------------------------------------
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

  // Extend vive en etapa D → usa ImmSrcD
  extend ext(
    .instr  (Instr[31:7]),
    .immsrc (ImmSrcD),
    .immext (ImmExt)
  );

  // ----------------------------------------------------------------
  // ALU — opera en etapa E con ALUSrcE / ALUControlE
  // ----------------------------------------------------------------
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

  // ----------------------------------------------------------------
  // Result mux — selecciona en etapa W con ResultSrcW
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
