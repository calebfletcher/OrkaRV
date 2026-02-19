#![no_std]
#![no_main]

use core::fmt::Write as _;

use common::uart::Uart;
use heapless::{String, Vec};
use riscv_rt::entry;

macro_rules! println {
    ($uart:expr, $dst:expr, $($arg:tt)*) => {
        writeln!($dst, $($arg)*).unwrap();
        for byte in $dst.as_bytes() {
            $uart.write(*byte);
        }
        $dst.clear();
    };
}

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
        let line = core::str::from_utf8(&buffer).unwrap().trim();

        handle_line(uart, &mut resp, line);

        println!(uart, &mut resp, "ok");
    }
}

fn handle_line(uart: Uart, resp: &mut String<64>, line: &str) {
    // split into parts
    let parts = line.split(' ').collect::<heapless::Vec<_, 8>>();

    match &*parts {
        ["ping"] => {
            println!(uart, resp, "pong");
        }
        ["time"] => {
            let time = riscv::register::time::read64();
            let ms = time / 100_000;
            println!(uart, resp, "{ms} ms since boot");
        }
        ["read", addr] => {
            let addr = parse_hex(addr);
            let ptr = addr as *const u32;
            let value = unsafe { ptr.read_volatile() };
            println!(uart, resp, "read from {addr:#010x}: {value:#010x}");
        }
        ["write", addr, value] => {
            let addr = parse_hex(addr);
            let value = parse_hex(value);
            let ptr = addr as *mut u32;
            unsafe { ptr.write_volatile(value) };
            println!(uart, resp, "wrote to {addr:#010x}");
        }
        _ => {
            println!(uart, resp, "unknown command");
        }
    }
}

fn parse_hex(value: &str) -> u32 {
    let value = value.strip_prefix("0x").unwrap_or(value);
    let v2 = value
        .chars()
        .filter(|v| v.is_ascii_alphanumeric())
        .collect::<String<16>>();
    u32::from_str_radix(&v2, 16).unwrap()
}
