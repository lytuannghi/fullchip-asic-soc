// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    boot_rom.v
// Description: 1KB On-Chip Boot ROM (Synthesizable ASIC Macro)
// =============================================================================

`timescale 1ns / 1ps

module boot_rom (
    input  wire        clk,
    input  wire [9:0]  addr,    // Word-aligned address (256 words = 1KB)
    output reg  [31:0] rdata
);

    reg [31:0] rom [0:255];

    always @(posedge clk) begin
        rdata <= rom[addr];
    end

    // ROM Initialization (Default Boot Routine)
    initial begin
        // 0x0000_0000: jal x0, 0x400 (Direct jump to SRAM at 0x0000_0400)
        rom[0] = 32'h4000006f;
        rom[1] = 32'h00000013; // nop
        rom[2] = 32'h00000013; // nop
    end

endmodule
