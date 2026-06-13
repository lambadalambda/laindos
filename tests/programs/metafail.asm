%include "tests/programs/common.inc"

COM_START
    cld

    mov dx, fname
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, [handle]
    mov dx, one_byte
    mov cx, 1
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 1
    jne fail_write

    mov bx, [handle]
    mov ax, 0x5701
    mov cx, 0x4321
    mov dx, 0x5A21
    int 0x21
    jnc fail_expected_time_error
    cmp ax, 5
    jne fail_expected_time_error

    mov bx, [handle]
    mov ah, 0x68
    int 0x21
    jc fail_commit_retry

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    PASS_WITH msg_pass

fail_create:
    mov dx, msg_fail_create
    jmp fail
fail_write:
    mov dx, msg_fail_write
    jmp fail
fail_expected_time_error:
    mov dx, msg_fail_expected_time_error
    jmp fail
fail_commit_retry:
    mov dx, msg_fail_commit_retry
    jmp fail
fail_close:
    mov dx, msg_fail_close
fail:
    mov ah, 0x09
    int 0x21
    EXIT_CODE 1

fname: db "METAFAIL.DAT", 0
handle: dw 0
one_byte: db 0xA7

msg_pass: db "PASS: METAFAIL", 13, 10, "$"
msg_fail_create: db "FAIL: METAFAIL CREATE", 13, 10, "$"
msg_fail_write: db "FAIL: METAFAIL WRITE", 13, 10, "$"
msg_fail_expected_time_error: db "FAIL: METAFAIL EXPECTED TIME ERROR", 13, 10, "$"
msg_fail_commit_retry: db "FAIL: METAFAIL COMMIT RETRY", 13, 10, "$"
msg_fail_close: db "FAIL: METAFAIL CLOSE", 13, 10, "$"
