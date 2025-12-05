#![no_std]

pub mod gpio;
pub mod reg;
pub mod uart;

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    unsafe { riscv::asm::ebreak() }
    loop {}
}

#[unsafe(export_name = "_setup_interrupts")]
pub fn setup_interrupts() {}
