[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x62
    int 0x21
    mov es, bx
    cmp byte [es:0x80], 3
    jne fail_tail
    cmp byte [es:0x81], ' '
    jne fail_tail
    cmp byte [es:0x82], '5'
    jne fail_tail
    mov al, [es:0x83]
    cmp al, 'C'
    je .tail_ok
    cmp al, 'K'
    jne fail_tail
.tail_ok:
    mov [close_flag], al
    cmp byte [es:0x18+5], 5
    jne fail_jft

    mov bx, 5
    mov dx, read_buf
    mov cx, 5
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 5
    jne fail_read
    mov si, expected
    mov di, read_buf
    mov cx, 5
    repe cmpsb
    jne fail_read

    cmp byte [close_flag], 'C'
    jne .done
    mov bx, 5
    mov ah, 0x3E
    int 0x21
    jc fail_close

.done:
    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_tail:
    push cs
    pop ds
    mov dx, fail_tail_msg
    jmp fail
fail_jft:
    push cs
    pop ds
    mov dx, fail_jft_msg
    jmp fail
fail_read:
    push cs
    pop ds
    mov dx, fail_read_msg
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

expected: db "SPAWN"
close_flag: db 0
read_buf: times 5 db 0
pass_msg: db "PASS: SPAWNCH", 13, 10, "$"
fail_tail_msg: db "FAIL: SPAWNCH TAIL", 13, 10, "$"
fail_jft_msg: db "FAIL: SPAWNCH JFT", 13, 10, "$"
fail_read_msg: db "FAIL: SPAWNCH READ", 13, 10, "$"
fail_close_msg: db "FAIL: SPAWNCH CLOSE", 13, 10, "$"
