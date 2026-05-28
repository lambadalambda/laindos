[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, filename
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [file_handle], ax

    mov bx, [file_handle]
    mov dx, data
    mov cx, data_len
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, data_len
    jne fail_write

    mov bx, [file_handle]
    mov ah, 0x45
    int 0x21
    jc fail_dup
    mov [dup_handle], ax

    mov bx, [dup_handle]
    mov ah, 0x68
    int 0x21
    jc fail_commit

    mov dx, filename
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_reopen
    mov [read_handle], ax

    mov bx, [read_handle]
    mov cx, data_len
    mov dx, read_buf
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, data_len
    jne fail_read

    mov si, data
    mov di, read_buf
    mov cx, data_len
    repe cmpsb
    jne fail_read

    mov bx, [read_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov bx, [dup_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov bx, [file_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov bx, 19
    mov ah, 0x68
    int 0x21
    jnc fail_bad_handle
    cmp ax, 6
    jne fail_bad_handle

    mov bx, 20
    mov ah, 0x68
    int 0x21
    jnc fail_bad_handle
    cmp ax, 6
    jne fail_bad_handle

    mov bx, 1
    mov ah, 0x68
    int 0x21
    jc fail_stdio

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_create:
    mov dx, fail_create_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
    jmp fail
fail_dup:
    mov dx, fail_dup_msg
    jmp fail
fail_commit:
    mov dx, fail_commit_msg
    jmp fail
fail_reopen:
    mov dx, fail_reopen_msg
    jmp fail
fail_read:
    mov dx, fail_read_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_bad_handle:
    mov dx, fail_bad_handle_msg
    jmp fail
fail_stdio:
    mov dx, fail_stdio_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "COMMIT.DAT", 0
data: db "COMMIT-OK"
data_len equ $ - data
file_handle: dw 0
dup_handle: dw 0
read_handle: dw 0
read_buf: times data_len db 0

pass_msg: db "PASS: COMMIT", 13, 10, "$"
fail_create_msg: db "FAIL: COMMIT CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: COMMIT WRITE", 13, 10, "$"
fail_dup_msg: db "FAIL: COMMIT DUP", 13, 10, "$"
fail_commit_msg: db "FAIL: COMMIT AH68", 13, 10, "$"
fail_reopen_msg: db "FAIL: COMMIT REOPEN", 13, 10, "$"
fail_read_msg: db "FAIL: COMMIT READ", 13, 10, "$"
fail_close_msg: db "FAIL: COMMIT CLOSE", 13, 10, "$"
fail_bad_handle_msg: db "FAIL: COMMIT BAD HANDLE", 13, 10, "$"
fail_stdio_msg: db "FAIL: COMMIT STDIO", 13, 10, "$"
