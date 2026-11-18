#!/usr/bin/env python3
# =============================================================================
# Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
# File:    generate_hex.py
# Description: Assembles RV32I Firmware for Full-Chip Peripheral Verification
# =============================================================================

def r_type(funct7, rs2, rs1, funct3, rd, opcode=0x33):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def i_type(imm, rs1, funct3, rd, opcode):
    imm_val = imm & 0xFFF
    return (imm_val << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def s_type(imm, rs2, rs1, funct3, opcode=0x23):
    imm_val = imm & 0xFFF
    imm_11_5 = (imm_val >> 5) & 0x7F
    imm_4_0 = imm_val & 0x1F
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | opcode

def u_type(imm, rd, opcode):
    imm_val = (imm >> 12) & 0xFFFFF
    return (imm_val << 12) | (rd << 7) | opcode

def b_type(imm, rs2, rs1, funct3, opcode=0x63):
    imm_val = imm & 0x1FFF
    b12 = (imm_val >> 12) & 0x1
    b10_5 = (imm_val >> 5) & 0x3F
    b4_1 = (imm_val >> 1) & 0xF
    b11 = (imm_val >> 11) & 0x1
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (b4_1 << 8) | (b11 << 7) | opcode

def assemble():
    # Peripheral Base Addresses
    # GPIO_BASE  = 0x1000_0000
    # TIMER_BASE = 0x1000_0100
    # UART_BASE  = 0x1000_0200
    # SPI_BASE   = 0x1000_0300
    # SRAM_DONE  = 0x0000_13FC (Signature: 0xCAFEFACE)

    instrs = [
        # 1. Base pointer setup: x1 = 0x1000_0000 (Peripheral Base)
        u_type(0x10000000, 1, 0x37),             # lui x1, 0x10000

        # 2. Configure GPIO: x2 = 0x0F (DIR: [3:0] Out, [7:4] In)
        i_type(0x0F, 0, 0x0, 2, 0x13),           # addi x2, x0, 0x0F
        s_type(0x08, 2, 1, 0x2, 0x23),           # sw x2, 8(x1)  -> GPIO_DIR = 0x0F

        # Write GPIO Output Data: x3 = 0x0A (Pattern 1010b)
        i_type(0x0A, 0, 0x0, 3, 0x13),           # addi x3, x0, 0x0A
        s_type(0x04, 3, 1, 0x2, 0x23),           # sw x3, 4(x1)  -> GPIO_DATA_OUT = 0x0A

        # 3. Configure Timer / PWM:
        # Load Timer: x4 = 50 (Reload value)
        i_type(50, 0, 0x0, 4, 0x13),             # addi x4, x0, 50
        s_type(0x108, 4, 1, 0x2, 0x23),          # sw x4, 0x108(x1) -> TIMER_LOAD = 50

        # Set PWM Compare: x5 = 128 (50% duty cycle)
        i_type(128, 0, 0x0, 5, 0x13),            # addi x5, x0, 128
        s_type(0x104, 5, 1, 0x2, 0x23),          # sw x5, 0x104(x1) -> TIMER_PWM_CMP = 128

        # Start Timer: x6 = 3 (Enable [0] + Auto-Reload [1])
        i_type(3, 0, 0x0, 6, 0x13),              # addi x6, x0, 3
        s_type(0x100, 6, 1, 0x2, 0x23),          # sw x6, 0x100(x1) -> TIMER_CTRL = 3

        # 4. Transmit characters over UART: "CHIP_PASS\n"
        # UART TX Data register is at 0x1000_0200 (x1 + 0x200)
    ]

    uart_chars = [ord(c) for c in "CHIP_PASS\n"]
    for ch in uart_chars:
        instrs.append(i_type(ch, 0, 0x0, 7, 0x13))       # addi x7, x0, ch
        instrs.append(s_type(0x200, 7, 1, 0x2, 0x23))    # sw x7, 0x200(x1)

    # 5. Configure & Trigger SPI Master:
    # Send byte 0x55 over SPI
    instrs.extend([
        i_type(0x55, 0, 0x0, 8, 0x13),           # addi x8, x0, 0x55
        s_type(0x308, 8, 1, 0x2, 0x23),          # sw x8, 0x308(x1) -> SPI_TXDATA = 0x55
        i_type(1, 0, 0x0, 9, 0x13),              # addi x9, x0, 1
        s_type(0x300, 9, 1, 0x2, 0x23),          # sw x9, 0x300(x1) -> SPI_CTRL = 1 (Start)

        # 6. Write Completion Signature: 0xCAFEFACE to 0x0000_13FC (End of SRAM)
        u_type(0xCAFF0000, 10, 0x37),            # lui x10, 0xCAFF0
        i_type(-1330, 10, 0x0, 10, 0x13),        # addi x10, x10, -1330 -> 0xCAFEFACE

        u_type(0x00001000, 11, 0x37),            # lui x11, 0x1
        i_type(0x3FC, 11, 0x0, 11, 0x13),        # addi x11, x11, 0x3FC -> 0x0000_13FC
        s_type(0x00, 10, 11, 0x2, 0x23),         # sw x10, 0(x11) -> [0x13FC] = 0xCAFEFACE

        # 7. Infinite Loop (Halt)
        b_type(0, 0, 0, 0x0, 0x63)               # beq x0, x0, 0 (Infinite loop)
    ])

    return instrs

if __name__ == "__main__":
    import os
    hex_code = assemble()
    script_dir = os.path.dirname(os.path.abspath(__file__))
    hex_path = os.path.join(script_dir, "boot_firmware.hex")
    with open(hex_path, "w") as f:
        for code in hex_code:
            f.write(f"{code:08x}\n")
    print(f"Generated {len(hex_code)} instructions in {hex_path}")
