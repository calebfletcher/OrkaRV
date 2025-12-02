#![no_std]
#![no_main]

// needed to link the boot.S
use rust as _;

use core::{arch::asm, panic::PanicInfo};

use rust::uart::Uart;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    unsafe { asm!("ebreak") }
    loop {}
}

#[unsafe(no_mangle)]
pub extern "C" fn main() -> ! {
    let uart = unsafe { Uart::from_ptr(0x0201_0000 as *mut _) };

    loop {
        let status = uart.status().read();

        // read
        if status.rxr() {
            // read byte to clear rx buffer
            let _byte = uart.rx();
        }

        // write
        if status.txe() {
            uart.tx(0xA5);
        }
    }
}
