[bits 16]
[org 0x0100]

ATTR_ARCHIVE equ 0x20
ATTR_RDONLY equ 0x01

ES_SENT equ 0x7777
BX_SENT equ 0x3333
CX_SENT equ 0x1357
DX_SENT equ 0x2468
SI_SENT equ 0x4812
DI_SENT equ 0x9ABC

start:
    push cs
    pop ds

    mov ax, ES_SENT
    mov es, ax
    mov bx, BX_SENT
    mov cx, CX_SENT
    mov dx, file_name
    mov si, SI_SENT
    mov di, DI_SENT
    mov ax, 0x3D02
    int 0x21
    jc fail_open
    mov [handle], ax
    mov ax, es
    cmp ax, ES_SENT
    jne fail_open_regs
    cmp bx, BX_SENT
    jne fail_open_regs
    cmp cx, CX_SENT
    jne fail_open_regs
    cmp dx, file_name
    jne fail_open_regs
    cmp si, SI_SENT
    jne fail_open_regs
    cmp di, DI_SENT
    jne fail_open_regs

    mov ax, ES_SENT
    mov es, ax
    mov bx, [handle]
    mov cx, CX_SENT
    mov dx, DX_SENT
    mov si, SI_SENT
    mov di, DI_SENT
    mov ah, 0x3E
    int 0x21
    jc fail_close
    mov ax, es
    cmp ax, ES_SENT
    jne fail_close_regs
    cmp bx, [handle]
    jne fail_close_regs
    cmp cx, CX_SENT
    jne fail_close_regs
    cmp dx, DX_SENT
    jne fail_close_regs
    cmp si, SI_SENT
    jne fail_close_regs
    cmp di, DI_SENT
    jne fail_close_regs

    mov ax, ES_SENT
    mov es, ax
    mov bx, 0x00FE
    mov cx, CX_SENT
    mov dx, DX_SENT
    mov si, SI_SENT
    mov di, DI_SENT
    mov ah, 0x3E
    int 0x21
    jnc fail_close_invalid
    mov ax, es
    cmp ax, ES_SENT
    jne fail_close_invalid_regs
    cmp bx, 0x00FE
    jne fail_close_invalid_regs
    cmp cx, CX_SENT
    jne fail_close_invalid_regs
    cmp dx, DX_SENT
    jne fail_close_invalid_regs
    cmp si, SI_SENT
    jne fail_close_invalid_regs
    cmp di, DI_SENT
    jne fail_close_invalid_regs

    mov ax, ES_SENT
    mov es, ax
    mov bx, BX_SENT
    mov cx, CX_SENT
    mov dx, missing_name
    mov si, SI_SENT
    mov di, DI_SENT
    mov ax, 0x3D00
    int 0x21
    jnc fail_open_missing
    mov ax, es
    cmp ax, ES_SENT
    jne fail_open_missing_regs
    cmp bx, BX_SENT
    jne fail_open_missing_regs
    cmp cx, CX_SENT
    jne fail_open_missing_regs
    cmp dx, missing_name
    jne fail_open_missing_regs
    cmp si, SI_SENT
    jne fail_open_missing_regs
    cmp di, DI_SENT
    jne fail_open_missing_regs

    mov ax, ES_SENT
    mov es, ax
    mov bx, BX_SENT
    mov dx, file_name
    mov si, SI_SENT
    mov di, DI_SENT
    mov ax, 0x4300
    int 0x21
    jc fail_attr_get
    cmp cx, ATTR_ARCHIVE
    jne fail_attr_get_value
    mov ax, es
    cmp ax, ES_SENT
    jne fail_attr_get_regs
    cmp bx, BX_SENT
    jne fail_attr_get_regs
    cmp dx, file_name
    jne fail_attr_get_regs
    cmp si, SI_SENT
    jne fail_attr_get_regs
    cmp di, DI_SENT
    jne fail_attr_get_regs

    mov ax, ES_SENT
    mov es, ax
    mov bx, BX_SENT
    mov cx, ATTR_ARCHIVE | ATTR_RDONLY
    mov dx, file_name
    mov si, SI_SENT
    mov di, DI_SENT
    mov ax, 0x4301
    int 0x21
    jc fail_attr_set
    mov ax, es
    cmp ax, ES_SENT
    jne fail_attr_set_regs
    cmp bx, BX_SENT
    jne fail_attr_set_regs
    cmp cx, ATTR_ARCHIVE | ATTR_RDONLY
    jne fail_attr_set_regs
    cmp dx, file_name
    jne fail_attr_set_regs
    cmp si, SI_SENT
    jne fail_attr_set_regs
    cmp di, DI_SENT
    jne fail_attr_set_regs

    mov dx, file_name
    mov ax, 0x4300
    int 0x21
    jc fail_attr_get
    cmp cx, ATTR_ARCHIVE | ATTR_RDONLY
    jne fail_attr_set_value

    mov ax, ES_SENT
    mov es, ax
    mov bx, BX_SENT
    mov cx, CX_SENT
    mov dx, missing_name
    mov si, SI_SENT
    mov di, DI_SENT
    mov ax, 0x4300
    int 0x21
    jnc fail_attr_missing
    mov ax, es
    cmp ax, ES_SENT
    jne fail_attr_missing_regs
    cmp bx, BX_SENT
    jne fail_attr_missing_regs
    cmp cx, CX_SENT
    jne fail_attr_missing_regs
    cmp dx, missing_name
    jne fail_attr_missing_regs
    cmp si, SI_SENT
    jne fail_attr_missing_regs
    cmp di, DI_SENT
    jne fail_attr_missing_regs

    mov ax, ES_SENT
    mov es, ax
    mov bx, BX_SENT
    mov cx, ATTR_ARCHIVE | ATTR_RDONLY
    mov dx, missing_name
    mov si, SI_SENT
    mov di, DI_SENT
    mov ax, 0x4301
    int 0x21
    jnc fail_attr_missing
    mov ax, es
    cmp ax, ES_SENT
    jne fail_attr_missing_regs
    cmp bx, BX_SENT
    jne fail_attr_missing_regs
    cmp cx, ATTR_ARCHIVE | ATTR_RDONLY
    jne fail_attr_missing_regs
    cmp dx, missing_name
    jne fail_attr_missing_regs
    cmp si, SI_SENT
    jne fail_attr_missing_regs
    cmp di, DI_SENT
    jne fail_attr_missing_regs

    mov bx, 0x0030
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [block], ax

    mov es, ax
    mov bx, BX_SENT
    mov cx, CX_SENT
    mov dx, DX_SENT
    mov si, SI_SENT
    mov di, DI_SENT
    mov ah, 0x49
    int 0x21
    jc fail_free
    mov ax, es
    cmp ax, [block]
    jne fail_free_regs
    cmp bx, BX_SENT
    jne fail_free_regs
    cmp cx, CX_SENT
    jne fail_free_regs
    cmp dx, DX_SENT
    jne fail_free_regs
    cmp si, SI_SENT
    jne fail_free_regs
    cmp di, DI_SENT
    jne fail_free_regs

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_open_regs:
    mov dx, fail_open_regs_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_close_regs:
    mov dx, fail_close_regs_msg
    jmp fail
