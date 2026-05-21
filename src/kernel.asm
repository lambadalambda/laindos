[bits 16]
[org 0x0000]

COM1_PORT equ 0x3F8

kernel_entry:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    cld

    call serial_init

    mov si, msg_booted
    call serial_print

    int 0x12
    mov [mem_kib], ax

    mov si, msg_mem
    call serial_print

    mov ax, [mem_kib]
    call serial_print_int

    mov si, msg_kib
    call serial_print

    mov si, msg_halt
    call serial_print
    cli
.halt:
    hlt
    jmp .halt

serial_init:
    mov dx, COM1_PORT + 1
    xor al, al
    out dx, al
    mov dx, COM1_PORT + 3
    mov al, 0x80
    out dx, al
    mov dx, COM1_PORT
    mov al, 0x01
    out dx, al
    mov dx, COM1_PORT + 1
    xor al, al
    out dx, al
    mov dx, COM1_PORT + 3
    mov al, 0x03
    out dx, al
    mov dx, COM1_PORT + 2
    mov al, 0xC7
    out dx, al
    mov dx, COM1_PORT + 4
    mov al, 0x0B
    out dx, al
    ret

serial_putchar:
    push dx
    push ax
    mov dx, COM1_PORT + 5
.wait:
    in al, dx
    test al, 0x20
    jz .wait
    pop ax
    mov dx, COM1_PORT
    out dx, al
    pop dx
    ret

serial_print:
    push si
    push ax
.loop:
    lodsb
    test al, al
    jz .done
    call serial_putchar
    jmp .loop
.done:
    pop ax
    pop si
    ret

serial_print_int:
    push ax
    push bx
    push cx
    push dx
    mov cx, 0
    mov bx, 10
.div_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div_loop
.print_loop:
    pop ax
    add al, '0'
    call serial_putchar
    loop .print_loop
    pop dx
    pop cx
    pop bx
    pop ax
    ret

msg_booted:  db "MiniDOS booted", 13, 10, 0
msg_mem:     db "Conventional memory: ", 0
msg_kib:    db " KB", 13, 10, 0
msg_halt:   db "HALT", 13, 10, 0

mem_kib: dw 0
