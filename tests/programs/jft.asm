[bits 16]
[org 0x0100]

MAX_HANDLES equ 20

start:
    push cs
    pop ds
    mov ah, 0x62
    int 0x21
    mov [psp_seg], bx
    mov es, bx

    cmp word [es:0x32], MAX_HANDLES
    jne fail_init
    cmp word [es:0x34], 0x0018
    jne fail_init
    cmp word [es:0x36], bx
    jne fail_init
    cmp byte [es:0x18], 0
    jne fail_init
    cmp byte [es:0x19], 1
    jne fail_init
    cmp byte [es:0x1A], 2
    jne fail_init
    cmp byte [es:0x1B], 3
    jne fail_init
    cmp byte [es:0x1C], 4
    jne fail_init
    cmp byte [es:0x1D], 0xFF
    jne fail_init

    push cs
    pop ds
    mov dx, data_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    cmp ax, 5
    jne fail_open
    mov [h1], ax
    mov es, [psp_seg]
    cmp byte [es:0x1D], 5
    jne fail_open

    mov bx, [h1]
    mov ah, 0x45
    int 0x21
    jc fail_dup
    cmp ax, 6
    jne fail_dup
    mov [h2], ax
    mov es, [psp_seg]
    cmp byte [es:0x1E], 6
    jne fail_dup

    mov bx, [h2]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    mov es, [psp_seg]
    cmp byte [es:0x1E], 0xFF
    jne fail_close

    mov bx, [h1]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    mov es, [psp_seg]
    cmp byte [es:0x1D], 0xFF
    jne fail_close

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_init:
    mov dx, fail_init_msg
    jmp fail
fail_open:
    push cs
    pop ds
    mov dx, fail_open_msg
    jmp fail
fail_dup:
    push cs
    pop ds
    mov dx, fail_dup_msg
    jmp fail
fail_close:
    push cs
    pop ds
    mov dx, fail_close_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

data_name: db "JFTDATA.TXT", 0
h1: dw 0
h2: dw 0
psp_seg: dw 0
pass_msg: db "PASS: JFT", 13, 10, "$"
fail_init_msg: db "FAIL: JFT INIT", 13, 10, "$"
fail_open_msg: db "FAIL: JFT OPEN", 13, 10, "$"
fail_dup_msg: db "FAIL: JFT DUP", 13, 10, "$"
fail_close_msg: db "FAIL: JFT CLOSE", 13, 10, "$"
