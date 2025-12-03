#![no_std]
#![no_main]

use heapless::Deque;
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

    let mut bytes = Deque::<_, 256>::new();

    loop {
        let status = uart.status().read();

        // read
        if status.rxr() {
            // read byte
            let byte = uart.rx();

            let _ = bytes.push_back(byte);
        }

        if bytes.back() == Some(&b'\n') {
            while let Some(byte) = bytes.pop_front() {
                // wait for tx slot
                loop {
                    let status = uart.status().read();
                    if status.txe() {
                        break;
                    }
                }

                uart.tx(byte);
            }

            panic!("");
        }
    }
}
