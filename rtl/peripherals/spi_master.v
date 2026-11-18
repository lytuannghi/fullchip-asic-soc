// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    spi_master.v
// Description: 4-Wire SPI Master Controller (SCLK, MOSI, MISO, CS_n)
// =============================================================================

`timescale 1ns / 1ps
`include "bus_defines.vh"

module spi_master (
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

    // SPI Physical Pins
    output reg         spi_sclk,
    output reg         spi_mosi,
    input  wire        spi_miso,
    output reg         spi_cs_n
);

    assign pready = 1'b1;

    reg [7:0] tx_data_reg;
    reg [7:0] rx_data_reg;
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;
    reg       busy;
    reg       done;
    reg [3:0] clk_div_cnt;

    localparam SPI_IDLE     = 2'd0;
    localparam SPI_TRANSFER = 2'd1;
    localparam SPI_FINISH   = 2'd2;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_sclk    <= 1'b0;
            spi_mosi    <= 1'b0;
            spi_cs_n    <= 1'b1;
            busy        <= 1'b0;
            done        <= 1'b0;
            bit_cnt     <= 3'd0;
            clk_div_cnt <= 4'd0;
            rx_data_reg <= 8'd0;
            state       <= SPI_IDLE;
        end else begin
            case (state)
                SPI_IDLE: begin
                    spi_sclk <= 1'b0;
                    done     <= 1'b0;
                    if (busy) begin
                        shift_reg   <= tx_data_reg;
                        spi_cs_n    <= 1'b0;
                        bit_cnt     <= 3'd7;
                        clk_div_cnt <= 4'd0;
                        state       <= SPI_TRANSFER;
                    end
                end

                SPI_TRANSFER: begin
                    clk_div_cnt <= clk_div_cnt + 1'b1;
                    if (clk_div_cnt == 4'd1) begin
                        spi_mosi <= shift_reg[bit_cnt];
                    end else if (clk_div_cnt == 4'd4) begin
                        spi_sclk <= 1'b1; // Rising edge: sample MISO
                        shift_reg[bit_cnt] <= spi_miso;
                    end else if (clk_div_cnt == 4'd8) begin
                        spi_sclk    <= 1'b0; // Falling edge
                        clk_div_cnt <= 4'd0;
                        if (bit_cnt == 3'd0) begin
                            state <= SPI_FINISH;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                SPI_FINISH: begin
                    spi_cs_n    <= 1'b1;
                    rx_data_reg <= shift_reg;
                    busy        <= 1'b0;
                    done        <= 1'b1;
                    state       <= SPI_IDLE;
                end
            endcase
        end
    end

    // APB Read/Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data_reg <= 8'd0;
            prdata      <= 32'd0;
        end else begin
            if (psel && penable && pwrite) begin
                case (paddr)
                    `SPI_REG_CTRL: begin
                        if (pwdata[0]) busy <= 1'b1; // Trigger SPI transfer
                    end
                    `SPI_REG_TXDATA: tx_data_reg <= pwdata[7:0];
                    default: ;
                endcase
            end

            if (psel && !pwrite) begin
                case (paddr)
                    `SPI_REG_STATUS: prdata <= {30'd0, done, busy};
                    `SPI_REG_RXDATA: prdata <= {24'd0, rx_data_reg};
                    default:         prdata <= 32'd0;
                endcase
            end
        end
    end

endmodule
