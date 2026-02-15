<!---
Markdown description for SystemRDL register map.

Don't override. Generated from: ClintRegisters
  - ../peripherals/clint/hdl/registers.rdl
-->

## ClintRegisters address map

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0xC000

|Offset|Identifier|Name|
|------|----------|----|
|0x0000|   msip   |  — |
|0x4000| mtimecmp |  — |
|0x4004| mtimecmph|  — |
|0xBFF8|   mtime  |  — |
|0xBFFC|  mtimeh  |  — |

### msip register

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|  0 |   msip   |  rw  | 0x0 |  — |

### mtimecmp register

- Absolute Address: 0x4000
- Base Offset: 0x4000
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0| mtimecmp |  rw  | 0x0 |  — |

### mtimecmph register

- Absolute Address: 0x4004
- Base Offset: 0x4004
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0| mtimecmph|  rw  | 0x0 |  — |

### mtime register

- Absolute Address: 0xBFF8
- Base Offset: 0xBFF8
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|   mtime  |   r  |  —  |  — |

### mtimeh register

- Absolute Address: 0xBFFC
- Base Offset: 0xBFFC
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|  mtimeh  |   r  |  —  |  — |
