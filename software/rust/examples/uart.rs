#![no_std]
#![no_main]

use heapless::Deque;
use rust::uart::Uart;

use riscv_rt::entry;

#[entry]
fn main() -> ! {
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
