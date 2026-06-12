[bits 16]
[org 0x0100]

; Era programs open read-only files with DOS sharing bits set (deny-none
; read = AX 3D20h). The close must still release the handle slot: the
; flush-on-close test is about the access bits, not the share bits.
; Red Alert's installer leaked its whole handle table through this.

start:
    push cs
    pop ds
    cld
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    mov word [count], 30
.loop:
    mov dx, fname
    mov ax, 0x3D20             ; read access, deny-none sharing
    int 0x21
    jc fail_open
    cmp word [first], 0
    jne .check_same
    mov [first], ax
.check_same:
    cmp ax, [first]
    jne fail_reuse
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close
    dec word [count]
    jnz .loop

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_reuse:
    mov dx, fail_reuse_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

count: dw 0
first: dw 0
fname: db 'D:\HELLO.TXT', 0
pass_msg: db 'PASS: CDSHARE', 13, 10, '$'
fail_open_msg: db 'FAIL: CDSHARE OPEN', 13, 10, '$'
fail_reuse_msg: db 'FAIL: CDSHARE REUSE', 13, 10, '$'
fail_close_msg: db 'FAIL: CDSHARE CLOSE', 13, 10, '$'
