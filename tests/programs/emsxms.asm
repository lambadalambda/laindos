%include "tests/programs/common.inc"

XMS_TEST_KB equ 15296
XMS_SENT_OFF equ 0x000F0000
EMS_TEST_PAGES equ 384
EMS_LAST_PAGE equ EMS_TEST_PAGES - 1

COM_START
    mov sp, 0x1FFE

    call get_xms
    jc fail_xms
    call alloc_xms
    jc fail_xms
    call write_xms_sentinel
    jc fail_xms_move

    call alloc_ems
    jc fail_ems
    call exercise_ems
    jc fail_ems_backing
    call read_xms_sentinel
    jc fail_xms_move
    call compare_xms_sentinel
    jc fail_overlap

    call free_ems
    jc fail_ems
    call free_xms
    jc fail_xms

    PASS_WITH pass_msg

get_xms:
    mov ax, 0x4300
    int 0x2F
    cmp al, 0x80
    jne .bad
    mov ax, 0x4310
    int 0x2F
    mov [xms_entry], bx
    mov [xms_entry+2], es
    mov ax, es
    or ax, bx
    jz .bad
    mov ah, 0x08
    call far [xms_entry]
    cmp ax, XMS_TEST_KB
    jb .bad
    clc
    ret
.bad:
    stc
    ret

alloc_xms:
    mov ah, 0x09
    mov dx, XMS_TEST_KB
    call far [xms_entry]
    cmp ax, 1
    jne .bad
    mov [xms_handle], dx
    mov [move_to_xms_dst_handle], dx
    mov [move_from_xms_src_handle], dx
    mov ax, cs
    mov [move_to_xms_src_seg], ax
    mov [move_from_xms_dst_seg], ax
    clc
    ret
.bad:
    stc
    ret

free_xms:
    mov ah, 0x0A
    mov dx, [xms_handle]
    call far [xms_entry]
    cmp ax, 1
    jne .bad
    clc
    ret
.bad:
    stc
    ret

write_xms_sentinel:
    mov ah, 0x0B
    mov si, move_to_xms
    call far [xms_entry]
    cmp ax, 1
    jne .bad
    clc
    ret
.bad:
    stc
    ret

read_xms_sentinel:
    push cs
    pop es
    mov di, xms_readback
    mov cx, 16
    xor ax, ax
    rep stosw
    mov ah, 0x0B
    mov si, move_from_xms
    call far [xms_entry]
    cmp ax, 1
    jne .bad
    clc
    ret
.bad:
    stc
    ret

compare_xms_sentinel:
    push cs
    pop ds
    push cs
    pop es
    mov si, xms_sentinel
    mov di, xms_readback
    mov cx, 16
    repe cmpsw
    jne .bad
    clc
    ret
.bad:
    stc
    ret

alloc_ems:
    mov ah, 0x40
    int 0x67
    test ah, ah
    jnz .bad
    mov ah, 0x42
    int 0x67
    test ah, ah
    jnz .bad
    cmp bx, EMS_TEST_PAGES
    jb .bad
    cmp dx, EMS_TEST_PAGES
    jb .bad
    mov ah, 0x41
    int 0x67
    test ah, ah
    jnz .bad
    mov [ems_frame], bx
    mov ah, 0x43
    mov bx, EMS_TEST_PAGES
    int 0x67
    test ah, ah
    jnz .bad
    mov [ems_handle], dx
    clc
    ret
.bad:
    stc
    ret

free_ems:
    mov ah, 0x45
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz .bad
    clc
    ret
.bad:
    stc
    ret

exercise_ems:
    xor bx, bx
    call map_ems0
    jc .bad
    mov si, ems_pattern0
    call write_ems_frame
    mov bx, EMS_LAST_PAGE
    call map_ems0
    jc .bad
    mov si, ems_pattern_last
    call write_ems_frame
    xor bx, bx
    call map_ems0
    jc .bad
    mov si, ems_pattern0
    call compare_ems_frame
    jc .bad
    clc
    ret
.bad:
    stc
    ret

map_ems0:
    mov ah, 0x44
    xor al, al
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz .bad
    clc
    ret
.bad:
    stc
    ret

write_ems_frame:
    mov ax, [ems_frame]
    mov es, ax
    xor di, di
    mov cx, 16
    rep movsw
    ret

compare_ems_frame:
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

fail_xms:
    mov dx, fail_xms_msg
    jmp fail
fail_xms_move:
    mov dx, fail_xms_move_msg
    jmp fail
fail_ems:
    mov dx, fail_ems_msg
    jmp fail
fail_ems_backing:
    mov dx, fail_ems_backing_msg
    jmp fail
fail_overlap:
    mov dx, fail_overlap_msg
fail:
    FAIL_WITH dx

xms_entry: dw 0, 0
xms_handle: dw 0
ems_handle: dw 0
ems_frame: dw 0

move_to_xms:
    dd 32
    dw 0
    dw xms_sentinel
move_to_xms_src_seg: dw 0
move_to_xms_dst_handle: dw 0
    dd XMS_SENT_OFF

move_from_xms:
    dd 32
move_from_xms_src_handle: dw 0
    dd XMS_SENT_OFF
    dw 0
    dw xms_readback
move_from_xms_dst_seg: dw 0

xms_sentinel: db "XMS and EMS must not alias!!", 0, 0, 0, 0
xms_readback: times 32 db 0
ems_pattern0: db "EMSXMS logical page zero!!!", 0, 0, 0, 0
ems_pattern_last: db "EMSXMS logical page last!!!", 0, 0, 0, 0
pass_msg: db "PASS: EMSXMS", 13, 10, "$"
fail_xms_msg: db "FAIL: EMSXMS XMS", 13, 10, "$"
fail_xms_move_msg: db "FAIL: EMSXMS XMSMOVE", 13, 10, "$"
fail_ems_msg: db "FAIL: EMSXMS EMS", 13, 10, "$"
fail_ems_backing_msg: db "FAIL: EMSXMS EMSBACK", 13, 10, "$"
fail_overlap_msg: db "FAIL: EMSXMS OVERLAP", 13, 10, "$"
