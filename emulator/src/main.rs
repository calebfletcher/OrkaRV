use std::{path::PathBuf, process::Command};

use anyhow::{anyhow, Context};

use crate::cpu::Cpu;

mod cpu;
mod instructions;

fn main() -> Result<(), anyhow::Error> {
    let elf_path: PathBuf = std::env::args_os()
        .nth(1)
        .ok_or_else(|| anyhow!("binary path required"))?
        .into();
    // Build binary
    // Command::new("cargo")
    //     .args(["build", "--example", &example])
    //     .current_dir("../rust")
    //     .status()
    //     .context("failed to build the binary")?;
    // let bin_path = elf_path.with_extension("bin");

    // // Make flat file
    // Command::new("riscv64-unknown-elf-objcopy")
    //     .args(["-O", "binary"])
    //     .arg(elf_path)
    //     .arg(&bin_path)
    //     .status()
    //     .context("could not create flat file")?;

    // // Create CPU
    // let mut cpu = Cpu::from_flat_file(&bin_path).context("could not load cpu")?;

    let mut cpu = Cpu::from_elf(&elf_path).context("could not load cpu")?;

    // Run
    while cpu.status().is_none() {
        cpu.step().context("could not step cpu")?;
    }

    let status = cpu.status().unwrap();
    println!("cpu stopped with status: {status:?}");

    Ok(())
}
