[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov dl, 0x80

scan_drive:
    cmp dl, 0xF0
    jae fail_no_cd
    mov [probe_drive], dl
    mov ax, 0x4100
    mov bx, 0x55AA
    int 0x13
    jc next_drive
    cmp bx, 0xAA55
    jne next_drive

    mov word [dap+2], 1
    mov word [dap+4], cd_buf
    mov ax, cs
    mov [dap+6], ax
    mov word [dap+8], 16
    mov word [dap+10], 0
    mov word [dap+12], 0
    mov word [dap+14], 0
    mov si, dap
    mov dl, [probe_drive]
    mov ah, 0x42
    int 0x13
    jc next_drive

    cmp byte [cd_buf+0], 1
    jne next_drive
    cmp byte [cd_buf+1], 'C'
    jne next_drive
    cmp byte [cd_buf+2], 'D'
    jne next_drive
    cmp byte [cd_buf+3], '0'
    jne next_drive
    cmp byte [cd_buf+4], '0'
    jne next_drive
    cmp byte [cd_buf+5], '1'
    jne next_drive
    cmp byte [cd_buf+40], 'L'
    jne fail_volume
    cmp byte [cd_buf+41], 'A'
    jne fail_volume
    cmp byte [cd_buf+42], 'I'
    jne fail_volume
    cmp byte [cd_buf+43], 'N'
    jne fail_volume
    cmp byte [cd_buf+44], 'C'
    jne fail_volume
    cmp byte [cd_buf+45], 'D'
    jne fail_volume
    jmp pass

next_drive:
    mov dl, [probe_drive]
    inc dl
    jmp scan_drive

pass:
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_no_cd:
    mov dx, fail_no_cd_msg
    jmp fail
fail_volume:
    mov dx, fail_volume_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

probe_drive: db 0
dap: db 0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
pass_msg: db 'PASS: CDPROBE', 13, 10, '$'
fail_no_cd_msg: db 'FAIL: CDPROBE NOCD', 13, 10, '$'
fail_volume_msg: db 'FAIL: CDPROBE VOLUME', 13, 10, '$'
cd_buf: times 2048 db 0
