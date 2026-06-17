%include "tests/programs/common.inc"

HANDLE_COUNT equ 17
MAP_PAGES equ 4
PATTERN_WORDS equ 8
FRAME_PAGE_PARAS equ 0x0400

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
    cmp bx, HANDLE_COUNT
    jb fail_handles

    mov cx, HANDLE_COUNT
    mov di, handles
.alloc_loop:
    mov ah, 0x43
    mov bx, 1
    int 0x67
    test ah, ah
    jnz fail_alloc_handles
    mov [di], dx
    add di, 2
    loop .alloc_loop

    mov cx, HANDLE_COUNT
    mov di, handles
.free_loop:
    mov ah, 0x45
    mov dx, [di]
    int 0x67
    test ah, ah
    jnz fail_free
    add di, 2
    loop .free_loop

    mov ah, 0x43
    mov bx, MAP_PAGES
    int 0x67
    test ah, ah
    jnz fail_alloc_map
    mov [ems_handle], dx

    mov ax, 0x5000
    mov cx, MAP_PAGES
    mov dx, [ems_handle]
    mov si, map_entries_initial
    int 0x67
    test ah, ah
    jnz fail_map_multi

    mov bx, 0
    mov si, pattern0
    call write_frame_page
    mov bx, 1
    mov si, pattern1
    call write_frame_page
    mov bx, 2
    mov si, pattern2
    call write_frame_page
    mov bx, 3
    mov si, pattern3
    call write_frame_page

    mov ax, 0x5000
    mov cx, MAP_PAGES
    mov dx, [ems_handle]
    mov si, map_entries_unmap
    int 0x67
    test ah, ah
    jnz fail_unmap_multi

    mov ax, 0x5000
    mov cx, MAP_PAGES
    mov dx, [ems_handle]
    mov si, map_entries_reverse
    int 0x67
    test ah, ah
    jnz fail_map_multi

    mov bx, 0
    mov si, pattern3
    call compare_frame_page
    jc fail_backing
    mov bx, 1
    mov si, pattern2
    call compare_frame_page
    jc fail_backing
    mov bx, 2
    mov si, pattern1
    call compare_frame_page
    jc fail_backing
    mov bx, 3
    mov si, pattern0
    call compare_frame_page
    jc fail_backing

    mov bx, 0
    mov si, pattern3_dirty
    call write_frame_page

    mov ax, 0x5000
    mov cx, MAP_PAGES
    mov dx, [ems_handle]
    mov si, map_entries_unmap
    int 0x67
    test ah, ah
    jnz fail_unmap_multi

    mov ah, 0x44
    xor al, al
    mov bx, 3
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz fail_map

    mov bx, 0
    mov si, pattern3_dirty
    call compare_frame_page
    jc fail_backing

    mov ah, 0x45
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz fail_free

    PASS_WITH pass_msg

frame_page_segment:
    push bx
    push cx
    push dx
    mov ax, bx
    mov cx, FRAME_PAGE_PARAS
    mul cx
    add ax, [ems_frame]
    pop dx
    pop cx
    pop bx
    ret

write_frame_page:
    push ax
    push bx
    push cx
    push si
    push di
    push es
    call frame_page_segment
    mov es, ax
    xor di, di
    mov cx, PATTERN_WORDS
    cld
    rep movsw
    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

compare_frame_page:
    push ax
    push bx
    push cx
    push si
    push di
    push es
    call frame_page_segment
    mov es, ax
    xor di, di
    mov cx, PATTERN_WORDS
.compare_loop:
    lodsw
    cmp ax, [es:di]
    jne .bad
    add di, 2
    loop .compare_loop
    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    clc
    ret
.bad:
    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
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
fail_alloc_handles:
    mov dx, fail_alloc_handles_msg
    jmp fail
fail_alloc_map:
    mov dx, fail_alloc_map_msg
    jmp fail
fail_map_multi:
    mov dx, fail_map_multi_msg
    jmp fail
fail_unmap_multi:
    mov dx, fail_unmap_multi_msg
    jmp fail
fail_map:
    mov dx, fail_map_msg
    jmp fail
fail_backing:
    mov dx, fail_backing_msg
    jmp fail
fail_free:
    mov dx, fail_free_msg
fail:
    FAIL_WITH dx

ems_handle: dw 0
ems_frame: dw 0
handles: times HANDLE_COUNT dw 0
map_entries_initial:
    dw 0, 0
    dw 1, 1
    dw 2, 2
    dw 3, 3
map_entries_reverse:
    dw 3, 0
    dw 2, 1
    dw 1, 2
    dw 0, 3
map_entries_unmap:
    dw 0xFFFF, 0
    dw 0xFFFF, 1
    dw 0xFFFF, 2
    dw 0xFFFF, 3
pattern0: dw 0x1000, 0x1001, 0x1002, 0x1003, 0x1004, 0x1005, 0x1006, 0x1007
pattern1: dw 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007
pattern2: dw 0x3000, 0x3001, 0x3002, 0x3003, 0x3004, 0x3005, 0x3006, 0x3007
pattern3: dw 0x4000, 0x4001, 0x4002, 0x4003, 0x4004, 0x4005, 0x4006, 0x4007
pattern3_dirty: dw 0x4D00, 0x4D01, 0x4D02, 0x4D03, 0x4D04, 0x4D05, 0x4D06, 0x4D07
pass_msg: db "PASS: EMSMAP40", 13, 10, "$"
fail_status_msg: db "FAIL: EMSMAP40 STATUS", 13, 10, "$"
fail_frame_msg: db "FAIL: EMSMAP40 FRAME", 13, 10, "$"
fail_handles_msg: db "FAIL: EMSMAP40 HANDLES", 13, 10, "$"
fail_alloc_handles_msg: db "FAIL: EMSMAP40 ALLOC HANDLES", 13, 10, "$"
fail_alloc_map_msg: db "FAIL: EMSMAP40 ALLOC MAP", 13, 10, "$"
fail_map_multi_msg: db "FAIL: EMSMAP40 MAP MULTI", 13, 10, "$"
fail_unmap_multi_msg: db "FAIL: EMSMAP40 UNMAP MULTI", 13, 10, "$"
fail_map_msg: db "FAIL: EMSMAP40 MAP", 13, 10, "$"
fail_backing_msg: db "FAIL: EMSMAP40 BACKING", 13, 10, "$"
fail_free_msg: db "FAIL: EMSMAP40 FREE", 13, 10, "$"
