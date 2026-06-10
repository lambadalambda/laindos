[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es

    mov bx, 16
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [legit_env], ax
    mov es, ax
    xor di, di
    mov si, custom_var
.copy_custom:
    lodsb
    stosb
    test al, al
    jnz .copy_custom
    mov si, self_path
.copy_path:
    lodsb
    stosb
    test al, al
    jnz .copy_path
    xor ax, ax
    stosb
    mov ax, 1
    stosw
    mov si, self_path
.copy_path2:
    lodsb
    stosb
    test al, al
    jnz .copy_path2

    push cs
    pop es
    mov word [exec_params+0], 0xFFFF
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jnc fail_kernel_seg
    cmp ax, 8
    jne fail_kernel_code

    push cs
    pop es
    mov word [exec_params+0], 0x063F
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jnc fail_below_seg
    cmp ax, 8
    jne fail_below_code

    push cs
    pop es
    mov word [exec_params+0], 0x0010
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jnc fail_ivt_seg
    cmp ax, 8
    jne fail_ivt_code

    push cs
    pop es
    mov word [exec_params+0], 0x0040
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jnc fail_bda_seg
    cmp ax, 8
    jne fail_bda_code

    push cs
    pop es
    mov word [exec_params+0], 0xA000
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jnc fail_vga_seg
    cmp ax, 8
    jne fail_vga_code

    push cs
    pop es
    mov ax, [legit_env]
    mov [exec_params+0], ax
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_legit_seg

    push cs
    pop ds
    mov es, [legit_env]
    mov ah, 0x49
    int 0x21

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_alloc:
    mov dx, fail_alloc_msg
    jmp fail
fail_kernel_seg:
    mov dx, fail_kernel_msg
    jmp fail
fail_kernel_code:
    mov dx, fail_kernel_code_msg
    jmp fail
fail_below_seg:
    mov dx, fail_below_msg
    jmp fail
fail_below_code:
    mov dx, fail_below_code_msg
    jmp fail
fail_ivt_seg:
    mov dx, fail_ivt_msg
    jmp fail
fail_ivt_code:
    mov dx, fail_ivt_code_msg
    jmp fail
fail_bda_seg:
    mov dx, fail_bda_msg
    jmp fail
fail_bda_code:
    mov dx, fail_bda_code_msg
    jmp fail
fail_vga_seg:
    mov dx, fail_vga_msg
    jmp fail
fail_vga_code:
    mov dx, fail_vga_code_msg
    jmp fail
fail_legit_seg:
    mov dx, fail_legit_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

legit_env: dw 0
child_path: db ".\ENVCHILD.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
comspec_var: db "COMSPEC=A:\COMMAND.COM", 0
custom_var: db "CUSTOM=YES", 0
self_path: db "A:\ENVCHILD.COM", 0
pass_msg: db "PASS: EXECSEG", 13, 10, "$"
fail_alloc_msg: db "FAIL: EXECSEG ALLOC$"
fail_kernel_msg: db "FAIL: EXECSEG KERNEL ACC$"
fail_kernel_code_msg: db "FAIL: EXECSEG KERNEL CODE$"
fail_below_msg: db "FAIL: EXECSEG BELOW ACC$"
fail_below_code_msg: db "FAIL: EXECSEG BELOW CODE$"
fail_ivt_msg: db "FAIL: EXECSEG IVT ACC$"
fail_ivt_code_msg: db "FAIL: EXECSEG IVT CODE$"
fail_bda_msg: db "FAIL: EXECSEG BDA ACC$"
fail_bda_code_msg: db "FAIL: EXECSEG BDA CODE$"
fail_vga_msg: db "FAIL: EXECSEG VGA ACC$"
fail_vga_code_msg: db "FAIL: EXECSEG VGA CODE$"
fail_legit_msg: db "FAIL: EXECSEG LEGIT$"
