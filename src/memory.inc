%ifndef __MEMORY_INC__
%define __MEMORY_INC__
LOAD_SEG equ 0x1000
RELOC_SEG equ 0x0340
SECTOR_BUF_PARAS equ 0x20
SEC_BUF equ 0x0AC0
READ_CACHE_BUF equ (SEC_BUF + SECTOR_BUF_PARAS)
MCB_START equ 0x1000
MEM_TOP equ 0xA000
ENV_PARAS equ 16
ENV_OWNER_TEMP equ 0xFFFF
%if (MEM_TOP & 0xFF) != 0
%error "MEM_TOP must be 256-byte aligned"
%endif
MCB_SIG_M equ 'M'
MCB_SIG_Z equ 'Z'
%endif
