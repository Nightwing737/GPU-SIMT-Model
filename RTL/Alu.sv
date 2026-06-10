
`include "Definition.sv"

module alu (
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic [`DATA_WIDTH-1:0] op1,
    input logic [`DATA_WIDTH-1:0] op2,
    output logic [`DATA_WIDTH-1:0] result
);

    logic [`DATA_WIDTH-1:0] add_sub_res;
    logic [`DATA_WIDTH-1:0] sll_res;
    logic [`DATA_WIDTH-1:0] srl_sra_res;
    logic [`DATA_WIDTH-1:0] slt_res;
    logic [`DATA_WIDTH-1:0] xor_res;
    logic [`DATA_WIDTH-1:0] or_res;
    logic [`DATA_WIDTH-1:0] and_res;

    assign add_sub_res = (funct7 == `F7_ALT && opcode == `RV32_OP) ? (op1 - op2) : (op1 + op2);
    assign sll_res     = op1 << op2[4:0];
    assign srl_sra_res = (funct7 == `F7_ALT) ? ($signed(op1) >>> op2[4:0]) : (op1 >> op2[4:0]);
    assign slt_res     = ($signed(op1) < $signed(op2)) ? 32'h1 : 32'h0;
    
    assign xor_res     = op1 ^ op2;
    assign or_res      = op1 | op2;
    assign and_res     = op1 & op2;

    always_comb begin 
        result = 32'h0;
        if (opcode == `RV32_LOAD || opcode == `RV32_STORE) begin
            result = add_sub_res;
        end
        else if (opcode == `RV32_OP || opcode == `RV32_IM) begin
            case (funct3)
                `F3_ADD_SUB: result = add_sub_res;
                `F3_SLL:     result = sll_res;
                `F3_SLT:     result = slt_res;
                `F3_XOR:     result = xor_res;
                `F3_SRL_SRA: result = srl_sra_res;
                `F3_OR:      result = or_res;
                `F3_AND:     result = and_res;
                default:     result = 32'h0;
            endcase
        end
    end
endmodule