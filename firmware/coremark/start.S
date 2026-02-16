    .section .text.start
    .globl _start
    .type _start, @function
_start:
    /* set stack pointer from linker script symbol */
    la   sp, _sp

    /* optional: clear .bss (recommended) */
    la   t0, _sbss
    la   t1, _ebss
1:
    bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:
    /* jump into C */
    call main

    /* if main returns, hang */
3:
    j 3b