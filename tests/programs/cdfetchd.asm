%include "tests/programs/common.inc"

COM_START
    cld

    mov ax, 0x3D00
    mov dx, read_path
    int 0x21
    jc fail_open
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov ah, 0x0E
    mov dl, 3
    int 0x21

    mov ax, 0xF004
    int 0x21
    jc fail_probe

    PASS_WITH msg_pass

fail_open:
    FAIL_WITH msg_fail_open
fail_close:
    FAIL_WITH msg_fail_close
fail_probe:
    FAIL_WITH msg_fail_probe

read_path: db "D:\HELLO.TXT", 0
msg_pass: db "PASS: CDFETCHD", 13, 10, "$"
msg_fail_open: db "FAIL: CDFETCHD OPEN", 13, 10, "$"
msg_fail_close: db "FAIL: CDFETCHD CLOSE", 13, 10, "$"
msg_fail_probe: db "FAIL: CDFETCHD PROBE", 13, 10, "$"
