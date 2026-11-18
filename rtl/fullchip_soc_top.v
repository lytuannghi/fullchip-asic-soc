// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    fullchip_soc_top.v
// Description: Full-Chip Top-Level Integration (Pad Ring + Core + Memory + Peripherals)
// =============================================================================

`timescale 1ns / 1ps
`include "bus_defines.vh"

module fullchip_soc_top (
    // -------------------------------------------------------------------------
    // Physical Package Bond Pads (External World Interface)
    // -------------------------------------------------------------------------
    input  wire       PAD_CLK,
    input  wire       PAD_RST_N,

    // UART Physical Pins
    output wire       PAD_UART_TX,
    input  wire       PAD_UART_RX,

    // Timer / PWM Pin
    output wire       PAD_PWM_OUT,

    // SPI Master Pins
    output wire       PAD_SPI_SCLK,
    output wire       PAD_SPI_MOSI,
    input  wire       PAD_SPI_MISO,
    output wire       PAD_SPI_CS_N,

    // 8 Bidirectional GPIO Pins
    inout  wire [7:0] PAD_GPIO
);

    // -------------------------------------------------------------------------
    // Internal Core Signals Interconnecting Pad Ring and Core
    // -------------------------------------------------------------------------
    wire       core_clk;
    wire       core_rst_n;
    wire       core_uart_tx;
    wire       core_uart_rx;
    wire       core_pwm_out;
    wire       core_spi_sclk;
    wire       core_spi_mosi;
    wire       core_spi_miso;
    wire       core_spi_cs_n;
    wire [7:0] core_gpio_out;
    wire [7:0] core_gpio_in;
    wire [7:0] core_gpio_dir;

    // -------------------------------------------------------------------------
    // 1. Chip Padframe / Pad Ring Instance
    // -------------------------------------------------------------------------
    chip_padring u_padring (
        .pad_clk        (PAD_CLK),
        .pad_rst_n      (PAD_RST_N),
        .pad_uart_tx    (PAD_UART_TX),
        .pad_uart_rx    (PAD_UART_RX),
        .pad_pwm_out    (PAD_PWM_OUT),
        .pad_spi_sclk   (PAD_SPI_SCLK),
        .pad_spi_mosi   (PAD_SPI_MOSI),
        .pad_spi_miso   (PAD_SPI_MISO),
        .pad_spi_cs_n   (PAD_SPI_CS_N),
        .pad_gpio       (PAD_GPIO),

        .core_clk       (core_clk),
        .core_rst_n     (core_rst_n),
        .core_uart_tx   (core_uart_tx),
        .core_uart_rx   (core_uart_rx),
        .core_pwm_out   (core_pwm_out),
        .core_spi_sclk  (core_spi_sclk),
        .core_spi_mosi  (core_spi_mosi),
        .core_spi_miso  (core_spi_miso),
        .core_spi_cs_n  (core_spi_cs_n),
        .core_gpio_out  (core_gpio_out),
        .core_gpio_in   (core_gpio_in),
        .core_gpio_dir  (core_gpio_dir)
    );

    // -------------------------------------------------------------------------
    // Internal Buses & Subsystem Wires
    // -------------------------------------------------------------------------
    // CPU Instruction Fetch Bus
    wire [31:0] cpu_instr_addr;
    wire [31:0] cpu_instr_rdata;

    // CPU Data Master Bus
    wire [31:0] cpu_data_addr;
    wire [31:0] cpu_data_wdata;
    wire [3:0]  cpu_data_wstrb;
    wire        cpu_data_req;
    wire        cpu_data_we;
    wire [31:0] cpu_data_rdata;
    wire        cpu_data_ready;

    // Memory Wires
    wire [9:0]  rom_addr;
    wire [31:0] rom_rdata;
    wire [9:0]  sram_addr;
    wire [31:0] sram_wdata;
    wire [3:0]  sram_wstrb;
    wire        sram_we;
    wire [31:0] sram_rdata;

    // Peripheral APB Buses
    wire        gpio_psel,  gpio_penable,  gpio_pwrite,  gpio_pready;
    wire [3:0]  gpio_paddr;
    wire [31:0] gpio_pwdata, gpio_prdata;
    wire        gpio_irq;

    wire        timer_psel, timer_penable, timer_pwrite, timer_pready;
    wire [3:0]  timer_paddr;
    wire [31:0] timer_pwdata, timer_prdata;
    wire        timer_irq;

    wire        uart_psel,  uart_penable,  uart_pwrite,  uart_pready;
    wire [3:0]  uart_paddr;
    wire [31:0] uart_pwdata, uart_prdata;
    wire        uart_irq;

    wire        spi_psel,   spi_penable,   spi_pwrite,   spi_pready;
    wire [3:0]  spi_paddr;
    wire [31:0] spi_pwdata, spi_prdata;

    // Global Interrupt Line (OR-ed GPIO + Timer)
    wire        ext_irq = gpio_irq | timer_irq;

    // -------------------------------------------------------------------------
    // 2. RISC-V RV32I Processor Core Instance
    // -------------------------------------------------------------------------
    riscv_core u_core (
        .clk         (core_clk),
        .rst_n       (core_rst_n),
        .instr_addr  (cpu_instr_addr),
        .instr_rdata (cpu_instr_rdata),
        .data_addr   (cpu_data_addr),
        .data_wdata  (cpu_data_wdata),
        .data_wstrb  (cpu_data_wstrb),
        .data_req    (cpu_data_req),
        .data_we     (cpu_data_we),
        .data_rdata  (cpu_data_rdata),
        .data_ready  (cpu_data_ready),
        .ext_irq     (ext_irq)
    );

    // -------------------------------------------------------------------------
    // 3. Memory Subsystem Instances
    // -------------------------------------------------------------------------
    // Boot ROM (Mapped to 0x0000_0000)
    wire [9:0]  rom_instr_addr = cpu_instr_addr[11:2];
    wire [31:0] rom_instr_rdata;

    boot_rom u_boot_rom (
        .clk   (core_clk),
        .addr  (rom_instr_addr),
        .rdata (rom_instr_rdata)
    );

    // 4KB Dual-Port SRAM (Mapped to 0x0000_0400)
    // Port A: Instruction Fetch from CPU
    // Port B: Data Read/Write from APB Interconnect
    wire [9:0] sram_instr_addr = (cpu_instr_addr - `ADDR_SRAM_BASE) >> 2;
    wire [31:0] sram_instr_rdata;

    sram_top u_sram (
        .clk     (core_clk),
        .rst_n   (core_rst_n),
        .addr_a  (sram_instr_addr),
        .rdata_a (sram_instr_rdata),
        .addr_b  (sram_addr),
        .wdata_b (sram_wdata),
        .wstrb_b (sram_wstrb),
        .we_b    (sram_we),
        .rdata_b (sram_rdata)
    );

    // Instruction Mux (ROM vs SRAM)
    assign cpu_instr_rdata = (cpu_instr_addr < `ADDR_SRAM_BASE) ? rom_instr_rdata : sram_instr_rdata;

    // -------------------------------------------------------------------------
    // 4. APB Crossbar Interconnect Instance
    // -------------------------------------------------------------------------
    apb_interconnect u_bus (
        .clk           (core_clk),
        .rst_n         (core_rst_n),
        .cpu_addr      (cpu_data_addr),
        .cpu_wdata     (cpu_data_wdata),
        .cpu_wstrb     (cpu_data_wstrb),
        .cpu_req       (cpu_data_req),
        .cpu_we        (cpu_data_we),
        .cpu_rdata     (cpu_data_rdata),
        .cpu_ready     (cpu_data_ready),
        .rom_addr      (rom_addr),
        .rom_rdata     (rom_rdata),
        .sram_addr     (sram_addr),
        .sram_wdata    (sram_wdata),
        .sram_wstrb    (sram_wstrb),
        .sram_we       (sram_we),
        .sram_rdata    (sram_rdata),
        .gpio_psel     (gpio_psel),
        .gpio_penable  (gpio_penable),
        .gpio_pwrite   (gpio_pwrite),
        .gpio_paddr    (gpio_paddr),
        .gpio_pwdata   (gpio_pwdata),
        .gpio_prdata   (gpio_prdata),
        .gpio_pready   (gpio_pready),
        .timer_psel    (timer_psel),
        .timer_penable (timer_penable),
        .timer_pwrite  (timer_pwrite),
        .timer_paddr   (timer_paddr),
        .timer_pwdata  (timer_pwdata),
        .timer_prdata  (timer_prdata),
        .timer_pready  (timer_pready),
        .uart_psel     (uart_psel),
        .uart_penable  (uart_penable),
        .uart_pwrite   (uart_pwrite),
        .uart_paddr    (uart_paddr),
        .uart_pwdata   (uart_pwdata),
        .uart_prdata   (uart_prdata),
        .uart_pready   (uart_pready),
        .spi_psel      (spi_psel),
        .spi_penable   (spi_penable),
        .spi_pwrite    (spi_pwrite),
        .spi_paddr     (spi_paddr),
        .spi_pwdata    (spi_pwdata),
        .spi_prdata    (spi_prdata),
        .spi_pready    (spi_pready)
    );

    // -------------------------------------------------------------------------
    // 5. Peripheral Instances
    // -------------------------------------------------------------------------
    // 8-Bit GPIO Controller
    gpio_controller u_gpio (
        .clk          (core_clk),
        .rst_n        (core_rst_n),
        .psel         (gpio_psel),
        .penable      (gpio_penable),
        .pwrite       (gpio_pwrite),
        .paddr        (gpio_paddr),
        .pwdata       (gpio_pwdata),
        .prdata       (gpio_prdata),
        .pready       (gpio_pready),
        .pad_gpio_in  (core_gpio_in),
        .pad_gpio_out (core_gpio_out),
        .pad_gpio_dir (core_gpio_dir),
        .gpio_irq     (gpio_irq)
    );

    // 32-Bit Hardware Timer & PWM Generator
    timer_pwm u_timer_pwm (
        .clk          (core_clk),
        .rst_n        (core_rst_n),
        .psel         (timer_psel),
        .penable      (timer_penable),
        .pwrite       (timer_pwrite),
        .paddr        (timer_paddr),
        .pwdata       (timer_pwdata),
        .prdata       (timer_prdata),
        .pready       (timer_pready),
        .timer_irq    (timer_irq),
        .pwm_out      (core_pwm_out)
    );

    // Full-Duplex UART Subsystem
    uart_controller u_uart (
        .clk          (core_clk),
        .rst_n        (core_rst_n),
        .psel         (uart_psel),
        .penable      (uart_penable),
        .pwrite       (uart_pwrite),
        .paddr        (uart_paddr),
        .pwdata       (uart_pwdata),
        .prdata       (uart_prdata),
        .pready       (uart_pready),
        .uart_rx      (core_uart_rx),
        .uart_tx      (core_uart_tx),
        .uart_irq     (uart_irq)
    );

    // 4-Wire SPI Master Controller
    spi_master u_spi (
        .clk          (core_clk),
        .rst_n        (core_rst_n),
        .psel         (spi_psel),
        .penable      (spi_penable),
        .pwrite       (spi_pwrite),
        .paddr        (spi_paddr),
        .pwdata       (spi_pwdata),
        .prdata       (spi_prdata),
        .pready       (spi_pready),
        .spi_sclk     (core_spi_sclk),
        .spi_mosi     (core_spi_mosi),
        .spi_miso     (core_spi_miso),
        .spi_cs_n     (core_spi_cs_n)
    );

endmodule
