#![no_std]
#![no_main]

use core::fmt::Write as _;

use common::{
    debug,
    uart::{UART_ADDR, Uart},
};
use embedded_hal::delay::DelayNs as _;
use heapless::String;
use riscv_rt::entry;

#[entry]
fn main() -> ! {
    let uart = unsafe { Uart::from_ptr(UART_ADDR as *mut _) };
    let mut delay = riscv::delay::McycleDelay::new(100_000_000);

    // wait for 1ms, timing the delay duration
    let start = riscv::register::time::read64();
    delay.delay_ms(1);
    let end = riscv::register::time::read64();

    // print results to uart
    let mut buffer = String::<64>::new();
    writeln!(&mut buffer, "start {start} end {end}").unwrap();
    for byte in buffer.as_bytes() {
        // wait for tx slot
        while !uart.status().read().txe() {}
        uart.tx(*byte);
    }

    // flush uart
    while !uart.status().read().txe() {}

    debug::set_pass();
}
