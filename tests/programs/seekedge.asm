[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, filename
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, [handle]
    xor cx, cx
    mov dx, 2
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    cmp ax, 2
    jne fail_seek
    cmp dx, 0
    jne fail_seek
    call read_one
    cmp byte [buf], 'C'
    jne fail_data

    mov bx, [handle]
    xor cx, cx
    mov dx, 1
    mov ax, 0x4201
    int 0x21
    jc fail_seek
    cmp ax, 4
    jne fail_seek
    cmp dx, 0
    jne fail_seek
    call read_one
    cmp byte [buf], 'E'
    jne fail_data

    mov bx, [handle]
    mov cx, 0xFFFF
    mov dx, 0xFFFE
    mov ax, 0x4202
    int 0x21
    jc fail_seek
    cmp ax, 3
    jne fail_seek
    cmp dx, 0
    jne fail_seek
    call read_one
    cmp byte [buf], 'D'
    jne fail_data

    mov bx, [handle]
    xor cx, cx
    mov dx, 8
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    cmp ax, 8
    jne fail_seek
    cmp dx, 0
    jne fail_seek

    mov bx, [handle]
    mov dx, buf
    mov cx, 1
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 0
    jne fail_read

    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4203
    int 0x21
    jnc fail_bad_origin
    cmp ax, 1
    jne fail_bad_origin

    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4201
    int 0x21
    jc fail_seek
    cmp ax, 8
    jne fail_bad_origin
    cmp dx, 0
    jne fail_bad_origin

    mov bx, 19
    xor cx, cx
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    jnc fail_bad_handle
    cmp ax, 6
    jne fail_bad_handle

    mov bx, 0x00FE
    xor cx, cx
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    jnc fail_bad_handle
    cmp ax, 6
    jne fail_bad_handle

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

read_one:
    mov bx, [handle]
    mov dx, buf
    mov cx, 1
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 1
    jne fail_read
    ret

fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_seek:
    mov dx, fail_seek_msg
    jmp fail
fail_read:
    mov dx, fail_read_msg
    jmp fail
fail_data:
    mov dx, fail_data_msg
    jmp fail
fail_bad_origin:
    mov dx, fail_bad_origin_msg
    jmp fail
fail_bad_handle:
    mov dx, fail_bad_handle_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "SEEKEDGE.DAT", 0
pass_msg: db "PASS: SEEKEDGE", 13, 10, "$"
fail_open_msg: db "FAIL: SEEKEDGE OPEN", 13, 10, "$"
fail_seek_msg: db "FAIL: SEEKEDGE SEEK", 13, 10, "$"
fail_read_msg: db "FAIL: SEEKEDGE READ", 13, 10, "$"
fail_data_msg: db "FAIL: SEEKEDGE DATA", 13, 10, "$"
fail_bad_origin_msg: db "FAIL: SEEKEDGE BAD ORIGIN", 13, 10, "$"
fail_bad_handle_msg: db "FAIL: SEEKEDGE BAD HANDLE", 13, 10, "$"
handle: dw 0
buf: db 0
