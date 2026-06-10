module riscvsingle(input  clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output MemWrite,
                   output [31:0] DataAdr, 
                   output [31:0] WriteData,
                   input  [31:0] ReadData);
  
  wire [31:0] ALUResult; 
  
  wire       ALUSrc, RegWrite, Jump, Zero, Negative, Overflow; 
  wire [1:0] ResultSrc;
  wire [2:0] ImmSrc; 
  wire [3:0] ALUControl; 
  wire       PCSrc; 

  // DataAdr is connected to ALUResult
  assign DataAdr = ALUResult;

  controller c(
    .op(Instr[6:0]), 
    .funct3(Instr[14:12]), 
    .funct7b5(Instr[30]), 
    .Zero(Zero),
    .Negative(Negative),
    .Overflow(Overflow),
    .ResultSrc(ResultSrc), 
    .MemWrite(MemWrite), 
    .PCSrc(PCSrc),
    .ALUSrc(ALUSrc), 
    .RegWrite(RegWrite), 
    .Jump(Jump),
    .ImmSrc(ImmSrc), 
    .ALUControl(ALUControl)
  ); 
  
  datapath dp(
    .clk(clk), 
    .reset(reset), 
    .ResultSrc(ResultSrc), 
    .PCSrc(PCSrc),
    .ALUSrc(ALUSrc), 
    .RegWrite(RegWrite),
    .ImmSrc(ImmSrc), 
    .ALUControl(ALUControl),
    .Zero(Zero), 
    .Negative(Negative),
    .Overflow(Overflow),
    .PC(PC), 
    .Instr(Instr),
    .ALUResult(ALUResult), 
    .WriteData(WriteData), 
    .ReadData(ReadData)
  ); 
endmodule
