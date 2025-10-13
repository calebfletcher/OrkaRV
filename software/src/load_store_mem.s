    .section .text
    .globl _start

_start:
    la x1, val1
    lw x2, 0(x1)
    la x3, val2
    sw x2, 0(x3)

    ebreak

    .section .data
val1: .word 0x12345678
val2: .word 0xdeadbeef
val3: .word 0x01010202
