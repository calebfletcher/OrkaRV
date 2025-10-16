#![no_std]
#![no_main]

use core::{arch::asm, panic::PanicInfo};

static RODATA: &[u8] = b"Hello, world!";
static mut BSS: [u8; 16] = [0; 16];
static mut DATA: u16 = 1;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    unsafe { asm!("ebreak") }
    loop {}
}

#[allow(static_mut_refs)]
#[unsafe(no_mangle)]
//#[unsafe(link_section = ".entry")]
pub extern "C" fn _start() -> ! {
    let _x = RODATA;
    let _y = unsafe { &BSS };
    let _z = unsafe { &DATA };
    math();
    panic!();
}

fn math() -> u32 {
    let a: i32 = 12345;
    let b: i32 = -6789;
    let mut c: i32;
    let mut f: f32 = 1.5;
    let mut g: f32 = -2.25;

    // Basic arithmetic
    c = a + b;
    c = c.wrapping_mul(3);
    c /= 7;
    c %= 5;

    // Bitwise
    c ^= 0x55AA;
    c |= 0x0F0F;
    c &= 0xFFFF;
    c = c.rotate_left(3);
    c = c.rotate_right(1);

    // Logical tests
    let lt = (a < b) as i32;
    let eq = (a == b) as i32;

    // Shifts
    let shl = (a << 3) ^ (b >> 2);

    // Mix signed/unsigned math
    let ua: u32 = a as u32;
    let ub: u32 = b as u32;
    let ures = ua.wrapping_add(ub).wrapping_mul(ua ^ ub);

    // Floating-point arithmetic
    f = f * g + core::f32::consts::PI;
    f /= 1.25;
    g = g * -0.5 + f;

    // Combine results into one checksum-like value
    let mix = (c as i64)
        ^ ((lt as i64) << 8)
        ^ ((eq as i64) << 9)
        ^ ((shl as i64) << 10)
        ^ ((ures as i64) << 16)
        ^ ((f.to_bits() as i64) << 32)
        ^ ((g.to_bits() as i64) << 40);

    let mix = mix as u64;
    (mix & 0xFFFFFFFF) as u32 + (mix >> 32) as u32
}
