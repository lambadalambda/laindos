%include "tests/programs/common.inc"

COM_START
    mov sp, 0x1FFE

    mov ax, 0x350D
    int 0x21
    mov [old_irq5_off], bx
    mov [old_irq5_seg], es

    mov dx, irq5_handler
    mov ax, 0x250D
    int 0x21

    mov al, 0x80
    mov ah, 0x02
    call mixer_write
    mov al, 0x81
    mov ah, 0x22
    call mixer_write

    in al, 0x21
    mov [old_pic_mask], al
    and al, 0xDF
    out 0x21, al
    sti

    call sb_reset
    jc fail_reset
    call sb_setup_common
    jc fail_write

    mov al, 0x80
    call sb_write
    jc fail_write
    mov ax, 1
    call sb_write_ax
    jc fail_write

    call wait_irq
    jc fail_irq

pass:
    call restore_irq5
    call print_diag
    PASS_WITH pass_msg

fail_reset:
    mov dx, fail_reset_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
    jmp fail
fail_irq:
    mov dx, fail_irq_msg
fail:
    call restore_irq5
    call print_diag
    FAIL_WITH dx

sb_setup_common:
    mov al, 0xD1
    call sb_write
    jc .fail
    mov al, 0x41
    call sb_write
    jc .fail
    mov al, 0x2B
    call sb_write
    jc .fail
    mov al, 0x11
    call sb_write
    jc .fail
    clc
    ret
.fail:
    stc
    ret

restore_irq5:
    push ax
    push dx
    push ds
    cli
    mov dx, 0x226
    mov al, 1
    out dx, al
    mov cx, 256
.hold:
    loop .hold
    xor al, al
    out dx, al
    mov al, [old_pic_mask]
    out 0x21, al
    mov dx, [old_irq5_off]
    mov ax, [old_irq5_seg]
    mov ds, ax
    mov ax, 0x250D
    int 0x21
    pop ds
    sti
    pop dx
    pop ax
    ret

sb_reset:
    mov dx, 0x226
    mov al, 1
    out dx, al
    mov cx, 256
.hold:
    loop .hold
    xor al, al
    out dx, al

    mov cx, 0xFFFF
.wait_ack:
    mov dx, 0x22E
    in al, dx
    test al, 0x80
    jz .next_ack
    mov dx, 0x22A
    in al, dx
    cmp al, 0xAA
    je .ok
.next_ack:
    loop .wait_ack
    stc
    ret
.ok:
    clc
    ret

sb_write_ax:
    push ax
    call sb_write
    jc .fail
    pop ax
    mov al, ah
    call sb_write
    ret
.fail:
    pop ax
    stc
    ret

sb_write:
    push cx
    push dx
    push ax
    mov cx, 0xFFFF
    mov dx, 0x22C
.wait_write:
    in al, dx
    test al, 0x80
    jz .ready
    loop .wait_write
    pop ax
    pop dx
    pop cx
    stc
    ret
.ready:
    pop ax
    out dx, al
    pop dx
    pop cx
    clc
    ret

mixer_write:
    push dx
    mov dx, 0x224
    out dx, al
    mov al, ah
    inc dx
    out dx, al
    pop dx
    ret

wait_irq:
    push ax
    push bx
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov bx, [0x006C]
.loop:
    cmp byte [cs:irq_seen], 0
    jne .ok
    mov ax, [0x006C]
    sub ax, bx
    cmp ax, 36
    jae .timeout
    sti
    hlt
    jmp .loop
.ok:
    pop ds
    pop bx
    pop ax
    clc
    ret
.timeout:
    pop ds
    pop bx
    pop ax
    stc
    ret

irq5_handler:
    push ax
    push dx
    mov byte [cs:irq_seen], 1
    mov dx, 0x224
    mov al, 0x82
    out dx, al
    inc dx
    in al, dx
    mov [cs:irq_status], al
    test al, 0x02
    jz .ack8
    mov dx, 0x22F
    in al, dx
    mov al, [cs:irq_status]
.ack8:
    test al, 0x01
    jz .ack_legacy
    mov dx, 0x22E
    in al, dx
.ack_legacy:
    mov al, 0x20
    out 0x20, al
    pop dx
    pop ax
    iret

print_diag:
    push ax
    push dx
    PRINT_DOLLAR diag_prefix
    mov al, [irq_status]
    call print_hex_byte
    PRINT_DOLLAR crlf_msg
    pop dx
    pop ax
    ret

print_hex_byte:
    push ax
    push bx
    mov bl, al
    shr al, 4
    call print_hex_nibble
    mov al, bl
    and al, 0x0F
    call print_hex_nibble
    pop bx
    pop ax
    ret

print_hex_nibble:
    cmp al, 10
    jb .digit
    add al, 'A' - 10
    jmp .out
.digit:
    add al, '0'
.out:
    mov dl, al
    mov ah, 0x02
    int 0x21
    ret

old_irq5_off: dw 0
old_irq5_seg: dw 0
old_pic_mask: db 0
irq_seen: db 0
irq_status: db 0

diag_prefix: db "SBPAUSE IRQSTAT=", "$"
crlf_msg: db 13, 10, "$"
pass_msg: db "PASS: SBPAUSE", 13, 10, "$"
fail_reset_msg: db "FAIL: SBPAUSE RESET", 13, 10, "$"
fail_write_msg: db "FAIL: SBPAUSE WRITE", 13, 10, "$"
fail_irq_msg: db "FAIL: SBPAUSE IRQ", 13, 10, "$"
