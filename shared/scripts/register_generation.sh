#!/usr/bin/env bash

# cd to script dir
cd "$(dirname "$0")"

uv run peakrdl regblock-vhdl ../csr/hdl/registers.rdl -o ../csr/hdl --cpuif passthrough
uv run peakrdl markdown ../csr/hdl/registers.rdl -o ../csr/Registers.md

for peripheral in gpio uart
do
    uv run peakrdl regblock-vhdl ../peripherals/$peripheral/hdl/registers.rdl -o ../peripherals/$peripheral/hdl --cpuif axi4-lite
    uv run peakrdl markdown ../peripherals/$peripheral/hdl/registers.rdl -o ../peripherals/$peripheral/Registers.md
done