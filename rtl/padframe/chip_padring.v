// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    chip_padring.v
// Description: Complete ASIC Pad Ring Surrounding the Core with ESD Protection
// =============================================================================

`timescale 1ns / 1ps

module chip_padring (
    // -------------------------------------------------------------------------
    // Physical Chip Pins (Package Bond Pads)
    // -------------------------------------------------------------------------
    input  wire       pad_clk,
    input  wire       pad_rst_n,

    // UART Pins
    output wire       pad_uart_tx,
    input  wire       pad_uart_rx,

    // Timer / PWM Pin
    output wire       pad_pwm_out,

    // SPI Master Pins
    output wire       pad_spi_sclk,
    output wire       pad_spi_mosi,
    input  wire       pad_spi_miso,
    output wire       pad_spi_cs_n,

    // 8 Bidirectional GPIO Pins
    inout  wire [7:0] pad_gpio,

    // -------------------------------------------------------------------------
    // Internal Core Logic Connections
    // -------------------------------------------------------------------------
    output wire       core_clk,
    output wire       core_rst_n,

    input  wire       core_uart_tx,
    output wire       core_uart_rx,

    input  wire       core_pwm_out,

    input  wire       core_spi_sclk,
    input  wire       core_spi_mosi,
    output wire       core_spi_miso,
    input  wire       core_spi_cs_n,

    input  wire [7:0] core_gpio_out,
    output wire [7:0] core_gpio_in,
    input  wire [7:0] core_gpio_dir
);

    // Clock & Reset Input Pads
    pad_in u_pad_clk   (.pad(pad_clk),   .cin(core_clk));
    pad_in u_pad_rst_n (.pad(pad_rst_n), .cin(core_rst_n));

    // UART Pads
    pad_out u_pad_uart_tx (.cout(core_uart_tx), .pad(pad_uart_tx));
    pad_in  u_pad_uart_rx (.pad(pad_uart_rx),   .cin(core_uart_rx));

    // PWM Output Pad
    pad_out u_pad_pwm_out (.cout(core_pwm_out), .pad(pad_pwm_out));

    // SPI Master Pads
    pad_out u_pad_spi_sclk (.cout(core_spi_sclk), .pad(pad_spi_sclk));
    pad_out u_pad_spi_mosi (.cout(core_spi_mosi), .pad(pad_spi_mosi));
    pad_in  u_pad_spi_miso (.pad(pad_spi_miso),   .cin(core_spi_miso));
    pad_out u_pad_spi_cs_n (.cout(core_spi_cs_n), .pad(pad_spi_cs_n));

    // 8 Bidirectional GPIO Pads
    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : gen_gpio_pads
            // oen = 0 when dir = 1 (Output); oen = 1 when dir = 0 (Input)
            pad_inout u_pad_gpio (
                .pad  (pad_gpio[g]),
                .cout (core_gpio_out[g]),
                .cin  (core_gpio_in[g]),
                .oen  (!core_gpio_dir[g])
            );
        end
    endgenerate

endmodule
