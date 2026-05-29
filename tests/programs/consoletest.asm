[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x06
    mov dl, 0xFF
    int 0x21
    jnz fail_status
    cmp ax, 0x0600
    jne fail_status

    mov dx, zero_line_buf
    mov ah, 0x0A
    int 0x21
    cmp byte [zero_line_buf+1], 0
    jne fail_line_zero

    mov ah, 0x02
    mov dl, 't'
    int 0x21
    cmp al, 't'
    jne fail_output

    mov ah, 0x06
    mov dl, 'o'
    int 0x21
    cmp al, 'o'
    jne fail_output

    mov dx, ready_msg
    mov ah, 0x09
    int 0x21

    mov ah, 0x01
    int 0x21
    cmp al, 'a'
    jne fail_read_echo

    mov ah, 0x07
    int 0x21
    cmp al, 'b'
    jne fail_read_direct

    mov ah, 0x08
    int 0x21
    cmp al, 'c'
    jne fail_read_08

.poll:
    mov ah, 0x06
    mov dl, 0xFF
    int 0x21
    jz .poll
    cmp al, 'd'
    jne fail_poll

    mov dx, line_buf
    mov ah, 0x0A
    int 0x21
    cmp byte [line_buf+1], 2
    jne fail_line
    cmp byte [line_buf+2], 'x'
    jne fail_line
    cmp byte [line_buf+3], 'z'
    jne fail_line
    cmp byte [line_buf+4], 13
    jne fail_line

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_status:
    mov dx, fail_status_msg
    jmp fail
fail_output:
    mov dx, fail_output_msg
    jmp fail
fail_read_echo:
    mov dx, fail_read_echo_msg
    jmp fail
fail_read_direct:
    mov dx, fail_read_direct_msg
    jmp fail
fail_read_08:
    mov dx, fail_read_08_msg
    jmp fail
fail_poll:
    mov dx, fail_poll_msg
    jmp fail
fail_line:
    mov dx, fail_line_msg
    jmp fail
fail_line_zero:
    mov dx, fail_line_zero_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

ready_msg: db "READY: CONSOLE", 13, 10, "$"
pass_msg: db 13, 10, "PASS: CONSOLE", 13, 10, "$"
fail_status_msg: db "FAIL: CONSOLE STATUS", 13, 10, "$"
fail_output_msg: db "FAIL: CONSOLE OUTPUT", 13, 10, "$"
fail_read_echo_msg: db "FAIL: CONSOLE READ ECHO", 13, 10, "$"
fail_read_direct_msg: db "FAIL: CONSOLE READ DIRECT", 13, 10, "$"
fail_read_08_msg: db "FAIL: CONSOLE READ 08", 13, 10, "$"
fail_poll_msg: db "FAIL: CONSOLE POLL", 13, 10, "$"
fail_line_msg: db "FAIL: CONSOLE LINE", 13, 10, "$"
fail_line_zero_msg: db "FAIL: CONSOLE LINE ZERO", 13, 10, "$"
zero_line_buf: db 0, 0xCC
line_buf: db 8, 0, 0, 0, 0, 0, 0, 0, 0, 0
