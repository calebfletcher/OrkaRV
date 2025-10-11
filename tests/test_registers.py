import glob
from pathlib import Path
import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb_tools.runner import get_runner

@cocotb.test()
async def registers(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    dut.wr_addr.value = 0
    dut.wr_data.value = 0
    dut.wr_strobe.value = 0

    dut.reset.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.reset.value = 0

    # Check registers
    assert dut.registerFile[0].value == 0
    assert dut.registerFile[1].value == 0
    assert dut.registerFile[2].value == 0
    assert dut.registerFile[3].value == 0

    # Trigger a write
    dut.wr_addr.value = 1
    dut.wr_data.value = 0x12345678
    dut.wr_strobe.value = 1
    await RisingEdge(dut.clk)
    dut.wr_addr.value = 0
    dut.wr_data.value = 0
    dut.wr_strobe.value = 0
    await RisingEdge(dut.clk)
    
    # Check registers
    assert dut.registerFile[0].value == 0
    assert dut.registerFile[1].value == 0x12345678
    assert dut.registerFile[2].value == 0
    assert dut.registerFile[3].value == 0

def test_runner():
    proj_path = Path(__file__).resolve().parent.parent
    sources = [
        proj_path / "shared" / "hdl" / "RiscVPkg.vhd",
        proj_path / "shared" / "hdl" / "Registers.vhd",
    ]

    runner = get_runner("ghdl")

    runner.build(
        sources=sources,
        always=True,
        build_args=["--std=08", "-fsynopsys", "-frelaxed-rules"],
        hdl_toplevel="registers"
    )

    runner.test(hdl_toplevel="registers", test_module=__name__, waves=True, test_args=["--std=08", "-fsynopsys", "-frelaxed-rules"])