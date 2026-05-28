[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, filename
    mov ax, 0x3D02
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, [handle]
    mov ax, 0x4400
    int 0x21
    jc fail_ioctl
    test dx, 0x0080
    jnz fail_file_info

    mov bx, [handle]
    mov dx, 0x0020
    mov ax, 0x4401
    int 0x21
    jc fail_set_info

    mov bx, 1
    mov ax, 0x4400
    int 0x21
    jc fail_ioctl
    test dx, 0x0080
    jz fail_device_info
    test dx, 0x0002
    jz fail_device_info

    mov bx, 1
    xor dx, dx
    mov ax, 0x4401
    int 0x21
    jc fail_set_info

    mov bx, 1
    mov ax, 0x4407
    int 0x21
    jc fail_output_status
    cmp al, 0xFF
    jne fail_output_status

    mov bx, 0x00FE
    mov ax, 0x4407
    int 0x21
    jnc fail_invalid_handle
    cmp ax, 6
    jne fail_invalid_handle

    mov bl, 0
    mov ax, 0x4408
    int 0x21
    jc fail_removable
    cmp ax, 0
    jne fail_removable

    mov bl, 1
    mov ax, 0x4408
    int 0x21
    jc fail_removable
    cmp ax, 0
    jne fail_removable

    mov bl, 2
    mov ax, 0x4408
    int 0x21
    jnc fail_invalid_drive
    cmp ax, 15
    jne fail_invalid_drive

    mov bl, 0
    mov ax, 0x4409
    int 0x21
    jc fail_local_drive
    test dx, 0x1000
    jnz fail_local_drive

    mov bl, 2
    mov ax, 0x4409
    int 0x21
    jnc fail_invalid_drive
    cmp ax, 15
    jne fail_invalid_drive

    mov bx, [handle]
    mov ax, 0x440A
    int 0x21
    jc fail_local_handle
    test dx, 0x8000
    jnz fail_local_handle

    mov bx, 1
    mov ax, 0x440A
    int 0x21
    jc fail_local_handle
    test dx, 0x8000
    jnz fail_local_handle

    mov bx, 0x00FE
    mov ax, 0x440A
    int 0x21
    jnc fail_invalid_handle
    cmp ax, 6
    jne fail_invalid_handle

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_ioctl:
    mov dx, fail_ioctl_msg
    jmp fail
fail_file_info:
    mov dx, fail_file_info_msg
    jmp fail
fail_set_info:
    mov dx, fail_set_info_msg
    jmp fail
fail_device_info:
    mov dx, fail_device_info_msg
    jmp fail
fail_output_status:
    mov dx, fail_output_status_msg
    jmp fail
fail_invalid_handle:
    mov dx, fail_invalid_handle_msg
    jmp fail
fail_removable:
    mov dx, fail_removable_msg
    jmp fail
fail_invalid_drive:
    mov dx, fail_invalid_drive_msg
    jmp fail
fail_local_drive:
    mov dx, fail_local_drive_msg
    jmp fail
fail_local_handle:
    mov dx, fail_local_handle_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "TEST.DAT", 0
pass_msg: db "PASS: IOCTLEXT", 13, 10, "$"
fail_open_msg: db "FAIL: IOCTLEXT OPEN", 13, 10, "$"
fail_ioctl_msg: db "FAIL: IOCTLEXT IOCTL", 13, 10, "$"
fail_file_info_msg: db "FAIL: IOCTLEXT FILE INFO", 13, 10, "$"
fail_set_info_msg: db "FAIL: IOCTLEXT SET INFO", 13, 10, "$"
fail_device_info_msg: db "FAIL: IOCTLEXT DEVICE INFO", 13, 10, "$"
fail_output_status_msg: db "FAIL: IOCTLEXT OUTPUT STATUS", 13, 10, "$"
fail_invalid_handle_msg: db "FAIL: IOCTLEXT INVALID HANDLE", 13, 10, "$"
fail_removable_msg: db "FAIL: IOCTLEXT REMOVABLE", 13, 10, "$"
fail_invalid_drive_msg: db "FAIL: IOCTLEXT INVALID DRIVE", 13, 10, "$"
fail_local_drive_msg: db "FAIL: IOCTLEXT LOCAL DRIVE", 13, 10, "$"
fail_local_handle_msg: db "FAIL: IOCTLEXT LOCAL HANDLE", 13, 10, "$"
handle: dw 0
