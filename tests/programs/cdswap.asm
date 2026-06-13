[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    cld
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    mov dx, dta
    mov ah, 0x1A
    int 0x21

    mov dx, cd_root
    mov cx, 0x0008
    mov ah, 0x4E
    int 0x21
    jc fail_old_label
    mov si, old_label
    mov di, dta + 30
    call str_equal
    jc fail_old_label_name

    mov dx, old_file
    call open_read4_close
    jc fail_old_open
    mov si, old_data
    mov di, buf
    call mem4_equal
    jc fail_old_data

    mov dx, ready_msg
    mov ah, 0x09
    int 0x21

    xor ah, ah
    int 0x16

    mov dx, cd_root
    mov cx, 0x0008
    mov ah, 0x4E
    int 0x21
    jc fail_new_label
    mov si, old_label
    mov di, dta + 30
    call str_equal
    jnc fail_stale_label
    mov si, new_label
    mov di, dta + 30
    call str_equal
    jc fail_new_label_name

    mov dx, cd_wild
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_find
    mov si, old_name
    mov di, dta + 30
    call str_equal
    jnc fail_stale_dir
    mov si, new_name
    mov di, dta + 30
    call str_equal
    jc fail_find_name

    mov dx, new_file
    call open_read4_close
    jc fail_new_open
    mov si, new_data
    mov di, buf
    call mem4_equal
    jc fail_new_data

    mov dx, old_file
    mov ax, 0x3D00
    int 0x21
    jnc fail_stale_open

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

open_read4_close:
    mov ax, 0x3D00
    int 0x21
    jc .err
    mov [handle], ax
    mov bx, ax
    mov cx, 4
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    pushf
    push ax
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    pop ax
    popf
    jc .err
    cmp ax, 4
    jne .err
    clc
    ret
.err:
    stc
    ret

str_equal:
    lodsb
    cmp al, [di]
    jne .diff
    inc di
    test al, al
    jnz str_equal
    clc
    ret
.diff:
    stc
    ret

mem4_equal:
    mov cx, 4
.loop:
    lodsb
    cmp al, [di]
    jne .diff
    inc di
    loop .loop
    clc
    ret
.diff:
    stc
    ret

fail_old_label:
    mov dx, fail_old_label_msg
    jmp fail
fail_old_label_name:
    mov dx, fail_old_label_name_msg
    jmp fail
fail_old_open:
    mov dx, fail_old_open_msg
    jmp fail
fail_old_data:
    mov dx, fail_old_data_msg
    jmp fail
fail_new_label:
    mov dx, fail_new_label_msg
    jmp fail
fail_stale_label:
    mov dx, fail_stale_label_msg
    jmp fail
fail_new_label_name:
    mov dx, fail_new_label_name_msg
    jmp fail
fail_find:
    mov dx, fail_find_msg
    jmp fail
fail_stale_dir:
    mov dx, fail_stale_dir_msg
    jmp fail
fail_find_name:
    mov dx, fail_find_name_msg
    jmp fail
fail_new_open:
    mov dx, fail_new_open_msg
    jmp fail
fail_new_data:
    mov dx, fail_new_data_msg
    jmp fail
fail_stale_open:
    mov dx, fail_stale_open_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

cd_root: db 'D:\', 0
cd_wild: db 'D:\*.*', 0
old_file: db 'D:\OLD.TXT', 0
new_file: db 'D:\NEWFILE.TXT', 0
old_label: db 'OLDCD', 0
new_label: db 'NEWCD', 0
old_name: db 'OLD.TXT', 0
new_name: db 'NEWFILE.TXT', 0
old_data: db 'OLD!'
new_data: db 'NEW!'
ready_msg: db 'READY: CDSWAP', 13, 10, '$'
pass_msg: db 'PASS: CDSWAP', 13, 10, '$'
fail_old_label_msg: db 'FAIL: CDSWAP OLD LABEL', 13, 10, '$'
fail_old_label_name_msg: db 'FAIL: CDSWAP OLD LABEL NAME', 13, 10, '$'
fail_old_open_msg: db 'FAIL: CDSWAP OLD OPEN', 13, 10, '$'
fail_old_data_msg: db 'FAIL: CDSWAP OLD DATA', 13, 10, '$'
fail_new_label_msg: db 'FAIL: CDSWAP NEW LABEL', 13, 10, '$'
fail_stale_label_msg: db 'FAIL: CDSWAP STALE LABEL', 13, 10, '$'
fail_new_label_name_msg: db 'FAIL: CDSWAP NEW LABEL NAME', 13, 10, '$'
fail_find_msg: db 'FAIL: CDSWAP FIND', 13, 10, '$'
fail_stale_dir_msg: db 'FAIL: CDSWAP STALE DIR', 13, 10, '$'
fail_find_name_msg: db 'FAIL: CDSWAP FIND NAME', 13, 10, '$'
fail_new_open_msg: db 'FAIL: CDSWAP NEW OPEN', 13, 10, '$'
fail_new_data_msg: db 'FAIL: CDSWAP NEW DATA', 13, 10, '$'
fail_stale_open_msg: db 'FAIL: CDSWAP STALE OPEN', 13, 10, '$'
handle: dw 0
buf: times 4 db 0
dta: times 64 db 0
