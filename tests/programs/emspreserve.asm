%include "tests/programs/common.inc"

EMS_PAGES equ 4

COM_START
    mov sp, 0x1FFE

    mov ah, 0x40
    int 0x67
    test ah, ah
    jnz fail_status

    mov ax, 0x43A5
    mov bx, EMS_PAGES
    mov cx, 0x1357
    mov dx, 0x9BDF
    mov si, 0x2468
    mov di, 0x369A
    mov bp, 0x4ACE
    push cs
    pop es
    int 0x67
    test ah, ah
    jnz fail_alloc
    cmp al, 0xA5
    jne fail_alloc_regs
    cmp bx, EMS_PAGES
    jne fail_alloc_regs
    cmp cx, 0x1357
    jne fail_alloc_regs
    cmp si, 0x2468
    jne fail_alloc_regs
    cmp di, 0x369A
    jne fail_alloc_regs
    cmp bp, 0x4ACE
    jne fail_alloc_regs
    push cs
    pop ax
    push ds
    pop bx
    cmp bx, ax
    jne fail_alloc_regs
    push es
    pop bx
    cmp bx, ax
    jne fail_alloc_regs
    mov [ems_handle], dx

    call check_map_regs
    jc fail_map_regs
    call check_map_regs
    jc fail_map_again_regs

    mov ax, 0x4CA5
    mov bx, 0xBEEF
    mov cx, 0x1357
    mov dx, [ems_handle]
    mov si, 0x2468
    mov di, 0x369A
    mov bp, 0x4ACE
    push cs
    pop es
    int 0x67
    test ah, ah
    jnz fail_info
    cmp al, 0xA5
    jne fail_info_regs
    cmp bx, EMS_PAGES
    jne fail_info
    cmp cx, 0x1357
    jne fail_info_regs
    cmp dx, [ems_handle]
    jne fail_info_regs
    cmp si, 0x2468
    jne fail_info_regs
    cmp di, 0x369A
    jne fail_info_regs
    cmp bp, 0x4ACE
    jne fail_info_regs
    push cs
    pop ax
    push ds
    pop bx
    cmp bx, ax
    jne fail_info_regs
    push es
    pop bx
    cmp bx, ax
    jne fail_info_regs

    mov ax, 0x45A5
    mov bx, 0xBEEF
    mov cx, 0x1357
    mov dx, [ems_handle]
    mov si, 0x2468
    mov di, 0x369A
    mov bp, 0x4ACE
    push cs
    pop es
    int 0x67
    test ah, ah
    jnz fail_free
    cmp al, 0xA5
    jne fail_free_regs
    cmp bx, 0xBEEF
    jne fail_free_regs
    cmp cx, 0x1357
    jne fail_free_regs
    cmp dx, [ems_handle]
    jne fail_free_regs
    cmp si, 0x2468
    jne fail_free_regs
    cmp di, 0x369A
    jne fail_free_regs
    cmp bp, 0x4ACE
    jne fail_free_regs
    push cs
    pop ax
    push ds
    pop bx
    cmp bx, ax
    jne fail_free_regs
    push es
    pop bx
    cmp bx, ax
    jne fail_free_regs

    PASS_WITH pass_msg

check_map_regs:
    mov ax, 0x4403
    mov bx, 3
    mov cx, 0x1357
    mov dx, [ems_handle]
    mov si, 0x2468
    mov di, 0x369A
    mov bp, 0x4ACE
    push cs
    pop es
    int 0x67
    test ah, ah
    jnz .bad
    cmp al, 3
    jne .bad
    cmp bx, 3
    jne .bad
    cmp cx, 0x1357
    jne .bad
    cmp dx, [ems_handle]
    jne .bad
    cmp si, 0x2468
    jne .bad
    cmp di, 0x369A
    jne .bad
    cmp bp, 0x4ACE
    jne .bad
    push cs
    pop ax
    push ds
    pop bx
    cmp bx, ax
    jne .bad
    push es
    pop bx
    cmp bx, ax
    jne .bad
    clc
    ret
.bad:
    stc
    ret

fail_status:
    mov dx, fail_status_msg
    jmp fail
fail_alloc:
    mov dx, fail_alloc_msg
    jmp fail
fail_alloc_regs:
    mov dx, fail_alloc_regs_msg
    jmp fail
fail_map_regs:
    mov dx, fail_map_regs_msg
    jmp fail
fail_map_again_regs:
    mov dx, fail_map_again_regs_msg
    jmp fail
fail_info:
    mov dx, fail_info_msg
    jmp fail
fail_info_regs:
    mov dx, fail_info_regs_msg
    jmp fail
fail_free:
    mov dx, fail_free_msg
    jmp fail
fail_free_regs:
    mov dx, fail_free_regs_msg
fail:
    FAIL_WITH dx

ems_handle: dw 0
pass_msg: db "PASS: EMSPRESERVE", 13, 10, "$"
fail_status_msg: db "FAIL: EMSPRESERVE STATUS", 13, 10, "$"
fail_alloc_msg: db "FAIL: EMSPRESERVE ALLOC", 13, 10, "$"
fail_alloc_regs_msg: db "FAIL: EMSPRESERVE ALLOC REGS", 13, 10, "$"
fail_map_regs_msg: db "FAIL: EMSPRESERVE MAP REGS", 13, 10, "$"
fail_map_again_regs_msg: db "FAIL: EMSPRESERVE MAP2 REGS", 13, 10, "$"
fail_info_msg: db "FAIL: EMSPRESERVE INFO", 13, 10, "$"
fail_info_regs_msg: db "FAIL: EMSPRESERVE INFO REGS", 13, 10, "$"
fail_free_msg: db "FAIL: EMSPRESERVE FREE", 13, 10, "$"
fail_free_regs_msg: db "FAIL: EMSPRESERVE FREE REGS", 13, 10, "$"
