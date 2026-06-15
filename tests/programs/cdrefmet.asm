%include "tests/programs/common.inc"

COM_START
    cld

    mov ax, 0xF003
    int 0x21
    jc fail_api

    mov ax, 0x3D00
    mov dx, read_path
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, ax
    mov cx, 64
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, expected_len
    jne fail_read_len

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov si, expected
    mov di, buf
    mov cx, expected_len
    repe cmpsb
    jne fail_contents

    PASS_WITH msg_pass

fail_api:
    FAIL_WITH msg_fail_api
fail_open:
    FAIL_WITH msg_fail_open
fail_read:
    FAIL_WITH msg_fail_read
fail_read_len:
    FAIL_WITH msg_fail_read_len
fail_close:
    FAIL_WITH msg_fail_close
fail_contents:
    FAIL_WITH msg_fail_contents

handle: dw 0
read_path: db "D:\HELLO.TXT", 0
expected: db "Hello from BIOS fallback CD refresh.", 13, 10
expected_len equ $ - expected
msg_pass: db "PASS: CDREFMET", 13, 10, "$"
msg_fail_api: db "FAIL: CDREFMET API", 13, 10, "$"
msg_fail_open: db "FAIL: CDREFMET OPEN", 13, 10, "$"
msg_fail_read: db "FAIL: CDREFMET READ", 13, 10, "$"
msg_fail_read_len: db "FAIL: CDREFMET READ LEN", 13, 10, "$"
msg_fail_close: db "FAIL: CDREFMET CLOSE", 13, 10, "$"
msg_fail_contents: db "FAIL: CDREFMET CONTENTS", 13, 10, "$"
buf: times 80 db 0
