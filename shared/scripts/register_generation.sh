#!/usr/bin/env bash

# cd to script dir
cd "$(dirname "$0")"

uv run peakrdl regblock-vhdl ../gpio/hdl/registers.rdl -o ../gpio/hdl --cpuif axi4-lite
uv run peakrdl markdown ../gpio/hdl/registers.rdl -o ../gpio/Registers.md