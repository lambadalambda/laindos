[bits 16]
[org 0x0100]

marker_off_hi equ 0x0200
marker_off_lo equ 0x0010
marker_len equ 16

start:
    push cs
    pop ds

    mov dx, filename
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, [handle]
    mov cx, marker_off_hi
    mov dx, marker_off_lo
    mov ax, 0x4200
    int 0x21
    jc fail_seek

    mov bx, [handle]
    mov dx, buf
    mov cx, marker_len
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, marker_len
    jne fail_read

    mov si, buf
    mov di, marker
    mov cx, marker_len
    repe cmpsb
    jne fail_data

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov dx, newname
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, [handle]
    mov dx, marker
    mov cx, marker_len
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, marker_len
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov dx, newname
    mov ax, 0x3D00
    int 0x21
    jc fail_reopen
    mov [handle], ax

    mov bx, [handle]
    mov dx, buf
    mov cx, marker_len
    mov ah, 0x3F
    int 0x21
    jc fail_reread
    cmp ax, marker_len
    jne fail_reread

    mov si, buf
    mov di, marker
    mov cx, marker_len
    repe cmpsb
    jne fail_data

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_seek:
    mov dx, fail_seek_msg
    jmp fail
fail_read:
    mov dx, fail_read_msg
    jmp fail
fail_data:
    mov dx, fail_data_msg
    jmp fail
fail_create:
    mov dx, fail_create_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
    jmp fail
fail_reopen:
    mov dx, fail_reopen_msg
    jmp fail
fail_reread:
    mov dx, fail_reread_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "BIG.DAT", 0
newname: db "NEW.DAT", 0
marker: db "FAT16-BIG-LBA!", 0, 0
pass_msg: db "PASS: FAT16BIG", 13, 10, "$"
fail_open_msg: db "FAIL: FAT16BIG OPEN", 13, 10, "$"
fail_seek_msg: db "FAIL: FAT16BIG SEEK", 13, 10, "$"
fail_read_msg: db "FAIL: FAT16BIG READ", 13, 10, "$"
fail_data_msg: db "FAIL: FAT16BIG DATA", 13, 10, "$"
fail_create_msg: db "FAIL: FAT16BIG CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: FAT16BIG WRITE", 13, 10, "$"
fail_reopen_msg: db "FAIL: FAT16BIG REOPEN", 13, 10, "$"
fail_reread_msg: db "FAIL: FAT16BIG REREAD", 13, 10, "$"
handle: dw 0
buf: times marker_len db 0
