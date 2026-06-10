`timescale 1ns/1ps
`ifndef DEFINITION_SV
`define DEFINITION_SV

`define DATA_WIDTH      32
`define ADDR_WIDTH      32
`define INSTR_WIDTH     32

`define NUM_WARPS       4
`define WARP_ID_WIDTH   2
`define NUM_LANES       4
`define LANE_MASK_WIDTH 4
`define REG_COUNT       32

`define STACK_DEPTH     8
`define STACK_PTR_WIDTH 3

`define OPCODE_MASK     7'h7F
`define FUNCT3_MASK     3'h7
`define FUNCT7_MASK     7'h7F

// Base OPCODES
`define RV32_OP         7'b0110011
`define RV32_IM         7'b0010011
`define RV32_LOAD       7'b0000011
`define RV32_STORE      7'b0100011
`define RV32_BRANCH     7'b1100011
`define RV32_CUSTOM_0     7'b0001011

//* Funct3 definitions
// FOR OP AND IM
`define F3_ADD_SUB      3'b000
`define F3_SLL          3'b001
`define F3_SLT          3'b010
`define F3_XOR          3'b100
`define F3_SRL_SRA      3'b101
`define F3_OR           3'b110
`define F3_AND          3'b111

// FOR BRANCH
`define F3_BEQ          3'b000
`define F3_BNE         3'b001

// FOR LOAD AND STORE
`define F3_WORD         3'b010

//* Funct7 definitions
// Differentiate ADD/SUB, SRL/SRA
`define F7_BASE         7'b0000000
`define F7_ALT          7'b0100000
`define F7_MULDIV       7'b0000001

//* GPU SIMT Instr
`define F3_SYNC         3'b000
`define F3_RECONV       3'b001
`define F3_GET_TID      3'b010
`define F3_GET_WID      3'b011
`define F3_HALT         3'b100

//* Warp States
`define WARP_STATE_W    2
`define WARP_READY      2'b00
`define WARP_WAIT_MEM   2'b01
`define WARP_WAIT_SYNC  2'b10
`define WARP_DONE       2'b11

//* Memory Map
`define MEM_BASE_INSTR  32'h0000_0000 
`define MEM_BASE_DATA   32'h0000_0100 
`define MEM_BASE_MMIO   32'hFFFF_0000

`endif