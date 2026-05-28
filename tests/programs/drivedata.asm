[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x1B
    int 0x21
    jc fail_default
    call check_floppy_info

    mov ah, 0x1C
    xor dl, dl
    int 0x21
    jc fail_drive_default
    call check_floppy_info

    mov ah, 0x1C
    mov dl, 1
    int 0x21
    jc fail_drive_a
    call check_floppy_info

    mov ah, 0x1C
    mov dl, 2
    int 0x21
    cmp al, 0xFF
    jne fail_invalid

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

check_floppy_info:
    cmp al, 1
    jne fail_info
    cmp cx, 512
    jne fail_info
    cmp dx, 2847
    jne fail_info
    cmp bx, 0
    je fail_media
    mov al, [ds:bx]
    cmp al, 0xF0
    jne fail_media
    ret

fail_default:
    mov dx, fail_default_msg
    jmp fail
fail_drive_default:
    mov dx, fail_drive_default_msg
    jmp fail
fail_drive_a:
    mov dx, fail_drive_a_msg
    jmp fail
fail_info:
    mov dx, fail_info_msg
    jmp fail
fail_media:
    mov dx, fail_media_msg
    jmp fail
fail_invalid:
    mov dx, fail_invalid_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db 'PASS: DRIVEDATA', 13, 10, '$'
fail_default_msg: db 'FAIL: DRIVEDATA AH1B', 13, 10, '$'
fail_drive_default_msg: db 'FAIL: DRIVEDATA AH1C DEFAULT', 13, 10, '$'
fail_drive_a_msg: db 'FAIL: DRIVEDATA AH1C A', 13, 10, '$'
fail_info_msg: db 'FAIL: DRIVEDATA INFO', 13, 10, '$'
fail_media_msg: db 'FAIL: DRIVEDATA MEDIA', 13, 10, '$'
fail_invalid_msg: db 'FAIL: DRIVEDATA INVALID', 13, 10, '$'
