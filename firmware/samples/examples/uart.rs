#![no_std]
#![no_main]

use core::cell::RefCell;

use common::{debug, uart::Uart};
use critical_section::Mutex;
use heapless::Deque;
use riscv::interrupt::Interrupt::MachineExternal;
use riscv_rt::entry;

static UART_BUFFER: Mutex<RefCell<Deque<u8, 256>>> = Mutex::new(RefCell::new(Deque::new()));

static UART: Mutex<Uart> = Mutex::new(unsafe { Uart::from_ptr(0x0201_0000 as *mut _) });

#[riscv_rt::core_interrupt(MachineExternal)]
fn machine_external_interrupt() {
    critical_section::with(|cs| {
        let uart = UART.borrow(cs);
        let mut buffer = UART_BUFFER.borrow(cs).borrow_mut();

        // read from uart
        while uart.status().read().rxr() {
            let byte: u8 = uart.rx();
            let _ = buffer.push_back(byte);
        }
    });
}

#[entry]
fn main() -> ! {
    critical_section::with(|cs| {
        let uart = UART.borrow(cs);
        uart.ctrl().modify(|v| v.set_rxie(true));
    });

    unsafe { riscv::interrupt::enable_interrupt(MachineExternal) };
    unsafe { riscv::interrupt::enable() };

    loop {
        critical_section::with(|cs| {
            let uart = UART.borrow(cs);
            let mut bytes = UART_BUFFER.borrow(cs).borrow_mut();

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

                debug::set_pass();
            }
        });

        // wait
        riscv::asm::wfi();
    }
}
