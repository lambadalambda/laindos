[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x3567
    int 0x21
    mov ax, es
    or ax, bx
    jz fail_vec

    mov dx, emm_name
    mov ax, 0x3D00
    int 0x21
    jc fail_device
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_device

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
    cmp bx, 4
    jb fail_pages
    cmp dx, bx
    jb fail_pages

    mov ah, 0x41
    int 0x67
    test ah, ah
    jnz fail_frame
    test bx, bx
    jz fail_frame
    mov [ems_frame], bx

    mov ah, 0x43
    mov bx, 4
    int 0x67
    test ah, ah
    jnz fail_alloc
    test dx, dx
    jz fail_alloc
    mov [ems_handle], dx

    mov ah, 0x4C
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz fail_info
    cmp bx, 4
    jne fail_info

    mov ah, 0x44
    xor al, al
    xor bx, bx
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz fail_map

    mov ax, [ems_frame]
    mov es, ax
    xor di, di
    mov si, pattern0
    mov cx, 8
    rep movsw

    mov ah, 0x44
    xor al, al
    mov bx, 1
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz fail_map

    mov ax, [ems_frame]
    mov es, ax
    xor di, di
    mov si, pattern1
    mov cx, 8
    rep movsw

    mov ah, 0x44
    xor al, al
    xor bx, bx
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz fail_map

    mov ax, [ems_frame]
    mov es, ax
    xor di, di
    mov si, pattern0
    mov cx, 8
.cmp_page0:
    lodsw
    cmp ax, [es:di]
    jne fail_backing
    add di, 2
    loop .cmp_page0

    mov ah, 0x45
    mov dx, [ems_handle]
    int 0x67
    test ah, ah
    jnz fail_free

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_vec:
    mov dx, fail_vec_msg
    jmp fail
fail_device:
    mov dx, fail_device_msg
    jmp fail
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
fail_info:
    mov dx, fail_info_msg
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
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

ems_handle: dw 0
ems_frame: dw 0
emm_name: db "EMMXXXX0", 0
pattern0: db "EMS page zero!!", 0, 0
pattern1: db "EMS page one!!!", 0
pass_msg: db "PASS: EMS", 13, 10, "$"
fail_vec_msg: db "FAIL: EMS VEC", 13, 10, "$"
fail_device_msg: db "FAIL: EMS DEVICE", 13, 10, "$"
fail_status_msg: db "FAIL: EMS STATUS", 13, 10, "$"
fail_version_msg: db "FAIL: EMS VERSION", 13, 10, "$"
fail_pages_msg: db "FAIL: EMS PAGES", 13, 10, "$"
fail_frame_msg: db "FAIL: EMS FRAME", 13, 10, "$"
fail_alloc_msg: db "FAIL: EMS ALLOC", 13, 10, "$"
fail_info_msg: db "FAIL: EMS INFO", 13, 10, "$"
fail_map_msg: db "FAIL: EMS MAP", 13, 10, "$"
fail_backing_msg: db "FAIL: EMS BACKING", 13, 10, "$"
fail_free_msg: db "FAIL: EMS FREE", 13, 10, "$"
