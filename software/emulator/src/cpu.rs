use std::path::Path;

use anyhow::{bail, ensure, Context};

use crate::instructions::{immediate, rd, rs1, rs2, Instruction};

const MEM_SIZE: usize = 64 * 1024;

pub struct Cpu {
    pc: u32,
    registers: Registers,
    memory: Ram,
    debug: DebugPeripheral,
}

impl Cpu {
    pub fn from_flat_file(path: impl AsRef<Path>) -> Result<Self, anyhow::Error> {
        let file_contents = std::fs::read(path).context("could not load binary path")?;

        let mut memory: Box<[u8; MEM_SIZE]> = vec![0u8; MEM_SIZE]
            .into_boxed_slice()
            .try_into()
            .expect("same size");

        ensure!(
            file_contents.len() < MEM_SIZE,
            "file is too large for memory ({} > {MEM_SIZE})",
            file_contents.len()
        );
        memory[..file_contents.len()].copy_from_slice(&file_contents);

        Ok(Self {
            pc: 0x01000000,
            registers: Registers::default(),
            memory: Ram {
                base: 0x01000000,
                data: memory,
            },
            debug: DebugPeripheral {
                base: 0x03000000,
                status: None,
            },
        })
    }

    pub fn step(&mut self) -> Result<(), anyhow::Error> {
        let raw_inst = self.read(self.pc)?;
        let inst = Instruction::try_from(raw_inst)?;

        let immediate = immediate(raw_inst).unwrap_or_default();
        let rd = rd(raw_inst);
        let rs1 = rs1(raw_inst);
        let rs2 = rs2(raw_inst);

        let rs1_value = self.registers.read(rs1);
        let rs2_value = self.registers.read(rs2);

        println!(
            "step {:08X} {inst:?} (imm = {immediate:08X}, rd = {rd}, rs1 = {rs1}, rs2 = {rs2})",
            self.pc
        );

        let mut advance_pc = true;

        use Instruction::*;
        match inst {
            Lui => {
                self.registers.write(rd, immediate);
                //println!("writing {immediate} to register {rd}");
            }
            Auipc => {
                let value = self.pc.wrapping_add(immediate);
                self.registers.write(rd, value);
                //println!("writing {value} to register {rd}");
            }
            Jal => {
                let next_inst_addr = self.pc + 4;
                let raw_address = self.pc.wrapping_add(immediate);
                self.pc = raw_address & 0xFFFFFFFE;
                self.registers.write(rd, next_inst_addr);
                advance_pc = false;
                //println!("jumping to addr {:08X}", self.pc);
            }
            Jalr => {
                let next_inst_addr = self.pc + 4;
                let raw_address = rs1_value.wrapping_add(immediate);
                self.pc = raw_address & 0xFFFFFFFE;
                self.registers.write(rd, next_inst_addr);
                advance_pc = false;
                //println!("jumping to addr {:08X}", self.pc);
            }
            Add => {
                let value = rs1_value.wrapping_add(rs2_value);
                self.registers.write(rd, value);
                //println!("writing {value} to register {rd}");
            }
            Sub => {
                let value = rs1_value.wrapping_sub(rs2_value);
                self.registers.write(rd, value);
                //println!("writing {value} to register {rd}");
            }
            Xor => {
                let value = rs1_value ^ rs2_value;
                self.registers.write(rd, value);
                //println!("writing {value} to register {rd}");
            }
            And => {
                self.registers.write(rd, rs1_value & rs2_value);
            }
            Or => {
                self.registers.write(rd, rs1_value | rs2_value);
            }
            Sll => {
                self.registers.write(rd, rs1_value << (rs2_value & 0b11111));
            }
            Srl => {
                self.registers.write(rd, rs1_value >> (rs2_value & 0b11111));
            }
            Sra => {
                self.registers
                    .write(rd, ((rs1_value as i32) >> (rs2_value & 0b11111)) as u32);
            }
            Xori => {
                self.registers.write(rd, rs1_value ^ immediate);
            }
            Addi => {
                let value = rs1_value.wrapping_add(immediate);
                self.registers.write(rd, value);
                //println!("writing {value} to register {rd}");
            }
            Andi => {
                self.registers.write(rd, rs1_value & immediate);
            }
            Slli => {
                self.registers.write(rd, rs1_value << (immediate & 0b11111));
            }
            Srai => {
                self.registers
                    .write(rd, ((rs1_value as i32) >> (immediate & 0b11111)) as u32);
            }
            Srli => {
                self.registers.write(rd, rs1_value >> (immediate & 0b11111));
            }
            Slt => {
                self.registers.write(
                    rd,
                    if (rs1_value as i32) < (rs2_value as i32) {
                        1
                    } else {
                        0
                    },
                );
            }
            Sltu => {
                self.registers
                    .write(rd, if rs1_value < rs2_value { 1 } else { 0 });
            }
            Sltiu => {
                self.registers
                    .write(rd, if rs1_value < immediate { 1 } else { 0 });
            }
            Bge => {
                if (rs1_value as i32) >= (rs2_value as i32) {
                    self.pc = self.pc.wrapping_add(immediate);
                    advance_pc = false;
                    //println!("{rs1_value} >= {rs2_value}, taking branch");
                } else {
                    //println!("{rs1_value} < {rs2_value}, not taking branch");
                }
            }
            Bgeu => {
                if rs1_value >= rs2_value {
                    self.pc = self.pc.wrapping_add(immediate);
                    advance_pc = false;
                    //println!("{rs1_value} >= {rs2_value}, taking branch");
                } else {
                    //println!("{rs1_value} < {rs2_value}, not taking branch");
                }
            }
            Blt => {
                if (rs1_value as i32) < (rs2_value as i32) {
                    self.pc = self.pc.wrapping_add(immediate);
                    advance_pc = false;
                }
            }
            Bltu => {
                if rs1_value < rs2_value {
                    self.pc = self.pc.wrapping_add(immediate);
                    advance_pc = false;
                }
            }
            Beq => {
                if rs1_value == rs2_value {
                    self.pc = self.pc.wrapping_add(immediate);
                    advance_pc = false;
                }
            }
            Bne => {
                if rs1_value != rs2_value {
                    self.pc = self.pc.wrapping_add(immediate);
                    advance_pc = false;
                }
            }
            Sw => {
                let addr = rs1_value.wrapping_add(immediate);
                self.write(addr, rs2_value)
                    .context("could not store word")?;
                //println!("writing {rs2_value} to {addr:08x}");
            }
            Lw => {
                let addr = rs1_value.wrapping_add(immediate);
                let value = self.read(addr)?;
                self.registers.write(rd, value);
                //println!("writing {value} from addr {addr:08X} to reg {rd}");
            }
            Lhu => {
                let addr = rs1_value.wrapping_add(immediate);
                let value = self.read(addr)? & 0x0000FFFF;
                self.registers.write(rd, value);
                //println!("writing {value} from addr {addr:08X} to reg {rd}");
            }
            _ => bail!("unexpected opcode: {inst:?}"),
        }

        if advance_pc {
            self.pc += 4;
        }

        Ok(())
    }

