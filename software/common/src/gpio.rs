use crate::reg::{R, RW, Reg};
use bit_field::BitField;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Direction {
    Input,
    Output,
}

const REG_DIRECTION: usize = 0x0;
const REG_OUTPUT: usize = 0x4;
const REG_INPUT: usize = 0x8;

#[derive(Clone, Copy)]
pub struct Gpio {
    ptr: *mut (),
}

impl Gpio {
    /// Claim an address as a GPIO peripheral instance
    ///
    /// # Safety
    /// Base address must be valid and only claimed once.
    pub const unsafe fn from_ptr(ptr: *mut ()) -> Self {
        Self { ptr }
    }

    pub fn direction(self) -> Reg<Dir, RW> {
        unsafe { Reg::from_ptr(self.ptr.byte_add(REG_DIRECTION) as *mut _) }
    }

    pub fn output(self) -> Reg<Output, RW> {
        unsafe { Reg::from_ptr(self.ptr.byte_add(REG_OUTPUT) as *mut _) }
    }

    pub fn input(self) -> Reg<Input, R> {
        unsafe { Reg::from_ptr(self.ptr.byte_add(REG_INPUT) as *mut _) }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Dir(pub u32);

impl Dir {
    pub fn dir(&self, n: usize) -> Direction {
        if self.0.get_bit(n) {
            Direction::Input
        } else {
            Direction::Output
        }
    }

    pub fn set_dir(&mut self, n: usize, dir: Direction) {
        self.0.set_bit(n, dir == Direction::Input);
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Output(pub u32);

impl Output {
    pub fn value(&self, n: usize) -> bool {
        self.0.get_bit(n)
    }

    pub fn set_value(&mut self, n: usize, value: bool) {
        self.0.set_bit(n, value);
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Input(pub u32);

impl Input {
    pub fn value(&self, n: usize) -> bool {
        self.0.get_bit(n)
    }
}
