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

    mov ax, 0x5800
    int 0x21
    jc fail_get
    cmp ax, 0
    jne fail_get_value

    mov ax, 0x5801
    mov bx, 3
    int 0x21
    jnc fail_bad_set
    cmp ax, 1
    jne fail_bad_set

    mov ax, 0x5802
    int 0x21
    jnc fail_bad_func
    cmp ax, 1
    jne fail_bad_func

    mov ax, 0x5801
    xor bx, bx
    int 0x21
    jc fail_set

    mov bx, 0x0080
    call alloc_block
    mov [block_a], ax
    mov bx, 0x0030
    call alloc_block
    mov [block_b], ax
    mov bx, 0x0040
    call alloc_block
    mov [block_c], ax
    mov bx, 0x0030
    call alloc_block
    mov [block_d], ax

    mov es, [block_a]
    call free_block
    mov es, [block_c]
    call free_block

    mov ax, 0x5801
    xor bx, bx
    int 0x21
    jc fail_set
    mov bx, 0x0030
    call alloc_block
    cmp ax, [block_a]
    jne fail_first
    mov [tmp_block], ax
    mov es, ax
    call free_block

    mov ax, 0x5801
    mov bx, 1
    int 0x21
    jc fail_set
    mov bx, 0x0030
    call alloc_block
    cmp ax, [block_c]
    jne fail_best
    mov [tmp_block], ax
    mov es, ax
    call free_block

    mov ax, 0x5801
    mov bx, 2
    int 0x21
    jc fail_set
    mov bx, 0x0030
    call alloc_block
    cmp ax, [block_d]
    jbe fail_last
    mov [tmp_block], ax
    mov es, ax
    call free_block

    mov ax, 0x5801
    xor bx, bx
    int 0x21
    jc fail_set
    mov ax, 0x5800
    int 0x21
    jc fail_get
    cmp ax, 0
    jne fail_get_value

    mov es, [block_b]
    call free_block
    mov es, [block_d]
    call free_block

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

alloc_block:
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    ret

free_block:
    mov ah, 0x49
    int 0x21
    jc fail_free
    ret

fail_get:
    mov dx, fail_get_msg
    jmp fail
fail_get_value:
    mov dx, fail_get_value_msg
    jmp fail
fail_bad_set:
    mov dx, fail_bad_set_msg
    jmp fail
fail_bad_func:
    mov dx, fail_bad_func_msg
    jmp fail
fail_set:
    mov dx, fail_set_msg
    jmp fail
fail_alloc:
    mov dx, fail_alloc_msg
    jmp fail
fail_free:
    mov dx, fail_free_msg
    jmp fail
fail_first:
    mov dx, fail_first_msg
    jmp fail
fail_best:
    mov dx, fail_best_msg
    jmp fail
fail_last:
    mov dx, fail_last_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

block_a: dw 0
block_b: dw 0
block_c: dw 0
block_d: dw 0
tmp_block: dw 0
pass_msg: db "PASS: STRATAPI", 13, 10, "$"
fail_get_msg: db "FAIL: STRATAPI GET", 13, 10, "$"
fail_get_value_msg: db "FAIL: STRATAPI GET VALUE", 13, 10, "$"
fail_bad_set_msg: db "FAIL: STRATAPI BAD SET", 13, 10, "$"
fail_bad_func_msg: db "FAIL: STRATAPI BAD FUNC", 13, 10, "$"
fail_set_msg: db "FAIL: STRATAPI SET", 13, 10, "$"
fail_alloc_msg: db "FAIL: STRATAPI ALLOC", 13, 10, "$"
fail_free_msg: db "FAIL: STRATAPI FREE", 13, 10, "$"
fail_first_msg: db "FAIL: STRATAPI FIRST", 13, 10, "$"
fail_best_msg: db "FAIL: STRATAPI BEST", 13, 10, "$"
fail_last_msg: db "FAIL: STRATAPI LAST", 13, 10, "$"
