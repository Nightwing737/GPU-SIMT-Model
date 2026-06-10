`include "Definition.sv"

module gpu_top (
    input logic clk,
    input logic reset_n,

    input logic host_start,
    output logic gpu_done,

    output logic [`ADDR_WIDTH-1:0] imem_addr,
    input logic [`INSTR_WIDTH-1:0] imem_rdata,

    output logic [`ADDR_WIDTH-1:0] dmem_addr,
    output logic [`DATA_WIDTH-1:0] dmem_wdata,
    output logic dmem_we,
    input logic [`DATA_WIDTH-1:0] dmem_rdata,
    input logic dmem_ready
); 

    logic [`ADDR_WIDTH-1:0] core_imem_addr;
    logic [`ADDR_WIDTH-1:0] core_dmem_addr;
    logic [`DATA_WIDTH-1:0] core_dmem_wdata;
    logic core_dmem_we;

    logic core_reset_n;
    assign core_reset_n = reset_n & host_start;

    logic[1:0] debug_warp_state_0_unused;

    core gpu_compute_core(
        .clk(clk),
        .reset_n(core_reset_n),
        .imem_addr(core_imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr(core_dmem_addr),
        .dmem_wdata(core_dmem_wdata),
        .dmem_we(core_dmem_we),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .debug_warp_state_0(debug_warp_state_0_unused),
        .gpu_done(gpu_done)
    );

    assign imem_addr = core_imem_addr;

    logic is_vram_addr;
    assign is_vram_addr = (core_dmem_addr >= `MEM_BASE_DATA) 
    && (core_dmem_addr < `MEM_BASE_MMIO);

    assign dmem_addr = is_vram_addr ? core_dmem_addr : 32'h0;
    assign dmem_wdata = is_vram_addr ? core_dmem_wdata : 32'h0;
    assign dmem_we = is_vram_addr ? core_dmem_we : 1'b0;

    logic is_mmio_addr;
    assign is_mmio_addr = (core_dmem_addr >= `MEM_BASE_MMIO);
endmodule