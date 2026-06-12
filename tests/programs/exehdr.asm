[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    mov word [hdr+0x0A], 0xFFFF
    call write_exe
    jc fail_setup
    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, exename
    mov ax, 0x4B00
    int 0x21
    jnc fail_minalloc
    cmp ax, 8
    jne fail_minalloc
    mov dx, msg_minalloc
    mov ah, 0x09
    int 0x21

    mov word [hdr+0x0A], 0
    mov word [hdr+0x08], 8
    call write_exe
    jc fail_setup
    mov bx, exec_params
    mov dx, exename
    mov ax, 0x4B00
    int 0x21
    jnc fail_hdrbig
    mov dx, msg_hdrbig
    mov ah, 0x09
    int 0x21

    mov word [hdr+0x08], 0x1000
    call write_exe
    jc fail_setup
    mov ah, 0x48
    mov bx, 0x0100
    int 0x21
    jc fail_setup
    mov [ovl_params], ax
    mov [ovl_params+2], ax
    mov bx, ovl_params
    mov dx, exename
    mov ax, 0x4B03
    int 0x21
    jnc fail_ovlhdr
    mov dx, msg_ovlhdr
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

write_exe:
    mov ah, 0x3C
    xor cx, cx
    mov dx, exename
    int 0x21
    jc .ret
    mov bx, ax
    mov ah, 0x40
    mov cx, 37
    mov dx, hdr
    int 0x21
    jc .close
    cmp ax, 37
    jne .close_err
    mov ah, 0x3E
    int 0x21
    clc
    ret
.close_err:
    stc
.close:
    pushf
    mov ah, 0x3E
    int 0x21
    popf
.ret:
    ret

fail_setup:
    mov dx, msg_fail_setup
    jmp fail
fail_minalloc:
    mov dx, msg_fail_minalloc
    jmp fail
fail_hdrbig:
    mov dx, msg_fail_hdrbig
    jmp fail
fail_ovlhdr:
    mov dx, msg_fail_ovlhdr
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

hdr:
    dw 0x5A4D
    dw 37
    dw 1
    dw 0
    dw 2
    dw 0
    dw 0xFFFF
    dw 0
    dw 0x0100
    dw 0
    dw 0
    dw 0
    dw 0x001E
    dw 0
    dw 0, 0
    db 0xB8, 0x00, 0x4C, 0xCD, 0x21

exename: db "HDRTEST.EXE", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
ovl_params: dw 0, 0
msg_minalloc:      db "PASS: EXEHDR MINALLOC", 13, 10, '$'
msg_hdrbig:        db "PASS: EXEHDR HDRBIG", 13, 10, '$'
msg_ovlhdr:        db "PASS: EXEHDR OVLHDR", 13, 10, '$'
msg_fail_setup:    db "FAIL: EXEHDR SETUP", 13, 10, '$'
msg_fail_minalloc: db "FAIL: EXEHDR MINALLOC", 13, 10, '$'
msg_fail_hdrbig:   db "FAIL: EXEHDR HDRBIG", 13, 10, '$'
msg_fail_ovlhdr:   db "FAIL: EXEHDR OVLHDR", 13, 10, '$'
