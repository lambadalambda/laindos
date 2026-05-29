[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, file_name
    mov ah, 0x41
    int 0x21

    xor dl, dl
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    je fail_ah36
    test ax, ax
    jz fail_ah36
    test bx, bx
    jz fail_ah36
    test cx, cx
    jz fail_ah36
    test dx, dx
    jz fail_ah36
    cmp bx, dx
    jae fail_free
    mov [before_spc], ax
    mov [before_free], bx
    mov [before_bps], cx
    mov [before_total], dx

    mov dx, file_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, data_buf
    mov cx, data_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, data_size
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    xor dl, dl
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    je fail_ah36
    cmp ax, [before_spc]
    jne fail_ah36
    cmp cx, [before_bps]
    jne fail_ah36
    cmp dx, [before_total]
    jne fail_ah36
    cmp bx, [before_free]
    jae fail_free_after

    mov ah, 0x19
    int 0x21
    inc al
    mov [valid_drive], al
    inc al
    mov [invalid_drive], al

    mov dl, [valid_drive]
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    je fail_drive
    mov dl, [invalid_drive]
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    jne fail_drive

    mov dx, file_name
    mov ah, 0x41
    int 0x21
    jc fail_delete

    xor dl, dl
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    je fail_ah36
    cmp bx, [before_free]
    jne fail_free_delete

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_ah36:
    mov dx, fail_ah36_msg
    jmp fail
fail_free:
    mov dx, fail_free_msg
    jmp fail
fail_free_after:
    mov dx, fail_free_after_msg
    jmp fail
fail_free_delete:
    mov dx, fail_free_delete_msg
    jmp fail
fail_drive:
    mov dx, fail_drive_msg
    jmp fail
fail_create:
    mov dx, fail_create_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_delete:
    mov dx, fail_delete_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
before_spc: dw 0
before_free: dw 0
before_bps: dw 0
before_total: dw 0
valid_drive: db 0
invalid_drive: db 0
file_name: db "FREECHK.DAT", 0
pass_msg: db "PASS: DISKFREE", 13, 10, "$"
fail_ah36_msg: db "FAIL: DISKFREE AH36", 13, 10, "$"
fail_free_msg: db "FAIL: DISKFREE FREE", 13, 10, "$"
fail_free_after_msg: db "FAIL: DISKFREE AFTER", 13, 10, "$"
fail_free_delete_msg: db "FAIL: DISKFREE DELETE FREE", 13, 10, "$"
fail_drive_msg: db "FAIL: DISKFREE DRIVE", 13, 10, "$"
fail_create_msg: db "FAIL: DISKFREE CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: DISKFREE WRITE", 13, 10, "$"
fail_close_msg: db "FAIL: DISKFREE CLOSE", 13, 10, "$"
fail_delete_msg: db "FAIL: DISKFREE DELETE", 13, 10, "$"
data_buf: times 600 db 0x5A
data_size equ $ - data_buf
