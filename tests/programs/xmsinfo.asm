[bits 16]
[org 0x0100]

; Diagnostic: report what a DOS extender would see for extended memory.
; Prints (to COM1) conventional KB (INT 12h), INT 15h AH=88h extended
; size, INT 15h AX=E801h, and the XMS driver's free-memory query. Used
; to compare 86Box's BIOS/XMS against QEMU when a DOS/4GW game thrashes
; its swap (a sign the extender got little or no extended memory).

start:
    push cs
    pop ds

    mov si, m_conv
    call puts
    int 0x12
    call puthex
    call crlf

    mov si, m_88
    call puts
    mov ah, 0x88
    int 0x15
    jnc .c88_ok
    mov bl, '1'
    jmp .c88_print
.c88_ok:
    mov bl, '0'
.c88_print:
    push ax
    mov al, bl
    mov bl, 'C'
    call putc
    mov bl, al
    call putc
    mov bl, ' '
    call putc
    pop ax
    call puthex
    call crlf

    mov ax, 0xE801
    xor bx, bx
    xor cx, cx
    xor dx, dx
    int 0x15
    mov [e_ax], ax
    mov [e_bx], bx
    mov [e_cx], cx
    mov [e_dx], dx
    mov si, m_e801
    call puts
    mov ax, [e_ax]
    call puthex
    mov bl, ' '
    call putc
    mov ax, [e_bx]
    call puthex
    mov bl, ' '
    call putc
    mov ax, [e_cx]
    call puthex
    mov bl, ' '
    call putc
    mov ax, [e_dx]
    call puthex
    call crlf

    ; XMS present?
    mov ax, 0x4300
    int 0x2F
    mov [xms_inst], al
    mov si, m_xinst
    call puts
    xor ah, ah
    mov al, [xms_inst]
    call puthex
    call crlf

    cmp byte [xms_inst], 0x80
    jne .done

    mov ax, 0x4310
    int 0x2F
    mov [xms_entry], bx
    mov [xms_entry+2], es

    mov ah, 0x00
    call far [xms_entry]
    mov si, m_xver
    call puts
    call puthex
    call crlf

    mov ah, 0x08
    call far [xms_entry]
    push ax
    push dx
    mov si, m_xfree
    call puts
    pop dx
    pop ax
    push dx
    call puthex          ; largest free block KB
    mov bl, ' '
    call putc
    pop ax
    call puthex          ; total free KB
    call crlf

.done:
    mov si, m_end
    call puts
    mov ax, 0x4C00
    int 0x21

; ---- helpers ----
putc:                        ; bl = char -> COM1
    push ax
    push dx
.wait:
    mov dx, 0x3FD
    in al, dx
    test al, 0x20
    jz .wait
    mov dx, 0x3F8
    mov al, bl
    out dx, al
    pop dx
    pop ax
    ret

crlf:
    mov bl, 13
    call putc
    mov bl, 10
    call putc
    ret

puts:                        ; ds:si = asciz -> COM1
    push ax
.loop:
    lodsb
    test al, al
    jz .done
    mov bl, al
    call putc
    jmp .loop
.done:
    pop ax
    ret

puthex:                      ; ax -> four hex digits on COM1
    push cx
    push ax
    mov cx, 4
.loop:
    rol ax, 4
    push ax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .ok
    add al, 7
.ok:
    mov bl, al
    call putc
    pop ax
    loop .loop
    pop ax
    pop cx
    ret

m_conv:  db "XMSINFO", 13, 10, "CONV12: ", 0
m_88:    db "INT15-88: ", 0
m_e801:  db "E801(ax bx cx dx): ", 0
m_xinst: db "XMSINST: ", 0
m_xver:  db "XMSVER: ", 0
m_xfree: db "XMSFREE(max tot): ", 0
m_end:   db "XMSINFO DONE", 13, 10, 0

e_ax: dw 0
e_bx: dw 0
e_cx: dw 0
e_dx: dw 0
xms_inst: db 0
xms_entry: dw 0, 0
