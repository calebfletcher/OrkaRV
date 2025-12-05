#![no_std]

pub mod debug;
pub mod gpio;
pub mod reg;
pub mod uart;

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    debug::set_fail();
}

#[unsafe(export_name = "_setup_interrupts")]
pub fn setup_interrupts() {}
