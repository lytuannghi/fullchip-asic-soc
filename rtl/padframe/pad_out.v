// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    pad_out.v
// Description: SkyWater 130nm Digital Output Pad with Slew Rate Control
// =============================================================================

`timescale 1ns / 1ps

module pad_out (
    input  wire cout,   // Internal Core Logic Signal
    output wire pad     // Physical Chip Pin
);

    // Behavioral model of SkyWater 130nm Output Pad
    assign pad = cout;

endmodule
