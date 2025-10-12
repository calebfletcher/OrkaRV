    .section .text
    .globl _start

_start:
    la x1, 0x12345678
    lw x2, 0(x1)
    li x3, 0xdeadbeef
    sw x2, 0(x3)

    ebreak