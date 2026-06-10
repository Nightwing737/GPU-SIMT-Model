`timescale 1ns/1ps
`include "../RTL/Definition.sv"

module tb_gpu;

    logic clk;
    logic reset_n;
    logic host_start;
    logic gpu_done;

    logic [`ADDR_WIDTH-1:0] imem_addr;
    wire [`INSTR_WIDTH-1:0] imem_rdata;

    logic [`ADDR_WIDTH-1:0] dmem_addr;
    logic [`DATA_WIDTH-1:0] dmem_wdata;
    logic dmem_we;
    logic [`DATA_WIDTH-1:0] dmem_rdata;
    logic dmem_ready;

    gpu_top dut(
        .clk(clk),
        .reset_n(reset_n),
        .host_start(host_start),
        .gpu_done(gpu_done),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_we(dmem_we),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready)
    );

    logic [`DATA_WIDTH-1:0] sram_array [0:65535];

    initial begin
        int file_handle;
        file_handle = $fopen("./kernel.hex", "r");
        if (file_handle == 0) begin
            $display("FATAL ERROR: Could not open kernel.hex at the specified path.");
            $finish;
        end else begin
            $display("SUCCESS: kernel.hex opened. Loading now...");
            $fclose(file_handle);
            $readmemh("./kernel.hex", sram_array);
        end
    end

    always #5 clk = ~clk;

    logic [31:0] latched_dmem_addr;
    logic [31:0] latched_dmem_wdata;
    logic latched_dmem_we;
    logic dmem_busy;

    initial begin
        $display("--- SIMULATION STARTING AT TIME %0t ---", $time);
    end

    

    assign imem_rdata = sram_array[imem_addr >> 2];

    always_ff @(posedge clk) begin

        if (dmem_addr >= `MEM_BASE_DATA && dmem_addr < `MEM_BASE_MMIO
        && !dmem_busy && !dmem_ready) begin
            latched_dmem_addr <= dmem_addr;
            latched_dmem_wdata <= dmem_wdata;
            latched_dmem_we <= dmem_we;
            dmem_busy <= 1'b1;
            dmem_ready <= 1'b0;
        end
        else if (dmem_busy) begin
            if (latched_dmem_we) begin
                sram_array[latched_dmem_addr >> 2] <= latched_dmem_wdata;
            end
            else begin
                dmem_rdata <= sram_array[latched_dmem_addr >> 2];
            end
            dmem_busy <= 1'b0;
            dmem_ready <= 1'b1;
        end
        else if (dmem_ready) begin
            dmem_ready <= 1'b0;
        end
    end

    initial begin
        clk = 0;
        reset_n = 0;
        host_start = 0;
        dmem_busy = 0;
        dmem_ready = 0;

        $dumpfile("./gpu_trace.vcd");
        $dumpvars(0, tb_gpu);

        #20;
        reset_n = 1;

        #20;
        host_start = 1;
        $display("GPU KERNEL START");

        wait(gpu_done == 1'b1);
        #50;
        $display("GPU EXECUTION COMPLETE.", $time);

        $display("RESULT [0]: %h", sram_array[(`MEM_BASE_DATA >> 2)+0]);  // w0
        $display("RESULT [1]: %h", sram_array[(`MEM_BASE_DATA >> 2)+1]);  // w1
        $display("RESULT [2]: %h", sram_array[(`MEM_BASE_DATA >> 2)+2]);  // w2
        $display("RESULT [3]: %h", sram_array[(`MEM_BASE_DATA >> 2)+3]); 
        $finish;
    end

initial begin
    #45;  // after host_start
    $display("w0[0]=%h w0[6]=%h", sram_array[0], sram_array[6]);
    $display("w3[0]=%h w3[6]=%h", sram_array[48], sram_array[54]);
end
    initial begin
    #20; // Wait for initial reset and readmemh to finish
    $display("DEBUG: Memory index 0 contains: %h", sram_array[0]);
    $display("DEBUG: Memory index 1 contains: %h", sram_array[1]);
    end
    initial begin
        #1000000;
        $display("FATAL: Watchdog timer expired. Core deadlocked.");
        $finish;
    end
    
endmodule