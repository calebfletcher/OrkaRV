#![no_std]
#![no_main]

use core::fmt::Write as _;

use common::uart::{UART_ADDR, Uart};
use heapless::{String, Vec};
use riscv_rt::entry;
use xmodem::Xmodem;

use crate::memio::MemIo;

mod memio;

unsafe extern "C" {
    static mut _app_start: u32;
    static _app_size: u32;
}

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
    let uart = unsafe { Uart::from_ptr(UART_ADDR as *mut _) };

    // print results to uart
    let mut buffer = Vec::<u8, 64>::new();
    let mut resp = String::<64>::new();

    println!(uart, resp, "bootloader running");

    loop {
        // read line from uart
        buffer.clear();
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

fn handle_line(mut uart: Uart, resp: &mut String<64>, line: &str) {
    // split into parts
    let mut parts = heapless::Vec::<_, 8>::new();
    for part in line.split(' ') {
        if parts.push(part).is_err() {
            println!(uart, resp, "too many parts, truncating");
            break;
        }
    }

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
        ["mem"] => {
            println!(uart, resp, "Memory Stats");

            let app_start = &raw mut _app_start as usize;
            let app_size = &raw const _app_size as usize;

            println!(
                uart,
                resp, "App Region - {app_start:#08X} with length {app_size:#08X}"
            );
        }
        ["upload"] => {
            let mut xmodem = Xmodem::new();

            let app_start = &raw mut _app_start as *mut u8;
            let app_size = &raw const _app_size as usize;
            let mut app_mem = unsafe { MemIo::from_raw_parts(app_start, app_size) };

            let size = xmodem
                .recv(&mut uart, &mut app_mem, xmodem::Checksum::CRC16)
                .unwrap();

            println!(uart, resp, "received file of {size} bytes");
        }
        [] => {}
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
