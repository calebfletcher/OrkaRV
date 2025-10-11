import glob
from pathlib import Path
from enum import IntEnum
import cocotb
from cocotb.triggers import Timer

from cocotb_tools.runner import get_runner

class PyInstruction(IntEnum):
    LUI = 0
    AUIPC = 1
    JAL = 2
    JALR = 3
    BEQ = 4
    BNE = 5
    BLT = 6
    BGE = 7
    BLTU = 8
    BGEU = 9
    LB = 10
    LH = 11
    LW = 12
    LBU = 13
    LHU = 14
    SB = 15
    SH = 16
    SW = 17
    ADDI = 18
    SLTI = 19
    SLTIU = 20
    XORI = 21
    ORI = 22
    ANDI = 23
    SLLI = 24
    SRLI = 25
    SRAI = 26
    ADD = 27
    SUB = 28
    SLL = 29
    SLT = 30
    SLTU = 31
    XOR = 32
    SRL = 33
    SRA = 34
    OR = 35
    AND = 36
    FENCE = 37
    FENCE_TSO = 38
    PAUSE = 39
    ECALL = 40
    EBREAK = 41
    UNKNOWN = 42

def twos_complement_bin(n, bits=12):
    return f"{n & ((1 << bits) - 1):0{bits}b}"

@cocotb.test()
async def addi(dut):

    async def addi_inner(immediate: int, rs1: int, rd: int):
        dut.instruction.value = f"{twos_complement_bin(immediate)}{rs1:05b}000{rd:05b}0010011"
        await Timer(1)
        assert dut.instructionType.value == PyInstruction.ADDI.value
        assert dut.immediate.value == twos_complement_bin(immediate, 32)
        assert dut.rs1.value == rs1
        assert dut.rd.value == rd

    await addi_inner(0, 0, 0)
    await addi_inner(1, 0, 0)
    await addi_inner(0, 1, 0)
    await addi_inner(0, 0, 1)
    await addi_inner(1, 2, 3)
    await addi_inner(-1, 31, 31)

def test_runner():
    proj_path = Path(__file__).resolve().parent.parent
    sources = [
        proj_path / "shared" / "hdl" / "RiscVPkg.vhd",
        proj_path / "shared" / "hdl" / "InstructionDecoder.vhd",
    ]

    runner = get_runner("ghdl")

    runner.build(
        sources=sources,
        always=True,
        build_args=["--std=08", "-fsynopsys", "-frelaxed-rules"],
        hdl_toplevel="instructiondecoder"
    )

    runner.test(hdl_toplevel="instructiondecoder", test_module=__name__, waves=True, test_args=["--std=08", "-fsynopsys", "-frelaxed-rules"])