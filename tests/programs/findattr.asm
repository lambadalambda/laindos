[bits 16]
[org 0x0100]

ATTR_HIDDEN equ 0x02
ATTR_SYSTEM equ 0x04
ATTR_VOLUME equ 0x08
ATTR_DIR equ 0x10

start:
    push cs
    pop ds

    mov dx, dta
    mov ah, 0x1A
    int 0x21

    mov dx, normal_name
    xor cx, cx
    call expect_found

    mov dx, hidden_name
    xor cx, cx
    call expect_missing
    mov dx, hidden_name
    mov cx, ATTR_HIDDEN
    call expect_found
    test byte [dta + 21], ATTR_HIDDEN
    jz fail_hidden

    mov dx, system_name
    xor cx, cx
    call expect_missing
    mov dx, system_name
    mov cx, ATTR_SYSTEM
    call expect_found
    test byte [dta + 21], ATTR_SYSTEM
    jz fail_system

    mov dx, subdir_name
    xor cx, cx
    call expect_missing
    mov dx, subdir_name
    mov cx, ATTR_DIR
    call expect_found
    test byte [dta + 21], ATTR_DIR
    jz fail_dir

    mov dx, volume_name
    xor cx, cx
    call expect_missing
    mov dx, volume_name
    mov cx, ATTR_VOLUME
    call expect_found
    test byte [dta + 21], ATTR_VOLUME
    jz fail_volume

    mov dx, volume_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc fail_volume_open

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

expect_found:
    mov ah, 0x4E
    int 0x21
    jc fail_found
    ret

expect_missing:
    mov ah, 0x4E
    int 0x21
    jnc fail_missing
    ret

fail_found:
    mov dx, fail_found_msg
    jmp fail
fail_missing:
    mov dx, fail_missing_msg
    jmp fail
fail_hidden:
    mov dx, fail_hidden_msg
    jmp fail
fail_system:
    mov dx, fail_system_msg
    jmp fail
fail_dir:
    mov dx, fail_dir_msg
    jmp fail
fail_volume:
    mov dx, fail_volume_msg
    jmp fail
fail_volume_open:
    mov dx, fail_volume_open_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

normal_name: db "NORMAL.TXT", 0
hidden_name: db "HIDDEN.TXT", 0
system_name: db "SYSTEM.TXT", 0
subdir_name: db "SUBDIR", 0
volume_name: db "VOLUME.LBL", 0
pass_msg: db "PASS: FINDATTR", 13, 10, "$"
fail_found_msg: db "FAIL: FINDATTR FOUND", 13, 10, "$"
fail_missing_msg: db "FAIL: FINDATTR MISSING", 13, 10, "$"
fail_hidden_msg: db "FAIL: FINDATTR HIDDEN", 13, 10, "$"
fail_system_msg: db "FAIL: FINDATTR SYSTEM", 13, 10, "$"
fail_dir_msg: db "FAIL: FINDATTR DIR", 13, 10, "$"
fail_volume_msg: db "FAIL: FINDATTR VOLUME", 13, 10, "$"
fail_volume_open_msg: db "FAIL: FINDATTR VOLUME OPEN", 13, 10, "$"
dta: times 64 db 0
