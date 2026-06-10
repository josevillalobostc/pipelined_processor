module mux4 (input  [WIDTH-1:0] d0, d1, d2, d3,
              input  [1:0]       s, 
              output [WIDTH-1:0] y);

  parameter WIDTH = 8;

  assign y = (s[1] & s[0] ) ? d3 : (s[1] ? d2 : ((s[0]) ? d1 : d0));
endmodule
