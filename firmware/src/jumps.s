    .section .text
    .globl _start

_start:
    j bar
foo:
    j end
bar:
    j foo
end:
    ebreak
