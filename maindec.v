module maindec(input  [6:0] op,
               output [1:0] ResultSrcD,
               output       MemWriteD,
               output       BranchD, ALUSrcD,
               output       RegWriteD, JumpD, PCTargetSrcD,
               output [2:0] ImmSrcD,
               output [1:0] ALUOp);

  // Control signals bit layout (13 bits total):
  // [12]    RegWriteD
  // [11:9]  ImmSrcD
  // [8]     ALUSrcD
  // [7]     MemWriteD
  // [6:5]   ResultSrcD
  // [4]     BranchD
  // [3:2]   ALUOp
  // [1]     JumpD
  // [0]     PCTargetSrcD
  reg [12:0] controls;

  assign {RegWriteD, ImmSrcD, ALUSrcD, MemWriteD,
          ResultSrcD, BranchD, ALUOp, JumpD, PCTargetSrcD} = controls;

  always @* case(op)
    //                      RegW ImmSrc  ALUS MemW  ResultSrc Br ALUOp  Jmp PCTgt
    7'b0000011: controls = 13'b1_000_1_0_01_0_00_0_0; // lw
    7'b0100011: controls = 13'b0_001_1_1_00_0_00_0_0; // sw
    7'b0110011: controls = 13'b1_000_0_0_00_0_10_0_0; // R-type
    7'b1100011: controls = 13'b0_010_0_0_00_1_01_0_0; // B-type (beq/bne/blt/bge)
    7'b0010011: controls = 13'b1_000_1_0_00_0_10_0_0; // I-type ALU (addi/xori/ori/andi/slli/srli/srai)
    7'b1101111: controls = 13'b1_011_0_0_10_0_00_1_0; // jal
    7'b0110111: controls = 13'b1_100_0_0_11_0_00_0_0; // lui
    7'b1100111: controls = 13'b1_000_1_0_10_0_00_1_1; // jalr
    7'b0000000: controls = 13'b0_000_0_0_00_0_00_0_0; // NOP/flush bubble
    default:    controls = 13'b0_000_0_0_00_0_00_0_0; // undefined -> safe NOP
  endcase
endmodule
