[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov bx, 6
    mov ah, 0x67
    int 0x21
    jc fail_set_count

    call query_handle_count
    jc fail_query_base
    mov [base_count], ax

    mov dx, fail_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jnc fail_expected_create_error
    cmp ax, 5
    jne fail_expected_create_error

    call query_handle_count
    jc fail_query_after
    cmp ax, [base_count]
    jne fail_leak

    mov dx, ok_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create_ok
    mov [ok_handle], ax

    call query_handle_count
    jc fail_query_open
    mov bx, [base_count]
    inc bx
    cmp ax, bx
    jne fail_open_count

    mov bx, [ok_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    call query_handle_count
    jc fail_query_closed
    cmp ax, [base_count]
    jne fail_close_count

    mov dx, ok_name
    mov ax, 0x3D00
    int 0x21
    jc fail_open_ok
    mov [ok_handle], ax

    mov bx, [ok_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close


    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

query_handle_count:
    mov ax, 0xF000
    int 0x21
    ret

fail_set_count:
    mov dx, fail_set_count_msg
    jmp fail
fail_query_base:
    mov dx, fail_query_base_msg
    jmp fail
fail_expected_create_error:
    mov dx, fail_expected_create_error_msg
    jmp fail
fail_query_after:
    mov dx, fail_query_after_msg
    jmp fail
fail_leak:
    mov dx, fail_leak_msg
    jmp fail
fail_create_ok:
    mov dx, fail_create_ok_msg
    jmp fail
fail_query_open:
    mov dx, fail_query_open_msg
    jmp fail
fail_open_count:
    mov dx, fail_open_count_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_query_closed:
    mov dx, fail_query_closed_msg
    jmp fail
fail_close_count:
    mov dx, fail_close_count_msg
    jmp fail
fail_open_ok:
    mov dx, fail_open_ok_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fail_name: db "FAILONE.DAT", 0
ok_name: db "OKFILE.DAT", 0
base_count: dw 0
ok_handle: dw 0

pass_msg: db "PASS: HANDLELEAK", 13, 10, "$"
fail_set_count_msg: db "FAIL: HANDLELEAK SET COUNT", 13, 10, "$"
fail_query_base_msg: db "FAIL: HANDLELEAK QUERY BASE", 13, 10, "$"
fail_expected_create_error_msg: db "FAIL: HANDLELEAK EXPECTED CREATE ERROR", 13, 10, "$"
fail_query_after_msg: db "FAIL: HANDLELEAK QUERY AFTER", 13, 10, "$"
fail_leak_msg: db "FAIL: HANDLELEAK COUNT LEAK", 13, 10, "$"
fail_create_ok_msg: db "FAIL: HANDLELEAK CREATE OK", 13, 10, "$"
fail_query_open_msg: db "FAIL: HANDLELEAK QUERY OPEN", 13, 10, "$"
fail_open_count_msg: db "FAIL: HANDLELEAK OPEN COUNT", 13, 10, "$"
fail_close_msg: db "FAIL: HANDLELEAK CLOSE", 13, 10, "$"
fail_query_closed_msg: db "FAIL: HANDLELEAK QUERY CLOSED", 13, 10, "$"
fail_close_count_msg: db "FAIL: HANDLELEAK CLOSE COUNT", 13, 10, "$"
fail_open_ok_msg: db "FAIL: HANDLELEAK OPEN OK", 13, 10, "$"
