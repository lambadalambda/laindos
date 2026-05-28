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

console_input_status:
    cmp byte [cs:console_ext_pending], 0
    jne .ready
    mov ah, 0x01
    int 0x16
    jz .empty
.ready:
    mov al, 0xFF
    ret
.empty:
    xor al, al
    ret

console_flush_input:
    push ax
    mov byte [cs:console_ext_pending], 0
.loop:
    mov ah, 0x01
    int 0x16
    jz .done
    xor ah, ah
    int 0x16
    jmp .loop
.done:
    pop ax
    ret

console_read_char:
    cmp byte [cs:console_ext_pending], 0
    je .read_bios
    mov al, [cs:console_ext_pending]
    mov byte [cs:console_ext_pending], 0
    stc
    ret
.read_bios:
    xor ah, ah
    int 0x16
    test al, al
    jnz .normal
    test ah, ah
    jz .normal
    mov [cs:console_ext_pending], ah
    xor al, al
    stc
    ret
.normal:
    clc
    ret

console_putchar:
    push ax
    cmp al, 12
    je .clear
    call serial_putchar
    call vga_putchar
    pop ax
    ret
.clear:
    call serial_putchar
    call vga_clear
    pop ax
    ret

vga_putchar:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    cmp al, 13
    je .cr
    cmp al, 10
    je .lf
    cmp al, 8
    je .bs
    push ax
    mov ax, [cs:vga_row]
    mov bx, VGA_COLS
    mul bx
    add ax, [cs:vga_col]
    shl ax, 1
    mov di, ax
    mov ax, VGA_TEXT_SEG
    mov es, ax
    pop ax
    mov ah, 0x07
    stosw
    inc word [cs:vga_col]
    cmp word [cs:vga_col], VGA_COLS
    jb .update
    mov word [cs:vga_col], 0
    jmp .advance_row
.cr:
    mov word [cs:vga_col], 0
    jmp .update
.lf:
    jmp .advance_row
.bs:
    cmp word [cs:vga_col], 0
    je .update
    dec word [cs:vga_col]
    jmp .update
.advance_row:
    inc word [cs:vga_row]
    cmp word [cs:vga_row], VGA_ROWS
    jb .update
    call vga_scroll
    mov word [cs:vga_row], VGA_ROWS - 1
.update:
    call vga_update_cursor
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

vga_clear:
    push ax
    push cx
    push es
    push di
    mov ax, VGA_TEXT_SEG
    mov es, ax
    xor di, di
    mov ax, 0x0720
    mov cx, VGA_COLS * VGA_ROWS
    cld
    rep stosw
    mov word [cs:vga_row], 0
    mov word [cs:vga_col], 0
    call vga_update_cursor
    pop di
    pop es
    pop cx
    pop ax
    ret

vga_scroll:
    push ax
    push cx
    push ds
    push es
    push si
    push di
    mov ax, VGA_TEXT_SEG
    mov ds, ax
    mov es, ax
    mov si, VGA_COLS * 2
    xor di, di
    mov cx, VGA_COLS * (VGA_ROWS - 1)
    cld
    rep movsw
    mov ax, 0x0720
    mov cx, VGA_COLS
    mov di, VGA_COLS * (VGA_ROWS - 1) * 2
    rep stosw
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop ax
    ret

vga_update_cursor:
    push ax
    push bx
    push dx
    mov ax, [cs:vga_row]
    mov bx, VGA_COLS
    mul bx
    add ax, [cs:vga_col]
    mov bx, ax
    mov dx, 0x03D4
    mov al, 0x0F
    out dx, al
    inc dx
    mov al, bl
    out dx, al
    dec dx
    mov al, 0x0E
    out dx, al
    inc dx
    mov al, bh
    out dx, al
    pop dx
    pop bx
    pop ax
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

serial_print_hex:
    push cx
    push ax
    mov cx, 2
.hloop:
    rol al, 4
    push ax
    and al, 0x0F
    cmp al, 10
    jae .alpha
    add al, '0'
    jmp .out
.alpha:
    add al, 'A' - 10
.out:
    call serial_putchar
    pop ax
    loop .hloop
    pop ax
    pop cx
    ret

serial_print_hex_word:
    push cx
    push ax
    mov cx, 4
.whloop:
    rol ax, 4
    push ax
    and al, 0x0F
    cmp al, 10
    jae .walpha
    add al, '0'
    jmp .wout
.walpha:
    add al, 'A' - 10
.wout:
    call serial_putchar
    pop ax
    loop .whloop
    pop ax
    pop cx
    ret
