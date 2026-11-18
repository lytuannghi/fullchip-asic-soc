// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    apb_interconnect.v
// Description: Zero-Wait-State High-Throughput APB Interconnect Crossbar
// =============================================================================

`timescale 1ns / 1ps
`include "bus_defines.vh"

module apb_interconnect (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Data Master Bus
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire [3:0]  cpu_wstrb,
    input  wire        cpu_req,
    input  wire        cpu_we,
    output reg  [31:0] cpu_rdata,
    output wire        cpu_ready,

    // Memory Slaves
    // Boot ROM
    output wire [9:0]  rom_addr,
    input  wire [31:0] rom_rdata,

    // SRAM
    output wire [9:0]  sram_addr,
    output wire [31:0] sram_wdata,
    output wire [3:0]  sram_wstrb,
    output wire        sram_we,
    input  wire [31:0] sram_rdata,

    // Peripheral APB Slaves: GPIO
    output wire        gpio_psel,
    output wire        gpio_penable,
    output wire        gpio_pwrite,
    output wire [3:0]  gpio_paddr,
    output wire [31:0] gpio_pwdata,
    input  wire [31:0] gpio_prdata,
    input  wire        gpio_pready,

    // Peripheral APB Slaves: Timer / PWM
    output wire        timer_psel,
    output wire        timer_penable,
    output wire        timer_pwrite,
    output wire [3:0]  timer_paddr,
    output wire [31:0] timer_pwdata,
    input  wire [31:0] timer_prdata,
    input  wire        timer_pready,

    // Peripheral APB Slaves: UART
    output wire        uart_psel,
    output wire        uart_penable,
    output wire        uart_pwrite,
    output wire [3:0]  uart_paddr,
    output wire [31:0] uart_pwdata,
    input  wire [31:0] uart_prdata,
    input  wire        uart_pready,

    // Peripheral APB Slaves: SPI Master
    output wire        spi_psel,
    output wire        spi_penable,
    output wire        spi_pwrite,
    output wire [3:0]  spi_paddr,
    output wire [31:0] spi_pwdata,
    input  wire [31:0] spi_prdata,
    input  wire        spi_pready
);

    // Address Decoding
    wire is_rom   = (cpu_addr >= `ADDR_BOOT_ROM_BASE) && (cpu_addr < `ADDR_BOOT_ROM_BASE + `ADDR_BOOT_ROM_SIZE);
    wire is_sram  = (cpu_addr >= `ADDR_SRAM_BASE) && (cpu_addr < `ADDR_SRAM_BASE + `ADDR_SRAM_SIZE);
    wire is_gpio  = (cpu_addr >= `ADDR_GPIO_BASE) && (cpu_addr < `ADDR_GPIO_BASE + 32'h100);
    wire is_timer = (cpu_addr >= `ADDR_TIMER_BASE) && (cpu_addr < `ADDR_TIMER_BASE + 32'h100);
    wire is_uart  = (cpu_addr >= `ADDR_UART_BASE) && (cpu_addr < `ADDR_UART_BASE + 32'h100);
    wire is_spi   = (cpu_addr >= `ADDR_SPI_BASE) && (cpu_addr < `ADDR_SPI_BASE + 32'h100);

    // Always ready in 1-cycle bus
    assign cpu_ready = 1'b1;

    // ROM / SRAM Address Mapping (Word-Aligned)
    assign rom_addr   = (cpu_addr - `ADDR_BOOT_ROM_BASE) >> 2;
    assign sram_addr  = (cpu_addr - `ADDR_SRAM_BASE) >> 2;
    assign sram_wdata = cpu_wdata;
    assign sram_wstrb = cpu_wstrb;
    assign sram_we    = is_sram && cpu_req && cpu_we;

    // Peripheral Signals (Zero-Wait-State APB)
    assign gpio_psel    = is_gpio && cpu_req;
    assign gpio_penable = gpio_psel;
    assign gpio_pwrite  = cpu_we;
    assign gpio_paddr   = cpu_addr[3:0];
    assign gpio_pwdata  = cpu_wdata;

    assign timer_psel    = is_timer && cpu_req;
    assign timer_penable = timer_psel;
    assign timer_pwrite  = cpu_we;
    assign timer_paddr   = cpu_addr[3:0];
    assign timer_pwdata  = cpu_wdata;

    assign uart_psel    = is_uart && cpu_req;
    assign uart_penable = uart_psel;
    assign uart_pwrite  = cpu_we;
    assign uart_paddr   = cpu_addr[3:0];
    assign uart_pwdata  = cpu_wdata;

    assign spi_psel    = is_spi && cpu_req;
    assign spi_penable = spi_psel;
    assign spi_pwrite  = cpu_we;
    assign spi_paddr   = cpu_addr[3:0];
    assign spi_pwdata  = cpu_wdata;

    // Read Data Multiplexer
    always @(*) begin
        if (is_rom)        cpu_rdata = rom_rdata;
        else if (is_sram)  cpu_rdata = sram_rdata;
        else if (is_gpio)  cpu_rdata = gpio_prdata;
        else if (is_timer) cpu_rdata = timer_prdata;
        else if (is_uart)  cpu_rdata = uart_prdata;
        else if (is_spi)   cpu_rdata = spi_prdata;
        else               cpu_rdata = 32'd0;
    end

endmodule
