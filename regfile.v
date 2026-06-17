module regfile(input         clk,
               input         we3,
               input  [4:0]  a1, a2, a3,
               input  [31:0] wd3,
               output [31:0] rd1, rd2);

  reg [31:0] rf[31:0];

  // Write port: write on rising edge (first half of clock cycle)
  always @(posedge clk) begin
    if (we3) rf[a3] <= wd3;
  end

  // Read ports: combinational (second half of clock cycle)
  // Internal bypass handles WB->D same-cycle hazard (write first half, read second half)
  assign rd1 = (a1 != 5'b0) ? ((a1 == a3 && we3) ? wd3 : rf[a1]) : 32'b0;
  assign rd2 = (a2 != 5'b0) ? ((a2 == a3 && we3) ? wd3 : rf[a2]) : 32'b0;

endmodule