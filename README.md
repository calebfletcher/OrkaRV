# OrkaRV

## References
RISC-V ISA Specifications = https://riscv.atlassian.net/wiki/spaces/HOME/pages/16154769/RISC-V+Technical+Specifications#ISA-Specifications

## Toolchains
C compiler and assembler: `sudo apt install gcc-riscv64-unknown-elf`

Rust
```bash
rustup target add riscv32i-unknown-none-elf
cd software/sample_rust
just rust simulate gui
```