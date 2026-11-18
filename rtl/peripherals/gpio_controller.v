// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    gpio_controller.v
// Description: 8-Bit Bidirectional GPIO Controller with Interrupt on Edge
// =============================================================================

`timescale 1ns / 1ps
`include "bus_defines.vh"

module gpio_controller (
    input  wire        clk,
    input  wire        rst_n,

    // APB Slave Interface
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [3:0]  paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,

    // Physical IO Pad Interface
    input  wire [7:0]  pad_gpio_in,
    output wire [7:0]  pad_gpio_out,
    output wire [7:0]  pad_gpio_dir,

    // Interrupt output
    output reg         gpio_irq
);

    assign pready = 1'b1;

    reg [7:0] gpio_out_reg;
    reg [7:0] gpio_dir_reg;
    reg [7:0] gpio_int_en_reg;
    reg [7:0] gpio_in_sync0, gpio_in_sync1, gpio_in_prev;

    assign pad_gpio_out = gpio_out_reg;
    assign pad_gpio_dir = gpio_dir_reg;

    // 2-Stage Synchronizer for external IO pins
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_in_sync0 <= 8'd0;
            gpio_in_sync1 <= 8'd0;
            gpio_in_prev  <= 8'd0;
        end else begin
            gpio_in_sync0 <= pad_gpio_in;
            gpio_in_sync1 <= gpio_in_sync0;
            gpio_in_prev  <= gpio_in_sync1;
        end
    end

    // Edge Detection Interrupt
    wire [7:0] gpio_edge = (gpio_in_sync1 ^ gpio_in_prev) & gpio_int_en_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_irq <= 1'b0;
        end else begin
            gpio_irq <= |gpio_edge;
        end
    end

    // APB Read/Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_out_reg    <= 8'd0;
            gpio_dir_reg    <= 8'd0; // Default all inputs
            gpio_int_en_reg <= 8'd0;
            prdata          <= 32'd0;
        end else begin
            if (psel && penable && pwrite) begin
                case (paddr)
                    `GPIO_REG_DATA_OUT: gpio_out_reg    <= pwdata[7:0];
                    `GPIO_REG_DIR:      gpio_dir_reg    <= pwdata[7:0];
                    `GPIO_REG_INT_EN:   gpio_int_en_reg <= pwdata[7:0];
                    default: ;
                endcase
            end

            if (psel && !pwrite) begin
                case (paddr)
                    `GPIO_REG_DATA_IN:  prdata <= {24'd0, gpio_in_sync1};
                    `GPIO_REG_DATA_OUT: prdata <= {24'd0, gpio_out_reg};
                    `GPIO_REG_DIR:      prdata <= {24'd0, gpio_dir_reg};
                    `GPIO_REG_INT_EN:   prdata <= {24'd0, gpio_int_en_reg};
                    default:            prdata <= 32'd0;
                endcase
            end
        end
    end

endmodule
