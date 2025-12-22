const BASE_ADDR: *mut u32 = 0x0300_0000 as _;

const REG_PASS: usize = 0x0;
const REG_FAIL: usize = 0x4;

pub fn set_pass() -> ! {
    unsafe { BASE_ADDR.byte_add(REG_PASS).write_volatile(0) };
    loop {
        riscv::asm::nop();
    }
}

pub fn set_fail() -> ! {
    unsafe { BASE_ADDR.byte_add(REG_FAIL).write_volatile(0) };
    loop {
        riscv::asm::nop();
    }
}
