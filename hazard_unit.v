module hazard_unit (input [4:0] Rs1D, Rs2D, 
               input [4:0] Rs1E, Rs2E,
               input [4:0] RdE, RdM, RdW,
               input RegWriteM, RegWriteW,
               input ResultSrcEb0,
               input PCSrcE,
               output StallF, StallD, FlushD, FlushE,
               output reg [1:0] ForwardAE, ForwardBE);
  always @(*) begin 
    if((Rs1E == RdM && RegWriteM) &&  Rs1E != 0) begin
        ForwardAE = 2'b10;
      end
    else if((Rs1E == RdW && RegWriteW) && Rs1E != 0) begin
        ForwardAE = 2'b01;
      end
    else ForwardAE = 2'b00;
  end

  always @(*) begin 
    if((Rs2E == RdM && RegWriteM) &&  Rs2E != 0) begin
        ForwardBE = 2'b10;
      end
    else if((Rs2E == RdW && RegWriteW) && Rs2E != 0) begin
        ForwardBE = 2'b01;
      end
    else ForwardBE = 2'b00;
  end

  wire lwStall;
  assign lwStall = ResultSrcEb0 & ((Rs1D == RdE) | (Rs2D == RdE));
  assign StallF = lwStall;
  assign StallD = lwStall;

  assign FlushD = PCSrcE;
  assign FlushE = lwStall | PCSrcE;

endmodule
