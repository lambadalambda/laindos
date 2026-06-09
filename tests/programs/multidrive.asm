[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x19
    int 0x21
    cmp al, 0
    jne fail_initial_drive

    mov dl, 2
    mov ah, 0x0E
    int 0x21
    cmp al, 3
    jne fail_select_c_count

    mov ah, 0x19
    int 0x21
    cmp al, 2
    jne fail_select_c_current

    mov dx, hd_path
    call open_read_expect
    jc fail_read_c

    mov dl, 0
    mov ah, 0x0E
    int 0x21
    cmp al, 3
    jne fail_select_a_count


    mov ah, 0x19
    int 0x21
    cmp al, 0
    jne fail_select_a_current


    mov dx, floppy_path
    call open_read_expect
    jc fail_read_a


    mov dx, hd_path
    call open_read_expect
    jc fail_prefix_c

    call interleaved_handle_test
    jc fail_interleave

    call findnext_drive_test
    jc fail_findnext_c

    call bare_name_drive_test
    jc fail_bare_name_drive

    mov dl, 2
    mov ah, 0x0E
    int 0x21
    mov dx, write_path
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create_c
    mov [handle], ax
    mov bx, ax
    mov dx, write_payload
    mov cx, write_payload_len
    mov ah, 0x40
    int 0x21
    jc fail_write_c
    cmp ax, write_payload_len
    jne fail_write_c
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close_c

    mov dl, 0
    mov ah, 0x0E
    int 0x21
    mov dx, floppy_path
    call open_read_expect
    jc fail_write_interlude_a

    mov dx, write_path
    call open_read_written
    jc fail_reread_c

    call explicit_parent_create_test
    jc fail_explicit_parent_create

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

open_read_expect:
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .err
    mov [handle], ax
    mov bx, ax
    mov dx, read_buf
    mov cx, expect_len
    mov ah, 0x3F
    int 0x21
    jc .close_err
    cmp ax, expect_len
    jne .close_err
    mov si, read_buf
    mov di, expect_payload
    mov cx, expect_len
    repe cmpsb
    jne .close_err
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc .err
    clc
    ret
.close_err:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
.err:
    stc
    ret

interleaved_handle_test:
    xor al, al
    mov dx, floppy_path
    mov ah, 0x3D
    int 0x21
    jc .err
    mov [handle_a], ax
    xor al, al
    mov dx, hd_path
    mov ah, 0x3D
    int 0x21
    jc .close_a_err
    mov [handle_c], ax

    mov bx, [handle_a]
    mov dx, read_buf
    mov cx, expect_part1_len
    mov ah, 0x3F
    int 0x21
    jc .close_both_err
    cmp ax, expect_part1_len
    jne .close_both_err
    mov si, read_buf
    mov di, expect_part1
    mov cx, expect_part1_len
    repe cmpsb
    jne .close_both_err

    mov bx, [handle_c]
    mov dx, read_buf
    mov cx, expect_part1_len
    mov ah, 0x3F
    int 0x21
    jc .close_both_err
    cmp ax, expect_part1_len
    jne .close_both_err
    mov si, read_buf
    mov di, expect_part1
    mov cx, expect_part1_len
    repe cmpsb
    jne .close_both_err

    mov bx, [handle_a]
    mov dx, read_buf
    mov cx, expect_part2_len
    mov ah, 0x3F
    int 0x21
    jc .close_both_err
    cmp ax, expect_part2_len
    jne .close_both_err
    mov si, read_buf
    mov di, expect_part2
    mov cx, expect_part2_len
    repe cmpsb
    jne .close_both_err

    mov bx, [handle_c]
    mov dx, read_buf
    mov cx, expect_part2_len
    mov ah, 0x3F
    int 0x21
    jc .close_both_err
    cmp ax, expect_part2_len
    jne .close_both_err
    mov si, read_buf
    mov di, expect_part2
    mov cx, expect_part2_len
    repe cmpsb
    jne .close_both_err

    mov bx, [handle_c]
    mov ah, 0x3E
    int 0x21
    jc .close_a_err
    mov bx, [handle_a]
    mov ah, 0x3E
    int 0x21
    jc .err
    clc
    ret
.close_both_err:
    mov bx, [handle_c]
    mov ah, 0x3E
    int 0x21
.close_a_err:
    mov bx, [handle_a]
    mov ah, 0x3E
    int 0x21
.err:
    stc
    ret

findnext_drive_test:
    mov dx, find_dta
    mov ah, 0x1A
    int 0x21
    xor cx, cx
    mov dx, find_path
    mov ah, 0x4E
    int 0x21
    jc .err
    mov dl, 0
    mov ah, 0x0E
    int 0x21
    mov ah, 0x4F
    int 0x21
    jc .err
    mov si, find_dta+30
    mov di, hdonly_name
    mov cx, hdonly_name_len
    repe cmpsb
    jne .err
     cmp byte [find_dta+30+hdonly_name_len], 0
    jne .err
    clc
    ret
.err:
    stc
    ret

bare_name_drive_test:
    mov dl, 0
    mov ah, 0x0E
    int 0x21
    mov dx, bare_c_path
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc .bare_err
    mov si, find_dta+30
    mov di, hdonly_name
    mov cx, hdonly_name_len
    repe cmpsb
    jne .bare_err
    cmp byte [find_dta+30+hdonly_name_len], 0
    jne .bare_err
    clc
    ret
.bare_err:
    stc
    ret

explicit_parent_create_test:
    mov dl, 0
    mov ah, 0x0E
    int 0x21
    mov dx, sammax_dir
    mov ah, 0x39
    int 0x21
    jc .err
    mov dx, sammax_ini
    xor cx, cx
    mov ax, 0x3C80
    int 0x21
    jc .err
    mov [handle], ax
    mov bx, ax
    mov dx, setmuse_payload
    mov cx, setmuse_payload_len
    mov ah, 0x40
    int 0x21
    jc .close_err
    cmp ax, setmuse_payload_len
    jne .close_err
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc .err
    mov dx, sammax_ini
    call open_read_setmuse
    jc .err
    clc
    ret
.close_err:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
.err:
    stc
    ret

open_read_setmuse:
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .err
    mov [handle], ax
    mov bx, ax
    mov dx, read_buf
    mov cx, setmuse_payload_len
    mov ah, 0x3F
    int 0x21
    jc .close_err
    cmp ax, setmuse_payload_len
    jne .close_err
    mov si, read_buf
    mov di, setmuse_payload
    mov cx, setmuse_payload_len
    repe cmpsb
    jne .close_err
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc .err
    clc
    ret
.close_err:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
.err:
    stc
    ret

open_read_written:
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .err
    mov [handle], ax
    mov bx, ax
    mov dx, read_buf
    mov cx, write_payload_len
    mov ah, 0x3F
    int 0x21
    jc .close_err
    cmp ax, write_payload_len
    jne .close_err
    mov si, read_buf
    mov di, write_payload
    mov cx, write_payload_len
    repe cmpsb
    jne .close_err
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc .err
    clc
    ret
.close_err:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
.err:
    stc
    ret

fail_initial_drive:
    mov dx, fail_initial_drive_msg
    jmp fail
fail_select_c_count:
    mov dx, fail_select_c_count_msg
    jmp fail
fail_select_c_current:
    mov dx, fail_select_c_current_msg
    jmp fail
fail_select_a_count:
    mov dx, fail_select_a_count_msg
    jmp fail
fail_select_a_current:
    mov dx, fail_select_a_current_msg
    jmp fail
fail_read_c:
    mov dx, fail_read_c_msg
    jmp fail
fail_read_a:
    mov dx, fail_read_a_msg
    jmp fail
fail_prefix_c:
    mov dx, fail_prefix_c_msg
    jmp fail
fail_interleave:
    mov dx, fail_interleave_msg
    jmp fail
 fail_findnext_c:
    mov dx, fail_findnext_c_msg
    jmp fail
fail_bare_name_drive:
    mov dx, fail_bare_name_drive_msg
    jmp fail
fail_create_c:
    mov dx, fail_create_c_msg
    jmp fail
fail_write_c:
    mov dx, fail_write_c_msg
    jmp fail
fail_close_c:
    mov dx, fail_close_c_msg
    jmp fail
fail_write_interlude_a:
    mov dx, fail_write_interlude_a_msg
    jmp fail
fail_reread_c:
    mov dx, fail_reread_c_msg
    jmp fail
fail_explicit_parent_create:
    mov dx, fail_explicit_parent_create_msg

fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

expect_payload: db "DRIVEOK"
expect_len equ $ - expect_payload
expect_part1: db "DRI"
expect_part1_len equ $ - expect_part1
expect_part2: db "VEOK"
expect_part2_len equ $ - expect_part2
write_payload: db "WRITEOK"
write_payload_len equ $ - write_payload
hd_path: db "C:\HDONLY.TXT", 0
floppy_path: db "A:\AONLY.TXT", 0
write_path: db "C:\WRTEST.TXT", 0
find_path: db "C:\*.*", 0
bare_c_path: db "C:HDONLY.TXT", 0
sammax_dir: db "C:\SAMNMAX.CD", 0
sammax_ini: db "C:\SAMNMAX.CD\SETMUSE.INI", 0
hdonly_name: db "HDONLY.TXT"
hdonly_name_len equ $ - hdonly_name
setmuse_payload: db "INI"
setmuse_payload_len equ $ - setmuse_payload
pass_msg: db "PASS: MULTIDRIVE", 13, 10, "$"
fail_initial_drive_msg: db "FAIL: MULTIDRIVE INITIAL DRIVE", 13, 10, "$"
fail_select_c_count_msg: db "FAIL: MULTIDRIVE SELECT C COUNT", 13, 10, "$"
fail_select_c_current_msg: db "FAIL: MULTIDRIVE SELECT C CURRENT", 13, 10, "$"
fail_select_a_count_msg: db "FAIL: MULTIDRIVE SELECT A COUNT", 13, 10, "$"
fail_select_a_current_msg: db "FAIL: MULTIDRIVE SELECT A CURRENT", 13, 10, "$"
fail_read_c_msg: db "FAIL: MULTIDRIVE READ C", 13, 10, "$"
fail_read_a_msg: db "FAIL: MULTIDRIVE READ A", 13, 10, "$"
fail_prefix_c_msg: db "FAIL: MULTIDRIVE PREFIX C", 13, 10, "$"
fail_interleave_msg: db "FAIL: MULTIDRIVE INTERLEAVE", 13, 10, "$"
fail_findnext_c_msg: db "FAIL: MULTIDRIVE FINDNEXT C", 13, 10, "$"
fail_bare_name_drive_msg: db "FAIL: MULTIDRIVE BARE NAME DRIVE", 13, 10, "$"
fail_create_c_msg: db "FAIL: MULTIDRIVE CREATE C", 13, 10, "$"
fail_write_c_msg: db "FAIL: MULTIDRIVE WRITE C", 13, 10, "$"
fail_close_c_msg: db "FAIL: MULTIDRIVE CLOSE C", 13, 10, "$"
fail_write_interlude_a_msg: db "FAIL: MULTIDRIVE WRITE INTERLUDE A", 13, 10, "$"
fail_reread_c_msg: db "FAIL: MULTIDRIVE REREAD C", 13, 10, "$"
fail_explicit_parent_create_msg: db "FAIL: MULTIDRIVE EXPLICIT PARENT CREATE", 13, 10, "$"
handle: dw 0
handle_a: dw 0
handle_c: dw 0
read_buf: times 16 db 0
find_dta: times 64 db 0
