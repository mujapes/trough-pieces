/* A piece as one flat, position-independent blob: code first, then its constants. No writable data. */
SECTIONS {
  . = 0;
  .text : { *(.text*) }
  . = ALIGN(8);
  .rodata : { *(.rodata*) *(.srodata*) *(.literal*) }
  .data : { *(.data*) *(.sdata*) }
  .bss : { *(.bss*) *(COMMON) }
  /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) *(.ARM.*) *(.gnu*) }
}
