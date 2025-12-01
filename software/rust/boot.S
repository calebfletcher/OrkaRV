.text
    .global _start

_start:
    la sp, _sp

    la t0, _sbss # t0 = _sbss
    la t1, _ebss # t1 = _ebss

    # TODO: copy .data

loop:
    sw zero, (t0)
    addi t0, t0, 4
    blt t0, t1, loop

    j main