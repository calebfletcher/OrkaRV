<!---
Markdown description for SystemRDL register map.

Don't override. Generated from: GpioRegisters
  - ../peripherals/gpio/hdl/registers.rdl
-->

## GpioRegisters address map

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0xC

|Offset|Identifier|    Name   |
|------|----------|-----------|
|  0x0 | direction| Direction |
|  0x4 |  output  |Output Data|
|  0x8 |   input  | Input Data|

### direction register

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x4

<p>For each pin, a value of 0 corresponds to input, and 1 corresponds to output.</p>

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0| direction|  rw  | 0x0 |  — |

### output register

- Absolute Address: 0x4
- Base Offset: 0x4
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|  output  |  rw  | 0x0 |  — |

### input register

- Absolute Address: 0x8
- Base Offset: 0x8
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|   input  |   r  | 0x0 |  — |
