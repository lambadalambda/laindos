[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    mov dx, dta
    mov ah, 0x1A
    int 0x21

    mov dx, subdir_name
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, subdir_name
    mov ah, 0x3B
    int 0x21
    jc fail_chdir

    mov bx, 1
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [path_seg], ax
    push ax
    pop es
    xor di, di
    mov al, '\'
    stosb
    mov si, root_file_name
.copy_path:
    lodsb
    stosb
    test al, al
    jnz .copy_path

    push cs
    pop ds
    mov ax, [path_seg]
    mov ds, ax
    xor dx, dx
    mov cx, 0x00
    mov ah, 0x4E
    int 0x21
    jc fail_findfirst

    push cs
    pop ds
    mov al, [dta+30]
    cmp al, 'F'
    jne fail_dta
    mov al, [dta+31]
    cmp al, 'F'
    jne fail_dta

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_mkdir:
    mov dx, fail_mkdir_msg
    jmp fail
fail_chdir:
    mov dx, fail_chdir_msg
    jmp fail
fail_alloc:
    mov dx, fail_alloc_msg
    jmp fail
fail_findfirst:
    mov dx, fail_findfirst_msg
    jmp fail
fail_dta:
    mov dx, fail_dta_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

path_seg: dw 0
subdir_name: db "FFSUBD", 0
root_file_name: db "FFROOT.DAT", 0
dta: times 43 db 0
pass_msg: db "PASS: FFROOT", 13, 10, "$"
fail_mkdir_msg: db "FAIL: FFROOT MKDIR$"
fail_chdir_msg: db "FAIL: FFROOT CHDIR$"
fail_alloc_msg: db "FAIL: FFROOT ALLOC$"
fail_findfirst_msg: db "FAIL: FFROOT FINDFIRST$"
fail_dta_msg: db "FAIL: FFROOT DTA$"