    fn read(&self, addr: u32) -> Result<u32, anyhow::Error> {
        if self.memory.contains(addr) {
            return self.memory.read(addr);
        }
        if self.debug.contains(addr) {
            return self.debug.read(addr);
        }

        bail!("invalid read address: {addr:08X}")
    }

    fn write(&mut self, addr: u32, value: u32) -> Result<(), anyhow::Error> {
        if self.memory.contains(addr) {
            self.memory.write(addr, value);
            return Ok(());
        }
        if self.debug.contains(addr) {
            self.debug.write(addr, value);
            return Ok(());
        }

        bail!("invalid write address: {addr:08X}");
    }

    pub fn status(&self) -> Option<Status> {
        self.debug.status
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    Success,
    Failure,
}

#[derive(Default)]
struct Registers {
    registers: [u32; 32],
}

impl Registers {
    fn read(&self, index: usize) -> u32 {
        self.registers[index]
    }

    fn write(&mut self, index: usize, value: u32) {
        if index == 0 {
            return;
        }
        self.registers[index] = value;
    }
}

struct Ram {
    base: u32,
    data: Box<[u8; MEM_SIZE]>,
}

impl Ram {
    fn contains(&self, addr: u32) -> bool {
        (self.base..self.base + MEM_SIZE as u32).contains(&addr)
    }

    fn read(&self, addr: u32) -> Result<u32, anyhow::Error> {
        let addr = (addr - self.base) as usize;
        Ok(u32::from_le_bytes(
            self.data[addr..addr + 4]
                .try_into()
                .context("address invalid for read")?,
        ))
    }

    fn write(&mut self, addr: u32, value: u32) {
        let addr = (addr - self.base) as usize;
        self.data[addr..addr + 4].copy_from_slice(&value.to_le_bytes());
    }
}

struct DebugPeripheral {
    base: u32,
    status: Option<Status>,
}

impl DebugPeripheral {
    fn contains(&self, addr: u32) -> bool {
        (self.base..self.base + 0x4).contains(&addr)
    }

    fn read(&self, addr: u32) -> Result<u32, anyhow::Error> {
        let addr = (addr - self.base) as usize;
        unimplemented!()
    }

    fn write(&mut self, addr: u32, value: u32) {
        let addr = (addr - self.base) as usize;
        match addr {
            0x0 => self.status = Some(Status::Success),
            0x4 => self.status = Some(Status::Failure),
            _ => unimplemented!(),
        }
    }
}
