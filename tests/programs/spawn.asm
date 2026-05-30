[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es

    mov dx, data_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    cmp ax, 5
    jne fail_open
    mov [data_handle], ax

    mov [exec_params+4], ds
    mov word [exec_params+2], cmd_tail_close
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec

    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_child

    mov bx, [data_handle]
    mov dx, read_buf
    mov cx, 1
    mov ah, 0x3F
    int 0x21
    jc fail_inherit
    cmp ax, 1
    jne fail_inherit
    cmp byte [read_buf], '!'
    jne fail_inherit

    mov bx, [data_handle]
    xor cx, cx
    xor dx, dx
    xor al, al
    mov ah, 0x42
    int 0x21
    jc fail_seek

    mov word [exec_params+2], cmd_tail_keep
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec

    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_child

    mov bx, [data_handle]
    mov dx, read_buf
    mov cx, 1
    mov ah, 0x3F
    int 0x21
    jc fail_inherit
    cmp ax, 1
    jne fail_inherit
    cmp byte [read_buf], '!'
    jne fail_inherit

    mov bx, [data_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, data_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_reopen
    cmp ax, 5
    jne fail_reopen
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open:
    push cs
    pop ds
    mov dx, fail_open_msg
    jmp fail
fail_exec:
    push cs
    pop ds
    mov dx, fail_exec_msg
    jmp fail
fail_child:
    push cs
    pop ds
    mov dx, fail_child_msg
    jmp fail
fail_inherit:
    push cs
    pop ds
    mov dx, fail_inherit_msg
    jmp fail
fail_seek:
    push cs
    pop ds
    mov dx, fail_seek_msg
    jmp fail
fail_reopen:
    push cs
    pop ds
    mov dx, fail_reopen_msg
    jmp fail
fail_close:
    push cs
    pop ds
    mov dx, fail_close_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

data_name: db "SPAWNDAT.TXT", 0
child_path: db "SPAWNCH.COM", 0
cmd_tail_close: db 3, " 5C", 13
cmd_tail_keep: db 3, " 5K", 13
exec_params:
    dw 0
    dw cmd_tail_close, 0
    dw 0, 0
    dw 0, 0
data_handle: dw 0
read_buf: db 0
pass_msg: db "PASS: SPAWN", 13, 10, "$"
fail_open_msg: db "FAIL: SPAWN OPEN", 13, 10, "$"
fail_exec_msg: db "FAIL: SPAWN EXEC", 13, 10, "$"
fail_child_msg: db "FAIL: SPAWN CHILD", 13, 10, "$"
fail_inherit_msg: db "FAIL: SPAWN INHERIT", 13, 10, "$"
fail_seek_msg: db "FAIL: SPAWN SEEK", 13, 10, "$"
fail_reopen_msg: db "FAIL: SPAWN REOPEN", 13, 10, "$"
fail_close_msg: db "FAIL: SPAWN CLOSE", 13, 10, "$"
