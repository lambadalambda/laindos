[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov dx, time_msg
    mov ah, 0x09
    int 0x21
    mov ah, 0x2C
    int 0x21
    mov al, ch
    call print2
    mov al, ':'
    call print_char
    mov al, cl
    call print2
    mov al, ':'
    call print_char
    mov al, dh
    call print2
    mov al, '.'
    call print_char
    mov al, dl
    call print2
    mov dx, crlf_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

print2:
    push bx
    xor ah, ah
    mov bl, 10
    div bl
    mov [digit_rem], ah
    call print_digit
    mov al, [digit_rem]
    call print_digit
    pop bx
    ret

print_digit:
    add al, '0'
print_char:
    push dx
    mov dl, al
    mov ah, 0x02
    int 0x21
    pop dx
    ret

time_msg: db "Current time: $"
crlf_msg: db 13, 10, "$"
digit_rem: db 0
