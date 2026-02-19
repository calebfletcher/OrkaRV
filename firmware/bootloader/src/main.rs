#![no_std]
#![no_main]

use core::fmt::Write as _;

use common::uart::Uart;
use heapless::{String, Vec};
use riscv_rt::entry;

#[entry]
fn main() -> ! {
    let uart = unsafe { Uart::from_ptr(0x2002_0000 as *mut _) };

    // print results to uart
    let mut buffer = Vec::<u8, 64>::new();
    let mut resp = String::<64>::new();

    loop {
        // read line from uart
        loop {
            let byte: u8 = uart.read();
            if byte == b'\n' {
                break;
            }
            let _ = buffer.push(byte);
        }
        let str = core::str::from_utf8(&buffer).unwrap().trim();

        writeln!(&mut resp, "first 5 chars: {}", &str[..5]).unwrap();

        for byte in resp.as_bytes() {
            uart.write(*byte);
        }
    }
}
