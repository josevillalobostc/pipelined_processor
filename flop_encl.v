// Enable-clear flip-flop (synchronous reset, clear, and enable)
// Priority: reset > clear > enable > hold
module flop_encl #(parameter WIDTH = 8)
                  (input              clk, reset, enable, clear,
                   input  [WIDTH-1:0] d,
                   output reg [WIDTH-1:0] q);

  always @(posedge clk) begin
    if      (reset)  q <= {WIDTH{1'b0}};
    else if (clear)  q <= {WIDTH{1'b0}};
    else if (enable) q <= d;
    // else: hold (stall)
  end

endmodule
