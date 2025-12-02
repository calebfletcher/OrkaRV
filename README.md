# OrkaRV

## References
RISC-V ISA Specifications = https://riscv.atlassian.net/wiki/spaces/HOME/pages/16154769/RISC-V+Technical+Specifications#ISA-Specifications

## Toolchains
C compiler and assembler: `sudo apt install gcc-riscv64-unknown-elf`

Rust
```bash
rustup target add riscv32i-unknown-none-elf
cd software/rust
cargo r -r --example gpio
```

## Python Environment

Uses `uv` as the package manager, install via `curl -LsSf https://astral.sh/uv/install.sh | sh`

Run tests with `uv run pytest`