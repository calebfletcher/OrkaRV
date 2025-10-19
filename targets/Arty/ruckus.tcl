# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load shared and sub-module ruckus.tcl files
loadRuckusTcl $::env(TOP_DIR)/submodules/surf
loadRuckusTcl $::env(TOP_DIR)/shared

# Load local source Code and constraints
loadSource      -dir "$::DIR_PATH/hdl" -fileType {VHDL 2019}
loadConstraints -dir "$::DIR_PATH/xdc"