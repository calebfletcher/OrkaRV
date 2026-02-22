#![no_std]

use crate::uart::Uart;
use core::fmt::Write;
use heapless::String;

pub mod debug;
pub mod gpio;
pub mod reg;
pub mod uart;

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    let uart = unsafe { Uart::from_ptr(uart::UART_ADDR as *mut _) };
    let mut resp = String::<256>::new();
    let _ = writeln!(resp, "{}", info);
    for byte in resp.as_bytes() {
        uart.write(*byte);
    }

    debug::set_fail();
}
