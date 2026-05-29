[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov bx, 19
    mov dx, buf
    mov cx, 1
    mov ah, 0x3F
    int 0x21
    jnc fail_bad_read_handle
    cmp ax, 6
    jne fail_bad_read_handle

    mov bx, 0x00FE
    mov dx, patch_data
    mov cx, 1
    mov ah, 0x40
    int 0x21
    jnc fail_bad_write_handle
    cmp ax, 6
    jne fail_bad_write_handle

    mov dx, filename
    mov ax, 0x3D02
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, [handle]
    mov dx, buf
    xor cx, cx
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 0
    jne fail_read
    call expect_pos_zero

    mov bx, [handle]
    mov dx, buf
    mov cx, 3
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 3
    jne fail_read
    cmp byte [buf], 'A'
    jne fail_data
    cmp byte [buf+1], 'B'
    jne fail_data
    cmp byte [buf+2], 'C'
    jne fail_data

    mov bx, [handle]
    mov dx, buf
    mov cx, 4
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 2
    jne fail_read
    cmp byte [buf], 'D'
    jne fail_data
    cmp byte [buf+1], 'E'
    jne fail_data

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
    mov ax, 0x4202
    int 0x21
    jc fail_seek
    cmp ax, 5
    jne fail_seek
    cmp dx, 0
    jne fail_seek

    mov bx, [handle]
    mov dx, patch_data
    xor cx, cx
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 0
    jne fail_write
    call expect_pos_five

    mov bx, [handle]
    xor cx, cx
    mov dx, 1
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    cmp ax, 1
    jne fail_seek
    cmp dx, 0
    jne fail_seek

    mov bx, [handle]
    mov dx, patch_data
    mov cx, 2
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 2
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, filename
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, [handle]
    mov dx, buf
    mov cx, 5
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 5
    jne fail_read
    cmp byte [buf], 'A'
    jne fail_data
    cmp byte [buf+1], 'X'
    jne fail_data
    cmp byte [buf+2], 'Y'
    jne fail_data
    cmp byte [buf+3], 'D'
    jne fail_data
    cmp byte [buf+4], 'E'
    jne fail_data

    mov bx, [handle]
    mov dx, patch_data
    mov cx, 1
    mov ah, 0x40
    int 0x21
    jnc fail_readonly_write
    cmp ax, 5
    jne fail_readonly_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

expect_pos_zero:
    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4201
    int 0x21
    jc fail_seek
    cmp ax, 0
    jne fail_seek
    cmp dx, 0
    jne fail_seek
    ret

expect_pos_five:
    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4201
    int 0x21
    jc fail_seek
    cmp ax, 5
    jne fail_seek
    cmp dx, 0
    jne fail_seek
    ret

fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_read:
    mov dx, fail_read_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
    jmp fail
fail_seek:
    mov dx, fail_seek_msg
    jmp fail
fail_data:
    mov dx, fail_data_msg
    jmp fail
fail_bad_read_handle:
    mov dx, fail_bad_read_handle_msg
    jmp fail
fail_bad_write_handle:
    mov dx, fail_bad_write_handle_msg
    jmp fail
fail_readonly_write:
    mov dx, fail_readonly_write_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "RWEDGE.DAT", 0
patch_data: db "XY"
pass_msg: db "PASS: RWEDGE", 13, 10, "$"
fail_open_msg: db "FAIL: RWEDGE OPEN", 13, 10, "$"
fail_close_msg: db "FAIL: RWEDGE CLOSE", 13, 10, "$"
fail_read_msg: db "FAIL: RWEDGE READ", 13, 10, "$"
fail_write_msg: db "FAIL: RWEDGE WRITE", 13, 10, "$"
fail_seek_msg: db "FAIL: RWEDGE SEEK", 13, 10, "$"
fail_data_msg: db "FAIL: RWEDGE DATA", 13, 10, "$"
fail_bad_read_handle_msg: db "FAIL: RWEDGE BAD READ HANDLE", 13, 10, "$"
fail_bad_write_handle_msg: db "FAIL: RWEDGE BAD WRITE HANDLE", 13, 10, "$"
fail_readonly_write_msg: db "FAIL: RWEDGE READONLY WRITE", 13, 10, "$"
handle: dw 0
buf: times 8 db 0
