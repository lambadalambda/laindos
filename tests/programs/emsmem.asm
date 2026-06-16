%include "tests/programs/common.inc"

MIN_FREE_PARAS equ 580 * 64
MIN_EMS_PAGES equ 384

COM_START
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    jc fail_resize

    mov ah, 0x40
    int 0x67
    test ah, ah
    jnz fail_ems

    mov ah, 0x42
    int 0x67
    test ah, ah
    jnz fail_ems
    cmp dx, MIN_EMS_PAGES
    jb fail_ems

    mov bx, 0xFFFF
    mov ah, 0x48
    int 0x21
    jnc fail_largest
    cmp ax, 8
    jne fail_largest
    cmp bx, MIN_FREE_PARAS
    jb fail_largest

    PASS_WITH pass_msg

fail_resize:
    mov dx, fail_resize_msg
    jmp fail
fail_ems:
    mov dx, fail_ems_msg
    jmp fail
fail_largest:
    mov dx, fail_largest_msg
fail:
    FAIL_WITH dx

pass_msg: db "PASS: EMSMEM", 13, 10, "$"
fail_resize_msg: db "FAIL: EMSMEM RESIZE", 13, 10, "$"
fail_ems_msg: db "FAIL: EMSMEM EMS", 13, 10, "$"
fail_largest_msg: db "FAIL: EMSMEM LARGEST", 13, 10, "$"
