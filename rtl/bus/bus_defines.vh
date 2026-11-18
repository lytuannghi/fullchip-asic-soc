`ifndef BUS_DEFINES_VH
`define BUS_DEFINES_VH

// =============================================================================
// Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
// File:    bus_defines.vh
// Description: Global Memory Map, Register Offsets, and Bus Constants
// =============================================================================

// Memory Map Architecture (32-bit Address Space)
`define ADDR_BOOT_ROM_BASE   32'h0000_0000
`define ADDR_BOOT_ROM_SIZE   32'h0000_0400   // 1KB Boot ROM

`define ADDR_SRAM_BASE       32'h0000_0400
`define ADDR_SRAM_SIZE       32'h0000_1000   // 4KB Dual-Port SRAM

`define ADDR_PERIPH_BASE     32'h1000_0000

// Peripheral Offsets
`define ADDR_GPIO_BASE       32'h1000_0000   // GPIO Controller (8-bit)
`define ADDR_TIMER_BASE      32'h1000_0100   // 32-bit Timer / PWM Generator
`define ADDR_UART_BASE       32'h1000_0200   // Full-Duplex UART Subsystem
`define ADDR_SPI_BASE        32'h1000_0300   // SPI Master Controller

// GPIO Register Offsets
`define GPIO_REG_DATA_IN     4'h0
`define GPIO_REG_DATA_OUT    4'h4
`define GPIO_REG_DIR         4'h8            // 1: Output, 0: Input
`define GPIO_REG_INT_EN      4'hC            // Interrupt Enable mask

// Timer / PWM Register Offsets
`define TIMER_REG_CTRL       4'h0            // [0]: Enable, [1]: Auto-reload, [2]: Int Enable
`define TIMER_REG_PRESCALE   4'h4            // Clock Prescaler
`define TIMER_REG_LOAD       4'h8            // Reload Value
`define TIMER_REG_VALUE      4'hC            // Current Counter Value
`define TIMER_REG_PWM_CMP    4'h4            // PWM Compare Value (Duty cycle)

// UART Register Offsets
`define UART_REG_TX_DATA     4'h0
`define UART_REG_RX_DATA     4'h4
`define UART_REG_STATUS      4'h8            // [0]: TX Full, [1]: RX Empty, [2]: TX Busy
`define UART_REG_BAUD_DIV    4'hC

// SPI Master Register Offsets
`define SPI_REG_CTRL         4'h0            // [0]: Start, [1]: CPOL, [2]: CPHA, [3]: CS_n
`define SPI_REG_STATUS       4'h4            // [0]: Busy, [1]: Done
`define SPI_REG_TXDATA       4'h8
`define SPI_REG_RXDATA       4'hC

`endif // BUS_DEFINES_VH
