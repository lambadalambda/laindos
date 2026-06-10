[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov ax, 0x4300
    int 0x2F
    cmp al, 0x80
    jne fail
    mov ax, 0x4310
    int 0x2F
    mov [xms_entry], bx
    mov [xms_entry+2], es
    mov ah, 0x09
    mov dx, 2048
    call far [xms_entry]
    cmp ax, 1
    jne fail
    mov dx, hold_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x3100
    mov dx, 0x0010
    int 0x21

fail:
    mov dx, fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

xms_entry: dd 0
hold_msg: db "XMSHOLD OK", 13, 10, "$"
fail_msg: db "FAIL: XMSHOLD", 13, 10, "$"
