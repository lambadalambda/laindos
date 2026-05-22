[bits 16]

reloc_count equ 140
hdr_bytes equ 0x001C + reloc_count * 4
hdr_size equ (hdr_bytes + 15) / 16

mz_header:
    dw 0x5A4D
    dw (file_end - mz_header) % 512
    dw ((file_end - mz_header) + 511) / 512
    dw reloc_count
    dw hdr_size
    dw 0x0000
    dw 0xFFFF
    dw 0x0000
    dw 0x0000
    dw 0x0000
    dw 0x0000
    dw 0x0000
    dw 0x001C
    dw 0x0000

reloc_table:
%assign i 0
%rep reloc_count
    dw reloc_targets + i * 2 - image_start
    dw 0x0000
%assign i i + 1
%endrep
    times (hdr_size * 16) - ($ - mz_header) db 0

image_start:
marker:
    dw 0xBEEF
reloc_targets:
    times reloc_count dw 0x0000

file_end:
