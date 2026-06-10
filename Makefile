# ==============================================================================
# Toolchain Definitions
# ==============================================================================
COMPILER = iverilog
SIMULATOR = vvp
VIEWER = gtkwave

# Compilation flags: 
# -g2012 enforces SystemVerilog-2012 IEEE standard.
# -Wall enables all warnings. Do not ignore warnings in hardware design.
CFLAGS = -g2012 -Wall -I RTL

# ==============================================================================
# Source File Hierarchy
# ==============================================================================
# Order strictly matters. defines.sv must be compiled first so the preprocessor 
# can expose the macros to the downstream modules.
RTL_SRC = \
	RTL/Clk_gate.sv \
	RTL/Alu.sv \
	RTL/Lane.sv \
	RTL/Core.sv \
	RTL/GPU_top.sv

SIM_SRC = Test/tb_gpu.sv

# Output binaries and trace files
SIM_BIN = Test/gpu_sim.vvp
VCD_FILE = Test/gpu_trace.vcd

# ==============================================================================
# Execution Targets
# ==============================================================================

# Default target executes when you just type 'make'
all: compile run

# 1. Compilation Phase
compile:
	@echo "================================================================"
	@echo "1. COMPILING RTL AND TESTBENCH"
	@echo "================================================================"
	$(COMPILER) $(CFLAGS) -o $(SIM_BIN) $(RTL_SRC) $(SIM_SRC)

# 2. Simulation Phase
run: compile
	@echo "================================================================"
	@echo "2. EXECUTING SIMULATION"
	@echo "================================================================"
	@if [ ! -f Test/kernel.hex ]; then \
		echo "FATAL: kernel.hex not found. You must create the machine code file."; \
		exit 1; \
	fi
	$(SIMULATOR) $(SIM_BIN)

# 3. Waveform Analysis
wave: run
	@echo "================================================================"
	@echo "3. LAUNCHING GTKWAVE"
	@echo "================================================================"
	$(VIEWER) $(VCD_FILE) &

# 4. Clean Directory
clean:
	@echo "Cleaning simulation binaries and waveforms..."
	rm -f $(SIM_BIN) $(VCD_FILE)

# Declare phony targets to prevent conflicts with files named 'clean' or 'all'
.PHONY: all compile run wave clean