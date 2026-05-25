[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, subdir_name
    mov ah, 0x3B
    int 0x21
    jc fail_chdir

    call read_magic
    call read_magic

    mov dx, root_path
    mov ah, 0x3B
    int 0x21
    jc fail_chdir

    call read_magic_after_mkdir

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

read_magic:
    mov dx, file_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, ax
    mov ax, 0x4200
    xor cx, cx
    mov dx, 0x0028
    int 0x21
    jc fail_seek
    cmp dx, 0
    jne fail_seek
    cmp ax, 0x0028
    jne fail_seek

    mov bx, [handle]
    mov dx, word_buf
    mov cx, 2
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 2
    jne fail_read
    cmp word [word_buf], 0x111B
    jne fail_data

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

read_magic_after_mkdir:
    mov dx, file_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [handle], ax

    call seek_magic
    call read_magic_word

    call seek_magic
    mov dx, mkdir_name
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov bx, [handle]
    mov dx, word_buf
    mov cx, 2
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 2
    jne fail_read
    cmp word [word_buf], 0x111B
    jne fail_data

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

seek_magic:
    mov bx, [handle]
    mov ax, 0x4200
    xor cx, cx
    mov dx, 0x0028
    int 0x21
    jc fail_seek
    cmp dx, 0
    jne fail_seek
    cmp ax, 0x0028
    jne fail_seek
    ret

read_magic_word:
    mov bx, [handle]
    mov dx, word_buf
    mov cx, 2
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 2
    jne fail_read
    cmp word [word_buf], 0x111B
    jne fail_data
    ret

fail_chdir:
    mov dx, fail_chdir_msg
    jmp fail
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
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_mkdir:
    mov dx, fail_mkdir_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
word_buf: dw 0
subdir_name: db "MIDEMO", 0
root_path: db "\\", 0
file_name: db "CACHE.DAT", 0
mkdir_name: db "CACHECHK", 0
pass_msg: db "PASS: READCACHE", 13, 10, "$"
fail_chdir_msg: db "FAIL: READCACHE CHDIR", 13, 10, "$"
fail_open_msg: db "FAIL: READCACHE OPEN", 13, 10, "$"
fail_seek_msg: db "FAIL: READCACHE SEEK", 13, 10, "$"
fail_read_msg: db "FAIL: READCACHE READ", 13, 10, "$"
fail_data_msg: db "FAIL: READCACHE DATA", 13, 10, "$"
fail_close_msg: db "FAIL: READCACHE CLOSE", 13, 10, "$"
fail_mkdir_msg: db "FAIL: READCACHE MKDIR", 13, 10, "$"