fail_close_invalid:
    mov dx, fail_close_invalid_msg
    jmp fail
fail_close_invalid_regs:
    mov dx, fail_close_invalid_regs_msg
    jmp fail
fail_open_missing:
    mov dx, fail_open_missing_msg
    jmp fail
fail_open_missing_regs:
    mov dx, fail_open_missing_regs_msg
    jmp fail
fail_attr_get:
    mov dx, fail_attr_get_msg
    jmp fail
fail_attr_get_regs:
    mov dx, fail_attr_get_regs_msg
    jmp fail
fail_attr_get_value:
    mov dx, fail_attr_get_value_msg
    jmp fail
fail_attr_set:
    mov dx, fail_attr_set_msg
    jmp fail
fail_attr_set_regs:
    mov dx, fail_attr_set_regs_msg
    jmp fail
fail_attr_set_value:
    mov dx, fail_attr_set_value_msg
    jmp fail
fail_attr_missing:
    mov dx, fail_attr_missing_msg
    jmp fail
fail_attr_missing_regs:
    mov dx, fail_attr_missing_regs_msg
    jmp fail
fail_alloc:
    mov dx, fail_alloc_msg
    jmp fail
fail_free:
    mov dx, fail_free_msg
    jmp fail
fail_free_regs:
    mov dx, fail_free_regs_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
block: dw 0
file_name: db "TESTFILE.DAT", 0
missing_name: db "MISSING.DAT", 0
pass_msg: db "PASS: REGPRES", 13, 10, "$"
fail_open_msg: db "FAIL: REGPRES OPEN", 13, 10, "$"
fail_open_regs_msg: db "FAIL: REGPRES OPEN REGS", 13, 10, "$"
fail_close_msg: db "FAIL: REGPRES CLOSE", 13, 10, "$"
fail_close_regs_msg: db "FAIL: REGPRES CLOSE REGS", 13, 10, "$"
fail_close_invalid_msg: db "FAIL: REGPRES CLOSE INVALID", 13, 10, "$"
fail_close_invalid_regs_msg: db "FAIL: REGPRES CLOSE INVALID REGS", 13, 10, "$"
fail_open_missing_msg: db "FAIL: REGPRES OPEN MISSING", 13, 10, "$"
fail_open_missing_regs_msg: db "FAIL: REGPRES OPEN MISSING REGS", 13, 10, "$"
fail_attr_get_msg: db "FAIL: REGPRES ATTR GET", 13, 10, "$"
fail_attr_get_regs_msg: db "FAIL: REGPRES ATTR GET REGS", 13, 10, "$"
fail_attr_get_value_msg: db "FAIL: REGPRES ATTR GET VALUE", 13, 10, "$"
fail_attr_set_msg: db "FAIL: REGPRES ATTR SET", 13, 10, "$"
fail_attr_set_regs_msg: db "FAIL: REGPRES ATTR SET REGS", 13, 10, "$"
fail_attr_set_value_msg: db "FAIL: REGPRES ATTR SET VALUE", 13, 10, "$"
fail_attr_missing_msg: db "FAIL: REGPRES ATTR MISSING", 13, 10, "$"
fail_attr_missing_regs_msg: db "FAIL: REGPRES ATTR MISSING REGS", 13, 10, "$"
fail_alloc_msg: db "FAIL: REGPRES ALLOC", 13, 10, "$"
fail_free_msg: db "FAIL: REGPRES FREE", 13, 10, "$"
fail_free_regs_msg: db "FAIL: REGPRES FREE REGS", 13, 10, "$"
