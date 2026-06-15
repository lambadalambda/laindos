%include "tests/programs/common.inc"

COM_START
    cld
    push cs
    pop es

    PRINT_DOLLAR msg_bench
    mov ax, 0xF000
    int 0x21
    jc fail_perf
    mov word [loop_count], 32
.perf_loop:
    mov dx, target_path
    call open_close
    dec word [loop_count]
    jnz .perf_loop
    mov ax, 0xF001
    int 0x21
    jc fail_perf

    mov dx, target_path
    call open_close

    mov dx, new_path
    call create_close
    mov dx, new_path
    call open_close
    mov dx, new_path
    call delete_path
    mov dx, new_path
    call expect_missing

    mov dx, old_path
    call create_close
    mov dx, old_path
    mov di, renamed_path
    mov ah, 0x56
    int 0x21
    jc fail_rename
    mov dx, old_path
    call expect_missing
    mov dx, renamed_path
    call open_close

    mov dx, attr_path
    call create_close
    mov dx, attr_path
    mov cx, 1
    mov ax, 0x4301
    int 0x21
    jc fail_attr
    mov dx, attr_path
    mov ax, 0x4300
    int 0x21
    jc fail_attr
    test cl, 1
    jz fail_attr

    mov dx, mkdir_path
    mov ah, 0x39
    int 0x21
    jc fail_mkdir
    mov dx, child_path
    call create_close
    mov dx, child_path
    call delete_path
    mov dx, mkdir_path
    mov ah, 0x3A
    int 0x21
    jc fail_rmdir
    mov dx, stale_child_path
    call expect_create_error

    PASS_WITH msg_pass

open_close:
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

create_close:
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

delete_path:
    mov ah, 0x41
    int 0x21
    jc fail_delete
    ret

expect_missing:
    mov ax, 0x3D00
    int 0x21
    jnc fail_expected_missing
    ret

expect_create_error:
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jnc fail_expected_create_error
    ret

fail_perf:
    FAIL_WITH msg_fail_perf
fail_open:
    FAIL_WITH msg_fail_open
fail_close:
    FAIL_WITH msg_fail_close
fail_create:
    FAIL_WITH msg_fail_create
fail_delete:
    FAIL_WITH msg_fail_delete
fail_rename:
    FAIL_WITH msg_fail_rename
fail_attr:
    FAIL_WITH msg_fail_attr
fail_mkdir:
    FAIL_WITH msg_fail_mkdir
fail_rmdir:
    FAIL_WITH msg_fail_rmdir
fail_expected_missing:
    FAIL_WITH msg_fail_expected_missing
fail_expected_create_error:
    FAIL_WITH msg_fail_expected_create_error

msg_bench: db "BENCH: DIRCACHE", 13, 10, "$"
msg_pass: db "PASS: DIRCACHE", 13, 10, "$"
msg_fail_perf: db "FAIL: DIRCACHE PERF", 13, 10, "$"
msg_fail_open: db "FAIL: DIRCACHE OPEN", 13, 10, "$"
msg_fail_close: db "FAIL: DIRCACHE CLOSE", 13, 10, "$"
msg_fail_create: db "FAIL: DIRCACHE CREATE", 13, 10, "$"
msg_fail_delete: db "FAIL: DIRCACHE DELETE", 13, 10, "$"
msg_fail_rename: db "FAIL: DIRCACHE RENAME", 13, 10, "$"
msg_fail_attr: db "FAIL: DIRCACHE ATTR", 13, 10, "$"
msg_fail_mkdir: db "FAIL: DIRCACHE MKDIR", 13, 10, "$"
msg_fail_rmdir: db "FAIL: DIRCACHE RMDIR", 13, 10, "$"
msg_fail_expected_missing: db "FAIL: DIRCACHE MISSING", 13, 10, "$"
msg_fail_expected_create_error: db "FAIL: DIRCACHE CREATEERR", 13, 10, "$"

target_path: db "CACHE\TARGET.DAT", 0
new_path: db "CACHE\NEWFILE.DAT", 0
old_path: db "CACHE\OLDNAME.DAT", 0
renamed_path: db "CACHE\RENAMED.DAT", 0
attr_path: db "CACHE\ATTR.DAT", 0
mkdir_path: db "CACHE\MAKEDIR", 0
child_path: db "CACHE\MAKEDIR\CHILD.DAT", 0
stale_child_path: db "CACHE\MAKEDIR\STALE.DAT", 0
loop_count: dw 0
