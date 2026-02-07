#![no_std]
#![no_main]

use common::debug;

use riscv_rt::entry;

#[entry]
fn main() -> ! {
    unsafe { riscv::register::mie::set_mext() };
    unsafe { riscv::register::mstatus::set_mie() };

    riscv::register::mscratch::read();
    unsafe { riscv::register::mscratch::write(0x12345678) };
    riscv::register::mscratch::read();

    debug::set_pass();
}
