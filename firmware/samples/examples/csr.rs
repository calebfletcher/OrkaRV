#![no_std]
#![no_main]

use common::debug;

use riscv_rt::entry;

#[riscv_rt::core_interrupt(riscv::interrupt::Interrupt::MachineExternal)]
fn machine_external_interrupt() {
    unsafe { riscv::register::mscratch::write(0xDEADBEEF) };
}

#[entry]
fn main() -> ! {
    unsafe { riscv::register::mie::set_mext() };
    unsafe { riscv::register::mstatus::set_mie() };
    riscv::register::mie::read();

    riscv::register::mscratch::read();
    unsafe { riscv::register::mscratch::write(0x12345678) };
    riscv::register::mscratch::read();

    loop {
        riscv::asm::nop();
    }

    debug::set_pass();
}
