`include "Definition.sv"

module lane #(
    parameter int THREAD_ID = 0
)(
    input logic clk,
    input logic reset_n,

    input  logic                      exec_en,      
    input  logic [6:0]                opcode,
    input  logic [2:0]                funct3,
    input  logic [6:0]                funct7,
    input  logic [4:0]                rs1,
    input  logic [4:0]                rs2,
    input  logic [4:0]                rd,
    input  logic [`DATA_WIDTH-1:0]    imm_i,
    input  logic [`WARP_ID_WIDTH-1:0] active_warp,  
    
    input  logic [`DATA_WIDTH-1:0]    mem_data_in,
    output logic [`DATA_WIDTH-1:0]    lane_rdata_out,
    output logic                      branch_taken,
    output logic [`DATA_WIDTH-1:0]    mem_addr_out,
    output logic [`DATA_WIDTH-1:0]    mem_store_data,
    output logic [`DATA_WIDTH-1:0]    debug_gpr_reg1
);

    logic [`DATA_WIDTH-1:0] gpr [`NUM_WARPS-1:0][`REG_COUNT-1:0];
    assign debug_gpr_reg1 = gpr[active_warp][5'b00001];

    logic [`DATA_WIDTH-1:0] rs1_val;
    logic [`DATA_WIDTH-1:0] rs2_val;

    assign rs1_val = (rs1 == 5'b00) ? 32'h0 : gpr[active_warp][rs1];
    assign rs2_val = (rs2 == 5'b00) ? 32'h0 : gpr[active_warp][rs2];

    logic [`DATA_WIDTH-1:0] alu_op2;
    always_comb begin 
        case (opcode)
            `RV32_IM, `RV32_LOAD: alu_op2 = imm_i;
            default: alu_op2 = rs2_val;
        endcase     
    end
    
    logic [`DATA_WIDTH-1:0] alu_core_result;
    logic [`DATA_WIDTH-1:0] final_writeback_data;

    alu lane_alu(
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .op1(rs1_val),
        .op2(alu_op2),
        .result(alu_core_result)
    );

    always_comb begin 
        final_writeback_data = alu_core_result;

        if (opcode == `RV32_CUSTOM_0) begin
            case (funct3)
                `F3_GET_TID: final_writeback_data = THREAD_ID;
                `F3_GET_WID: final_writeback_data = {{32-`WARP_ID_WIDTH{1'b0}}, active_warp}; 
                default: final_writeback_data = 32'h0;
            endcase
        end
    end

    always_comb begin
        branch_taken = 1'b0;
        if (opcode == `RV32_BRANCH) begin
            case (funct3)
                `F3_BEQ: branch_taken = (rs1_val == rs2_val);
                `F3_BNE: branch_taken = (rs1_val != rs2_val); 
                default: branch_taken = 1'b0;
            endcase
        end
    end

    assign lane_rdata_out = (opcode == `RV32_STORE) ? rs2_val : alu_core_result;
    assign mem_addr_out   = alu_core_result;    
    assign mem_store_data = rs2_val;    
    always_ff @(posedge clk or negedge reset_n) begin

        integer w;
        integer r;

        if (!reset_n) begin
            for (w = 0; w < `NUM_WARPS; w = w+1) begin
                for (r = 0; r < `REG_COUNT; r = r+1) begin
                    gpr[w][r] <= 0;
                end
            end
        end
        else begin     
            if (exec_en && (rd != 5'b0)) begin
                if (opcode == `RV32_OP || opcode == `RV32_IM 
                || opcode == `RV32_CUSTOM_0) begin
                    gpr[active_warp][rd] <= final_writeback_data;
                end
                else if (opcode == `RV32_LOAD) begin
                    gpr[active_warp][rd] <= mem_data_in;
                end
            end     
        end
    end

endmodule