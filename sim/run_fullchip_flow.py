#!/usr/bin/env python3
# =============================================================================
# Project: Full-Chip Tape-Out Ready RISC-V SoC (SkyWater 130nm ASIC)
# File:    run_fullchip_flow.py
# Description: Portable Automated Compilation, Simulation, & Verification Flow
# =============================================================================

import os
import shutil
import subprocess
import sys
import time


def resolve_tool(name, proj_dir):
    found = shutil.which(name)
    if found:
        return found
    sibling = os.path.join(os.path.dirname(proj_dir), "iverilog", "bin", name + ".exe")
    return sibling if os.path.exists(sibling) else name


def main():
    proj_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rtl_dir = os.path.join(proj_dir, "rtl")
    tb_dir = os.path.join(proj_dir, "tb")
    agents_dir = os.path.join(proj_dir, "agents")
    output_dir = os.path.join(proj_dir, "sim")
    os.makedirs(output_dir, exist_ok=True)

    vvp_out = os.path.join(output_dir, "fullchip_sim.vvp")
    iverilog_exe = resolve_tool("iverilog", proj_dir)
    vvp_exe = resolve_tool("vvp", proj_dir)

    print("=" * 75)
    print("  FULL-CHIP TAPE-OUT READY RISC-V SOC - AUTOMATED FLOW & REGRESSION")
    print("=" * 75)
    print(f"[*] Project Root: {proj_dir}")

    print("\n[PHASE 1] Executing Multi-Agent EDA Architecture & Analysis Pipeline...")
    sys.path.append(agents_dir)
    try:
        from run_agents import run_multi_agent_pipeline
        run_multi_agent_pipeline()
    except Exception as e:
        print(f"[!] Warning running agents directly: {e}")

    print("\n[PHASE 2] Collecting Full-Chip RTL and Padframe Sources...")
    rtl_sources = [
        os.path.join(rtl_dir, "core", "alu.v"),
        os.path.join(rtl_dir, "core", "regfile.v"),
        os.path.join(rtl_dir, "core", "hazard_unit.v"),
        os.path.join(rtl_dir, "core", "riscv_core.v"),
        os.path.join(rtl_dir, "memory", "boot_rom.v"),
        os.path.join(rtl_dir, "memory", "sram_top.v"),
        os.path.join(rtl_dir, "bus", "apb_interconnect.v"),
        os.path.join(rtl_dir, "peripherals", "gpio_controller.v"),
        os.path.join(rtl_dir, "peripherals", "timer_pwm.v"),
        os.path.join(rtl_dir, "peripherals", "uart_controller.v"),
        os.path.join(rtl_dir, "peripherals", "spi_master.v"),
        os.path.join(rtl_dir, "padframe", "pad_in.v"),
        os.path.join(rtl_dir, "padframe", "pad_out.v"),
        os.path.join(rtl_dir, "padframe", "pad_inout.v"),
        os.path.join(rtl_dir, "padframe", "chip_padring.v"),
        os.path.join(rtl_dir, "fullchip_soc_top.v"),
    ]
    tb_sources = [os.path.join(tb_dir, "fullchip_soc_tb.v")]
    include_dir = os.path.join(rtl_dir, "bus")

    print("[PHASE 3] Compiling Full-Chip ASIC Top Level with iverilog (-Wall)...")
    iverilog_cmd = [
        iverilog_exe,
        "-Wall",
        "-g2005",
        f"-I{include_dir}",
        "-o", vvp_out,
    ] + rtl_sources + tb_sources

    compile_res = subprocess.run(
        iverilog_cmd,
        cwd=proj_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    if compile_res.returncode != 0 or compile_res.stderr.strip():
        print("[!] Compilation FAILED or emitted -Wall warnings:")
        print(compile_res.stderr)
        sys.exit(1)
    print("    -> Compilation Clean (0 warnings)! Binary generated:", vvp_out)

    print("[PHASE 4] Running Full-Chip Hardware Simulation with vvp...")
    t0 = time.time()
    sim_res = subprocess.run(
        [vvp_exe, vvp_out],
        cwd=proj_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    sim_time = time.time() - t0
    print(sim_res.stdout)
    if sim_res.stderr:
        print(sim_res.stderr)

    print(f"[*] Simulation Execution Time: {sim_time:.2f} seconds")
    if sim_res.returncode != 0 or "ALL TESTS PASSED SUCCESSFULLY" not in sim_res.stdout or "[FAIL]" in sim_res.stdout:
        print("[!] Verification FAILED!")
        sys.exit(1)
    print("[SUCCESS] Full-Chip ASIC SoC Verified (0 warnings, 100% Pass)!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
