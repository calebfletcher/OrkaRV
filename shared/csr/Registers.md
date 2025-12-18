<!---
Markdown description for SystemRDL register map.

Don't override. Generated from: CsrRegisters
  - ../csr/hdl/registers.rdl
-->

## CsrRegisters address map

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0xC18

|Offset|Identifier|Name|
|------|----------|----|
| 0xC00|  mstatus |  — |
| 0xC04|   misa   |  — |
| 0xC10|    mie   |  — |
| 0xC14|   mtvec  |  — |

### mstatus register

- Absolute Address: 0xC00
- Base Offset: 0xC00
- Size: 0x4

| Bits|Identifier|Access|Reset|Name|
|-----|----------|------|-----|----|
|  1  |    sie   |  rw  |  —  |  — |
|  3  |    mie   |  rw  |  —  |  — |
|  5  |   spie   |  rw  |  —  |  — |
|  6  |    ube   |  rw  |  —  |  — |
|  7  |   mpie   |  rw  |  —  |  — |
|  8  |    spp   |  rw  |  —  |  — |
| 10:9|    vs    |  rw  |  —  |  — |
|12:11|    mpp   |  rw  |  —  |  — |
|14:13|    fs    |  rw  |  —  |  — |
|16:15|    xs    |  rw  |  —  |  — |
|  17 |   mprv   |  rw  |  —  |  — |
|  18 |    sum   |  rw  |  —  |  — |
|  19 |    mxr   |  rw  |  —  |  — |
|  20 |    tvm   |  rw  |  —  |  — |
|  21 |    tw    |  rw  |  —  |  — |
|  22 |    tsr   |  rw  |  —  |  — |
|  23 |   spelp  |  rw  |  —  |  — |
|  24 |    sdt   |  rw  |  —  |  — |
|  31 |    sd    |  rw  |  —  |  — |

### misa register

- Absolute Address: 0xC04
- Base Offset: 0xC04
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|   misa   |  rw  |  —  |  — |

### mie register

- Absolute Address: 0xC10
- Base Offset: 0xC10
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|    mie   |  rw  |  —  |  — |

### mtvec register

- Absolute Address: 0xC14
- Base Offset: 0xC14
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|   mtvec  |  rw  |  —  |  — |
