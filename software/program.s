    .section .text
    .globl _start

_start:
    # Load immediate values into registers
    li x5, 10          # x5 = 10
    li x6, 20          # x6 = 20

    # Add them
    add x7, x5, x6     # x7 = x5 + x6 = 30
