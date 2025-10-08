source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Vivado comes with an older version of libusb, so override it to the system's one instead
set ::env(LD_LIBRARY_PATH) "/usr/lib/x86_64-linux-gnu:/usr/local/lib"
exec openFPGALoader -b arty_a7_35t "${IMAGES_DIR}/$::env(IMAGENAME).bit" >@stdout 2>@stderr