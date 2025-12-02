<!---
Markdown description for SystemRDL register map.

Don't override. Generated from: UartRegisters
  - ../peripherals/uart/hdl/registers.rdl
-->

## UartRegisters address map

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x10

<p>Basic UART, no flow control, fixed 1M baud, no FIFO.</p>

|Offset|Identifier|            Name            |
|------|----------|----------------------------|
|  0x0 |    rx    |  Receiver Buffer Register  |
|  0x4 |    tx    |Transmitter Holding Register|
|  0x8 |   ctrl   |      Control Register      |
|  0xC |  status  |       Status Register      |

### rx register

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
| 7:0|    rx    |   r  |  —  |  — |

### tx register

- Absolute Address: 0x4
- Base Offset: 0x4
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
| 7:0|    tx    |   w  | 0x0 |  — |

### ctrl register

- Absolute Address: 0x8
- Base Offset: 0x8
- Size: 0x4

|Bits|Identifier|Access|Reset|    Name    |
|----|----------|------|-----|------------|
|  0 |  enable  |  rw  | 0x1 |Enable TX/RX|

### status register

- Absolute Address: 0xC
- Base Offset: 0xC
- Size: 0x4

|Bits|Identifier|Access|Reset|     Name    |
|----|----------|------|-----|-------------|
|  0 |    rxr   |   r  |  —  |RX Data Ready|
|  1 |    txe   |   r  |  —  |   TX Empty  |
