[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x62
    int 0x21
    mov es, bx
    mov ax, [es:0x2C]
    mov [env_seg], ax

    mov es, ax
    mov word [es:0x0000], 'EN'
    mov word [es:0x0002], 'VM'
    mov word [es:0x0004], 'RK'

    xor ax, ax
    mov es, ax
    mov ax, [env_seg]
    mov [es:0x04F0], ax

    mov dx, msg
    mov ah, 0x09
    int 0x21

    mov ax, 0x3110
    mov dx, 0x0020
    int 0x21

env_seg: dw 0
msg: db "PASS: TSRENVC", 13, 10, '$'
