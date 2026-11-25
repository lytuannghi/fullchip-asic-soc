# Portable Logic Synthesis Script Reference (Synopsys DC / OpenROAD Yosys Template)
set TOP_MODULE "fullchip_soc_top"
set SDC_FILE   "syn/fullchip_soc_top.sdc"
set rtl_files [glob -nocomplain rtl/*.v rtl/*/*.v]
read_verilog $rtl_files
elaborate $TOP_MODULE
link
source $SDC_FILE
compile_ultra -no_autoungroup
report_timing -max_paths 10 > syn/reports/timing_summary.rpt
report_area   > syn/reports/area_summary.rpt
