module maindec(input  [6:0] op,
               output [1:0] ResultSrcD,
               output       MemWriteD,
               output       BranchD, ALUSrcD,
               output       RegWriteD, JumpD, PCTargetSrcD,
               output [2:0] ImmSrcD,
               output [1:0] ALUOp);

  // 13 bits: RegWriteD(1) + ImmSrcD(3) + ALUSrcD(1) + MemWriteD(1) +
  //          ResultSrcD(2) + BranchD(1) + ALUOp(2) + JumpD(1) + PCTargetSrcD(1) = 13
  reg [12:0] controls;

  assign {RegWriteD, ImmSrcD, ALUSrcD, MemWriteD,
          ResultSrcD, BranchD, ALUOp, JumpD, PCTargetSrcD} = controls;

  always @* case(op)
    // RegWriteD_ImmSrcD_ALUSrcD_MemWriteD_ResultSrcD_BranchD_ALUOp_JumpD_PCTargetSrcD
      7'b0000011: controls = 13'b1_000_1_0_01_0_00_0_0; // lw
      7'b0100011: controls = 13'b0_001_1_1_00_0_00_0_0; // sw
      7'b0110011: controls = 13'b1_xxx_0_0_00_0_10_0_0; // R-type
      7'b1100011: controls = 13'b0_010_0_0_00_1_01_0_0; // B-type
      7'b0010011: controls = 13'b1_000_1_0_00_0_10_0_0; // I-type ALU
      7'b1101111: controls = 13'b1_011_0_0_10_0_00_1_0; // jal
      7'b0110111: controls = 13'b1_100_x_0_11_0_xx_0_0; // lui
      7'b1100111: controls = 13'b1_000_1_0_10_0_00_1_1; // jalr
      default:    controls = 13'bx_xxx_x_x_xx_x_xx_x_x; // non-implemented instruction
    endcase
endmodule
