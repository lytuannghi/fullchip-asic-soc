// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    sram_top.v
// Description: 4KB Dual-Port Synchronous SRAM Macro with Byte-Write Strobes
// =============================================================================

`timescale 1ns / 1ps

module sram_top (
    input  wire        clk,
    input  wire        rst_n,

    // Port A: Instruction Fetch (Read-Only)
    input  wire [9:0]  addr_a,      // 1024 words = 4KB
    output reg  [31:0] rdata_a,

    // Port B: Data Read/Write (Read/Write with Byte Mask)
    input  wire [9:0]  addr_b,
    input  wire [31:0] wdata_b,
    input  wire [3:0]  wstrb_b,
    input  wire        we_b,
    output reg  [31:0] rdata_b
);

    reg [31:0] mem [0:1023];

    // Port A: Instruction Fetch
    always @(posedge clk) begin
        rdata_a <= mem[addr_a];
    end

    // Port B: Data Read and Write with Byte Strobes
    always @(posedge clk) begin
        if (we_b) begin
            if (wstrb_b[0]) mem[addr_b][7:0]   <= wdata_b[7:0];
            if (wstrb_b[1]) mem[addr_b][15:8]  <= wdata_b[15:8];
            if (wstrb_b[2]) mem[addr_b][23:16] <= wdata_b[23:16];
            if (wstrb_b[3]) mem[addr_b][31:24] <= wdata_b[31:24];
        end
        rdata_b <= mem[addr_b];
    end

endmodule
