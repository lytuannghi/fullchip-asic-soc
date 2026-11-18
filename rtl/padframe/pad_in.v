// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    pad_in.v
// Description: SkyWater 130nm Digital Input Pad with ESD Protection Cell
// =============================================================================

`timescale 1ns / 1ps

module pad_in (
    input  wire pad,    // Physical Chip Pin
    output wire cin     // Internal Core Logic Signal
);

    // Behavioral model of SkyWater 130nm Input Pad (sky130_fd_io__top_gpiov2)
    assign cin = pad;

endmodule
