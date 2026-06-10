# GPU-SIMT-PROJECT


### A synthesizable SIMT (Single Instruction Multiple Threads) GPU processor core built in SystemVerilog. Implements a custom, simplified RISCV-32 based ISA.

### <u>KEY FEATURES</u>
* __Multi-Warp Scheduler__: Utilizes concurrent warps with priority based warp-scheduling.
* __SIMD Execution Lanes__: Broadcasts decoded instructions across multiple parallel lanes.
* __Instruction Replay Architecture__: Emulates real GPU memory controllers by using an MSHR-like buffer to handle long-latency load/store operations without stalling the main pipeline.
* __Branch Divergence Management__: Implements a SIMT reconvergence stack to handle divergent control flow across threads.
* __Memory Subsystem Wrapper__: Features a top-level bridge (gpu_top.sv) with address decoding to safely handle VRAM operations.
* __Self-Contained Testbench__: Employs a unified SRAM array (tb_gpu.sv) that dynamically loads compiled assembly binaries (kernel.hex) for cycle-accurate simulation and verification.

## Quick Start

### Using Makefile
```bash
make clean
make            # Text output
make wave       # Check on GTKWAVE
```

### Using Direct Commands
```powershell
iverilog -g2012 -I RTL -o Test/gpu_sim.vvp RTL/*.sv Test/tb_gpu.sv
vvp Test/gpu_sim.vvp            # Run First always. Text output
gtkwave 
```