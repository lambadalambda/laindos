[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, fname
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc .fail_create1
    mov [h1], ax

    mov bx, ax
    mov dx, wdata
    mov cx, wdata_size
    mov ah, 0x40
    int 0x21
    jc .fail_write
    cmp ax, wdata_size
    jne .fail_write

    mov bx, [h1]
    mov ah, 0x3E
    int 0x21
    jc .fail_close1

    mov dx, fname
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .fail_open1
    mov [h1], ax

    mov dx, fname
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jnc .fail_truncate_allowed
    cmp ax, 5
    je .truncate_rejected
    jmp .fail_truncate_wrong_err
.truncate_rejected:

    mov bx, [h1]
    mov dx, rbuf
    mov cx, wdata_size
    mov ah, 0x3F
    int 0x21
    jc .fail_read
    cmp ax, wdata_size
    jne .fail_read

    push cs
    pop es
    mov si, wdata
    mov di, rbuf
    mov cx, wdata_size
.verify_loop:
    cmpsb
    jne .fail_verify
    loop .verify_loop

    mov bx, [h1]
    mov ah, 0x3E
    int 0x21
    jc .fail_close2

    mov dx, fname
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc .fail_create2
    mov [h2], ax

    mov bx, [h2]
    mov ah, 0x3E
    int 0x21
    jc .fail_close3

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_create1:
    mov dx, fail_create1_msg
    jmp .print_fail
.fail_write:
    mov dx, fail_write_msg
    jmp .print_fail
.fail_close1:
    mov dx, fail_close1_msg
    jmp .print_fail
.fail_open1:
    mov dx, fail_open1_msg
    jmp .print_fail
.fail_truncate_allowed:
    mov dx, fail_trunc_allowed_msg
    jmp .print_fail
.fail_truncate_wrong_err:
    mov dx, fail_trunc_err_msg
    jmp .print_fail
.fail_read:
    mov dx, fail_read_msg
    jmp .print_fail
.fail_verify:
    mov dx, fail_verify_msg
    jmp .print_fail
.fail_close2:
    mov dx, fail_close2_msg
    jmp .print_fail
.fail_create2:
    mov dx, fail_create2_msg
    jmp .print_fail
.fail_close3:
    mov dx, fail_close3_msg
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fname: db "CTRUNC.DAT", 0
wdata: db "Hello from CTRUNC test!", 13, 10
wdata_size equ $ - wdata
pass_msg: db "PASS: CTRUNC", 13, 10, "$"
fail_create1_msg: db "FAIL: CTRUNC CREATE1", 13, 10, "$"
fail_write_msg: db "FAIL: CTRUNC WRITE", 13, 10, "$"
fail_close1_msg: db "FAIL: CTRUNC CLOSE1", 13, 10, "$"
fail_open1_msg: db "FAIL: CTRUNC OPEN1", 13, 10, "$"
fail_trunc_allowed_msg: db "FAIL: CTRUNC TRUNC ALLOWED", 13, 10, "$"
fail_trunc_err_msg: db "FAIL: CTRUNC TRUNC WRONG ERR", 13, 10, "$"
fail_read_msg: db "FAIL: CTRUNC READ", 13, 10, "$"
fail_verify_msg: db "FAIL: CTRUNC VERIFY", 13, 10, "$"
fail_close2_msg: db "FAIL: CTRUNC CLOSE2", 13, 10, "$"
fail_create2_msg: db "FAIL: CTRUNC CREATE2", 13, 10, "$"
fail_close3_msg: db "FAIL: CTRUNC CLOSE3", 13, 10, "$"
h1: dw 0
h2: dw 0
rbuf: times 64 db 0
