#![no_std]
#![no_main]

use riscv_rt::entry;

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    common::debug::set_fail();
}

#[unsafe(export_name = "_setup_interrupts")]
pub fn setup_interrupts() {}

#[entry]
fn main() -> ! {
    panic!();
}
