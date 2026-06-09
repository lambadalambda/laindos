[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x3D00
    mov dx, read_path
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, ax
    mov cx, 64
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, expected_len
    jne fail_read_len

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov si, expected
    mov di, buf
    mov cx, expected_len
    repe cmpsb
    jne fail_contents

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_read:
    mov dx, fail_read_msg
    jmp fail
fail_read_len:
    mov dx, fail_read_len_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_contents:
    mov dx, fail_contents_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
read_path: db 'D:\SUBDIR\HELLO.TXT', 0
expected: db 'Hello from a LainDOS CD-ROM subdirectory.', 13, 10
expected_len equ $ - expected
pass_msg: db 'PASS: CDSUBDIR', 13, 10, '$'
fail_open_msg: db 'FAIL: CDSUBDIR OPEN', 13, 10, '$'
fail_read_msg: db 'FAIL: CDSUBDIR READ', 13, 10, '$'
fail_read_len_msg: db 'FAIL: CDSUBDIR READ LEN', 13, 10, '$'
fail_close_msg: db 'FAIL: CDSUBDIR CLOSE', 13, 10, '$'
fail_contents_msg: db 'FAIL: CDSUBDIR CONTENTS', 13, 10, '$'
buf: times 80 db 0
