module controller(input  [6:0] op,
                  input  [2:0] funct3,
                  input        funct7b5,
                  input        Zero,
                  input        Negative,
                  input        Overflow,
                  output [1:0] ResultSrc, 
                  output MemWrite,
                  output PCSrc, ALUSrc,
                  output RegWrite, Jump,
                  output [2:0] ImmSrc, 
                  output [3:0] ALUControl);
  
  wire [1:0] ALUOp; 
  wire       Branch; 
  
  maindec md(
    .op(op), 
    .ResultSrc(ResultSrc), 
    .MemWrite(MemWrite), 
    .Branch(Branch),
    .ALUSrc(ALUSrc), 
    .RegWrite(RegWrite), 
    .Jump(Jump), 
    .ImmSrc(ImmSrc), 
    .ALUOp(ALUOp)
  ); 

  aludec  ad(
    .opb5(op[5]), 
    .funct3(funct3), 
    .funct7b5(funct7b5), 
    .ALUOp(ALUOp), 
    .ALUControl(ALUControl)
  ); 
  reg ValidBranch;
  always @* case(funct3)
    3'b000 : ValidBranch = Branch & Zero;
    3'b001 : ValidBranch = Branch & ~Zero;
    3'b100 : ValidBranch = Branch & (Negative ^ Overflow);
    3'b101 : ValidBranch = Branch & (~Negative ^ Overflow);
  endcase
  assign PCSrc = ValidBranch | Jump; 
endmodule
