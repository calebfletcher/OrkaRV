# Define the TOP_DIR path
export TOP_DIR = $(abspath $(PWD)/../..)

# Define target output
target: prom

# Define target part
export PRJ_PART = XC7A35TICSG324-1L

include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

flash:
	IMG=$$(ls -t images/*.bit | head -n1); openFPGALoader -b arty_a7_35t $$IMG