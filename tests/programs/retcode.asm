[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    mov [exec_params+4], ds

    mov cl, 0
    call check_return

    mov dx, missing_path
    call expect_exec_fail
    mov cl, 0
    call check_return

    mov dx, ret7_path
    call exec_child
    mov dx, missing_path
    call expect_exec_fail
    mov cl, 7
    call check_return
    mov cl, 0
    call check_return

    mov dx, ret42_path
    call exec_child
    mov cl, 42
    call check_return
    mov cl, 0
    call check_return

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

exec_child:
    mov bx, exec_params
    mov ax, 0x4B00
    int 0x21
    jc fail_exec
    ret

expect_exec_fail:
    mov bx, exec_params
    mov ax, 0x4B00
    int 0x21
    jnc fail_exec_missing
    ret

check_return:
    mov [expected_code], cl
    mov ah, 0x4D
    int 0x21
    test ah, ah
    jnz fail_return_type
    cmp al, [expected_code]
    jne fail_return_code
    ret

fail_exec:
    mov dx, fail_exec_msg
    jmp fail
fail_exec_missing:
    mov dx, fail_exec_missing_msg
    jmp fail
fail_return_type:
    mov dx, fail_return_type_msg
    jmp fail
fail_return_code:
    mov dx, fail_return_code_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

expected_code: db 0
ret7_path: db "RET7.COM", 0
ret42_path: db "RET42.COM", 0
missing_path: db "MISSING.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0
pass_msg: db "PASS: RETCODE", 13, 10, "$"
fail_exec_msg: db "FAIL: RETCODE EXEC", 13, 10, "$"
fail_exec_missing_msg: db "FAIL: RETCODE MISSING", 13, 10, "$"
fail_return_type_msg: db "FAIL: RETCODE TYPE", 13, 10, "$"
fail_return_code_msg: db "FAIL: RETCODE CODE", 13, 10, "$"
