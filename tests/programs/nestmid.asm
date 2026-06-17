%include "tests/programs/common.inc"

COM_START
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    jc fail_resize

    mov [exec_params+4], ds
    mov word [exec_params+2], empty_tail
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec

    mov ah, 0x4D
    int 0x21
    cmp ah, 0
    jne fail_child
    cmp al, 0x5A
    jne fail_child

    EXIT_CODE 0

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

child_path: db "NESTCHD.COM", 0
empty_tail: db 0, 13
exec_params:
    dw 0
    dw empty_tail, 0
    dw 0, 0
    dw 0, 0
fail_resize_msg: db "FAIL: NESTMID RESIZE", 13, 10, "$"
fail_exec_msg: db "FAIL: NESTMID EXEC", 13, 10, "$"
fail_child_msg: db "FAIL: NESTMID CHILD", 13, 10, "$"
