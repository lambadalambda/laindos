[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, fname
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc .fail_create
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

    push cs
    pop es
    mov dx, fname
    mov di, newname
    mov ah, 0x56
    int 0x21
    jnc .fail_rename_open_allowed
    cmp ax, 5
    je .rename_open_rejected
    jmp .fail_rename_open_err
.rename_open_rejected:

    mov bx, [h1]
    mov dx, rbuf
    mov cx, wdata_size
    mov ah, 0x3F
    int 0x21
    jc .fail_read1
    cmp ax, wdata_size
    jne .fail_read1

    push cs
    pop es
    mov si, wdata
    mov di, rbuf
    mov cx, wdata_size
.verify1:
    cmpsb
    jne .fail_verify1
    loop .verify1

    mov bx, [h1]
    mov ah, 0x3E
    int 0x21
    jc .fail_close2

    mov dx, rdname
    mov cx, 1
    mov ah, 0x3C
    int 0x21
    jc .fail_create_rd
    mov [h2], ax

    mov bx, [h2]
    mov ah, 0x3E
    int 0x21
    jc .fail_close3

    push cs
    pop es
    mov dx, rdname
    mov di, newname
    mov ah, 0x56
    int 0x21
    jnc .fail_rename_rd_allowed
    cmp ax, 5
    je .rename_rd_rejected
    jmp .fail_rename_rd_err
.rename_rd_rejected:

    push cs
    pop es
    mov dx, fname
    mov di, newname
    mov ah, 0x56
    int 0x21
    jc .fail_rename_normal

    mov dx, newname
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .fail_open2
    mov [h2], ax

    mov bx, ax
    mov dx, rbuf
    mov cx, wdata_size
    mov ah, 0x3F
    int 0x21
    jc .fail_read2
    cmp ax, wdata_size
    jne .fail_read2

    push cs
    pop es
    mov si, wdata
    mov di, rbuf
    mov cx, wdata_size
.verify2:
    cmpsb
    jne .fail_verify2
    loop .verify2

    mov bx, [h2]
    mov ah, 0x3E
    int 0x21
    jc .fail_close4

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_create:
    mov dx, fail_create_msg
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
.fail_rename_open_allowed:
    mov dx, fail_rename_open_msg
    jmp .print_fail
.fail_rename_open_err:
    mov dx, fail_rename_open_err_msg
    jmp .print_fail
.fail_read1:
    mov dx, fail_read1_msg
    jmp .print_fail
.fail_verify1:
    mov dx, fail_verify1_msg
    jmp .print_fail
.fail_close2:
    mov dx, fail_close2_msg
    jmp .print_fail
.fail_create_rd:
    mov dx, fail_create_rd_msg
    jmp .print_fail
.fail_close3:
    mov dx, fail_close3_msg
    jmp .print_fail
.fail_rename_rd_allowed:
    mov dx, fail_rename_rd_msg
    jmp .print_fail
.fail_rename_rd_err:
    mov dx, fail_rename_rd_err_msg
    jmp .print_fail
.fail_rename_normal:
    mov dx, fail_rename_normal_msg
    jmp .print_fail
.fail_open2:
    mov dx, fail_open2_msg
    jmp .print_fail
.fail_read2:
    mov dx, fail_read2_msg
    jmp .print_fail
.fail_verify2:
    mov dx, fail_verify2_msg
    jmp .print_fail
.fail_close4:
    mov dx, fail_close4_msg
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fname: db "RNGUARD.DAT", 0
newname: db "RNGDONE.DAT", 0
rdname: db "RNGRDONLYDAT", 0
wdata: db "Hello from RNGUARD!", 13, 10
wdata_size equ $ - wdata
pass_msg: db "PASS: RNGUARD", 13, 10, "$"
fail_create_msg: db "FAIL: RNGUARD CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: RNGUARD WRITE", 13, 10, "$"
fail_close1_msg: db "FAIL: RNGUARD CLOSE1", 13, 10, "$"
fail_open1_msg: db "FAIL: RNGUARD OPEN1", 13, 10, "$"
fail_rename_open_msg: db "FAIL: RNGUARD RENAME OPEN", 13, 10, "$"
fail_rename_open_err_msg: db "FAIL: RNGUARD RENAME OPEN ERR", 13, 10, "$"
fail_read1_msg: db "FAIL: RNGUARD READ1", 13, 10, "$"
fail_verify1_msg: db "FAIL: RNGUARD VERIFY1", 13, 10, "$"
fail_close2_msg: db "FAIL: RNGUARD CLOSE2", 13, 10, "$"
fail_create_rd_msg: db "FAIL: RNGUARD CREATE RD", 13, 10, "$"
fail_close3_msg: db "FAIL: RNGUARD CLOSE3", 13, 10, "$"
fail_rename_rd_msg: db "FAIL: RNGUARD RD RENAME ALLOWED", 13, 10, "$"
fail_rename_rd_err_msg: db "FAIL: RNGUARD RD RENAME ERR", 13, 10, "$"
fail_rename_normal_msg: db "FAIL: RNGUARD RENAME NORMAL", 13, 10, "$"
fail_open2_msg: db "FAIL: RNGUARD OPEN2", 13, 10, "$"
fail_read2_msg: db "FAIL: RNGUARD READ2", 13, 10, "$"
fail_verify2_msg: db "FAIL: RNGUARD VERIFY2", 13, 10, "$"
fail_close4_msg: db "FAIL: RNGUARD CLOSE4", 13, 10, "$"
h1: dw 0
h2: dw 0
rbuf: times 64 db 0
