[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    cld

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

    mov dx, over_src_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc .fail_create_over_src
    mov [h1], ax

    mov bx, ax
    mov dx, over_src_data
    mov cx, over_src_size
    mov ah, 0x40
    int 0x21
    jc .fail_write_over_src
    cmp ax, over_src_size
    jne .fail_write_over_src

    mov bx, [h1]
    mov ah, 0x3E
    int 0x21
    jc .fail_close_over_src

    mov dx, over_dst_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc .fail_create_over_dst
    mov [h2], ax

    mov bx, ax
    mov dx, over_dst_data
    mov cx, over_dst_size
    mov ah, 0x40
    int 0x21
    jc .fail_write_over_dst
    cmp ax, over_dst_size
    jne .fail_write_over_dst

    mov bx, [h2]
    mov ah, 0x3E
    int 0x21
    jc .fail_close_over_dst

    push cs
    pop es
    mov dx, over_src_name
    mov di, over_dst_name
    mov ah, 0x56
    int 0x21
    jnc .fail_rename_over_allowed
    cmp ax, 5
    jne .fail_rename_over_err

    mov dx, over_src_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .fail_open_over_src
    mov [h1], ax

    mov bx, ax
    mov dx, rbuf
    mov cx, over_src_size
    mov ah, 0x3F
    int 0x21
    jc .fail_read_over_src
    cmp ax, over_src_size
    jne .fail_read_over_src

    push cs
    pop es
    mov si, over_src_data
    mov di, rbuf
    mov cx, over_src_size
.verify_over_src:
    cmpsb
    jne .fail_verify_over_src
    loop .verify_over_src

    mov bx, [h1]
    mov ah, 0x3E
    int 0x21
    jc .fail_close_over_src2

    mov dx, over_dst_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .fail_open_over_dst
    mov [h2], ax

    mov bx, ax
    mov dx, rbuf
    mov cx, over_dst_size
    mov ah, 0x3F
    int 0x21
    jc .fail_read_over_dst
    cmp ax, over_dst_size
    jne .fail_read_over_dst

    push cs
    pop es
    mov si, over_dst_data
    mov di, rbuf
    mov cx, over_dst_size
.verify_over_dst:
    cmpsb
    jne .fail_verify_over_dst
    loop .verify_over_dst

    mov bx, [h2]
    mov ah, 0x3E
    int 0x21
    jc .fail_close_over_dst2

    mov dx, cross_dir_name
    mov ah, 0x39
    int 0x21
    jc .fail_mkdir_cross

    mov dx, cross_src_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc .fail_create_cross
    mov [h1], ax

    mov bx, ax
    mov dx, cross_data
    mov cx, cross_size
    mov ah, 0x40
    int 0x21
    jc .fail_write_cross
    cmp ax, cross_size
    jne .fail_write_cross

    mov bx, [h1]
    mov ah, 0x3E
    int 0x21
    jc .fail_close_cross

    push cs
    pop es
    mov dx, cross_src_name
    mov di, cross_dst_path
    mov ah, 0x56
    int 0x21
    jnc .fail_rename_cross_allowed
    cmp ax, 5
    jne .fail_rename_cross_err

    mov dx, cross_src_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .fail_open_cross_src
    mov [h1], ax

    mov bx, ax
    mov dx, rbuf
    mov cx, cross_size
    mov ah, 0x3F
    int 0x21
    jc .fail_read_cross
    cmp ax, cross_size
    jne .fail_read_cross

    push cs
    pop es
    mov si, cross_data
    mov di, rbuf
    mov cx, cross_size
.verify_cross:
    cmpsb
    jne .fail_verify_cross
    loop .verify_cross

    mov bx, [h1]
    mov ah, 0x3E
    int 0x21
    jc .fail_close_cross2

    mov dx, cross_dst_path
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc .fail_cross_target_exists

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
    jmp .print_fail
.fail_create_over_src:
    mov dx, fail_create_over_src_msg
    jmp .print_fail
.fail_write_over_src:
    mov dx, fail_write_over_src_msg
    jmp .print_fail
.fail_close_over_src:
    mov dx, fail_close_over_src_msg
    jmp .print_fail
.fail_create_over_dst:
    mov dx, fail_create_over_dst_msg
    jmp .print_fail
.fail_write_over_dst:
    mov dx, fail_write_over_dst_msg
    jmp .print_fail
.fail_close_over_dst:
    mov dx, fail_close_over_dst_msg
    jmp .print_fail
.fail_rename_over_allowed:
    mov dx, fail_rename_over_msg
    jmp .print_fail
.fail_rename_over_err:
    mov dx, fail_rename_over_err_msg
    jmp .print_fail
.fail_open_over_src:
    mov dx, fail_open_over_src_msg
    jmp .print_fail
.fail_read_over_src:
    mov dx, fail_read_over_src_msg
    jmp .print_fail
.fail_verify_over_src:
    mov dx, fail_verify_over_src_msg
    jmp .print_fail
.fail_close_over_src2:
    mov dx, fail_close_over_src2_msg
    jmp .print_fail
.fail_open_over_dst:
    mov dx, fail_open_over_dst_msg
    jmp .print_fail
.fail_read_over_dst:
    mov dx, fail_read_over_dst_msg
    jmp .print_fail
.fail_verify_over_dst:
    mov dx, fail_verify_over_dst_msg
    jmp .print_fail
.fail_close_over_dst2:
    mov dx, fail_close_over_dst2_msg
    jmp .print_fail
.fail_mkdir_cross:
    mov dx, fail_mkdir_cross_msg
    jmp .print_fail
.fail_create_cross:
    mov dx, fail_create_cross_msg
    jmp .print_fail
.fail_write_cross:
    mov dx, fail_write_cross_msg
    jmp .print_fail
.fail_close_cross:
    mov dx, fail_close_cross_msg
    jmp .print_fail
.fail_rename_cross_allowed:
    mov dx, fail_rename_cross_msg
    jmp .print_fail
.fail_rename_cross_err:
    mov dx, fail_rename_cross_err_msg
    jmp .print_fail
.fail_open_cross_src:
    mov dx, fail_open_cross_src_msg
    jmp .print_fail
.fail_read_cross:
    mov dx, fail_read_cross_msg
    jmp .print_fail
.fail_verify_cross:
    mov dx, fail_verify_cross_msg
    jmp .print_fail
.fail_close_cross2:
    mov dx, fail_close_cross2_msg
    jmp .print_fail
.fail_cross_target_exists:
    mov dx, fail_cross_target_exists_msg
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fname: db "RNGUARD.DAT", 0
newname: db "RNGDONE.DAT", 0
rdname: db "RNGRDONLYDAT", 0
over_src_name: db "OVRSRC.DAT", 0
over_dst_name: db "OVRDST.DAT", 0
cross_dir_name: db "RNDIR", 0
cross_src_name: db "RNCROSS.DAT", 0
cross_dst_path: db "RNDIR\RNCROSS.DAT", 0
wdata: db "Hello from RNGUARD!", 13, 10
wdata_size equ $ - wdata
over_src_data: db "rename source", 13, 10
over_src_size equ $ - over_src_data
over_dst_data: db "rename dest", 13, 10
over_dst_size equ $ - over_dst_data
cross_data: db "rename cross", 13, 10
cross_size equ $ - cross_data
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
fail_create_over_src_msg: db "FAIL: RNGUARD OVER CREATE SRC", 13, 10, "$"
fail_write_over_src_msg: db "FAIL: RNGUARD OVER WRITE SRC", 13, 10, "$"
fail_close_over_src_msg: db "FAIL: RNGUARD OVER CLOSE SRC", 13, 10, "$"
fail_create_over_dst_msg: db "FAIL: RNGUARD OVER CREATE DST", 13, 10, "$"
fail_write_over_dst_msg: db "FAIL: RNGUARD OVER WRITE DST", 13, 10, "$"
fail_close_over_dst_msg: db "FAIL: RNGUARD OVER CLOSE DST", 13, 10, "$"
fail_rename_over_msg: db "FAIL: RNGUARD OVER RENAME ALLOWED", 13, 10, "$"
fail_rename_over_err_msg: db "FAIL: RNGUARD OVER RENAME ERR", 13, 10, "$"
fail_open_over_src_msg: db "FAIL: RNGUARD OVER OPEN SRC", 13, 10, "$"
fail_read_over_src_msg: db "FAIL: RNGUARD OVER READ SRC", 13, 10, "$"
fail_verify_over_src_msg: db "FAIL: RNGUARD OVER VERIFY SRC", 13, 10, "$"
fail_close_over_src2_msg: db "FAIL: RNGUARD OVER CLOSE SRC2", 13, 10, "$"
fail_open_over_dst_msg: db "FAIL: RNGUARD OVER OPEN DST", 13, 10, "$"
fail_read_over_dst_msg: db "FAIL: RNGUARD OVER READ DST", 13, 10, "$"
fail_verify_over_dst_msg: db "FAIL: RNGUARD OVER VERIFY DST", 13, 10, "$"
fail_close_over_dst2_msg: db "FAIL: RNGUARD OVER CLOSE DST2", 13, 10, "$"
fail_mkdir_cross_msg: db "FAIL: RNGUARD CROSS MKDIR", 13, 10, "$"
fail_create_cross_msg: db "FAIL: RNGUARD CROSS CREATE", 13, 10, "$"
fail_write_cross_msg: db "FAIL: RNGUARD CROSS WRITE", 13, 10, "$"
fail_close_cross_msg: db "FAIL: RNGUARD CROSS CLOSE", 13, 10, "$"
fail_rename_cross_msg: db "FAIL: RNGUARD CROSS RENAME ALLOWED", 13, 10, "$"
fail_rename_cross_err_msg: db "FAIL: RNGUARD CROSS RENAME ERR", 13, 10, "$"
fail_open_cross_src_msg: db "FAIL: RNGUARD CROSS OPEN SRC", 13, 10, "$"
fail_read_cross_msg: db "FAIL: RNGUARD CROSS READ", 13, 10, "$"
fail_verify_cross_msg: db "FAIL: RNGUARD CROSS VERIFY", 13, 10, "$"
fail_close_cross2_msg: db "FAIL: RNGUARD CROSS CLOSE2", 13, 10, "$"
fail_cross_target_exists_msg: db "FAIL: RNGUARD CROSS TARGET", 13, 10, "$"
h1: dw 0
h2: dw 0
rbuf: times 64 db 0
