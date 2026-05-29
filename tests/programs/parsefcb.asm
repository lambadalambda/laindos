[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es

    call init_fcb
    mov si, preserve_name
    mov di, fcb_buf
    mov ax, 0x290A
    int 0x21
    push cs
    pop ds
    push cs
    pop es
    cmp al, 0
    jne fail_preserve
    cmp si, preserve_name_end
    jne fail_preserve
    mov si, fcb_buf
    mov di, expect_preserve
    mov cx, 12
    repe cmpsb
    jne fail_preserve

    call init_fcb
    mov si, empty_name
    mov di, fcb_buf
    mov ax, 0x290E
    int 0x21
    push cs
    pop ds
    push cs
    pop es
    cmp al, 0
    jne fail_empty_preserve
    cmp si, empty_name
    jne fail_empty_preserve
    mov si, fcb_buf
    mov di, fcb_seed
    mov cx, 12
    repe cmpsb
    jne fail_empty_preserve

    call init_fcb
    mov si, leading_name
    mov di, fcb_buf
    mov ax, 0x2900
    int 0x21
    push cs
    pop ds
    push cs
    pop es
    cmp al, 0
    jne fail_leading_stop
    cmp si, leading_name
    jne fail_leading_stop
    mov si, fcb_buf
    mov di, expect_blank
    mov cx, 12
    repe cmpsb
    jne fail_leading_stop

    call init_fcb
    mov si, leading_name
    mov di, fcb_buf
    mov ax, 0x2901
    int 0x21
    push cs
    pop ds
    push cs
    pop es
    cmp al, 0
    jne fail_leading_skip
    cmp si, leading_name_end
    jne fail_leading_skip
    mov si, fcb_buf
    mov di, expect_leading
    mov cx, 12
    repe cmpsb
    jne fail_leading_skip

    call init_fcb
    mov si, wildcard_name
    mov di, fcb_buf
    mov ax, 0x2901
    int 0x21
    push cs
    pop ds
    push cs
    pop es
    cmp al, 1
    jne fail_wildcard
    cmp si, wildcard_name_end
    jne fail_wildcard
    mov si, fcb_buf
    mov di, expect_wildcard
    mov cx, 12
    repe cmpsb
    jne fail_wildcard

    call init_fcb
    mov si, bad_drive_name
    mov di, fcb_buf
    mov ax, 0x2901
    int 0x21
    push cs
    pop ds
    push cs
    pop es
    cmp al, 0xFF
    jne fail_bad_drive
    cmp si, bad_drive_after_spec
    jne fail_bad_drive

    call init_fcb
    mov si, separator_name
    mov di, fcb_buf
    mov ax, 0x2901
    int 0x21
    push cs
    pop ds
    push cs
    pop es
    cmp al, 0
    jne fail_separator
    cmp si, separator_stop
    jne fail_separator
    mov si, fcb_buf
    mov di, expect_separator
    mov cx, 12
    repe cmpsb
    jne fail_separator

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

init_fcb:
    push si
    push di
    push cx
    mov si, fcb_seed
    mov di, fcb_buf
    mov cx, 16
    rep movsb
    pop cx
    pop di
    pop si
    ret

fail_preserve:
    mov dx, fail_preserve_msg
    jmp fail
fail_empty_preserve:
    mov dx, fail_empty_preserve_msg
    jmp fail
fail_leading_stop:
    mov dx, fail_leading_stop_msg
    jmp fail
fail_leading_skip:
    mov dx, fail_leading_skip_msg
    jmp fail
fail_wildcard:
    mov dx, fail_wildcard_msg
    jmp fail
fail_bad_drive:
    mov dx, fail_bad_drive_msg
    jmp fail
fail_separator:
    mov dx, fail_separator_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

preserve_name: db "name"
preserve_name_end: db 0
empty_name: db 0
leading_name: db "  next.txt"
leading_name_end: db 0
wildcard_name: db "ab*.q*"
wildcard_name_end: db 0
bad_drive_name: db "1:"
bad_drive_after_spec: db "bad", 0
separator_name: db "foo"
separator_stop: db ";bar", 0

fcb_seed: db 7, "OLDNAME ", "EXT", 0, 0, 0, 0
expect_preserve: db 7, "NAME    ", "EXT"
expect_blank: db 0, "        ", "   "
expect_leading: db 0, "NEXT    ", "TXT"
expect_wildcard: db 0, "AB??????", "Q??"
expect_separator: db 0, "FOO     ", "   "
fcb_buf: times 16 db 0

pass_msg: db "PASS: PARSEFCB", 13, 10, "$"
fail_preserve_msg: db "FAIL: PARSEFCB PRESERVE", 13, 10, "$"
fail_empty_preserve_msg: db "FAIL: PARSEFCB EMPTY PRESERVE", 13, 10, "$"
fail_leading_stop_msg: db "FAIL: PARSEFCB LEADING STOP", 13, 10, "$"
fail_leading_skip_msg: db "FAIL: PARSEFCB LEADING SKIP", 13, 10, "$"
fail_wildcard_msg: db "FAIL: PARSEFCB WILDCARD", 13, 10, "$"
fail_bad_drive_msg: db "FAIL: PARSEFCB BAD DRIVE", 13, 10, "$"
fail_separator_msg: db "FAIL: PARSEFCB SEPARATOR", 13, 10, "$"
