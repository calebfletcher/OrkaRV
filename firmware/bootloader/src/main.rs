#![no_std]
#![no_main]

use riscv_rt::entry;

// need panic handler
use common as _;

#[unsafe(export_name = "_setup_interrupts")]
pub fn setup_interrupts() {}

#[entry]
fn main() -> ! {
    panic!();
}
