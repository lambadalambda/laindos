%ifndef __MEMORY_INC__
%define __MEMORY_INC__
LOAD_SEG equ 0x1000
RELOC_SEG equ 0x0340
SEC_BUF equ 0x0920
ENV_SEG equ 0x0940
MCB_START equ 0x1000
MEM_TOP equ 0xA000
%if (MEM_TOP & 0xFF) != 0
%error "MEM_TOP must be 256-byte aligned"
%endif
MCB_SIG_M equ 'M'
MCB_SIG_Z equ 'Z'
%endif
