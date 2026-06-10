%include "tests/programs/common.inc"

COM_START
    PRINT_DOLLAR msg
.hang:
    jmp .hang

msg: db "PASS: HANGLOOP", 13, 10, "$"
