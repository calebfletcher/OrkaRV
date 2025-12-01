#![no_std]
#![no_main]

use core::{arch::asm, panic::PanicInfo};

use rust::gpio::{Direction, Gpio};

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    unsafe { asm!("ebreak") }
    loop {}
}

#[allow(static_mut_refs)]
#[unsafe(no_mangle)]
pub extern "C" fn main() -> ! {
    let gpio = unsafe { Gpio::from_ptr(0x0200_0000 as *mut _) };

    gpio.direction().modify(|w| w.set_dir(0, Direction::Output));
    gpio.output().modify(|w| w.set_value(0, true));
    gpio.output().modify(|w| w.set_value(0, false));
    gpio.output().modify(|w| w.set_value(0, true));
    gpio.output().modify(|w| w.set_value(0, false));
    gpio.output().modify(|w| w.set_value(0, true));

    panic!();
}
