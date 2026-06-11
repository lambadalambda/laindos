%include "tests/programs/common.inc"

COM_START
    pushf
    pop ax
    test ax, 0x0200
    jz fail_if_clear

    mov ah, 0x30
    int 0x21
    pushf
    pop ax
    test ax, 0x0200
    jz fail_if_clear

    xor ax, ax
    mov es, ax
    mov bx, [es:0x046C]
    mov dx, 0x2000
.spin_outer:
    xor cx, cx
.spin_inner:
    cmp bx, [es:0x046C]
    jne tick_advanced
    loop .spin_inner
    dec dx
    jnz .spin_outer
    FAIL_WITH fail_frozen_msg

tick_advanced:
    PASS_WITH pass_msg

fail_if_clear:
    sti
    FAIL_WITH fail_if_msg

pass_msg: db "PASS: TICKSPIN", 13, 10, "$"
fail_if_msg: db "FAIL: TICKSPIN IF CLEAR", 13, 10, "$"
fail_frozen_msg: db "FAIL: TICKSPIN TICK FROZEN", 13, 10, "$"
