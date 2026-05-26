[bits 16]
[org 0x0100]

marker_off_hi equ 0x0200
marker_off_lo equ 0x0010
marker_len equ 16
chunk_len equ 512
chunk_count equ 40
large_size equ chunk_len * chunk_count

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
    call check_marker

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov dx, rootname
    call create_large_file
    mov dx, rootname
    call verify_large_file
    mov dx, rootname
    call truncate_marker_file
    mov dx, rootname
    call verify_marker_file

    mov dx, subname
    call create_large_file
    mov dx, subname
    call verify_large_file
    mov dx, subname
    call truncate_marker_file
    mov dx, subname
    call verify_marker_file

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

create_large_file:
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax
    call write_blocks
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    ret

verify_large_file:
    mov ax, 0x3D00
    int 0x21
    jc fail_reopen
    mov [handle], ax
    mov ax, large_size
    call check_size
    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    call read_blocks
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    ret

truncate_marker_file:
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
    ret

verify_marker_file:
    mov ax, 0x3D00
    int 0x21
    jc fail_reopen
    mov [handle], ax
    mov ax, marker_len
    call check_size
    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    mov bx, [handle]
    mov dx, buf
    mov cx, marker_len
    mov ah, 0x3F
    int 0x21
    jc fail_reread
    cmp ax, marker_len
    jne fail_reread
    call check_marker
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    ret

check_size:
    mov [expect_size], ax
    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4202
    int 0x21
    jc fail_seek
    cmp dx, 0
    jne fail_size
    cmp ax, [expect_size]
    jne fail_size
    ret

write_blocks:
    mov byte [pattern], 0
    mov word [chunks_left], chunk_count
.loop:
    call fill_buf
    mov bx, [handle]
    mov dx, buf
    mov cx, chunk_len
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, chunk_len
    jne fail_write
    inc byte [pattern]
    dec word [chunks_left]
    jnz .loop
    ret

read_blocks:
    mov byte [pattern], 0
    mov word [chunks_left], chunk_count
.loop:
    mov bx, [handle]
    mov dx, buf
    mov cx, chunk_len
    mov ah, 0x3F
    int 0x21
    jc fail_reread
    cmp ax, chunk_len
    jne fail_reread
    call check_buf
    inc byte [pattern]
    dec word [chunks_left]
    jnz .loop
    ret

fill_buf:
    push ax
    push cx
    push di
    push es
    push cs
    pop es
    mov di, buf
    mov al, [pattern]
    mov cx, chunk_len
    cld
    rep stosb
    pop es
    pop di
    pop cx
    pop ax
    ret

check_buf:
    push ax
    push cx
    push si
    mov si, buf
    mov al, [pattern]
    mov cx, chunk_len
.loop:
    cmp [si], al
    jne fail_data
    inc si
    loop .loop
    pop si
    pop cx
    pop ax
    ret

check_marker:
    mov si, buf
    mov di, marker
    mov cx, marker_len
    repe cmpsb
    jne fail_data
    ret

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
    jmp fail
fail_size:
    mov dx, fail_size_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "BIG.DAT", 0
rootname: db "NEW.DAT", 0
subname: db "\CFGDIR\SET.DAT", 0
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
fail_size_msg: db "FAIL: FAT16BIG SIZE", 13, 10, "$"
handle: dw 0
expect_size: dw 0
chunks_left: dw 0
pattern: db 0
buf: times chunk_len db 0
