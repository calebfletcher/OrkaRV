#![no_std]
#![no_main]

use rust::gpio::{Direction, Gpio};

use riscv_rt::entry;

#[entry]
fn main() -> ! {
    let gpio = unsafe { Gpio::from_ptr(0x0200_0000 as *mut _) };

    gpio.direction().modify(|w| w.set_dir(0, Direction::Output));
    gpio.output().modify(|w| w.set_value(0, true));
    gpio.output().modify(|w| w.set_value(0, false));
    gpio.output().modify(|w| w.set_value(0, true));
    gpio.output().modify(|w| w.set_value(0, false));
    gpio.output().modify(|w| w.set_value(0, true));

    panic!();
}
