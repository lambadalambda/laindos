[bits 16]
[org 0x0100]

%include "src/memory.inc"

start:
    push cs
    pop ds
    push cs
    pop es
    mov ah, 0x62
    int 0x21
    mov [psp_seg], bx
    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec
    mov ah, 0x4D
    int 0x21
    cmp al, 0
    jne fail_child
    call check_mcb_owners
    jc fail_mcb
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_exec:
    mov dx, fail_exec_msg
    jmp fail
fail_child:
    mov dx, fail_child_msg
    jmp fail
fail_mcb:
    mov dx, fail_mcb_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

check_mcb_owners:
    push ax
    push ds
    push si
    mov si, MCB_START
.loop:
    mov ds, si
    cmp byte [0], 'M'
    je .check_owner
    cmp byte [0], 'Z'
    jne .bad
.check_owner:
    mov ax, [1]
    test ax, ax
    jz .owner_ok
    cmp ax, [cs:psp_seg]
    jne .bad
.owner_ok:
    cmp byte [0], 'Z'
    je .ok
    mov ax, [3]
    test ax, ax
    jz .bad
    add ax, si
    jc .bad
    inc ax
    jc .bad
    cmp ax, MEM_TOP
    jae .bad
    mov si, ax
    jmp .loop
.ok:
    clc
    jmp .done
.bad:
    stc
.done:
    pop si
    pop ds
    pop ax
    ret

child_path: db "ENVCHLD.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0
pass_msg: db "PASS: ENVMCB", 13, 10, "$"
fail_exec_msg: db "FAIL: ENVMCB EXEC", 13, 10, "$"
fail_child_msg: db "FAIL: ENVMCB CHILD", 13, 10, "$"
fail_mcb_msg: db "FAIL: ENVMCB MCB", 13, 10, "$"
psp_seg: dw 0
