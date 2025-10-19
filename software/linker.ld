STACK_SIZE = 0x100;

ENTRY(entry)

SECTIONS {
  .text : { *(.text); *(.text.*); }
  .rodata : { *(.rodata); *(.rodata.*); }
  .bss :
  {
    . = ALIGN(4);
    _sbss = .;
    *(.bss .bss.*)
    . = ALIGN(4);
    _ebss = .;
  }
  .data : {
    . = ALIGN(4);
    _sdata = .;
    *(.data .data.*);
    _edata = .;
    . = ALIGN(4);
  }
  .stack :
  {
    . = ALIGN(4);
    . = . + STACK_SIZE;
    _sp = .;
    . = ALIGN(4);
  }
}
