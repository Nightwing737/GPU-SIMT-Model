`include "Definition.sv"

module core (
    input logic clk,
    input logic reset_n,

    // Instruction Memory
    output logic [`ADDR_WIDTH-1:0] imem_addr,
    input logic [`INSTR_WIDTH-1:0] imem_rdata,

    // Data Memory
    output logic [`ADDR_WIDTH-1:0] dmem_addr,
    output logic [`DATA_WIDTH-1:0] dmem_wdata,
    output logic dmem_we,
    input logic [`DATA_WIDTH-1:0] dmem_rdata,
    input logic dmem_ready,
    output logic [1:0] debug_warp_state_0,
    output logic gpu_done
);

    // Warp Registers and State Tables
    logic [`ADDR_WIDTH-1:0] warp_pc [`NUM_WARPS-1:0];
    logic [`WARP_STATE_W-1:0] warp_state [`NUM_WARPS-1:0];
    logic [`LANE_MASK_WIDTH-1:0] warp_mask [`NUM_WARPS-1:0];

    logic [`NUM_WARPS-1:0] load_data_ready;
    logic [`DATA_WIDTH-1:0] load_data_buffer [`NUM_WARPS-1:0];
    logic mem_busy_lock;

    logic [`WARP_ID_WIDTH-1:0] active_warp;
    logic active_warp_valid;
    logic [`INSTR_WIDTH-1:0] current_instr;


    // SIMT Reconv Stack Struct
    logic [`ADDR_WIDTH-1:0]      simt_stack_pc   [`NUM_WARPS-1:0][`STACK_DEPTH-1:0];
    logic [`LANE_MASK_WIDTH-1:0] simt_stack_mask [`NUM_WARPS-1:0][`STACK_DEPTH-1:0];
    logic [`STACK_PTR_WIDTH-1:0] simt_stack_ptr  [`NUM_WARPS-1:0];

    // RISCV Fields
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1;
    logic [4:0] rs2;

    logic [`DATA_WIDTH-1:0] imm_i;
    logic [`DATA_WIDTH-1:0] imm_s;
    logic [`DATA_WIDTH-1:0] imm_b;

    logic [`DATA_WIDTH-1:0] lane_mem_addr [`NUM_LANES-1:0];
    logic [`DATA_WIDTH-1:0] lane_store_data [`NUM_LANES-1:0];
    logic [`DATA_WIDTH-1:0] lane_debug_x1 [`NUM_LANES-1:0];

    assign opcode = current_instr[6:0];
    assign rd = current_instr[11:7];
    assign funct3 = current_instr[14:12];
    assign rs1 = current_instr[19:15];
    assign rs2 = current_instr[24:20];
    assign funct7 = current_instr[31:25];

    assign imm_i = {{20{current_instr[31]}}, current_instr[31:20]};
    assign imm_s = {{20{current_instr[31]}}, current_instr[31:25], current_instr[11:7]};
    assign imm_b = {{20{current_instr[31]}}, current_instr[7],  current_instr[30:25],
    current_instr[11:8], 1'b0};

    assign debug_warp_state_0 = warp_state[0];

    // Fetch Routing
    assign imem_addr = warp_pc[active_warp];
    assign current_instr = imem_rdata;

    // Warp Scheduler
    always_comb begin
        active_warp = 2'b00;
        active_warp_valid = 1'b0;

        // Find first WARP that is Ready
        for (int w = 0; w < `NUM_WARPS; w=w+1) begin
            if (warp_state[w] == `WARP_READY && !active_warp_valid) begin
                active_warp = w;
                active_warp_valid = 1'b1;
            end
        end
    end

    // Branch Feedback (Checking Divergence)
    logic [`DATA_WIDTH-1:0] lane_rdata_out [`NUM_LANES-1:0];
    logic [`NUM_LANES-1:0]  lane_branch_taken;
    logic [`LANE_MASK_WIDTH-1:0] active_votes;

    assign active_votes = lane_branch_taken & warp_mask[active_warp];
    logic is_div_branch;

    assign is_div_branch = (opcode == `RV32_BRANCH) &&
                            (|active_votes) &&
                            (active_votes != warp_mask[active_warp]);


//     // //! Test
// always @(posedge clk) begin
//     if (active_warp == 2'd0 && active_warp_valid)
//         $display("W3 PC=%h opcode=%b funct3=%b imm_b=%0d branch_taken=%b",
//             warp_pc[3], opcode, funct3, $signed(imm_b), lane_branch_taken);
// end

    logic all_at_barrier;
    logic any_waiting;
    logic all_accounted;

    always_comb begin 
        any_waiting = 1'b0;
        all_accounted = 1'b1;

        for (int w = 0; w < `NUM_WARPS; w=w+1) begin
            if (warp_state[w] == `WARP_WAIT_SYNC) begin 
                any_waiting = 1'b1;
            end
            if ((warp_state[w] != `WARP_WAIT_SYNC) &&
            (warp_state[w] != `WARP_DONE))
            all_accounted = 1'b0;
        end     
        all_at_barrier = any_waiting && all_accounted;  
    end

    logic reset_done;
    logic all_done;

    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) reset_done <= 1'b0;
        else reset_done <= 1'b1; 
    end

    always_comb begin
        all_done = 1'b1;
        for (int w = 0; w < `NUM_WARPS; w=w+1) begin
            if (warp_state[w] != `WARP_DONE) begin
                all_done = 1'b0;
            end
        end
    end
    assign gpu_done = all_done && reset_done;

    // Main Pipeline
    always_ff @(posedge clk or negedge reset_n) begin 
        // Inside your always_ff block
        if (!reset_n) begin
            mem_busy_lock <= 1'b0;

            for (int w = 0; w < `NUM_WARPS; w=w+1) begin
                warp_pc[w] <= `MEM_BASE_INSTR + (w * 32'h0000_0040); // Assign PC
                warp_state[w] <= `WARP_READY;
                warp_mask[w] <= 4'b1111; 
                simt_stack_ptr[w] <= 0;
                load_data_ready[w] <= 1'b0;
                load_data_buffer[w] <= 32'h0;
            end
        end
        else begin
            if (dmem_ready) begin
                mem_busy_lock <= 1'b0;
                for (int w = 0; w < `NUM_WARPS; w=w+1) begin
                    if (warp_state[w] == `WARP_WAIT_MEM) begin
                        warp_state[w] <= `WARP_READY;
                        load_data_ready[w] <= 1'b1;
                        load_data_buffer[w] <= dmem_rdata;
                    end
                end
            end

            if (all_at_barrier) begin
                for (int w = 0; w < `NUM_WARPS; w=w+1) begin
                    if (warp_state[w] == `WARP_WAIT_SYNC) begin
                        warp_state[w] <= `WARP_READY;
                        warp_pc[w] <= warp_pc[w] + 4;  
                    end
                end
            end

            else if (active_warp_valid) begin
                if (opcode == `RV32_LOAD || opcode == `RV32_STORE) begin
                    if (!load_data_ready[active_warp]) begin
                        if (mem_busy_lock) begin
                            warp_pc[active_warp] <= warp_pc[active_warp];
                        end else begin
                            mem_busy_lock <= 1'b1;
                            warp_state[active_warp] <= `WARP_WAIT_MEM;
                            warp_pc[active_warp] <= warp_pc[active_warp];
                        end
                    end else begin
                        load_data_ready[active_warp] <= 1'b0;
                        warp_pc[active_warp] <= warp_pc[active_warp] + 4;
                    end
                end

                // Custom instr 
                else if (opcode == `RV32_CUSTOM_0 && funct3 == `F3_SYNC) begin
                    warp_state[active_warp] <= `WARP_WAIT_SYNC;
                    warp_pc[active_warp] <= warp_pc[active_warp];
                    //! Later - global barrier
                end

                else if (opcode == `RV32_CUSTOM_0 && funct3 == 3'b111) begin
                    warp_state[active_warp] <= `WARP_DONE;
                    warp_pc[active_warp] <= warp_pc[active_warp];
                end

                // Halt Instruction
                else if (opcode == `RV32_CUSTOM_0 && funct3 == `F3_RECONV) begin
                    if (simt_stack_ptr[active_warp] > 0) begin
                        logic [`STACK_PTR_WIDTH-1:0] popped_ptr;
                        popped_ptr = simt_stack_ptr[active_warp] - 1;
                        warp_pc[active_warp] <= simt_stack_pc[active_warp][popped_ptr];
                        warp_mask[active_warp] <= simt_stack_mask[active_warp][popped_ptr];
                        simt_stack_ptr[active_warp] <= popped_ptr;
                    end else begin
                        warp_pc[active_warp] <= warp_pc[active_warp] + 4;
                    end
                end        

                // Divergence Handler
                else if (is_div_branch) begin
                    simt_stack_pc[active_warp][simt_stack_ptr[active_warp]] <= warp_pc[active_warp] + imm_b;
                    simt_stack_mask[active_warp][simt_stack_ptr[active_warp]] <= ~active_votes & warp_mask[active_warp];
                    simt_stack_ptr[active_warp] <= simt_stack_ptr[active_warp] + 1;
                    warp_pc[active_warp] <= warp_pc[active_warp] + 4;
                end

                else if (opcode == `RV32_BRANCH && (&lane_branch_taken)) begin
                    warp_pc[active_warp] <= warp_pc[active_warp] + imm_b;
                end
                else begin
                    warp_pc[active_warp] <= warp_pc[active_warp] + 4;
                end
            end
        end
    end

    // Execution
    genvar i;
    generate
        for (i = 0; i < `NUM_LANES; i = i+1) begin : SIMD_LINES
            lane #(.THREAD_ID(i)) execution_lane(
                .clk(clk),
                .reset_n(reset_n),
                // Only enable Core if Scheduler mask bit high and warp select is valid
                .exec_en(warp_mask[active_warp][i] && active_warp_valid),
                .opcode(opcode),
                .funct3(funct3),
                .funct7(funct7),
                .rs1(rs1),
                .rs2(rs2),
                .rd(rd),
                .imm_i(imm_i),
                .active_warp(active_warp),
                .mem_data_in(load_data_buffer[active_warp]),
                .lane_rdata_out(lane_rdata_out[i]),
                .branch_taken(lane_branch_taken[i]),
                .mem_addr_out(lane_mem_addr[i]),
                .mem_store_data(lane_store_data[i]),
                .debug_gpr_reg1(lane_debug_x1[i])
            );
        end
    endgenerate
    
    assign dmem_addr  = ((opcode == `RV32_STORE || opcode == `RV32_LOAD) 
    && active_warp_valid && !load_data_ready[active_warp]) ? lane_mem_addr[0] : 32'h0;
    assign dmem_wdata = (opcode == `RV32_STORE) ? lane_store_data[0] : 32'h0;
    assign dmem_we    = (opcode == `RV32_STORE) && active_warp_valid && !load_data_ready[active_warp];

    always_ff @(posedge clk) begin
    if (dmem_we) begin
        $display("[DEBUG] Time: %0t | Active Warp: %0d | Store Addr: %h | Data: %h", 
                 $time, active_warp, dmem_addr, dmem_wdata);
    end
    end

endmodule