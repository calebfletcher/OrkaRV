<!---
Markdown description for SystemRDL register map.

Don't override. Generated from: CsrRegisters
  - ../csr/hdl/registers.rdl
-->

## CsrRegisters address map

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x3C58

|Offset|Identifier|Name|
|------|----------|----|
|0x0C00|  mstatus |  — |
|0x0C04|   misa   |  — |
|0x0C08|  medeleg |  — |
|0x0C0C|  mideleg |  — |
|0x0C10|    mie   |  — |
|0x0C14|   mtvec  |  — |
|0x0C40| mstatush |  — |
|0x0C48| medelegh |  — |
|0x0D00| mscratch |  — |
|0x0D04|   mepc   |  — |
|0x0D08|  mcause  |  — |
|0x0D0C|   mtval  |  — |
|0x0D10|    mip   |  — |
|0x2C00|  mcycle  |  — |
|0x2E00|  mcycleh |  — |
|0x3004|   time   |  — |
|0x3204|   timeh  |  — |
|0x3C44| mvendorid|  — |
|0x3C48|  marchid |  — |
|0x3C4C|  mimpid  |  — |
|0x3C50|  mhartid |  — |
|0x3C54|mconfigptr|  — |

### mstatus register

- Absolute Address: 0xC00
- Base Offset: 0xC00
- Size: 0x4

| Bits|Identifier|Access|Reset|Name|
|-----|----------|------|-----|----|
|  1  |    sie   |  rw  | 0x0 |  — |
|  3  |    mie   |  rw  | 0x0 |  — |
|  5  |   spie   |  rw  | 0x0 |  — |
|  6  |    ube   |   r  | 0x0 |  — |
|  7  |   mpie   |  rw  | 0x0 |  — |
|  8  |    spp   |  rw  | 0x0 |  — |
| 10:9|    vs    |   r  | 0x0 |  — |
|12:11|    mpp   |  rw  | 0x0 |  — |
|14:13|    fs    |   r  | 0x0 |  — |
|16:15|    xs    |   r  | 0x0 |  — |
|  17 |   mprv   |   r  | 0x0 |  — |
|  18 |    sum   |   r  | 0x0 |  — |
|  19 |    mxr   |   r  | 0x0 |  — |
|  20 |    tvm   |   r  | 0x0 |  — |
|  21 |    tw    |   r  | 0x0 |  — |
|  22 |    tsr   |   r  | 0x0 |  — |
|  31 |    sd    |   r  | 0x0 |  — |

### misa register

- Absolute Address: 0xC04
- Base Offset: 0xC04
- Size: 0x4

| Bits|Identifier|Access|Reset|Name|
|-----|----------|------|-----|----|
|  0  |     a    |   r  | 0x0 |  — |
|  1  |     b    |   r  | 0x0 |  — |
|  2  |     c    |   r  | 0x0 |  — |
|  3  |     d    |   r  | 0x0 |  — |
|  4  |     e    |   r  | 0x0 |  — |
|  5  |     f    |   r  | 0x0 |  — |
|  7  |     h    |   r  | 0x0 |  — |
|  8  |     i    |   r  | 0x1 |  — |
|  12 |     m    |   r  | 0x0 |  — |
|  13 |     n    |   r  | 0x0 |  — |
|  15 |     p    |   r  | 0x0 |  — |
|  16 |     q    |   r  | 0x0 |  — |
|  18 |     s    |   r  | 0x0 |  — |
|  20 |     u    |   r  | 0x0 |  — |
|  21 |     v    |   r  | 0x0 |  — |
|  23 |     x    |   r  | 0x0 |  — |
|31:30|    mxl   |   r  | 0x1 |  — |

### medeleg register

- Absolute Address: 0xC08
- Base Offset: 0xC08
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|  medeleg |   r  | 0x0 |  — |

### mideleg register

- Absolute Address: 0xC0C
- Base Offset: 0xC0C
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|  mideleg |   r  | 0x0 |  — |

### mie register

- Absolute Address: 0xC10
- Base Offset: 0xC10
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|  1 |   ssie   |   r  | 0x0 |  — |
|  3 |   msie   |  rw  | 0x0 |  — |
|  5 |   stie   |   r  | 0x0 |  — |
|  7 |   mtie   |  rw  | 0x0 |  — |
|  9 |   seie   |   r  | 0x0 |  — |
| 11 |   meie   |  rw  | 0x0 |  — |

### mtvec register

- Absolute Address: 0xC14
- Base Offset: 0xC14
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
| 1:0|   mode   |  rw  | 0x0 |  — |
|31:2|   base   |  rw  | 0x0 |  — |

### mstatush register

- Absolute Address: 0xC40
- Base Offset: 0xC40
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|  4 |    sbe   |   r  | 0x0 |  — |
|  5 |    mbe   |   r  | 0x0 |  — |
|  6 |    gva   |  rw  | 0x0 |  — |
|  7 |    mpv   |  rw  | 0x0 |  — |
|  9 |   mpelp  |  rw  | 0x0 |  — |
| 10 |    mdt   |  rw  | 0x0 |  — |

### medelegh register

- Absolute Address: 0xC48
- Base Offset: 0xC48
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0| medelegh |   r  | 0x0 |  — |

### mscratch register

- Absolute Address: 0xD00
- Base Offset: 0xD00
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0| mscratch |  rw  | 0x0 |  — |

### mepc register

- Absolute Address: 0xD04
- Base Offset: 0xD04
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|   mepc   |  rw  | 0x0 |  — |

### mcause register

- Absolute Address: 0xD08
- Base Offset: 0xD08
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|30:0|   code   |  rw  | 0x0 |  — |
| 31 | interrupt|  rw  | 0x0 |  — |

### mtval register

- Absolute Address: 0xD0C
- Base Offset: 0xD0C
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|   mtval  |  rw  | 0x0 |  — |

### mip register

- Absolute Address: 0xD10
- Base Offset: 0xD10
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|  1 |   ssip   |   r  | 0x0 |  — |
|  3 |   msip   |   r  | 0x0 |  — |
|  5 |   stip   |   r  | 0x0 |  — |
|  7 |   mtip   |   r  | 0x0 |  — |
|  9 |   seip   |   r  | 0x0 |  — |
| 11 |   meip   |   r  | 0x0 |  — |

### mcycle register

- Absolute Address: 0x2C00
- Base Offset: 0x2C00
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|  mcycle  |   r  |  —  |  — |

### mcycleh register

- Absolute Address: 0x2E00
- Base Offset: 0x2E00
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|  mcycleh |   r  |  —  |  — |

### time register

- Absolute Address: 0x3004
- Base Offset: 0x3004
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|   time   |   r  |  —  |  — |

### timeh register

- Absolute Address: 0x3204
- Base Offset: 0x3204
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|   timeh  |   r  |  —  |  — |

### mvendorid register

- Absolute Address: 0x3C44
- Base Offset: 0x3C44
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
| 6:0|  offset  |   r  | 0x0 |  — |
|31:7|   bank   |   r  | 0x0 |  — |

### marchid register

- Absolute Address: 0x3C48
- Base Offset: 0x3C48
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|  marchid |   r  | 0x0 |  — |

### mimpid register

- Absolute Address: 0x3C4C
- Base Offset: 0x3C4C
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|  mimpid  |   r  | 0x0 |  — |

### mhartid register

- Absolute Address: 0x3C50
- Base Offset: 0x3C50
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|  mhartid |   r  | 0x0 |  — |

### mconfigptr register

- Absolute Address: 0x3C54
- Base Offset: 0x3C54
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|mconfigptr|   r  | 0x0 |  — |
