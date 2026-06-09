[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, dta
    mov ah, 0x1A
    int 0x21

    mov dx, lower_mixed_file
    mov ax, 0x3D00
    int 0x21
    jc fail_open_lower
    mov [handle], ax
    mov bx, ax
    mov dx, read_buf
    mov cx, 5
    mov ah, 0x3F
    int 0x21
    jc fail_read_lower
    cmp ax, 5
    jne fail_read_lower
    mov si, hello_prefix
    mov di, read_buf
    mov cx, 5
    repe cmpsb
    jne fail_read_lower
    call close_handle

    mov dx, lower_find_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_find_lower
    mov si, expected_subtest
    mov di, dta + 30
    call check_zstr
    jc fail_find_lower

    mov dx, lower_device_path
    mov ax, 0x3D00
    int 0x21
    jc fail_device_path
    mov [handle], ax
    mov bx, ax
    mov dx, read_buf
    mov cx, 4
    mov ah, 0x3F
    int 0x21
    jc fail_device_path
    test ax, ax
    jne fail_device_path
    call close_handle

    mov dx, mixed_dot_dir
    mov ah, 0x3B
    int 0x21
    jc fail_cd_mixed
    mov si, expected_midemo
    call check_curdir
    jc fail_curdir

    mov dx, dot_relative_file
    mov ax, 0x3D00
    int 0x21
    jc fail_open_dot_relative
    mov [handle], ax
    call close_handle

    mov dx, above_root_dir
    mov ah, 0x3B
    int 0x21
    jc fail_cd_above
    mov si, expected_root
    call check_curdir
    jc fail_curdir_root

    mov dx, dot_dir
    mov ah, 0x3B
    int 0x21
    jc fail_cd_dot
    mov si, expected_root
    call check_curdir
    jc fail_curdir_root

    mov dx, dotdot_dir
    mov ah, 0x3B
    int 0x21
    jc fail_cd_dotdot
    mov si, expected_root
    call check_curdir
    jc fail_curdir_root

    mov dx, empty_dir
    mov ah, 0x3B
    int 0x21
    jnc fail_cd_empty

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

close_handle:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    ret

check_curdir:
    mov [expected_ptr], si
    mov dl, 0
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

fail_open_lower:
    mov dx, fail_open_lower_msg
    jmp fail
fail_read_lower:
    mov dx, fail_read_lower_msg
    jmp fail
fail_find_lower:
    mov dx, fail_find_lower_msg
    jmp fail
fail_device_path:
    mov dx, fail_device_path_msg
    jmp fail
fail_cd_mixed:
    mov dx, fail_cd_mixed_msg
    jmp fail
fail_open_dot_relative:
    mov dx, fail_open_dot_relative_msg
    jmp fail
fail_cd_above:
    mov dx, fail_cd_above_msg
    jmp fail
fail_cd_dot:
    mov dx, fail_cd_dot_msg
    jmp fail
fail_cd_dotdot:
    mov dx, fail_cd_dotdot_msg
    jmp fail
fail_cd_empty:
    mov dx, fail_cd_empty_msg
    jmp fail
fail_curdir:
    mov dx, fail_curdir_msg
    jmp fail
fail_curdir_root:
    mov dx, fail_curdir_root_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

lower_mixed_file: db "a:/midemo\subtest.dat", 0
lower_find_pattern: db "a:\midemo/*.dat", 0
lower_device_path: db "a:/nUl.txt", 0
mixed_dot_dir: db "a:/midemo/../midemo/.", 0
dot_relative_file: db ".\subtest.dat", 0
above_root_dir: db "..\..", 0
dot_dir: db ".", 0
dotdot_dir: db "..", 0
empty_dir: db 0
hello_prefix: db "Hello"
expected_subtest: db "SUBTEST.DAT", 0
expected_midemo: db "MIDEMO", 0
expected_root: db 0
pass_msg: db "PASS: PATHCANON", 13, 10, "$"
fail_open_lower_msg: db "FAIL: PATHCANON OPEN LOWER", 13, 10, "$"
fail_read_lower_msg: db "FAIL: PATHCANON READ LOWER", 13, 10, "$"
fail_find_lower_msg: db "FAIL: PATHCANON FIND LOWER", 13, 10, "$"
fail_device_path_msg: db "FAIL: PATHCANON DEVICE PATH", 13, 10, "$"
fail_cd_mixed_msg: db "FAIL: PATHCANON CD MIXED", 13, 10, "$"
fail_open_dot_relative_msg: db "FAIL: PATHCANON OPEN DOTREL", 13, 10, "$"
fail_cd_above_msg: db "FAIL: PATHCANON CD ABOVE", 13, 10, "$"
fail_cd_dot_msg: db "FAIL: PATHCANON CD DOT", 13, 10, "$"
fail_cd_dotdot_msg: db "FAIL: PATHCANON CD DOTDOT", 13, 10, "$"
fail_cd_empty_msg: db "FAIL: PATHCANON CD EMPTY", 13, 10, "$"
fail_curdir_msg: db "FAIL: PATHCANON CURDIR", 13, 10, "$"
fail_curdir_root_msg: db "FAIL: PATHCANON ROOT CURDIR", 13, 10, "$"
handle: dw 0
expected_ptr: dw 0
read_buf: times 8 db 0
curdir_buf: times 64 db 0
dta: times 64 db 0
