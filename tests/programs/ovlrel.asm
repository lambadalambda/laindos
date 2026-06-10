[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x48
    mov bx, 0x0040
    int 0x21
    jc fail_alloc
    mov [load_seg], ax

    mov [ovl_params], ax
    mov [ovl_params+2], ax
    mov bx, ovl_params
    mov dx, ovl_name
    mov ax, 0x4B03
    int 0x21
    jc fail_load
    mov dx, msg_load
    mov ah, 0x09
    int 0x21

    mov ax, [load_seg]
    add ax, 0x1111
    mov bx, ax
    mov es, [load_seg]
    cmp [es:0x0000], bx
    jne fail_patch
    cmp [es:0x00C8], bx
    jne fail_patch
    cmp [es:0x018C], bx
    jne fail_patch
    mov dx, msg_patch
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_alloc:
    mov dx, msg_fail_alloc
    jmp fail
fail_load:
    mov dx, msg_fail_load
    jmp fail
fail_patch:
    mov dx, msg_fail_patch
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

load_seg: dw 0
ovl_params: dw 0, 0
ovl_name: db "OVLREL.OVL", 0
msg_load:       db "PASS: OVLREL LOAD", 13, 10, '$'
msg_patch:      db "PASS: OVLREL PATCH", 13, 10, '$'
msg_fail_alloc: db "FAIL: OVLREL ALLOC", 13, 10, '$'
msg_fail_load:  db "FAIL: OVLREL LOAD", 13, 10, '$'
msg_fail_patch: db "FAIL: OVLREL PATCH", 13, 10, '$'
