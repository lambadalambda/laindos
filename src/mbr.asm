[bits 16]
[org 0x7C00]

MBR_BASE equ 0x0600

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    cld
    mov si, 0x7C00
    mov di, MBR_BASE
    mov cx, 256
    rep movsw
    jmp 0x0000:MBR_BASE + relocated - $$

relocated:
    sti
    mov [MBR_BASE + drv - $$], dl

    mov si, MBR_BASE + 446
    mov cx, 4
.find_active:
    cmp byte [si], 0x80
    je .found
    add si, 16
    loop .find_active
    mov si, MBR_BASE + msg_no_part - $$
    jmp .fatal

.found:
    mov byte [MBR_BASE + retries - $$], 3
.retry:
    mov bx, 0x7C00
    mov ax, 0x0201
    mov dl, [MBR_BASE + drv - $$]
    mov dh, [si+1]
    mov cl, [si+2]
    mov ch, [si+3]
    int 0x13
    jnc .boot
    xor ax, ax
    mov dl, [MBR_BASE + drv - $$]
    int 0x13
    dec byte [MBR_BASE + retries - $$]
    jnz .retry
    mov si, MBR_BASE + msg_read_err - $$
    jmp .fatal

.boot:
    cmp word [0x7DFE], 0xAA55
    jne .bad_vbr
    mov dl, [MBR_BASE + drv - $$]
    jmp 0x0000:0x7C00

.bad_vbr:
    mov si, MBR_BASE + msg_bad_vbr - $$
    jmp .fatal

.fatal:
    call sprint
    cli
.halt:
    hlt
    jmp .halt

sprint:
    lodsb
    test al, al
    jz .done
    mov ah, al
    mov dx, 0x3FD
.wait:
    in al, dx
    test al, 0x20
    jz .wait
    mov al, ah
    mov dx, 0x3F8
    out dx, al
    jmp sprint
.done:
    ret

drv: db 0
retries: db 3
msg_no_part: db "No active partition", 0
msg_read_err: db "Partition boot read failed", 0
msg_bad_vbr: db "Bad partition boot signature", 0

times 446-($-$$) db 0
times 64 db 0
dw 0xAA55
