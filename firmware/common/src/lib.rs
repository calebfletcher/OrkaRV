#![no_std]

pub mod debug;
pub mod gpio;
pub mod reg;
pub mod uart;

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    debug::set_fail();
}
