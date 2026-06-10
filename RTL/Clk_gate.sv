`include "Definition.sv"

module clk_gate (
    input logic clk_in,
    input logic enable,
    output logic clk_out
);

    logic latched_en;

    always_latch begin 
        if (!clk_in) begin
            latched_en <= enable;
        end
    end

    assign clk_out = clk_in & latched_en;
    
endmodule