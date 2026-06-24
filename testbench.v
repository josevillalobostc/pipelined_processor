`timescale 1ns / 1ns

module testbench;
  reg          clk;
  reg          reset;
  wire [31:0]  WriteData;
  wire [31:0]  DataAdr;
  wire         MemWrite;
  
  top dut(
    .clk(clk), 
    .reset(reset), 
    .WriteData(WriteData), 
    .DataAdr(DataAdr), 
    .MemWrite(MemWrite)
  );

  initial begin
    reset = 1; # 22;
    reset = 0;
  end

  always begin
    clk = 1;
    # 5; clk = 0; # 5;
  end

  initial begin
    #2000;
    $display("Finishing...");
    $finish;
  end

  always @(negedge clk) begin
    if(MemWrite) begin
      if(DataAdr === 32'd8 & WriteData === 32'd40) begin
        $display("Simulation succeeded");
        $stop;
      end else begin
        $display("Simulation failed");
        $stop;
      end
    end
  end
endmodule