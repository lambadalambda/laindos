[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    mov [exec_params+4], ds
    mov [exec_params+8], ds
    mov [exec_params+12], ds

    mov word [exec_params+2], short_tail
    mov [exec_params+4], ds
    call run_child
    jc fail_short

    push cs
    pop ds
    mov word [exec_params+2], long_tail
    mov [exec_params+4], ds
    call run_child
    jc fail_long

    push cs
    pop ds
    mov word [exec_params+2], long_tail
    mov word [exec_params+4], 0x0340
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jnc fail_kernel_seg
    cmp ax, 8
    jne fail_kernel_code

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

run_child:
    push bx
    push dx
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc .err
    mov ah, 0x4D
    int 0x21
    cmp ax, 0x0033
    jne .err
    pop dx
    pop bx
    clc
    ret
.err:
    pop dx
    pop bx
    stc
    ret

fail_short:
    push cs
    pop ds
    mov dx, fail_short_msg
    jmp fail
fail_long:
    push cs
    pop ds
    mov dx, fail_long_msg
    jmp fail
fail_kernel_seg:
    push cs
    pop ds
    mov dx, fail_kernel_seg_msg
    jmp fail
fail_kernel_code:
    push cs
    pop ds
    mov dx, fail_kernel_code_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

child_path: db "TAILCHK.COM", 0
short_tail: db 0, 13, "LEAKED-BY-FIXED-COPY"
long_tail: db 200
%assign i 0
%rep 200
    db 'A' + (i % 26)
%assign i i + 1
%endrep
    db 13
exec_params:
    dw 0
    dw short_tail, 0
    dw fcb1, 0
    dw fcb2, 0
fcb1: times 16 db 0
fcb2: times 16 db 0
pass_msg: db "PASS: EXECTAIL", 13, 10, "$"
fail_short_msg: db "FAIL: EXECTAIL SHORT", 13, 10, "$"
fail_long_msg: db "FAIL: EXECTAIL LONG", 13, 10, "$"
fail_kernel_seg_msg: db "FAIL: EXECTAIL KERNEL ACC", 13, 10, "$"
fail_kernel_code_msg: db "FAIL: EXECTAIL KERNEL CODE", 13, 10, "$"
