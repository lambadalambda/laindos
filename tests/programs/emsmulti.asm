%include "tests/programs/common.inc"

EMS_HANDLE_PAGES equ 4

COM_START
    mov sp, 0x1FFE

    mov ah, 0x40
    int 0x67
    test ah, ah
    jnz fail_status

    mov ah, 0x41
    int 0x67
    test ah, ah
    jnz fail_frame
    mov [ems_frame], bx

    mov ah, 0x4B
    int 0x67
    test ah, ah
    jnz fail_handles
    cmp bx, 2
    jb fail_handles

    mov ah, 0x43
    mov bx, EMS_HANDLE_PAGES
    int 0x67
    test ah, ah
    jnz fail_alloc1
    mov [ems_handle1], dx

    mov ah, 0x43
    mov bx, EMS_HANDLE_PAGES
    int 0x67
    test ah, ah
    jnz fail_alloc2
    mov [ems_handle2], dx

    mov dx, [ems_handle1]
    xor bx, bx
    call map0
    jc fail_map
    mov si, pattern1
    call write_frame

    mov dx, [ems_handle2]
    xor bx, bx
    call map0
    jc fail_map
    mov si, pattern2
    call write_frame

    mov dx, [ems_handle1]
    xor bx, bx
    call map0
    jc fail_map
    mov si, pattern1
    call compare_frame
    jc fail_backing

    mov dx, [ems_handle2]
    xor bx, bx
    call map0
    jc fail_map
    mov si, pattern2
    call compare_frame
    jc fail_backing

    mov ah, 0x4C
    mov dx, [ems_handle1]
    int 0x67
    test ah, ah
    jnz fail_info
    cmp bx, EMS_HANDLE_PAGES
    jne fail_info

    mov ah, 0x4C
    mov dx, [ems_handle2]
    int 0x67
    test ah, ah
    jnz fail_info
    cmp bx, EMS_HANDLE_PAGES
    jne fail_info

    mov ah, 0x45
    mov dx, [ems_handle1]
    int 0x67
    test ah, ah
    jnz fail_free
    mov ah, 0x45
    mov dx, [ems_handle2]
    int 0x67
    test ah, ah
    jnz fail_free

    PASS_WITH pass_msg

map0:
    mov ah, 0x44
    xor al, al
    int 0x67
    test ah, ah
    jnz .bad
    clc
    ret
.bad:
    stc
    ret

write_frame:
    mov ax, [ems_frame]
    mov es, ax
    xor di, di
    mov cx, 16
    rep movsw
    ret

compare_frame:
    mov ax, [ems_frame]
    mov es, ax
    xor di, di
    mov cx, 16
.loop:
    lodsw
    cmp ax, [es:di]
    jne .bad
    add di, 2
    loop .loop
    clc
    ret
.bad:
    stc
    ret

fail_status:
    mov dx, fail_status_msg
    jmp fail
fail_frame:
    mov dx, fail_frame_msg
    jmp fail
fail_handles:
    mov dx, fail_handles_msg
    jmp fail
fail_alloc1:
    mov dx, fail_alloc1_msg
    jmp fail
fail_alloc2:
    mov dx, fail_alloc2_msg
    jmp fail
fail_map:
    mov dx, fail_map_msg
    jmp fail
fail_backing:
    mov dx, fail_backing_msg
    jmp fail
fail_info:
    mov dx, fail_info_msg
    jmp fail
fail_free:
    mov dx, fail_free_msg
fail:
    FAIL_WITH dx

ems_handle1: dw 0
ems_handle2: dw 0
ems_frame: dw 0
pattern1: db "EMS handle one backing marker", 0, 0, 0, 0
pattern2: db "EMS handle two backing marker", 0, 0, 0, 0
pass_msg: db "PASS: EMSMULTI", 13, 10, "$"
fail_status_msg: db "FAIL: EMSMULTI STATUS", 13, 10, "$"
fail_frame_msg: db "FAIL: EMSMULTI FRAME", 13, 10, "$"
fail_handles_msg: db "FAIL: EMSMULTI HANDLES", 13, 10, "$"
fail_alloc1_msg: db "FAIL: EMSMULTI ALLOC1", 13, 10, "$"
fail_alloc2_msg: db "FAIL: EMSMULTI ALLOC2", 13, 10, "$"
fail_map_msg: db "FAIL: EMSMULTI MAP", 13, 10, "$"
fail_backing_msg: db "FAIL: EMSMULTI BACKING", 13, 10, "$"
fail_info_msg: db "FAIL: EMSMULTI INFO", 13, 10, "$"
fail_free_msg: db "FAIL: EMSMULTI FREE", 13, 10, "$"
