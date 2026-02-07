use crate::reg::{R, RW, Reg};
use bit_field::BitField;

const REG_RX: usize = 0x0;
const REG_TX: usize = 0x4;
const REG_CTRL: usize = 0x8;
const REG_STATUS: usize = 0xC;

#[derive(Clone, Copy)]
pub struct Uart {
    ptr: *mut (),
}

unsafe impl Send for Uart {}

impl Uart {
    /// Claim an address as a UART peripheral instance
    ///
    /// # Safety
    /// Base address must be valid and only claimed once.
    pub const unsafe fn from_ptr(ptr: *mut ()) -> Self {
        Self { ptr }
    }

    pub fn rx(self) -> u8 {
        unsafe { self.ptr.byte_add(REG_RX).cast::<u8>().read_volatile() }
    }

    pub fn tx(self, byte: u8) {
        unsafe { self.ptr.byte_add(REG_TX).cast::<u8>().write_volatile(byte) }
    }

    pub fn ctrl(self) -> Reg<Ctrl, RW> {
        unsafe { Reg::from_ptr(self.ptr.byte_add(REG_CTRL) as *mut _) }
    }

    pub fn status(self) -> Reg<Status, R> {
        unsafe { Reg::from_ptr(self.ptr.byte_add(REG_STATUS) as *mut _) }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Ctrl(pub u32);

impl Ctrl {
    pub fn rxie(&self) -> bool {
        self.0.get_bit(0)
    }

    pub fn set_rxie(&mut self, value: bool) {
        self.0.set_bit(0, value);
    }

    pub fn txie(&self) -> bool {
        self.0.get_bit(1)
    }

    pub fn set_txie(&mut self, value: bool) {
        self.0.set_bit(1, value);
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Status(pub u32);

impl Status {
    pub fn rxr(&self) -> bool {
        self.0.get_bit(0)
    }

    pub fn txe(&self) -> bool {
        self.0.get_bit(1)
    }
}
