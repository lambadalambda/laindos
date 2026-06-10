[bits 16]

; EXE with relocation targets beyond the first 64K of the image, encoded the
; way real linkers do it (table-entry segment > 0x1000, small offset), plus
; maxalloc=0xFFFF so the program block spans all free memory like MONKEY2.

low_count equ 432
high_count equ 432
reloc_count equ low_count + high_count
hdr_size equ 0x00E0

mz_header:
    dw 0x5A4D
    dw (file_end - mz_header) % 512
    dw ((file_end - mz_header) + 511) / 512
    dw reloc_count
    dw hdr_size
    dw 0x0010
    dw 0xFFFF
    dw 0x0000
    dw 0xFFFE
    dw 0x0000
    dw 0x0000
    dw 0x0000
    dw 0x001C
    dw 0x0000

reloc_table:
%assign i 0
%rep low_count
    dw (low_targets + i * 2 - image_start) & 0xF
    dw (low_targets + i * 2 - image_start) >> 4
%assign i i + 1
%endrep
%assign i 0
%rep high_count
    dw (high_targets + i * 2 - image_start) & 0xF
    dw (high_targets + i * 2 - image_start) >> 4
%assign i i + 1
%endrep
    times (hdr_size * 16) - ($ - mz_header) db 0

image_start:
    push cs
    pop ds
    mov bx, cs

    mov cx, low_count
    mov si, low_targets - image_start
.check_low:
    lodsw
    cmp ax, bx
    jne fail_low
    loop .check_low

    mov ax, cs
    add ax, 0x1000
    mov es, ax
    xor di, di
    mov cx, high_count
.check_high:
    mov ax, [es:di]
    cmp ax, bx
    jne fail_high
    add di, 2
    loop .check_high

    mov dx, ok_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_low:
    mov dx, fail_low_msg
    jmp fail
fail_high:
    mov dx, fail_high_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

ok_msg: db 'PASS: BIGRELHI', 13, 10, '$'
fail_low_msg: db 'FAIL: BIGRELHI LOW', 13, 10, '$'
fail_high_msg: db 'FAIL: BIGRELHI HIGH', 13, 10, '$'

low_targets:
    times low_count dw 0

    times (image_start + 0x10000) - $ db 0
high_targets:
    times high_count dw 0
file_end:
