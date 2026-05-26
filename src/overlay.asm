[bits 16]

reloc_count equ 140
tail_pad equ 300
append_bytes equ 0xFF00
hdr_bytes equ 0x001C + reloc_count * 4
hdr_size equ (hdr_bytes + 15) / 16

mz_header:
    dw 0x5A4D
    dw (mz_image_end - mz_header) % 512
    dw ((mz_image_end - mz_header) + 511) / 512
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
    times tail_pad db 0xAA
tail_marker:
    dw 0xCAFE

mz_image_end:
    times append_bytes db 0
file_end:
