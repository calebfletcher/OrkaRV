import time
import serial
from crc import Calculator, Crc32
import sys

HAS_RESET = False
    
def send_file(ser: serial.Serial):
    with open("../target/riscv32i-unknown-none-elf/release/bootloader", 'rb') as elf_file:
        contents = elf_file.read()

    uncompressed_size = len(contents)

    calculator = Calculator(Crc32.CRC32)
    checksum: int = calculator.checksum(contents)

    print(uncompressed_size, checksum)

    ser.write(b"upload\n")

    ser.write(uncompressed_size.to_bytes(4, "little"))
    ser.write(checksum.to_bytes(4, "little"))


if __name__ == "__main__":
    ser = serial.Serial(sys.argv[1], timeout=3)

    if HAS_RESET:
        ser.dtr = False
        # sleep for 10ms to make sure the cpu is reset
        time.sleep(10e-3)
        ser.dtr = True

        # wait for the bootloader to start up
        line = ser.readline()
        if not line:
            raise RuntimeError("bootloader not initialised")
        assert b"bootloader running" in line, f"received: {line}"
    send_file(ser)

