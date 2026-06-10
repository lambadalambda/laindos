%ifndef __MEMORY_INC__
%define __MEMORY_INC__
LOAD_SEG equ 0x1000
HMA_SEG equ 0xFFFF
HMA_OFF equ 0x0010
ENTRY_SEG equ (LOAD_SEG - 1)
SECTOR_BUF_PARAS equ 0x20
CD_BUF_PARAS equ 0x80
CD_BUF equ 0x0180
SEC_BUF equ 0x0200
READ_CACHE_BUF equ (SEC_BUF + SECTOR_BUF_PARAS)
MCB_START equ 0x0640
MEM_TOP equ 0xA000
ENV_PARAS equ 16
ENV_SIZE_BYTES equ (ENV_PARAS * 16)
ENV_OWNER_TEMP equ 0xFFFF
%if (MEM_TOP & 0xFF) != 0
%error "MEM_TOP must be 256-byte aligned"
%endif
MCB_SIG_M equ 'M'
MCB_SIG_Z equ 'Z'
%macro MCB_IS_VALID 0
    cmp byte [ds:0], MCB_SIG_M
    je %%mcb_ok
    cmp byte [ds:0], MCB_SIG_Z
    jne %%mcb_fail
%%mcb_ok:
%%mcb_fail:
%endmacro
%endif
