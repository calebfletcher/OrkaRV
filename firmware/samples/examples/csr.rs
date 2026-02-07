#![no_std]
#![no_main]

use common::debug;

use riscv::interrupt::Interrupt::MachineExternal;
use riscv_rt::entry;

#[riscv_rt::core_interrupt(MachineExternal)]
fn machine_external_interrupt() {
    if !riscv::interrupt::is_interrupt_pending(MachineExternal) {
        return;
    }
    unsafe { riscv::register::mscratch::write(0xDEADBEEF) };
}

#[entry]
fn main() -> ! {
    unsafe { riscv::interrupt::enable_interrupt(MachineExternal) };
    unsafe { riscv::interrupt::enable() };
    riscv::register::mie::read();

    riscv::register::mscratch::read();
    unsafe { riscv::register::mscratch::write(0x12345678) };
    riscv::register::mscratch::read();

    loop {
        riscv::asm::wfi();
    }

    debug::set_pass();
}
