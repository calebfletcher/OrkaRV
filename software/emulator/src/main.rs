use std::{path::Path, process::Command};

use anyhow::Context;

use crate::cpu::Cpu;

mod cpu;
mod instructions;

fn main() -> Result<(), anyhow::Error> {
    // Build binary
    Command::new("cargo")
        .args(&["build", "--example", "math"])
        .current_dir("../rust")
        .status()
        .context("failed to build the binary")?;
    let elf_path = Path::new("../rust/target/riscv32i-unknown-none-elf/debug/examples/math");

    // Make flat file
    Command::new("riscv64-unknown-elf-objcopy")
        .args(["-O", "binary"])
        .arg(elf_path)
        .arg("program.bin")
        .status()
        .context("could not create flat file")?;

    // Create CPU
    let mut cpu = Cpu::from_flat_file("program.bin").context("could not load cpu")?;

    // Run
    while !cpu.halted {
        cpu.step().context("could not step cpu")?;
    }

    Ok(())
}
