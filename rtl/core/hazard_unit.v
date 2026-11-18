// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    hazard_unit.v
// Description: Pipeline Hazard Detection and Forwarding Unit
// =============================================================================

`timescale 1ns / 1ps

module hazard_unit (
    input  wire [4:0]  rs1_e,
    input  wire [4:0]  rs2_e,
    input  wire [4:0]  rd_m,
    input  wire        reg_write_m,
    input  wire [4:0]  rd_w,
    input  wire        reg_write_w,
    input  wire [4:0]  rs1_d,
    input  wire [4:0]  rs2_d,
    input  wire [4:0]  rd_e,
    input  wire        mem_read_e,
    input  wire        branch_taken_e,

    output reg  [1:0]  forward_a_e,
    output reg  [1:0]  forward_b_e,
    output wire        stall_f,
    output wire        stall_d,
    output wire        flush_e,
    output wire        flush_d
);

    // Forwarding to Execute stage
    always @(*) begin
        // Forward A
        if (reg_write_m && (rd_m != 5'd0) && (rd_m == rs1_e))
            forward_a_e = 2'b10; // Forward from Memory stage
        else if (reg_write_w && (rd_w != 5'd0) && (rd_w == rs1_e))
            forward_a_e = 2'b01; // Forward from Writeback stage
        else
            forward_a_e = 2'b00; // No forwarding

        // Forward B
        if (reg_write_m && (rd_m != 5'd0) && (rd_m == rs2_e))
            forward_b_e = 2'b10;
        else if (reg_write_w && (rd_w != 5'd0) && (rd_w == rs2_e))
            forward_b_e = 2'b01;
        else
            forward_b_e = 2'b00;
    end

    // Load-Use Data Hazard Detection
    wire load_use_hazard = mem_read_e && ((rd_e == rs1_d) || (rd_e == rs2_d)) && (rd_e != 5'd0);

    assign stall_f = load_use_hazard;
    assign stall_d = load_use_hazard;
    assign flush_e = load_use_hazard || branch_taken_e;
    assign flush_d = branch_taken_e;

endmodule
