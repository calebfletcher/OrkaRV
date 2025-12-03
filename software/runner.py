import glob
from shutil import copyfile
from pathlib import Path
import subprocess
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb_tools.runner import get_runner
from cocotbext.uart import UartSink, UartSource

@cocotb.test(timeout_time=2, timeout_unit="ms")
async def run(dut):
    clock = Clock(dut.clk, 10, unit="ns")
    clock.start()

    uart_sink = UartSink(dut.uart_rxd_out, baud=1000000)
    uart_source = UartSource(dut.uart_txd_in, baud=1000000)

    dut.uart_txd_in.value = 1

    # Reset the CPU
    dut.reset.value = 1
    await clock.cycles(3)
    dut.reset.value = 0

    expected_string = b"Hello World! This is a long test string from cocotb to the orkarv core.\n"

    await uart_source.write(expected_string)
    
    # receive newline-terminated string
    received_buffer = bytearray()
    while True:
        data = await uart_sink.read()
        received_buffer.extend(data)
        if received_buffer.endswith(b'\n'):
            break

    assert received_buffer == expected_string

    # Wait for it to halt
    if not dut.halt.value:
        await RisingEdge(dut.halt)

def main():
    proj_path = Path(__file__).resolve().parent.parent
    sources = [
        proj_path / "shared" / "hdl" / "RiscVPkg.vhd",
        proj_path / "shared" / "hdl" / "InstructionDecoder.vhd",
        proj_path / "shared" / "hdl" / "Registers.vhd",
        proj_path / "shared" / "hdl" / "Cpu.vhd",

        proj_path / "shared" / "hdl" / "Ram.vhd",

        proj_path / "shared" / "hdl" / "reg_utils.vhd",
        proj_path / "shared" / "hdl" / "axi4lite_intf_pkg.vhd",
        proj_path / "shared" / "hdl" / "AxiLitePeakRdlBridge.vhd",
        
        proj_path / "shared" / "peripherals" / "gpio" / "hdl" / "GpioRegisters_pkg.vhd",
        proj_path / "shared" / "peripherals" / "gpio" / "hdl" / "GpioRegisters.vhd",
        proj_path / "shared" / "peripherals" / "gpio" / "hdl" / "Gpio.vhd",
        
        proj_path / "shared" / "peripherals" / "uart" / "hdl" / "UartRegisters_pkg.vhd",
        proj_path / "shared" / "peripherals" / "uart" / "hdl" / "UartRegisters.vhd",
        proj_path / "shared" / "peripherals" / "uart" / "hdl" / "Uart.vhd",

        proj_path / "shared" / "hdl" / "Soc.vhd",
    ]

    runner = get_runner("ghdl")

    subprocess.run("make src", cwd=proj_path / "submodules" / "surf", shell=True, check=True)

    runner.build(
        sources=glob.glob("../submodules/surf/build/SRC_VHDL/surf/*"),
        hdl_library="surf",
        always=True,
        build_args=["--std=08"],
        clean=True
    )

    runner.build(
        sources=glob.glob("../submodules/surf/build/SRC_VHDL/ruckus/*"),
        hdl_library="ruckus",
        always=True,
        build_args=["--std=08"],
    )

    runner.build(
        sources=sources,
        always=True,
        build_args=["--std=08", "-fsynopsys", "-frelaxed-rules", "-Wno-elaboration", "-Wno-shared"],
        hdl_toplevel="soc",
    )

    memory_file_path = Path(__file__).resolve().parent.joinpath("build/program.hex")

    runner.test(
        hdl_toplevel="soc",
        test_module="runner",
        parameters={"RAM_FILE_PATH_G": memory_file_path},
        waves=True,
        test_args=["--std=08", "-fsynopsys", "-frelaxed-rules"],
    )

    copyfile(runner.test_dir.joinpath("soc.ghw"), "build/sim/out.ghw")


if __name__ == "__main__":
    main()
