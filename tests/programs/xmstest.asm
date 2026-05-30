[bits 16]
[org 0x0100]

XMS_TEST_KB equ 15360
XMS_TEST_BAD_OFF equ 0x00EFFFF0
XMS_TEST_64K_OFF equ 0x00030000
CONV_TEST_SEG equ 0x8000

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
    cmp ax, XMS_TEST_KB
    jb fail_query
    cmp dx, ax
    jb fail_query

    mov ah, 0x09
    mov dx, XMS_TEST_KB
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
    sti
    call far [xms_entry]
    pushf
    pop bx
    test bx, 0x0200
    jnz .move_to_if_ok
    sti
    jmp fail_move_if
.move_to_if_ok:
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

    call seed_conv_64k
    mov dx, [xms_handle]
    mov [move_64k_dst_handle], dx
    mov ah, 0x0B
    mov si, move_64k_to_xms
    call far [xms_entry]
    cmp ax, 1
    jne fail_move_64k_to

    call clear_dst_data
    call bios_copy_xms_expected_head
    jc fail_move_64k_bios
    mov si, dst_data
    mov di, expected_data
    mov cx, 16
    repe cmpsw
    jne fail_move_64k_bios_cmp

    mov dx, [xms_handle]
    mov [move_64k_head_src_handle], dx
    mov [move_64k_tail_src_handle], dx
    mov ax, cs
    mov [move_64k_head_dst_seg], ax
    mov [move_64k_tail_dst_seg], ax
    call clear_dst_data
    mov ah, 0x0B
    mov si, move_64k_head_from_xms
    call far [xms_entry]
    cmp ax, 1
    jne fail_move_64k_head
    mov si, dst_data
    mov di, expected_data
    mov cx, 16
    repe cmpsw
    jne fail_move_64k_cmp

    call clear_dst_data
    mov ah, 0x0B
    mov si, move_64k_tail_from_xms
    call far [xms_entry]
    cmp ax, 1
    jne fail_move_64k_tail
    mov si, dst_data
    mov di, tail_data
    mov cx, 16
    repe cmpsw
    jne fail_move_64k_cmp

    call clear_conv_64k_edges
    mov dx, [xms_handle]
    mov [move_64k_back_src_handle], dx
    mov ah, 0x0B
    mov si, move_64k_back_to_conv
    call far [xms_entry]
    cmp ax, 1
    jne fail_move_64k_back
    push cs
    pop ds
    mov ax, CONV_TEST_SEG
    mov es, ax
    mov si, expected_data
    xor di, di
    mov cx, 16
    repe cmpsw
    jne fail_move_64k_back_cmp
    mov si, tail_data
    mov di, 0xFFE0
    mov cx, 16
    repe cmpsw
    jne fail_move_64k_back_cmp

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
    cmp dx, XMS_TEST_KB
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
fail_move_if:
    mov dx, fail_move_if_msg
    jmp fail
fail_move_cmp:
    mov dx, fail_move_cmp_msg
    jmp fail
fail_move_64k_to:
    mov dx, fail_move_64k_to_msg
    jmp fail
fail_move_64k_bios:
    mov dx, fail_move_64k_bios_msg
    jmp fail
fail_move_64k_bios_cmp:
    mov dx, fail_move_64k_bios_cmp_msg
    jmp fail
fail_move_64k_head:
    mov dx, fail_move_64k_head_msg
    jmp fail
fail_move_64k_tail:
    mov dx, fail_move_64k_tail_msg
    jmp fail
fail_move_64k_cmp:
    mov dx, fail_move_64k_cmp_msg
    jmp fail
fail_move_64k_back:
    mov dx, fail_move_64k_back_msg
    jmp fail
fail_move_64k_back_cmp:
    mov dx, fail_move_64k_back_cmp_msg
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
move_64k_to_xms:
    dd 0x00010000
    dw 0
    dw 0, CONV_TEST_SEG
move_64k_dst_handle: dw 0
    dd XMS_TEST_64K_OFF
move_64k_head_from_xms:
    dd 32
move_64k_head_src_handle: dw 0
    dd XMS_TEST_64K_OFF
    dw 0
    dw dst_data
move_64k_head_dst_seg: dw 0
move_64k_tail_from_xms:
    dd 32
