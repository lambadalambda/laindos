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

    mov bx, 0xFFFF
    mov ah, 0x48
    int 0x21
    jnc fail_alloc_too_big
    cmp ax, 8
    jne fail_alloc_too_big
    test bx, bx
    jz fail_alloc_largest
    cmp bx, 0xFFFF
    jae fail_alloc_largest

    mov ax, 0x0001
    mov es, ax
    mov ah, 0x49
    int 0x21
    jnc fail_free_invalid
    cmp ax, 9
    jne fail_free_invalid

    mov ax, 0x0001
    mov es, ax
    mov bx, 0x0020
    mov ah, 0x4A
    int 0x21
    jnc fail_resize_invalid
    cmp ax, 9
    jne fail_resize_invalid

    mov bx, 0x0020
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [block_a], ax
    mov bx, 0x0020
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [block_b], ax

    mov es, [block_a]
    mov bx, 0x0080
    mov ah, 0x4A
    int 0x21
    jnc fail_resize_grow
    cmp ax, 8
    jne fail_resize_grow
    cmp bx, 0x0020
    jne fail_resize_largest
    mov ax, [block_a]
    dec ax
    mov es, ax
    cmp word [es:3], 0x0020
    jne fail_resize_changed

    mov es, [block_b]
    mov ah, 0x49
    int 0x21
    jc fail_free
    mov es, [block_a]
    mov ah, 0x49
    int 0x21
    jc fail_free

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_alloc_too_big:
    mov dx, fail_alloc_too_big_msg
    jmp fail
fail_alloc_largest:
    mov dx, fail_alloc_largest_msg
    jmp fail
fail_free_invalid:
    mov dx, fail_free_invalid_msg
    jmp fail
fail_resize_invalid:
    mov dx, fail_resize_invalid_msg
    jmp fail
fail_alloc:
    mov dx, fail_alloc_msg
    jmp fail
fail_resize_grow:
    mov dx, fail_resize_grow_msg
    jmp fail
fail_resize_largest:
    mov dx, fail_resize_largest_msg
    jmp fail
fail_resize_changed:
    push cs
    pop ds
    mov dx, fail_resize_changed_msg
    jmp fail
fail_free:
    push cs
    pop ds
    mov dx, fail_free_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

block_a: dw 0
block_b: dw 0
pass_msg: db "PASS: MEMFAIL", 13, 10, "$"
fail_alloc_too_big_msg: db "FAIL: MEMFAIL ALLOC BIG", 13, 10, "$"
fail_alloc_largest_msg: db "FAIL: MEMFAIL ALLOC LARGEST", 13, 10, "$"
fail_free_invalid_msg: db "FAIL: MEMFAIL FREE INVALID", 13, 10, "$"
fail_resize_invalid_msg: db "FAIL: MEMFAIL RESIZE INVALID", 13, 10, "$"
fail_alloc_msg: db "FAIL: MEMFAIL ALLOC", 13, 10, "$"
fail_resize_grow_msg: db "FAIL: MEMFAIL RESIZE GROW", 13, 10, "$"
fail_resize_largest_msg: db "FAIL: MEMFAIL RESIZE LARGEST", 13, 10, "$"
fail_resize_changed_msg: db "FAIL: MEMFAIL RESIZE CHANGED", 13, 10, "$"
fail_free_msg: db "FAIL: MEMFAIL FREE", 13, 10, "$"
