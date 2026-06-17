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
    cmp bx, 0x020A
    jne fail_version

    mov byte [drive_list], 0xFF
    push cs
    pop es
    mov bx, drive_list
    mov ax, 0x150D
    int 0x2F
    cmp byte [drive_list], 3
    jne fail_drive_list

    mov word [dev_list], 0xCCCC
    mov word [dev_list+2], 0xCCCC
    mov byte [dev_list+4], 0xCC
    push cs
    pop es
    mov bx, dev_list
    mov ax, 0x1501
    int 0x2F
    cmp byte [dev_list], 0
    jne fail_device_list
    mov ax, [dev_list+1]
    or ax, [dev_list+3]
    jz fail_device_list

    les di, [dev_list+1]
    cmp word [es:di], 0xFFFF
    jne fail_device_header
    cmp word [es:di+2], 0xFFFF
    jne fail_device_header
    test word [es:di+4], 0xC000
    jz fail_device_header
    cmp word [es:di+6], 0
    je fail_device_header
    cmp word [es:di+8], 0
    je fail_device_header

    mov ax, [es:di+6]
    mov [strategy_ptr], ax
    mov ax, [dev_list+3]
    mov [strategy_ptr+2], ax
    mov ax, [es:di+8]
    mov [interrupt_ptr], ax
    mov ax, [dev_list+3]
    mov [interrupt_ptr+2], ax

    push cs
    pop ds
    push cs
    pop es
    mov byte [req+2], 3
    mov word [req+3], 0
    mov byte [cb], 0
    mov word [req+14], cb
    mov word [req+16], cs
    mov word [req+18], 5
    mov bx, req
    call far [strategy_ptr]
    call far [interrupt_ptr]
    mov ax, [req+3]
    test ax, 0x0100
    jz fail_device_request
    test ax, 0x8000
    jnz fail_device_request
    mov ax, [cb+1]
    cmp ax, [dev_list+1]
    jne fail_device_request
    mov ax, [cb+3]
    cmp ax, [dev_list+3]
    jne fail_device_request

    mov word [req+3], 0x5555
    call far [interrupt_ptr]
    cmp word [req+3], 0x5555
    jne fail_device_request

    mov byte [req+2], 3
    mov word [req+3], 0
    mov byte [cb], 10
    mov word [req+14], cb
    mov word [req+16], cs
    mov word [req+18], 7
    mov bx, req
    call far [strategy_ptr]
    call far [interrupt_ptr]
    mov ax, [req+3]
    test ax, 0x0100
    jz fail_device_request
    test ax, 0x8000
    jnz fail_device_request
    cmp byte [cb+1], 1
    jne fail_device_request
    cmp byte [cb+2], 1
    jne fail_device_request

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
fail_device_list:
    mov dx, fail_device_list_msg
    jmp fail
fail_device_header:
    mov dx, fail_device_header_msg
    jmp fail
fail_device_request:
    mov dx, fail_device_request_msg
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
dev_list: times 5 db 0
strategy_ptr: dw 0, 0
interrupt_ptr: dw 0, 0
req: db 26, 0, 0
     dw 0
     times 8 db 0
     db 0
     dw 0, 0
     dw 0
     dw 0, 0, 0
cb:  times 16 db 0
pass_msg: db 'PASS: CDMSCDEX', 13, 10, '$'
fail_install_count_msg: db 'FAIL: CDMSCDEX INSTALL COUNT', 13, 10, '$'
fail_install_drive_msg: db 'FAIL: CDMSCDEX INSTALL DRIVE', 13, 10, '$'
fail_drive_sig_msg: db 'FAIL: CDMSCDEX DRIVE SIG', 13, 10, '$'
fail_drive_supported_msg: db 'FAIL: CDMSCDEX DRIVE SUPPORTED', 13, 10, '$'
fail_drive_unsupported_msg: db 'FAIL: CDMSCDEX DRIVE UNSUPPORTED', 13, 10, '$'
fail_version_msg: db 'FAIL: CDMSCDEX VERSION', 13, 10, '$'
fail_drive_list_msg: db 'FAIL: CDMSCDEX DRIVE LIST', 13, 10, '$'
fail_device_list_msg: db 'FAIL: CDMSCDEX DEVICE LIST', 13, 10, '$'
fail_device_header_msg: db 'FAIL: CDMSCDEX DEVICE HEADER', 13, 10, '$'
fail_device_request_msg: db 'FAIL: CDMSCDEX DEVICE REQUEST', 13, 10, '$'
fail_xms_still_works_msg: db 'FAIL: CDMSCDEX XMS', 13, 10, '$'
