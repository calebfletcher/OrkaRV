# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

loadRuckusTcl $::DIR_PATH/peripherals

# Load local source Code and constraints
loadSource      -dir "$::DIR_PATH/axi/hdl" -fileType {VHDL 2019}
loadSource      -dir "$::DIR_PATH/csr/hdl" -fileType {VHDL 2019}
loadSource      -dir "$::DIR_PATH/hdl" -fileType {VHDL 2019}