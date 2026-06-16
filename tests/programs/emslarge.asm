%include "tests/programs/common.inc"

EMS_TEST_PAGES equ 384
EMS_LAST_PAGE equ EMS_TEST_PAGES - 1

COM_START
    mov sp, 0x1FFE

    mov ah, 0x40
    int 0x67
    test ah, ah
    jnz fail_status

    mov ah, 0x46
    int 0x67
    test ah, ah
    jnz fail_version
    cmp al, 0x40
    jb fail_version

    mov ah, 0x42
    int 0x67
    test ah, ah
    jnz fail_pages
    cmp bx, EMS_TEST_PAGES
    jb fail_pages
    cmp dx, EMS_TEST_PAGES
    jb fail_pages

    mov ah, 0x41
    int 0x67
    test ah, ah
    jnz fail_frame
    cmp bx, 0xD000
    jne fail_frame
    mov [ems_frame], bx

    mov ah, 0x43
    mov bx, EMS_TEST_PAGES
    int 0x67
    test ah, ah
    jnz fail_alloc
    mov [ems_handle], dx

    xor bx, bx
    mov al, 0
    call map_page
    jc fail_map
    mov si, pattern0
    call write_frame

    mov bx, EMS_LAST_PAGE
    mov al, 0
    call map_page
    jc fail_map
    mov si, pattern_last
    call write_frame

    xor bx, bx
    mov al, 0
    call map_page
    jc fail_map
    mov si, pattern0
    call compare_frame
    jc fail_backing

    mov bx, EMS_LAST_PAGE
    mov al, 0
    call map_page
    jc fail_map
    mov si, pattern_last
    call compare_frame
    jc fail_backing

    mov ah, 0x4C
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz fail_info
    cmp bx, EMS_TEST_PAGES
    jne fail_info

    mov ah, 0x45
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz fail_free

    PASS_WITH pass_msg

map_page:
    mov ah, 0x44
    mov dx, [ems_handle]
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
fail_version:
    mov dx, fail_version_msg
    jmp fail
fail_pages:
    mov dx, fail_pages_msg
    jmp fail
fail_frame:
    mov dx, fail_frame_msg
    jmp fail
fail_alloc:
    mov dx, fail_alloc_msg
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

ems_handle: dw 0
ems_frame: dw 0
pattern0: db "EMS large page zero marker!!", 0, 0, 0, 0
pattern_last: db "EMS large final page mark!", 0, 0, 0, 0, 0
pass_msg: db "PASS: EMSLARGE", 13, 10, "$"
fail_status_msg: db "FAIL: EMSLARGE STATUS", 13, 10, "$"
fail_version_msg: db "FAIL: EMSLARGE VERSION", 13, 10, "$"
fail_pages_msg: db "FAIL: EMSLARGE PAGES", 13, 10, "$"
fail_frame_msg: db "FAIL: EMSLARGE FRAME", 13, 10, "$"
fail_alloc_msg: db "FAIL: EMSLARGE ALLOC", 13, 10, "$"
fail_map_msg: db "FAIL: EMSLARGE MAP", 13, 10, "$"
fail_backing_msg: db "FAIL: EMSLARGE BACKING", 13, 10, "$"
fail_info_msg: db "FAIL: EMSLARGE INFO", 13, 10, "$"
fail_free_msg: db "FAIL: EMSLARGE FREE", 13, 10, "$"
