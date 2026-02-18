# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load local source Code and constraints
loadSource      -dir "$::DIR_PATH/clint/hdl" -fileType {VHDL 2019}
loadSource      -dir "$::DIR_PATH/gpio/hdl" -fileType {VHDL 2019}
loadSource      -dir "$::DIR_PATH/uart/hdl" -fileType {VHDL 2019}