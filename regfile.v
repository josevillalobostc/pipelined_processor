module regfile(input         clk,
               input         we3,
               input  [4:0]  a1, a2, a3,
               input  [31:0] wd3,
               output [31:0] rd1, rd2);

  reg [31:0] rf[31:0];

  // puerto de escritura: escribe en el flanco de subida (primera mitad del ciclo de reloj)
  always @(posedge clk) begin
    if (we3) rf[a3] <= wd3;
  end

  // puertos de lectura: combinacionales (para leer en segunda mitad del ciclo de reloj)
  assign rd1 = (a1 != 5'b0) ? ((a1 == a3 && we3) ? wd3 : rf[a1]) : 32'b0;
  assign rd2 = (a2 != 5'b0) ? ((a2 == a3 && we3) ? wd3 : rf[a2]) : 32'b0;

endmodule
