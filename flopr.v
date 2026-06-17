// Resettable flip-flop (asynchronous reset)
module flopr #(parameter WIDTH = 8)
              (input              clk, reset,
               input  [WIDTH-1:0] d,
               output reg [WIDTH-1:0] q);

  always @(posedge clk or posedge reset) begin
    if (reset) q <= {WIDTH{1'b0}};
    else       q <= d;
  end

endmodule