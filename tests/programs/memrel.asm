[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    push cs
    pop es
    mov [exec_params+4], ds

    call largest_free
    mov [before_largest], bx

    call run_child
    call check_return
    call check_largest_restored

    call run_child
    call check_return
    call check_largest_restored

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

largest_free:
    mov bx, 0xFFFF
    mov ah, 0x48
    int 0x21
    jnc fail_largest
    cmp ax, 8
    jne fail_largest
    ret

run_child:
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec
    ret

check_return:
    mov ah, 0x4D
    int 0x21
    test ah, ah
    jnz fail_child
    test al, al
    jnz fail_child
    ret

check_largest_restored:
    call largest_free
    cmp bx, [before_largest]
    jne fail_leak
    ret

fail_largest:
    mov dx, fail_largest_msg
    jmp fail
fail_exec:
    mov dx, fail_exec_msg
    jmp fail
fail_child:
    mov dx, fail_child_msg
    jmp fail
fail_leak:
    mov dx, fail_leak_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

before_largest: dw 0
child_path: db "MEMRCHLD.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0
pass_msg: db "PASS: MEMREL", 13, 10, "$"
fail_largest_msg: db "FAIL: MEMREL LARGEST", 13, 10, "$"
fail_exec_msg: db "FAIL: MEMREL EXEC", 13, 10, "$"
fail_child_msg: db "FAIL: MEMREL CHILD", 13, 10, "$"
fail_leak_msg: db "FAIL: MEMREL LEAK", 13, 10, "$"
