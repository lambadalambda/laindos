[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    cld

    mov dx, dta
    mov ah, 0x1A
    int 0x21

    mov dx, base_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir_base

    mov dx, base_dir
    mov ah, 0x3B
    int 0x21
    jc fail_cd_base

    mov dx, local_file
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, payload
    mov cx, payload_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, payload_size
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, drive_rel_file
    mov ax, 0x3D00
    int 0x21
    jc fail_open_drive_rel
    mov [handle], ax

    mov bx, ax
    mov dx, read_buf
    mov cx, payload_size
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, payload_size
    jne fail_read
    mov si, payload
    mov di, read_buf
    mov cx, payload_size
    repe cmpsb
    jne fail_read

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, drive_rel_find
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_find_drive_rel
    mov si, expected_local
    mov di, dta + 30
    call check_zstr
    jc fail_find_drive_rel

    mov dx, inner_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir_inner

    mov dx, drive_rel_inner
    mov ah, 0x3B
    int 0x21
    jc fail_cd_drive_rel

    mov si, expected_inner
    call check_curdir
    jc fail_curdir_inner

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

check_curdir:
    mov [expected_ptr], si
    xor dl, dl
    mov si, curdir_buf
    mov ah, 0x47
    int 0x21
    jc .bad
    mov si, [expected_ptr]
    mov di, curdir_buf
    call check_zstr
    ret
.bad:
    stc
    ret

check_zstr:
    lodsb
    cmp al, [di]
    jne .bad
    inc di
    test al, al
    jnz check_zstr
    clc
    ret
.bad:
    stc
    ret

fail_mkdir_base:
    mov dx, fail_mkdir_base_msg
    jmp fail
fail_cd_base:
    mov dx, fail_cd_base_msg
    jmp fail
fail_create:
    mov dx, fail_create_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_open_drive_rel:
    mov dx, fail_open_drive_rel_msg
    jmp fail
fail_read:
    mov dx, fail_read_msg
    jmp fail
fail_find_drive_rel:
    mov dx, fail_find_drive_rel_msg
    jmp fail
fail_mkdir_inner:
    mov dx, fail_mkdir_inner_msg
    jmp fail
fail_cd_drive_rel:
    mov dx, fail_cd_drive_rel_msg
    jmp fail
fail_curdir_inner:
    mov dx, fail_curdir_inner_msg

fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

base_dir: db "DPBASE", 0
inner_dir: db "INNER", 0
local_file: db "LOCAL.TXT", 0
drive_rel_file: db "A:LOCAL.TXT", 0
drive_rel_find: db "A:*.TXT", 0
drive_rel_inner: db "A:INNER", 0
expected_local: db "LOCAL.TXT", 0
expected_inner: db "DPBASE\INNER", 0
payload: db "drive-relative", 13, 10
payload_size equ $ - payload
pass_msg: db "PASS: DRIVEPATH", 13, 10, "$"
fail_mkdir_base_msg: db "FAIL: DRIVEPATH MKDIR BASE", 13, 10, "$"
fail_cd_base_msg: db "FAIL: DRIVEPATH CD BASE", 13, 10, "$"
fail_create_msg: db "FAIL: DRIVEPATH CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: DRIVEPATH WRITE", 13, 10, "$"
fail_close_msg: db "FAIL: DRIVEPATH CLOSE", 13, 10, "$"
fail_open_drive_rel_msg: db "FAIL: DRIVEPATH OPEN REL", 13, 10, "$"
fail_read_msg: db "FAIL: DRIVEPATH READ", 13, 10, "$"
fail_find_drive_rel_msg: db "FAIL: DRIVEPATH FIND REL", 13, 10, "$"
fail_mkdir_inner_msg: db "FAIL: DRIVEPATH MKDIR INNER", 13, 10, "$"
fail_cd_drive_rel_msg: db "FAIL: DRIVEPATH CD REL", 13, 10, "$"
fail_curdir_inner_msg: db "FAIL: DRIVEPATH CURDIR INNER", 13, 10, "$"
handle: dw 0
expected_ptr: dw 0
read_buf: times 32 db 0
curdir_buf: times 64 db 0
dta: times 64 db 0
