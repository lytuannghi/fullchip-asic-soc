// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    regfile.v
// Description: RV32I 32x32-bit Dual-Read Single-Write Register File
// =============================================================================

`timescale 1ns / 1ps

module regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);

    reg [31:0] registers [0:31];
    integer i;

    // x0 is hardwired to 0
    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : 
                    ((we && (waddr == raddr1)) ? wdata : registers[raddr1]);
    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : 
                    ((we && (waddr == raddr2)) ? wdata : registers[raddr2]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end else if (we && (waddr != 5'd0)) begin
            registers[waddr] <= wdata;
        end
    end

endmodule
