#!/usr/bin/env bash

# cd to script dir
cd "$(dirname "$0")"

for peripheral in gpio uart
do
    uv run peakrdl regblock-vhdl ../peripherals/$peripheral/hdl/registers.rdl -o ../peripherals/$peripheral/hdl --cpuif axi4-lite
    uv run peakrdl markdown ../peripherals/$peripheral/hdl/registers.rdl -o ../peripherals/$peripheral/Registers.md
done