move_64k_tail_src_handle: dw 0
    dd XMS_TEST_64K_OFF + 0xFFE0
    dw 0
    dw dst_data
move_64k_tail_dst_seg: dw 0
move_64k_back_to_conv:
    dd 0x00010000
move_64k_back_src_handle: dw 0
    dd XMS_TEST_64K_OFF
    dw 0
    dw 0, CONV_TEST_SEG
move_bad_bounds:
    dd 32
move_bad_src_handle: dw 0
    dd XMS_TEST_BAD_OFF
    dw 0
    dw dst_data
move_bad_dst_seg: dw 0
move_src_seg equ move_to_xms + 8
bios_copy_xms_expected_head:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    push cs
    pop ds
    mov di, bios_gdt + 0x10
    mov ax, 31
    xor bx, bx
    mov dx, 0x0013
    call set_bios_desc
    mov di, bios_gdt + 0x18
    mov ax, dst_data
    mov dx, cs
    call real_to_phys
    mov ax, 31
    call set_bios_desc
    mov ax, 0x8700
    mov cx, 16
    mov si, bios_gdt
    push cs
    pop es
    int 0x15
    jc .fail
    test ah, ah
    jnz .fail
    clc
    jmp .done
.fail:
    stc
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
set_bios_desc:
    mov [di], ax
    mov [di+2], bx
    mov [di+4], dl
    mov byte [di+5], 0x93
    mov word [di+6], 0
    ret
real_to_phys:
    push cx
    mov bx, dx
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shr dx, 12
    add ax, bx
    adc dx, 0
    mov bx, ax
    pop cx
    ret
clear_dst_data:
    push ax
    push cx
    push di
    push es
    push cs
    pop es
    mov di, dst_data
    mov cx, 16
    xor ax, ax
    rep stosw
    pop es
    pop di
    pop cx
    pop ax
    ret
seed_conv_64k:
    push ax
    push cx
    push si
    push di
    push ds
    push es
    push cs
    pop ds
    mov ax, CONV_TEST_SEG
    mov es, ax
    mov si, expected_data
    xor di, di
    mov cx, 32
    rep movsb
    mov si, tail_data
    mov di, 0xFFE0
    mov cx, 32
    rep movsb
    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret
clear_conv_64k_edges:
    push ax
    push cx
    push di
    push es
    mov ax, CONV_TEST_SEG
    mov es, ax
    xor ax, ax
    xor di, di
    mov cx, 16
    rep stosw
    mov di, 0xFFE0
    mov cx, 16
    rep stosw
    pop es
    pop di
    pop cx
    pop ax
    ret
src_data:
    db "LainDOS XMS move regression!!", 0, 0, 0
expected_data:
    db "LainDOS XMS move regression!!", 0, 0, 0
tail_data:
    db "Tail marker across 64K chunk!!", 0, 0, 0, 0
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
fail_move_if_msg: db "FAIL: XMS MOVE IF", 13, 10, "$"
fail_move_cmp_msg: db "FAIL: XMS MOVE CMP", 13, 10, "$"
fail_move_64k_to_msg: db "FAIL: XMS MOVE 64K TO", 13, 10, "$"
fail_move_64k_bios_msg: db "FAIL: XMS MOVE 64K BIOS", 13, 10, "$"
fail_move_64k_bios_cmp_msg: db "FAIL: XMS MOVE 64K BIOS CMP", 13, 10, "$"
fail_move_64k_head_msg: db "FAIL: XMS MOVE 64K HEAD", 13, 10, "$"
fail_move_64k_tail_msg: db "FAIL: XMS MOVE 64K TAIL", 13, 10, "$"
fail_move_64k_cmp_msg: db "FAIL: XMS MOVE 64K CMP", 13, 10, "$"
fail_move_64k_back_msg: db "FAIL: XMS MOVE 64K BACK", 13, 10, "$"
fail_move_64k_back_cmp_msg: db "FAIL: XMS MOVE 64K BACK CMP", 13, 10, "$"
fail_move_bounds_msg: db "FAIL: XMS MOVE BOUNDS", 13, 10, "$"
fail_free_msg: db "FAIL: XMS FREE", 13, 10, "$"
bios_gdt: times 48 db 0
