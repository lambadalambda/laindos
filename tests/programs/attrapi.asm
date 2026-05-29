[bits 16]
[org 0x0100]

ATTR_RDONLY equ 0x01
ATTR_HIDDEN equ 0x02
ATTR_SYSTEM equ 0x04
ATTR_VOLUME equ 0x08
ATTR_DIR equ 0x10
ATTR_ARCHIVE equ 0x20
ATTR_MUTABLE equ ATTR_RDONLY | ATTR_HIDDEN | ATTR_SYSTEM | ATTR_ARCHIVE

start:
    push cs
    pop ds

    mov dx, file_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax
    call close_handle

    mov dx, file_name
    mov cx, ATTR_MUTABLE
    mov ax, 0x4301
    int 0x21
    jc fail_set_file
    mov dx, file_name
    mov cl, ATTR_MUTABLE
    call check_attr

    mov dx, file_name
    mov cx, ATTR_DIR
    call expect_protected
    mov dx, file_name
    mov cl, ATTR_MUTABLE
    call check_attr

    mov dx, file_name
    xor cx, cx
    mov ax, 0x4301
    int 0x21
    jc fail_set_file
    mov dx, file_name
    xor cl, cl
    call check_attr

    mov dx, file_name
    mov cx, ATTR_VOLUME
    call expect_protected
    mov dx, file_name
    xor cl, cl
    call check_attr

    mov dx, dir_name
    mov ah, 0x39
    int 0x21
    jc fail_mkdir
    mov dx, dir_name
    mov cl, ATTR_DIR
    call check_attr

    mov dx, dir_name
    mov cx, ATTR_HIDDEN
    mov ax, 0x4301
    int 0x21
    jc fail_set_dir
    mov dx, dir_name
    mov cl, ATTR_DIR | ATTR_HIDDEN
    call check_attr

    mov dx, dir_name
    xor cx, cx
    mov ax, 0x4301
    int 0x21
    jc fail_set_dir
    mov dx, dir_name
    mov cl, ATTR_DIR
    call check_attr

    mov dx, dir_name
    mov cx, ATTR_DIR
    call expect_protected
    mov dx, dir_name
    mov cl, ATTR_DIR
    call check_attr

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

close_handle:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

check_attr:
    mov [expected_attr], cl
    mov ax, 0x4300
    int 0x21
    jc fail_get_attr
    test ch, ch
    jnz fail_attr_value
    cmp cl, [expected_attr]
    jne fail_attr_value
    ret

expect_protected:
    mov ax, 0x4301
    int 0x21
    jnc fail_protected
    cmp ax, 5
    jne fail_protected_code
    ret

fail_create:
    mov dx, fail_create_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_set_file:
    mov dx, fail_set_file_msg
    jmp fail
fail_set_dir:
    mov dx, fail_set_dir_msg
    jmp fail
fail_mkdir:
    mov dx, fail_mkdir_msg
    jmp fail
fail_get_attr:
    mov dx, fail_get_attr_msg
    jmp fail
fail_attr_value:
    mov dx, fail_attr_value_msg
    jmp fail
fail_protected:
    mov dx, fail_protected_msg
    jmp fail
fail_protected_code:
    mov dx, fail_protected_code_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
expected_attr: db 0
file_name: db "ATTRF.DAT", 0
dir_name: db "ATTRDIR", 0
pass_msg: db "PASS: ATTRAPI", 13, 10, "$"
fail_create_msg: db "FAIL: ATTRAPI CREATE", 13, 10, "$"
fail_close_msg: db "FAIL: ATTRAPI CLOSE", 13, 10, "$"
fail_set_file_msg: db "FAIL: ATTRAPI SET FILE", 13, 10, "$"
fail_set_dir_msg: db "FAIL: ATTRAPI SET DIR", 13, 10, "$"
fail_mkdir_msg: db "FAIL: ATTRAPI MKDIR", 13, 10, "$"
fail_get_attr_msg: db "FAIL: ATTRAPI GET", 13, 10, "$"
fail_attr_value_msg: db "FAIL: ATTRAPI VALUE", 13, 10, "$"
fail_protected_msg: db "FAIL: ATTRAPI PROTECTED", 13, 10, "$"
fail_protected_code_msg: db "FAIL: ATTRAPI PROTECTED CODE", 13, 10, "$"
