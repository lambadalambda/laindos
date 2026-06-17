%include "tests/programs/common.inc"

COM_START
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    jc fail_resize

    mov byte [runs_left], 80

.again:
    cmp byte [runs_left], 0
    je .passed
    push cs
    pop ds
    mov [exec_params+4], ds
    mov word [exec_params+2], empty_tail
    mov bx, exec_params
    mov dx, mid_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec

    mov ah, 0x4D
    int 0x21
    cmp ah, 0
    jne fail_child
    cmp al, 0
    jne fail_child

    dec byte [runs_left]
    jmp .again

.passed:
    PASS_WITH pass_msg

fail_resize:
    push cs
    pop ds
    FAIL_WITH fail_resize_msg
fail_exec:
    push cs
    pop ds
    FAIL_WITH fail_exec_msg
fail_child:
    push cs
    pop ds
    FAIL_WITH fail_child_msg

mid_path: db "NESTMID.COM", 0
empty_tail: db 0, 13
exec_params:
    dw 0
    dw empty_tail, 0
    dw 0, 0
    dw 0, 0
runs_left: db 0
pass_msg: db "PASS: NESTEXEC", 13, 10, "$"
fail_resize_msg: db "FAIL: NESTEXEC RESIZE", 13, 10, "$"
fail_exec_msg: db "FAIL: NESTEXEC EXEC", 13, 10, "$"
fail_child_msg: db "FAIL: NESTEXEC CHILD", 13, 10, "$"
