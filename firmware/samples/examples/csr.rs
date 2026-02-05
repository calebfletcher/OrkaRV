#![no_std]
#![no_main]

use common::debug;

use riscv_rt::entry;

#[entry]
fn main() -> ! {
    riscv::register::mhartid::read();
    riscv::register::mscratch::read();
    unsafe { riscv::register::mscratch::write(0x12345678) };
    riscv::register::mscratch::read();

    debug::set_pass();
}
