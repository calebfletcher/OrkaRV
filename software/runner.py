from shutil import copyfile
from pathlib import Path
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb_tools.runner import get_runner

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def run(dut):
    clock = Clock(dut.clk, 10, unit="ns")
    clock.start()

    # Reset the CPU
    dut.reset.value = 1
    await clock.cycles(3)
    dut.reset.value = 0

    # Wait for it to halt
    await RisingEdge(dut.halt)

def main():
    proj_path = Path(__file__).resolve().parent.parent
    sources = [
        proj_path / "shared" / "hdl" / "RiscVPkg.vhd",
        proj_path / "shared" / "hdl" / "InstructionDecoder.vhd",
        proj_path / "shared" / "hdl" / "Ram.vhd",
        proj_path / "shared" / "hdl" / "Registers.vhd",
        proj_path / "shared" / "hdl" / "Cpu.vhd",
    ]

    runner = get_runner("ghdl")

    runner.build(
        sources=sources,
        always=True,
        build_args=["--std=08", "-fsynopsys", "-frelaxed-rules"],
        hdl_toplevel="cpu",
    )

    memory_file_path = Path(__file__).resolve().parent.joinpath("build/program.hex")

    runner.test(
        hdl_toplevel="cpu",
        test_module="runner",
        parameters={"RAM_FILE_PATH_G": memory_file_path},
        waves=True,
        test_args=["--std=08", "-fsynopsys", "-frelaxed-rules"],
    )

    copyfile(runner.test_dir.joinpath("cpu.ghw"), "build/sim/out.ghw")


if __name__ == "__main__":
    main()
