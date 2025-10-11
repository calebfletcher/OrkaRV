# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load local source Code and constraints
loadSource      -dir "$::DIR_PATH/hdl" -fileType {VHDL 2019}