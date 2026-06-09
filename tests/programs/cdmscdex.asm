[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    cld

    mov ax, 0x1500
    xor bx, bx
    int 0x2F
    cmp bx, 1
    jne fail_install_count
    cmp cx, 3
    jne fail_install_drive

    mov ax, 0x150B
    mov cx, 3
    int 0x2F
    cmp bx, 0xADAD
    jne fail_drive_sig
    test ax, ax
    jz fail_drive_supported

    mov ax, 0x150B
    mov cx, 2
    int 0x2F
    cmp bx, 0xADAD
    jne fail_drive_sig
    test ax, ax
    jnz fail_drive_unsupported

    mov ax, 0x150C
    xor bx, bx
    int 0x2F
    cmp bx, 0x0200
    jne fail_version

    mov byte [drive_list], 0xFF
    push cs
    pop es
    mov bx, drive_list
    mov ax, 0x150D
    int 0x2F
    cmp byte [drive_list], 3
    jne fail_drive_list

    mov ax, 0x4300
    int 0x2F
    cmp al, 0x80
    jne fail_xms_still_works

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_install_count:
    mov dx, fail_install_count_msg
    jmp fail
fail_install_drive:
    mov dx, fail_install_drive_msg
    jmp fail
fail_drive_sig:
    mov dx, fail_drive_sig_msg
    jmp fail
fail_drive_supported:
    mov dx, fail_drive_supported_msg
    jmp fail
fail_drive_unsupported:
    mov dx, fail_drive_unsupported_msg
    jmp fail
fail_version:
    mov dx, fail_version_msg
    jmp fail
fail_drive_list:
    mov dx, fail_drive_list_msg
    jmp fail
fail_xms_still_works:
    mov dx, fail_xms_still_works_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

drive_list: db 0
pass_msg: db 'PASS: CDMSCDEX', 13, 10, '$'
fail_install_count_msg: db 'FAIL: CDMSCDEX INSTALL COUNT', 13, 10, '$'
fail_install_drive_msg: db 'FAIL: CDMSCDEX INSTALL DRIVE', 13, 10, '$'
fail_drive_sig_msg: db 'FAIL: CDMSCDEX DRIVE SIG', 13, 10, '$'
fail_drive_supported_msg: db 'FAIL: CDMSCDEX DRIVE SUPPORTED', 13, 10, '$'
fail_drive_unsupported_msg: db 'FAIL: CDMSCDEX DRIVE UNSUPPORTED', 13, 10, '$'
fail_version_msg: db 'FAIL: CDMSCDEX VERSION', 13, 10, '$'
fail_drive_list_msg: db 'FAIL: CDMSCDEX DRIVE LIST', 13, 10, '$'
fail_xms_still_works_msg: db 'FAIL: CDMSCDEX XMS', 13, 10, '$'
