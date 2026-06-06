[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, base1_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open_base1
    mov [base1_handle], ax

    mov dx, long_name_path
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc fail_long_name_succeeded

    mov bx, [base1_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close_corrupted

    mov dx, base2_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open_base2
    mov [base2_handle], ax

    mov dx, long_ext_path
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc fail_long_ext_succeeded

    mov bx, [base2_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close_corrupted2

    mov dx, dot_long_ext_path
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc fail_dot_ext_succeeded

    mov dx, exact_11_path
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc fail_exact_11_succeeded

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open_base1:
    mov dx, fail_open_base1_msg
    jmp fail
fail_long_name_succeeded:
    mov dx, fail_long_name_msg
    jmp fail
fail_close_corrupted:
    mov dx, fail_close_msg
    jmp fail
fail_open_base2:
    mov dx, fail_open_base2_msg
    jmp fail
fail_long_ext_succeeded:
    mov dx, fail_long_ext_msg
    jmp fail
fail_close_corrupted2:
    mov dx, fail_close_msg
    jmp fail
fail_dot_ext_succeeded:
    mov dx, fail_dot_ext_msg
    jmp fail
fail_exact_11_succeeded:
    mov dx, fail_exact_11_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

base1_name: db "PBASE1.DAT", 0
base1_handle: dw 0
base2_name: db "PBASE2.DAT", 0
base2_handle: dw 0
long_name_path: times 200 db 'A'
db 0
long_ext_path: db "X"
times 200 db 'B'
db 0
dot_long_ext_path: db "A."
times 200 db 'B'
db 0
exact_11_path: db "ABCDEFGHIJK", 0
pass_msg: db "PASS: PATHBUF", 13, 10, "$"
fail_open_base1_msg: db "FAIL: PATHBUF OPEN1$"
fail_long_name_msg: db "FAIL: PATHBUF LONG NAME$"
fail_close_msg: db "FAIL: PATHBUF HANDLE CORRUPTED$"
fail_open_base2_msg: db "FAIL: PATHBUF OPEN2$"
fail_long_ext_msg: db "FAIL: PATHBUF LONG EXT$"
fail_dot_ext_msg: db "FAIL: PATHBUF DOT EXT$"
fail_exact_11_msg: db "FAIL: PATHBUF EXACT 11$"
