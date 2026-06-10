%include "tests/programs/common.inc"

COM_START
    mov ax, 0x3700
    mov dx, 0xFFFF
    int 0x21
    jc fail_get
    cmp al, 0
    jne fail_get
    cmp dl, '/'
    jne fail_get

    mov ax, 0x3701
    mov dl, '-'
    int 0x21
    jc fail_set
    mov ax, 0x3700
    int 0x21
    jc fail_set
    cmp dl, '-'
    jne fail_set

    mov ax, 0x3701
    mov dl, '/'
    int 0x21
    jc fail_set

    mov ax, 0x3702
    int 0x21
    cmp al, 0xFF
    jne fail_bad_subfunc

    PASS_WITH pass_msg

fail_get:
    FAIL_WITH fail_get_msg
fail_set:
    FAIL_WITH fail_set_msg
fail_bad_subfunc:
    FAIL_WITH fail_bad_subfunc_msg

pass_msg: db "PASS: SWITCHAR", 13, 10, "$"
fail_get_msg: db "FAIL: SWITCHAR GET", 13, 10, "$"
fail_set_msg: db "FAIL: SWITCHAR SET", 13, 10, "$"
fail_bad_subfunc_msg: db "FAIL: SWITCHAR BADFUNC", 13, 10, "$"
