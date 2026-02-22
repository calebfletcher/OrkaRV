pub struct MemIo<'a> {
    buf: &'a mut [u8],
    pos: usize,
}

impl<'a> MemIo<'a> {
    /// # Safety
    /// Caller must provide a valid, uniquely owned memory region.
    pub unsafe fn from_raw_parts(ptr: *mut u8, len: usize) -> Self {
        let buf = unsafe { core::slice::from_raw_parts_mut(ptr, len) };
        Self { buf, pos: 0 }
    }

    fn remaining(&self) -> usize {
        self.buf.len().saturating_sub(self.pos)
    }
}

impl xmodem::io::Read for MemIo<'_> {
    fn read(&mut self, buf: &mut [u8]) -> xmodem::io::Result<usize> {
        let available = self.remaining();
        if available == 0 {
            return Ok(0);
        }
        let count = available.min(buf.len());
        let end = self.pos + count;
        buf[..count].copy_from_slice(&self.buf[self.pos..end]);
        self.pos = end;
        Ok(count)
    }

    fn read_exact(&mut self, buf: &mut [u8]) -> xmodem::io::Result<()> {
        if self.remaining() < buf.len() {
            return Err(xmodem::io::Error::new(
                xmodem::io::ErrorKind::Other,
                "short read",
            ));
        }
        let end = self.pos + buf.len();
        buf.copy_from_slice(&self.buf[self.pos..end]);
        self.pos = end;
        Ok(())
    }
}

impl xmodem::io::Write for MemIo<'_> {
    fn flush(&mut self) -> xmodem::io::Result<()> {
        Ok(())
    }

    fn write(&mut self, buf: &[u8]) -> xmodem::io::Result<usize> {
        let available = self.remaining();
        if available == 0 {
            return Ok(0);
        }
        let count = available.min(buf.len());
        let end = self.pos + count;
        self.buf[self.pos..end].copy_from_slice(&buf[..count]);
        self.pos = end;
        Ok(count)
    }

    fn write_all(&mut self, buf: &[u8]) -> xmodem::io::Result<()> {
        if self.remaining() < buf.len() {
            return Err(xmodem::io::Error::new(
                xmodem::io::ErrorKind::Other,
                "short write",
            ));
        }
        let end = self.pos + buf.len();
        self.buf[self.pos..end].copy_from_slice(buf);
        self.pos = end;
        Ok(())
    }
}
