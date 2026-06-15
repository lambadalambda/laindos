%include "tests/programs/common.inc"

COM_START
    cld

    mov dx, target_path
    call open_close

    mov dx, bad_path
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jnc fail_expected_create_error

    mov dx, bad_path
    call expect_missing

    mov dx, good_path
    call create_close
    mov dx, good_path
    call open_close

    PASS_WITH msg_pass

open_close:
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

create_close:
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

expect_missing:
    mov ax, 0x3D00
    int 0x21
    jnc fail_expected_missing
    ret

fail_open:
    FAIL_WITH msg_fail_open
fail_close:
    FAIL_WITH msg_fail_close
fail_create:
    FAIL_WITH msg_fail_create
fail_expected_create_error:
    FAIL_WITH msg_fail_expected_create_error
fail_expected_missing:
    FAIL_WITH msg_fail_expected_missing

msg_pass: db "PASS: DIRCFFAIL", 13, 10, "$"
msg_fail_open: db "FAIL: DIRCFFAIL OPEN", 13, 10, "$"
msg_fail_close: db "FAIL: DIRCFFAIL CLOSE", 13, 10, "$"
msg_fail_create: db "FAIL: DIRCFFAIL CREATE", 13, 10, "$"
msg_fail_expected_create_error: db "FAIL: DIRCFFAIL CREATEOK", 13, 10, "$"
msg_fail_expected_missing: db "FAIL: DIRCFFAIL MISSING", 13, 10, "$"

target_path: db "CACHE\TARGET.DAT", 0
bad_path: db "CACHE\BADFAIL.DAT", 0
good_path: db "CACHE\GOOD.DAT", 0
