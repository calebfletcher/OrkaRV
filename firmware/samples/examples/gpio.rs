#![no_std]
#![no_main]

use common::gpio::{Direction, Gpio};

use embedded_hal::delay::DelayNs as _;
use riscv_rt::entry;

#[entry]
fn main() -> ! {
    let gpio = unsafe { Gpio::from_ptr(0x0200_0000 as *mut _) };

    let mut delay = riscv::delay::McycleDelay::new(100_000_000);

    gpio.direction().modify(|w| w.set_dir(0, Direction::Output));

    loop {
        gpio.output().modify(|w| w.set_value(0, true));
        delay.delay_ms(1000);
        gpio.output().modify(|w| w.set_value(0, false));
        delay.delay_ms(1000);
    }
}
