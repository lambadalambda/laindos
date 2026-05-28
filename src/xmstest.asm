[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x352F
    int 0x21
    mov ax, es
    or ax, bx
    jz fail_vec

    mov ax, 0x4300
    int 0x2F
    cmp al, 0x80
    jne fail_install

    mov ax, 0x4310
    int 0x2F
    mov [xms_entry], bx
    mov [xms_entry+2], es
    mov ax, es
    or ax, bx
    jz fail_entry

    mov ah, 0x00
    call far [xms_entry]
    cmp ax, 0x0200
    jb fail_version

    mov ah, 0x08
    call far [xms_entry]
    cmp ax, 8192
    jb fail_query
    cmp dx, ax
    jb fail_query

    mov ah, 0x09
    mov dx, 8192
    call far [xms_entry]
    cmp ax, 1
    jne fail_alloc
    test dx, dx
    jz fail_alloc
    mov [xms_handle], dx

    push cs
    pop es

    mov si, src_data
    mov di, expected_data
    mov cx, 16
    repe cmpsw
    jne fail_move

    mov ax, cs
    mov [move_src_seg], ax
    mov [move_dst_handle], dx
    mov ah, 0x0B
    mov si, move_to_xms
    call far [xms_entry]
    cmp ax, 1
    jne fail_move_to

    mov di, dst_data
    mov cx, 16
    xor ax, ax
    rep stosw

    mov ax, cs
    mov [move_dst_seg], ax
    mov dx, [xms_handle]
    mov [move_src_handle], dx
    mov ah, 0x0B
    mov si, move_from_xms
    call far [xms_entry]
    cmp ax, 1
    jne fail_move_from

    mov si, dst_data
    mov di, expected_data
    mov cx, 16
    repe cmpsw
    jne fail_move_cmp

    mov dx, [xms_handle]
    mov [move_bad_src_handle], dx
    mov ax, cs
    mov [move_bad_dst_seg], ax
    mov ah, 0x0B
    mov si, move_bad_bounds
    call far [xms_entry]
    cmp ax, 0
    jne fail_move_bounds

    mov ah, 0x0E
    mov dx, [xms_handle]
    call far [xms_entry]
    cmp ax, 1
    jne fail_info
    cmp dx, 8192
    jne fail_info

    mov ah, 0x0A
    mov dx, [xms_handle]
    call far [xms_entry]
    cmp ax, 1
    jne fail_free

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_vec:
    mov dx, fail_vec_msg
    jmp fail
fail_install:
    mov dx, fail_install_msg
    jmp fail
fail_entry:
    mov dx, fail_entry_msg
    jmp fail
fail_version:
    mov dx, fail_version_msg
    jmp fail
fail_query:
    mov dx, fail_query_msg
    jmp fail
fail_alloc:
    mov dx, fail_alloc_msg
    jmp fail
fail_info:
    mov dx, fail_info_msg
    jmp fail
fail_move:
    mov dx, fail_move_msg
    jmp fail
fail_move_to:
    mov dx, fail_move_to_msg
    jmp fail
fail_move_from:
    mov dx, fail_move_from_msg
    jmp fail
fail_move_cmp:
    mov dx, fail_move_cmp_msg
    jmp fail
fail_move_bounds:
    mov dx, fail_move_bounds_msg
    jmp fail
fail_free:
    mov dx, fail_free_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

xms_entry: dw 0, 0
xms_handle: dw 0
move_to_xms:
    dd 32
    dw 0
    dw src_data, 0
move_dst_handle: dw 0
    dd 0
move_from_xms:
    dd 32
move_src_handle: dw 0
    dd 0
    dw 0
    dw dst_data
move_dst_seg: dw 0
move_bad_bounds:
    dd 32
move_bad_src_handle: dw 0
    dd 0x007FFFF0
    dw 0
    dw dst_data
move_bad_dst_seg: dw 0
move_src_seg equ move_to_xms + 8
src_data:
    db "LainDOS XMS move regression!!", 0, 0, 0
expected_data:
    db "LainDOS XMS move regression!!", 0, 0, 0
dst_data: times 32 db 0
pass_msg: db "PASS: XMS", 13, 10, "$"
fail_vec_msg: db "FAIL: XMS VEC", 13, 10, "$"
fail_install_msg: db "FAIL: XMS INSTALL", 13, 10, "$"
fail_entry_msg: db "FAIL: XMS ENTRY", 13, 10, "$"
fail_version_msg: db "FAIL: XMS VERSION", 13, 10, "$"
fail_query_msg: db "FAIL: XMS QUERY", 13, 10, "$"
fail_alloc_msg: db "FAIL: XMS ALLOC", 13, 10, "$"
fail_info_msg: db "FAIL: XMS INFO", 13, 10, "$"
fail_move_msg: db "FAIL: XMS MOVE", 13, 10, "$"
fail_move_to_msg: db "FAIL: XMS MOVE TO", 13, 10, "$"
fail_move_from_msg: db "FAIL: XMS MOVE FROM", 13, 10, "$"
fail_move_cmp_msg: db "FAIL: XMS MOVE CMP", 13, 10, "$"
fail_move_bounds_msg: db "FAIL: XMS MOVE BOUNDS", 13, 10, "$"
fail_free_msg: db "FAIL: XMS FREE", 13, 10, "$"
