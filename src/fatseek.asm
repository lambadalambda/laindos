[bits 16]
[org 0x100]

seek_count equ 128
entry_size equ 6
seek_start equ 0x00000123
seek_step equ 0x00020000

start:
    push cs
    pop ds

    mov dx, filename
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax

    mov si, seek_table
    mov word [seek_left], seek_count
.loop:
    mov bx, [handle]
    mov dx, [si]
    mov cx, [si+2]
    mov ax, 0x4200
    int 0x21
    jc fail_seek

    mov bx, [handle]
    mov dx, buf
    mov cx, 1
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 1
    jne fail_read
    mov al, [buf]
    cmp al, [si+4]
    jne fail_data

    add si, entry_size
    dec word [seek_left]
    jnz .loop

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
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "SEEKBIG.DAT", 0
pass_msg: db "PASS: FATSEEK", 13, 10, "$"
fail_open_msg: db "FAIL: FATSEEK OPEN", 13, 10, "$"
fail_seek_msg: db "FAIL: FATSEEK SEEK", 13, 10, "$"
fail_read_msg: db "FAIL: FATSEEK READ", 13, 10, "$"
fail_data_msg: db "FAIL: FATSEEK DATA", 13, 10, "$"
handle: dw 0
seek_left: dw 0
buf: db 0

seek_table:
%assign idx 1
%assign off seek_start
%rep seek_count
    dw off & 0xFFFF
    dw (off >> 16) & 0xFFFF
    db idx & 0xFF
    db 0
%assign idx idx + 1
%assign off off + seek_step
%endrep
