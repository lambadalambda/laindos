[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, ready_msg
    mov ah, 0x09
    int 0x21

    call wait_ticks


    mov ax, 0x0C01
    int 0x21
    cmp al, 'y'
    jne fail_flush_read

    mov ah, 0x0B
    int 0x21
    test al, al
    jnz fail_status

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

wait_ticks:
    push ax
    push bx
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov bx, [0x006C]
.loop:
    mov ax, [0x006C]
    sub ax, bx
    cmp ax, 18
    jb .loop
    pop ds
    pop bx
    pop ax
    ret

fail_flush_read:
    mov dx, fail_flush_read_msg
    jmp fail
fail_status:
    mov dx, fail_status_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

ready_msg: db "READY: FLUSHREAD", 13, 10, "$"
pass_msg: db "PASS: FLUSHREAD", 13, 10, "$"
fail_flush_read_msg: db "FAIL: FLUSHREAD CHAR", 13, 10, "$"
fail_status_msg: db "FAIL: FLUSHREAD STATUS", 13, 10, "$"
