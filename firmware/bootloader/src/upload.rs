use std::time::Duration;

const CRC: crc::Crc<u32> = crc::Crc::<u32>::new(&crc::CRC_32_ISO_HDLC);

fn main() {
    let (mut port_a, port_b) = serial2::SerialPort::pair().unwrap();

    // Parse debug string to extract fd
    let debug_str_b = format!("{:?}", port_b);
    let fd_b = debug_str_b
        .split("fd:")
        .nth(1)
        .and_then(|s| {
            let trimmed = s.trim().trim_end_matches(',').trim_end_matches('}').trim();
            println!("Extracted B: {:?}", trimmed);
            trimmed.split_whitespace().next()?.parse::<i32>().ok()
        })
        .expect("Failed to parse fd from debug string B");
    let path_b =
        std::fs::read_link(format!("/proc/self/fd/{}", fd_b)).expect("Failed to read fd link");
    println!("port_b (fd {}): {:?}", fd_b, path_b);

    port_a.set_read_timeout(Duration::from_secs(30)).unwrap();

    let mut line = Vec::new();
    let mut byte = 0;
    loop {
        let count = port_a.read(std::slice::from_mut(&mut byte)).unwrap();
        if count == 0 {
            panic!("stream ended?");
        }
        if byte == b'\n' {
            // end of line
            break;
        }
        line.push(byte);
    }
    let line = std::str::from_utf8(&line).unwrap();

    println!("received message: {line}");

    if line.starts_with("upload") {
        let mut buffer = [0; 4];

        port_a.read_exact(&mut buffer).unwrap();
        let uncompressed_size = u32::from_le_bytes(buffer);

        assert!(uncompressed_size < 1_000_000);

        let mut uncompressed_data = vec![0; uncompressed_size as usize];
        port_a.read_exact(&mut uncompressed_data).unwrap();

        port_a.read_exact(&mut buffer).unwrap();
        let crc = u32::from_le_bytes(buffer);

        let calc_crc = CRC.checksum(&uncompressed_data);
        if calc_crc == crc {
            println!("CRC matches")
        } else {
            println!("CRC does not match")
        }
    }
}
