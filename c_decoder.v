module c_decoder(
    input  [15:0] c_instr,
    output reg [31:0] instr_32
);

    // rs1' y rs2'
    wire [4:0] rd_prime  = {2'b01, c_instr[4:2]};
    wire [4:0] rs1_prime = {2'b01, c_instr[9:7]};
    wire [4:0] rs2_prime = {2'b01, c_instr[4:2]};

    wire [4:0] c_rd  = c_instr[11:7];
    wire [4:0] c_rs1 = c_instr[11:7];
    wire [4:0] c_rs2 = c_instr[6:2];


    always @(*) begin
        instr_32 = {16'b0, c_instr};
        case (c_instr[1:0])
            2'b00: begin
                case (c_instr[15:13])
                    // c.lw -> lw rd', imm(rs1')
                    3'b010: instr_32 = { {5'b0, c_instr[5], c_instr[12:10], c_instr[6], 2'b00}, rs1_prime, 3'b010, rd_prime, 7'b0000011 };
                    
                    // c.sw -> sw rs2', imm(rs1')
                    3'b110: instr_32 = { {5'b00000, c_instr[5], c_instr[12]}, rs2_prime, rs1_prime, 3'b010, {c_instr[11:10], c_instr[6], 2'b00}, 7'b0100011 };
                endcase
            end

            2'b01: begin
                case (c_instr[15:13])
                    // c.addi -> addi rd, rd, imm
                    3'b000: instr_32 = { {6{c_instr[12]}}, c_instr[12], c_instr[6:2], c_rs1, 3'b000, c_rd, 7'b0010011 };

                    // c.jal -> jal x1, offset  (Solo RV32C)
                    3'b001: instr_32 = { c_instr[12], c_instr[8], c_instr[10:9], c_instr[6], c_instr[7], c_instr[2], c_instr[11], c_instr[5:3], c_instr[12], {8{c_instr[12]}}, 5'd1, 7'b1101111 };

                    // c.lui -> lui rd, nzimm
                    3'b011: instr_32 = { {15{c_instr[12]}}, c_instr[6:2], c_rd, 7'b0110111 };

                    3'b100: begin
                        case (c_instr[11:10])
                            // c.srli -> srli rd', rd', shamt
                            2'b00: instr_32 = { 6'b000000, c_instr[12], c_instr[6:2], rs1_prime, 3'b101, rs1_prime, 7'b0010011 };
                            
                            // c.srai -> srai rd', rd', shamt
                            2'b01: instr_32 = { 6'b010000, c_instr[12], c_instr[6:2], rs1_prime, 3'b101, rs1_prime, 7'b0010011 };
                            
                            // c.andi -> andi rd', rd', imm
                            2'b10: instr_32 = { {6{c_instr[12]}}, c_instr[12], c_instr[6:2], rs1_prime, 3'b111, rs1_prime, 7'b0010011 };
                            
                            2'b11: begin
                                case (c_instr[6:5])
                                    // c.sub -> sub rd', rd', rs2'
                                    2'b00: instr_32 = { 7'b0100000, rs2_prime, rs1_prime, 3'b000, rs1_prime, 7'b0110011 };
                                    // c.xor -> xor rd', rd', rs2'
                                    2'b01: instr_32 = { 7'b0000000, rs2_prime, rs1_prime, 3'b100, rs1_prime, 7'b0110011 };
                                    // c.or -> or rd', rd', rs2'
                                    2'b10: instr_32 = { 7'b0000000, rs2_prime, rs1_prime, 3'b110, rs1_prime, 7'b0110011 };
                                    // c.and -> and rd', rd', rs2'
                                    2'b11: instr_32 = { 7'b0000000, rs2_prime, rs1_prime, 3'b111, rs1_prime, 7'b0110011 };
                                endcase
                            end
                        endcase
                    end

                    // c.j -> jal x0, offset
                    3'b101: instr_32 = { c_instr[12], c_instr[8], c_instr[10:9], c_instr[6], c_instr[7], c_instr[2], c_instr[11], c_instr[5:3], c_instr[12], {8{c_instr[12]}}, 5'd0, 7'b1101111 };

                    // c.beqz -> beq rs1', x0, offset
                    3'b110: instr_32 = { {4{c_instr[12]}}, c_instr[6:5], c_instr[2], 5'b00000, rs1_prime, 3'b000, c_instr[11:10], c_instr[4:3], c_instr[12], 7'b1100011 };
                    
                    // c.bnez -> bne rs1', x0, offset
                    3'b111: instr_32 = { {4{c_instr[12]}}, c_instr[6:5], c_instr[2], 5'b00000, rs1_prime, 3'b001, c_instr[11:10], c_instr[4:3], c_instr[12], 7'b1100011 };
                endcase
            end

            2'b10: begin
                case (c_instr[15:13])
                    // c.slli -> slli rd, rd, shamt
                    3'b000: instr_32 = { 6'b000000, c_instr[12], c_instr[6:2], c_rd, 3'b001, c_rd, 7'b0010011 };

                    // c.lwsp -> lw rd, imm(x2)
                    3'b010: instr_32 = { 4'b0000, c_instr[3:2], c_instr[12], c_instr[6:4], 2'b00, 5'd2, 3'b010, c_rd, 7'b0000011 };

                    3'b100: begin
                        if (c_instr[12] == 1'b0 && c_instr[6:2] == 5'b00000)
                            // c.jr -> jalr x0, rs1, 0
                            instr_32 = { 12'b0, c_rs1, 3'b000, 5'b00000, 7'b1100111 };
                        else if (c_instr[12] == 1'b1 && c_instr[6:2] == 5'b00000)
                            // c.jalr -> jalr x1, rs1, 0
                            instr_32 = { 12'b0, c_rs1, 3'b000, 5'b00001, 7'b1100111 };
                        else if (c_instr[12] == 1'b1 && c_instr[6:2] != 5'b00000)
                            // c.add -> add rd, rd, rs2
                            instr_32 = { 7'b0000000, c_rs2, c_rd, 3'b000, c_rd, 7'b0110011 };
                    end

                    // c.swsp -> sw rs2, imm(x2)
                    3'b110: instr_32 = { 4'b0000, c_instr[8:7], c_instr[12], c_rs2, 5'd2, 3'b010, c_instr[11:9], 2'b00, 7'b0100011 };
                endcase
            end
        endcase
    end
endmodule
