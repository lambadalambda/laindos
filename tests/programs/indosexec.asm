%include "tests/programs/common.inc"

COM_START
    mov ah, 0x34
    int 0x21
    mov al, [es:bx]
    cmp al, 0
    jne fail_elevated

    PASS_WITH pass_msg

fail_elevated:
    FAIL_WITH fail_msg

pass_msg: db "PASS: INDOSEXEC", 13, 10, "$"
fail_msg: db "FAIL: INDOSEXEC ELEVATED", 13, 10, "$"
