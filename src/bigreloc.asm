[bits 16]

reloc_count equ 300
hdr_bytes equ 0x001C + reloc_count * 4
hdr_size equ (hdr_bytes + 15) / 16

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
%rep reloc_count
    dw reloc_targets + i * 2 - image_start
    dw 0x0000
%assign i i + 1
%endrep
    times (hdr_size * 16) - ($ - mz_header) db 0

image_start:
    push cs
    pop ds
    mov bx, cs
    mov cx, reloc_count
    mov si, reloc_targets - image_start
.check_loop:
    lodsw
    cmp ax, bx
    jne .fail_reloc
    loop .check_loop

    mov ax, 0x3D00
    mov dx, testfile_name - image_start
    int 0x21
    jc .fail_open
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc .fail_close

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_reloc:
    mov dx, fail_reloc_msg - image_start
    jmp .print_fail
.fail_open:
    mov dx, fail_open_msg - image_start
    jmp .print_fail
.fail_close:
    mov dx, fail_close_msg - image_start
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

testfile_name: db "TESTFILE.DAT", 0
pass_msg: db "PASS: BIGRELOC", 13, 10, "$"
fail_reloc_msg: db "FAIL: BIGRELOC RELOC", 13, 10, "$"
fail_open_msg: db "FAIL: BIGRELOC OPEN", 13, 10, "$"
fail_close_msg: db "FAIL: BIGRELOC CLOSE", 13, 10, "$"

reloc_targets:
    times reloc_count dw 0x0000

file_end:
