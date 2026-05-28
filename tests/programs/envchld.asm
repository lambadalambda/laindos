[bits 16]
[org 0x0100]

%include "src/memory.inc"

start:
    mov ah, 0x62
    int 0x21
    mov [psp_seg], bx
    mov ds, bx
    mov ax, [0x2C]
    test ax, ax
    jz fail
    cmp ax, MCB_START
    jb fail
    mov [env_seg], ax
    dec ax
    mov ds, ax
    mov al, [0]
    cmp al, 'M'
    je sig_ok
    cmp al, 'Z'
    jne fail
sig_ok:
    mov ax, [1]
    cmp ax, [cs:psp_seg]
    jne fail
    cmp word [3], ENV_PARAS
    jb fail
    mov ax, [cs:env_seg]
    mov ds, ax
    xor si, si
    mov di, comspec_name
    mov cx, comspec_len
check_comspec:
    mov al, [si]
    cmp al, [cs:di]
    jne fail
    inc si
    inc di
    loop check_comspec
    mov ax, 0x4C00
    int 0x21

fail:
    mov ax, 0x4C01
    int 0x21

comspec_name: db "COMSPEC="
comspec_len equ $ - comspec_name
psp_seg: dw 0
env_seg: dw 0
