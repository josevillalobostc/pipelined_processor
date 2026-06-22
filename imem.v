module imem(input  [31:0] a,
            output [31:0] rd);
  
  reg [31:0] RAM_WORD[63:0]; 
  reg [7:0]  RAM[255:0];
  integer i;

  initial begin
      $readmemh("riscvtest.mem", RAM_WORD); 
      for (i = 0; i < 64; i = i + 1) begin
          RAM[i*4]     = RAM_WORD[i][7:0];
          RAM[i*4+1]   = RAM_WORD[i][15:8];
          RAM[i*4+2]   = RAM_WORD[i][23:16];
          RAM[i*4+3]   = RAM_WORD[i][31:24];
      end
  end

  assign rd = {RAM[a+3], RAM[a+2], RAM[a+1], RAM[a]};
endmodule
