module enable_flipflop (input        clk, reset, enable, clear,
                        input  [WIDTH-1:0] d,
                        output [WIDTH-1:0] q);

  parameter WIDTH = 8;

  reg [WIDTH-1:0] q;

  always @(posedge clk) begin
    if    (reset)  q <= 0;
    else if(clear)  q <= 0;
    else if(enable) q <= d;
  end
endmodule
