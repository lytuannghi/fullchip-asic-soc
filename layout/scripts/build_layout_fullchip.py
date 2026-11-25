#!/usr/bin/env python3
import os
from build_layout_engine import build_asic_layout

if __name__ == "__main__":
    lay_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    gds_out = os.path.join(lay_root, "gds", "fullchip_soc.gds")
    rep_out = os.path.join(lay_root, "reports", "drc_report.txt")
    build_asic_layout(
        gds_path=gds_out,
        report_path=rep_out,
        top_name="fullchip_soc_top",
        libname="FULLCHIP_SOC_TOP_LIB",
        die_w=640000,
        die_h=640000,
        macro_cols=4,
        macro_rows=4,
        pad_count_per_side=5,
    )
