[bits 16]
[org 0x0100]

    mov ah, 0x0B
    int 0x21
    cmp al, 0x00
    jne fail_status

    mov ah, 0x01
    int 0x16
    jnz fail_bios

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_status:
    mov dx, fail_status_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fail_bios:
    mov dx, fail_bios_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db "PASS: KEY", 13, 10, "$"
fail_status_msg: db "FAIL: KEY STATUS", 13, 10, "$"
fail_bios_msg: db "FAIL: BIOS KEY STATUS", 13, 10, "$"
