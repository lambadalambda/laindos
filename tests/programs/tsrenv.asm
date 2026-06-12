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

    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec

    xor ax, ax
    mov es, ax
    mov ax, [es:0x04F0]
    test ax, ax
    jz fail_exec
    mov [env_seg], ax

    push cs
    pop es
    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, hello_path
    mov ax, 0x4B00
    int 0x21
    jc fail_alloc

    mov es, [env_seg]
    cmp word [es:0x0000], 'EN'
    jne fail_marker
    cmp word [es:0x0002], 'VM'
    jne fail_marker
    cmp word [es:0x0004], 'RK'
    jne fail_marker

    push cs
    pop ds
    mov dx, msg_pass
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_exec:
    push cs
    pop ds
    mov dx, msg_fail_exec
    jmp fail
fail_alloc:
    mov dx, msg_fail_alloc
    jmp fail
fail_marker:
    push cs
    pop ds
    mov dx, msg_fail_marker
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

env_seg: dw 0
child_path: db "TSRENVC.COM", 0
hello_path: db "HELLO.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
msg_pass:        db "PASS: TSRENV KEPT", 13, 10, '$'
msg_fail_exec:   db "FAIL: TSRENV EXEC", 13, 10, '$'
msg_fail_alloc:  db "FAIL: TSRENV EXEC2", 13, 10, '$'
msg_fail_marker: db "FAIL: TSRENV MARKER", 13, 10, '$'
