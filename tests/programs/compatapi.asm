[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x62
    int 0x21
    mov [orig_psp], bx

    mov ah, 0x51
    int 0x21
    cmp bx, [orig_psp]
    jne fail_psp

    mov bx, 0x1234
    mov ah, 0x50
    int 0x21
    mov ah, 0x51
    int 0x21
    cmp bx, 0x1234
    jne fail_psp
    mov bx, [orig_psp]
    mov ah, 0x50
    int 0x21
    mov ah, 0x62
    int 0x21
    cmp bx, [orig_psp]
    jne fail_psp

    mov ax, 0x5D06
    int 0x21
    jc fail_sda
    cmp cx, 0
    je fail_sda
    cmp dx, 0
    je fail_sda
    cmp byte [ds:si], 0
    jne fail_sda
    cmp byte [ds:si+1], 0
    jne fail_sda
    mov ax, [ds:si+0x10]
    push cs
    pop ds
    cmp ax, [orig_psp]
    jne fail_sda
    push cs
    pop ds
    mov ax, 0x5D00
    int 0x21
    jnc fail_sda
    cmp ax, 1
    jne fail_sda

    push cs
    pop ds
    push cs
    pop es
    mov si, true_rel
    mov di, out_buf
    mov ah, 0x60
    int 0x21
    jc fail_true
    mov si, true_rel_expected
    mov di, out_buf
    call match_value
    jc fail_true

    push cs
    pop ds
    push cs
    pop es
    mov si, true_abs
    mov di, out_buf
    mov ah, 0x60
    int 0x21
    jc fail_true
    mov si, true_abs_expected
    mov di, out_buf
    call match_value
    jc fail_true

    push cs
    pop ds
    push cs
    pop es
    mov si, true_drive_rel
    mov di, out_buf
    mov ah, 0x60
    int 0x21
    jc fail_true
    mov si, true_drive_rel_expected
    mov di, out_buf
    call match_value
    jc fail_true

    push cs
    pop ds
    push cs
    pop es
    mov si, true_parent_root
    mov di, out_buf
    mov ah, 0x60
    int 0x21
    jc fail_true
    mov si, true_parent_root_expected
    mov di, out_buf
    call match_value
    jc fail_true

    push cs
    pop ds
    push cs
    pop es
    mov si, true_empty
    mov di, out_buf
    mov ah, 0x60
    int 0x21
    jnc fail_true
    cmp ax, 3
    jne fail_true

    push cs
    pop ds
    push cs
    pop es
    mov si, true_bare_drive
    mov di, out_buf
    mov ah, 0x60
    int 0x21
    jnc fail_true
    cmp ax, 2
    jne fail_true

    push cs
    pop ds
    mov dx, subdir
    mov ah, 0x39
    int 0x21
    jc fail_true
    mov dx, subdir
    mov ah, 0x3B
    int 0x21
    jc fail_true

    push cs
    pop ds
    push cs
    pop es
    mov si, true_cwd
    mov di, out_buf
    mov ah, 0x60
    int 0x21
    jc fail_true
    mov si, true_cwd_expected
    mov di, out_buf
    call match_value
    jc fail_true

    push cs
    pop ds
    mov dx, root_name
    mov ah, 0x3B
    int 0x21
    jc fail_true

    push cs
    pop ds
    push cs
    pop es
    mov si, true_dot
    mov di, out_buf
    mov ah, 0x60
    int 0x21
    jc fail_true
    mov si, true_dot_expected
    mov di, out_buf
    call match_value
    jc fail_true

    stc
    mov ax, 0x71A0
    mov dx, root_name
    mov di, out_buf
    mov cx, 16
    int 0x21
    jnc fail_lfn
    cmp ax, 0x7100
    jne fail_lfn

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

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

fail_psp:
    push cs
    pop ds
    mov dx, fail_psp_msg
    jmp fail
fail_sda:
    push cs
    pop ds
    mov dx, fail_sda_msg
    jmp fail
fail_true:
    push cs
    pop ds
    mov dx, fail_true_msg
    jmp fail
fail_lfn:
    push cs
    pop ds
    mov dx, fail_lfn_msg
fail:
    mov ah, 0x09
    int 0x21
    mov bx, [orig_psp]
    mov ah, 0x50
    int 0x21
    mov ax, 0x4C01
    int 0x21

orig_psp: dw 0
true_rel: db "foo/../bar.txt", 0
true_rel_expected: db "A:\BAR.TXT", 0
true_dot: db ".\readme", 0
true_dot_expected: db "A:\README", 0
true_abs: db "\foo/bar.txt", 0
true_abs_expected: db "A:\FOO\BAR.TXT", 0
true_drive_rel: db "A:foo/bar", 0
true_drive_rel_expected: db "A:\FOO\BAR", 0
true_parent_root: db "../../foo", 0
true_parent_root_expected: db "A:\FOO", 0
true_empty: db 0
true_bare_drive: db "A:", 0
true_cwd: db "file.txt", 0
true_cwd_expected: db "A:\SUB\FILE.TXT", 0
subdir: db "SUB", 0
root_name: db "A:\", 0
out_buf: times 128 db 0
pass_msg: db "PASS: COMPATAPI", 13, 10, "$"
fail_psp_msg: db "FAIL: COMPATAPI PSP", 13, 10, "$"
fail_sda_msg: db "FAIL: COMPATAPI SDA", 13, 10, "$"
fail_true_msg: db "FAIL: COMPATAPI TRUE", 13, 10, "$"
fail_lfn_msg: db "FAIL: COMPATAPI LFN", 13, 10, "$"
