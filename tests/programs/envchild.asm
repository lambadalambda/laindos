[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov ah, 0x62
    int 0x21
    mov es, bx
    mov ax, [es:0x2C]
    test ax, ax
    jz fail_env
    mov es, ax
    mov si, custom_var
    call find_var
    jc fail_custom
    call find_env_tail
    jc fail_tail
    cmp word [es:di], 1
    jne fail_tail
    add di, 2
    mov si, self_path
    call match_value
    jc fail_tail
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

find_var:
    push ax
    push bx
    push dx
    push si
    mov dx, si
    xor bx, bx
.next_string:
    cmp byte [es:bx], 0
    je .not_found
    mov si, dx
    mov di, bx
.compare:
    lodsb
    test al, al
    jz .found
    cmp al, [es:di]
    jne .skip_string
    inc di
    jmp .compare
.skip_string:
    mov di, bx
.skip_loop:
    cmp byte [es:di], 0
    je .skipped
    inc di
    jmp .skip_loop
.skipped:
    lea bx, [di+1]
    jmp .next_string
.found:
    pop si
    pop dx
    pop bx
    pop ax
    clc
    ret
.not_found:
    pop si
    pop dx
    pop bx
    pop ax
    stc
    ret

match_value:
    push ax
    push si
    push di
.loop:
    lodsb
    cmp al, [es:di]
    jne .no
    inc di
    test al, al
    jnz .loop
    pop di
    pop si
    pop ax
    clc
    ret
.no:
    pop di
    pop si
    pop ax
    stc
    ret

find_env_tail:
    xor di, di
.string:
    cmp byte [es:di], 0
    je .end_string
    inc di
    jmp .string
.end_string:
    cmp byte [es:di+1], 0
    je .found_tail
    inc di
    jmp .string
.found_tail:
    add di, 2
    clc
    ret

fail_env:
    mov dx, fail_env_msg
    jmp fail
fail_custom:
    mov dx, fail_custom_msg
    jmp fail
fail_tail:
    mov dx, fail_tail_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

custom_var: db "CUSTOM=YES", 0
self_path: db "A:\ENVCHILD.COM", 0
pass_msg: db "PASS: ENVCHILD", 13, 10, "$"
fail_env_msg: db "FAIL: ENVCHILD ENV", 13, 10, "$"
fail_custom_msg: db "FAIL: ENVCHILD CUSTOM", 13, 10, "$"
fail_tail_msg: db "FAIL: ENVCHILD TAIL", 13, 10, "$"
