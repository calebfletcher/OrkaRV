use anyhow::{Context, bail, ensure};

/// 7-bit opcode (includes length bits)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Opcode(pub u8);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InstEncoding {
    R,
    I,
    S,
    B,
    U,
    J,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Instruction {
    Lui,
    Auipc,
    Jal,
    Jalr,
    Beq,
    Bne,
    Blt,
    Bge,
    Bltu,
    Bgeu,
    Lb,
    Lh,
    Lw,
    Lbu,
    Lhu,
    Sb,
    Sh,
    Sw,
    Addi,
    Slti,
    Sltiu,
    Xori,
    Ori,
    Andi,
    Slli,
    Srli,
    Srai,
    Add,
    Sub,
    Sll,
    Slt,
    Sltu,
    Xor,
    Srl,
    Sra,
    Or,
    And,
    Fence,
    Ecall,
    Ebreak,
}

impl TryFrom<u32> for Instruction {
    type Error = anyhow::Error;

    fn try_from(inst: u32) -> Result<Self, Self::Error> {
        let value = opcode(inst)?;
        let funct3 = funct3(inst);
        let funct7 = funct7(inst);
        use Instruction::*;
        Ok(match (value.0, funct3, funct7) {
            (0b0110111, _, _) => Lui,
            (0b0010111, _, _) => Auipc,
            (0b1101111, _, _) => Jal,
            (0b1100111, _, _) => Jalr,
            (0b1100011, 0b000, _) => Beq,
            (0b1100011, 0b001, _) => Bne,
            (0b1100011, 0b100, _) => Blt,
            (0b1100011, 0b101, _) => Bge,
            (0b1100011, 0b110, _) => Bltu,
            (0b1100011, 0b111, _) => Bgeu,
            (0b0000011, 0b000, _) => Lb,
            (0b0000011, 0b001, _) => Lh,
            (0b0000011, 0b010, _) => Lw,
            (0b0000011, 0b100, _) => Lbu,
            (0b0000011, 0b101, _) => Lhu,
            (0b0100011, 0b000, _) => Sb,
            (0b0100011, 0b001, _) => Sh,
            (0b0100011, 0b010, _) => Sw,
            (0b0010011, 0b000, _) => Addi,
            (0b0010011, 0b010, _) => Slti,
            (0b0010011, 0b011, _) => Sltiu,
            (0b0010011, 0b100, _) => Xori,
            (0b0010011, 0b110, _) => Ori,
            (0b0010011, 0b111, _) => Andi,
            (0b0010011, 0b001, 0b0000000) => Slli,
            (0b0010011, 0b101, 0b0000000) => Srli,
            (0b0010011, 0b101, 0b0100000) => Srai,
            (0b0110011, 0b000, 0b0000000) => Add,
            (0b0110011, 0b000, 0b0100000) => Sub,
            (0b0110011, 0b001, 0b0000000) => Sll,
            (0b0110011, 0b010, 0b0000000) => Slt,
            (0b0110011, 0b011, 0b0000000) => Sltu,
            (0b0110011, 0b100, 0b0000000) => Xor,
            (0b0110011, 0b101, 0b0000000) => Srl,
            (0b0110011, 0b101, 0b0100000) => Sra,
            (0b0110011, 0b110, 0b0000000) => Or,
            (0b0110011, 0b111, 0b0000000) => And,
            _ => bail!("could not decode instruction: {inst:032b}"),
        })
    }
}

impl TryFrom<Opcode> for InstEncoding {
    type Error = anyhow::Error;

    fn try_from(value: Opcode) -> Result<Self, Self::Error> {
        Ok(match value.0 {
            0b1100111 | 0b0000011 | 0b0010011 | 0b1110011 => InstEncoding::I,
            0b0100011 => InstEncoding::S,
            0b1100011 => InstEncoding::B,
            0b0110111 | 0b0010111 => InstEncoding::U,
            0b1101111 => InstEncoding::J,
            0b0110011 => InstEncoding::R,
            opcode => bail!("could not determine inst encoding for opcode: {opcode:07b}"),
        })
    }
}

pub fn opcode(inst: u32) -> Result<Opcode, anyhow::Error> {
    ensure!(inst & 0b11 == 0b11, "instruction is not compressed");
    Ok(Opcode(inst as u8 & 0b1111111))
}

pub fn rd(inst: u32) -> usize {
    (inst >> 7) as usize & 0b11111
}

pub fn rs1(inst: u32) -> usize {
    (inst >> 15) as usize & 0b11111
}

pub fn rs2(inst: u32) -> usize {
    (inst >> 20) as usize & 0b11111
}

pub fn funct3(inst: u32) -> usize {
    (inst >> 12) as usize & 0b111
}

pub fn funct7(inst: u32) -> usize {
    (inst >> 25) as usize & 0b1111111
}

pub fn immediate(inst: u32) -> Result<u32, anyhow::Error> {
    let encoding: InstEncoding = opcode(inst)?.try_into()?;
    Ok(match encoding {
        InstEncoding::R => bail!("r-type instruction does not have an immediate"),
        // I-type: bits 31:20, sign-extended
        InstEncoding::I => ((inst as i32) >> 20) as u32,
        // S-type: bits 31:25 (imm[11:5]), 11:7 (imm[4:0]), sign-extended
        InstEncoding::S => {
            let imm = (((inst >> 7) & 0x1F) | (((inst >> 25) & 0x7F) << 5)) as i32;
            let imm = (imm << 20) >> 20; // sign-extend from 12 bits
            imm as u32
        }
        // B-type: bits 31 (imm[12]), 7 (imm[11]), 30:25 (imm[10:5]), 11:8 (imm[4:1]), 0 (zero), sign-extended
        InstEncoding::B => {
            let imm = ((((inst >> 31) & 0x1) << 12)
                | (((inst >> 7) & 0x1) << 11)
                | (((inst >> 25) & 0x3F) << 5)
                | (((inst >> 8) & 0xF) << 1)) as i32;
            let imm = (imm << 19) >> 19; // sign-extend from 13 bits
            imm as u32
        }
        // U-type: bits 31:12, lower 12 bits are zero
        InstEncoding::U => inst & 0xFFFFF000,
        // J-type: bits 31 (imm[20]), 19:12 (imm[19:12]), 20 (imm[11]), 30:21 (imm[10:1]), 0 (zero), sign-extended
        InstEncoding::J => {
            let imm = ((((inst >> 31) & 0x1) << 20)
                | (((inst >> 12) & 0xFF) << 12)
                | (((inst >> 20) & 0x1) << 11)
                | (((inst >> 21) & 0x3FF) << 1)) as i32;
            let imm = (imm << 11) >> 11; // sign-extend from 21 bits
            imm as u32
        }
    })
}
