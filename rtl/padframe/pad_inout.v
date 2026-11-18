// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    pad_inout.v
// Description: SkyWater 130nm Bidirectional GPIO Pad with Tri-State Control
// =============================================================================

`timescale 1ns / 1ps

module pad_inout (
    inout  wire pad,    // Physical Chip Pin
    input  wire cout,   // Data from Core
    output wire cin,    // Data to Core
    input  wire oen     // Output Enable (Active Low: 0=Output, 1=Input)
);

    // Tri-state buffer
    assign pad = (!oen) ? cout : 1'bz;
    assign cin = pad;

endmodule
