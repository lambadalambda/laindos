[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, nul_ext_name
    mov ax, 0x3D01
    int 0x21
    jc fail_nul_open
    mov [handle], ax
    mov bx, ax
    mov dx, payload
    mov cx, payload_len
    mov ah, 0x40
    int 0x21
    jc fail_nul_write
    cmp ax, payload_len
    jne fail_nul_write
    call close_handle

    mov dx, nul_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_nul_create
    mov [handle], ax
    mov bx, ax
    mov dx, payload
    mov cx, payload_len
    mov ah, 0x40
    int 0x21
    jc fail_nul_write
    cmp ax, payload_len
    jne fail_nul_write
    call close_handle

    mov dx, nul_name
    mov ax, 0x3D00
    int 0x21
    jc fail_nul_open
    mov [handle], ax
    mov bx, ax
    mov dx, buf
    mov cx, 4
    mov ah, 0x3F
    int 0x21
    jc fail_nul_read
    test ax, ax
    jne fail_nul_read
    call close_handle

    mov dx, con_ext_name
    mov ax, 0x3D01
    int 0x21
    jc fail_con_open
    mov [handle], ax
    mov bx, ax
    mov dx, con_write_msg
    mov cx, con_write_len
    mov ah, 0x40
    int 0x21
    jc fail_con_write
    cmp ax, con_write_len
    jne fail_con_write
    call close_handle

    mov dx, con_name
    mov ax, 0x3D00
    int 0x21
    jc fail_con_open
    mov [handle], ax
    mov dx, ready_msg
    mov ah, 0x09
    int 0x21
    mov bx, [handle]
    mov dx, buf
    mov cx, 1
    mov ah, 0x3F
    int 0x21
    jc fail_con_read
    cmp ax, 1
    jne fail_con_read
    call close_handle

    mov dx, prn_name
    mov ax, 0x3D01
    int 0x21
    jnc fail_prn
    cmp ax, 5
    jne fail_prn

    mov dx, aux_name
    mov ax, 0x3D00
    int 0x21
    jnc fail_aux
    cmp ax, 5
    jne fail_aux

    mov dx, real_name
    mov ax, 0x3D00
    int 0x21
    jc fail_real
    mov [handle], ax
    mov bx, ax
    mov dx, buf
    mov cx, 4
    mov ah, 0x3F
    int 0x21
    jc fail_real
    cmp ax, 4
    jne fail_real
    cmp byte [buf], 'R'
    jne fail_real
    cmp byte [buf+1], 'E'
    jne fail_real
    cmp byte [buf+2], 'A'
    jne fail_real
    cmp byte [buf+3], 'L'
    jne fail_real
    call close_handle

    mov dx, nul_name
    mov ax, 0x3D00
    int 0x21
    jc fail_nul_open
    mov [handle], ax
    mov bx, ax
    mov dx, buf
    mov cx, 4
    mov ah, 0x3F
    int 0x21
    jc fail_nul_read
    test ax, ax
    jne fail_nul_read
    call close_handle

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

close_handle:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    ret

fail_nul_open:
    mov dx, fail_nul_open_msg
    jmp fail
fail_nul_write:
    mov dx, fail_nul_write_msg
    jmp fail
fail_nul_create:
    mov dx, fail_nul_create_msg
    jmp fail
fail_nul_read:
    mov dx, fail_nul_read_msg
    jmp fail
fail_con_open:
    mov dx, fail_con_open_msg
    jmp fail
fail_con_write:
    mov dx, fail_con_write_msg
    jmp fail
fail_con_read:
    mov dx, fail_con_read_msg
    jmp fail
fail_prn:
    mov dx, fail_prn_msg
    jmp fail
fail_aux:
    mov dx, fail_aux_msg
    jmp fail
fail_real:
    mov dx, fail_real_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

nul_ext_name: db "nUl.TxT", 0
nul_name: db "NUL", 0
con_ext_name: db "cOn.any", 0
con_name: db "CON", 0
prn_name: db "PRN", 0
aux_name: db "AUX", 0
real_name: db "NULFILE.DAT", 0
payload: db "discarded"
payload_len equ $ - payload
con_write_msg: db "PASS: CONWRITE", 13, 10
con_write_len equ $ - con_write_msg
ready_msg: db "READY: DEVREAD", 13, 10, "$"
pass_msg: db "PASS: DEVNAMES", 13, 10, "$"
fail_nul_open_msg: db "FAIL: DEVNAMES NUL OPEN", 13, 10, "$"
fail_nul_write_msg: db "FAIL: DEVNAMES NUL WRITE", 13, 10, "$"
fail_nul_create_msg: db "FAIL: DEVNAMES NUL CREATE", 13, 10, "$"
fail_nul_read_msg: db "FAIL: DEVNAMES NUL READ", 13, 10, "$"
fail_con_open_msg: db "FAIL: DEVNAMES CON OPEN", 13, 10, "$"
fail_con_write_msg: db "FAIL: DEVNAMES CON WRITE", 13, 10, "$"
fail_con_read_msg: db "FAIL: DEVNAMES CON READ", 13, 10, "$"
fail_prn_msg: db "FAIL: DEVNAMES PRN", 13, 10, "$"
fail_aux_msg: db "FAIL: DEVNAMES AUX", 13, 10, "$"
fail_real_msg: db "FAIL: DEVNAMES REAL", 13, 10, "$"
handle: dw 0
buf: times 8 db 0
