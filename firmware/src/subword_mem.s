    .section .text
    .globl _start

_start:
    la x1, val1
    lb x2, 0(x1)
    lb x2, 1(x1)
    lb x2, 2(x1)
    lb x2, 3(x1)
    lh x2, 0(x1)
    lh x2, 2(x1)

    li x3, 0x55
    sb x3, 0(x1)
    sb x3, 1(x1)
    sb x3, 2(x1)
    sb x3, 3(x1)
    li x3, 0xAAAA
    sh x3, 0(x1)
    sh x3, 2(x1)
    li x3, 0xAAAABBBB
    sw x3, 0(x1)

    ebreak

    .section .data
val1: .word 0x12345678
