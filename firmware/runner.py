import asyncio
import glob
from shutil import copyfile
from pathlib import Path
import subprocess
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Event, RisingEdge, Timer
from cocotb_tools.runner import get_runner
from cocotbext.uart import UartSink, UartSource
from cocotbext.axi import AxiLiteMaster, AxiLiteSlave, AxiLiteBus

class DebugPeripheral:
    def __init__(self):
        self.pass_event = Event()
        self.fail_event = Event()

    async def write(self, address: int, data: bytes):
        masked_addr = address & ((1 << 24) - 1)
        print(f"0x{masked_addr:08X}", data)
        match masked_addr:
            case 0x0:
                # pass
                self.pass_event.set()
            case 0x4:
                # pass
                self.fail_event.set()
            case _:
                raise RuntimeError("invalid peripheral write addr")

    async def read(self, address: int, length: int):
        raise RuntimeError("attempt read from debug peripheral")

@cocotb.test(timeout_time=2, timeout_unit="ms")
async def run(dut):
    clock = Clock(dut.clk, 10, unit="ns")
    clock.start()
    
    debug_peripheral = DebugPeripheral()

    uart_sink = UartSink(dut.uart_rxd_out, baud=1000000)
    uart_source = UartSource(dut.uart_txd_in, baud=1000000)

    # Reset the CPU
    dut.reset.value = 1
    await clock.cycles(3)
    dut.reset.value = 0

    axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.clk)
    axil_slave = AxiLiteSlave(AxiLiteBus.from_prefix(dut, "M_AXI"), dut.clk, target=debug_peripheral)

    # detect fail event from debug peripheral
    async def fail_on_error():
        await debug_peripheral.fail_event.wait()
        raise RuntimeError
    cocotb.start_soon(fail_on_error())
    # detect fail event from traps
    async def fail_on_trap():
        await RisingEdge(dut.trap)
        raise RuntimeError
    cocotb.start_soon(fail_on_trap())

    await Timer(50, 'us')
    expected_string = b"Hello World! This is a long test string from cocotb to the orkarv core.\n"
    await uart_source.write(expected_string)
    
    # # receive newline-terminated string
    # received_buffer = bytearray()
    # while True:
    #     data = await uart_sink.read()
    #     received_buffer.extend(data)
    #     if received_buffer.endswith(b'\n'):
    #         break

    # assert received_buffer == expected_string

    # wait for pass
    await debug_peripheral.pass_event.wait()

def main():
    proj_path = Path(__file__).resolve().parent.parent
    sources = [
        proj_path / "shared" / "hdl" / "RiscVPkg.vhd",
        proj_path / "shared" / "hdl" / "InstructionDecoder.vhd",
        proj_path / "shared" / "hdl" / "Registers.vhd",
        proj_path / "shared" / "csr" / "hdl" / "csrif_pkg.vhd",
        proj_path / "shared" / "csr" / "hdl" / "Csr.vhd",
        proj_path / "shared" / "csr" / "hdl" / "CsrRegisters_pkg.vhd",
        proj_path / "shared" / "csr" / "hdl" / "CsrRegisters.vhd",
        proj_path / "shared" / "hdl" / "Cpu.vhd",

        proj_path / "shared" / "hdl" / "Ram.vhd",

        proj_path / "shared" / "hdl" / "reg_utils.vhd",
        proj_path / "shared" / "hdl" / "axi4lite_intf_pkg.vhd",
        proj_path / "shared" / "hdl" / "AxiLitePeakRdlBridge.vhd",
        proj_path / "shared" / "hdl" / "AxiToAxiLite.vhd",
        proj_path / "shared" / "hdl" / "AxiPkg.vhd",
        proj_path / "shared" / "hdl" / "AxiCrossbar.vhd",
        proj_path / "shared" / "hdl" / "SlaveAxiIpIntegrator.vhd",
        
        proj_path / "shared" / "peripherals" / "gpio" / "hdl" / "GpioRegisters_pkg.vhd",
        proj_path / "shared" / "peripherals" / "gpio" / "hdl" / "GpioRegisters.vhd",
        proj_path / "shared" / "peripherals" / "gpio" / "hdl" / "Gpio.vhd",
        
        proj_path / "shared" / "peripherals" / "uart" / "hdl" / "UartRegisters_pkg.vhd",
        proj_path / "shared" / "peripherals" / "uart" / "hdl" / "UartRegisters.vhd",
        proj_path / "shared" / "peripherals" / "uart" / "hdl" / "Uart.vhd",

        proj_path / "shared" / "hdl" / "Soc.vhd",
        
        proj_path / "targets" / "CocotbSoc" / "hdl" / "CocotbSoc.vhd",
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
        build_args=["--std=08", "-fsynopsys", "-frelaxed-rules", "-Wno-elaboration", "-Wno-shared", "-Wno-specs"],
        hdl_toplevel="cocotbsoc",
    )

    memory_file_path = Path(__file__).resolve().parent.joinpath("build/program.hex")

    runner.test(
        hdl_toplevel="cocotbsoc",
        test_module="runner",
        parameters={"RAM_FILE_PATH_G": memory_file_path},
        waves=True,
        test_args=["--std=08", "-fsynopsys", "-frelaxed-rules"],
    )

    copyfile(runner.test_dir.joinpath("cocotbsoc.ghw"), "build/sim/out.ghw")


if __name__ == "__main__":
    main()
