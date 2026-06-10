module aludec(input  opb5,
              input  [2:0] funct3,
              input  funct7b5, 
              input  [1:0] ALUOp,
              output [3:0] ALUControl);
  
  wire  RtypeSub; 
  reg [3:0] ALUControl_reg; 

  assign RtypeSub = funct7b5 & opb5;  // TRUE for R-type subtract instruction
  assign ALUControl = ALUControl_reg;

  always @* case(ALUOp)
      2'b00:                ALUControl_reg = 4'b0000; // addition
      2'b01:                ALUControl_reg = 4'b0001; // subtraction
      default: case(funct3) // R-type or I-type ALU
                 3'b000:  if (RtypeSub) 
                            ALUControl_reg = 4'b0001; // sub
                          else          
                            ALUControl_reg = 4'b0000; // add, addi
                 3'b010:    ALUControl_reg = 4'b0101; // slt, slti
                 3'b110:    ALUControl_reg = 4'b0011; // or, ori
                 3'b111:    ALUControl_reg = 4'b0010; // and, andi
                 3'b100:    ALUControl_reg = 4'b0100; // xor
                 3'b001:    ALUControl_reg = 4'b0110; // sll
                 3'b101:    if(funct7b5)
                              ALUControl_reg = 4'b1000;
                            else 
                              ALUControl_reg = 4'b0111;
                 default:   ALUControl_reg = 4'bxxxx; // ???
               endcase
    endcase
endmodule
