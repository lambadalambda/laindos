%include "tests/programs/common.inc"

DMA8_LEN equ 32
DMA16_BYTES equ 32
DMA16_WORDS equ DMA16_BYTES / 2

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

    call run_dma8
    jc fail_dma8
    test byte [status8], 0x01
    jz fail_status8

    call sb_reset
    jc fail_reset
    call sb_setup_common
    jc fail_write

    call run_dma16
    jc fail_dma16
    test byte [status16], 0x02
    jz fail_status16

    call sb_reset
    jc fail_reset
    call sb_setup_biing
    jc fail_write

    call run_dma8_auto
    jc fail_auto8
    test byte [status_auto], 0x01
    jz fail_status_auto

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
fail_dma8:
    mov dx, fail_dma8_msg
    jmp fail
fail_status8:
    mov dx, fail_status8_msg
    jmp fail
fail_dma16:
    mov dx, fail_dma16_msg
    jmp fail
fail_status16:
    mov dx, fail_status16_msg
    jmp fail
fail_auto8:
    mov dx, fail_auto8_msg
    jmp fail
fail_status_auto:
    mov dx, fail_status_auto_msg
fail:
    call restore_irq5
    call print_diag
    FAIL_WITH dx

run_dma8:
    mov byte [phase], 8
    mov byte [irq_seen], 0
    mov byte [status8], 0
    mov bx, dma8_buffer
    call calc_phys
    mov bx, ax

    mov al, 0x05
    out 0x0A, al
    xor al, al
    out 0x0C, al
    mov al, 0x49
    out 0x0B, al
    mov dx, 0x02
    mov al, bl
    out dx, al
    mov al, bh
    out dx, al
    mov dx, 0x83
    mov al, [phys_page]
    out dx, al
    mov dx, 0x03
    mov ax, DMA8_LEN - 1
    out dx, al
    mov al, ah
    out dx, al
    mov al, 0x01
    out 0x0A, al

    mov al, 0xC0
    call sb_write
    jc .fail
    xor al, al
    call sb_write
    jc .fail
    mov ax, DMA8_LEN - 1
    call sb_write_ax
    jc .fail
    call wait_irq
    ret
.fail:
    stc
    ret

run_dma8_auto:
    mov byte [phase], 6
    mov byte [irq_seen], 0
    mov byte [status_auto], 0
    mov bx, dma8_buffer
    call calc_phys
    mov bx, ax

    mov al, 0x05
    out 0x0A, al
    xor al, al
    out 0x0C, al
    mov al, 0x59
    out 0x0B, al
    mov dx, 0x02
    mov al, bl
    out dx, al
    mov al, bh
    out dx, al
    mov dx, 0x83
    mov al, [phys_page]
    out dx, al
    mov dx, 0x03
    mov ax, DMA8_LEN - 1
    out dx, al
    mov al, ah
    out dx, al
    mov al, 0x01
    out 0x0A, al

    mov al, 0xC6
    call sb_write
    jc .fail
    mov al, 0x21
    call sb_write
    jc .fail
    mov ax, DMA8_LEN - 1
    call sb_write_ax
    jc .fail
    call wait_irq
    ret
.fail:
    stc
    ret

run_dma16:
    mov byte [phase], 16
    mov byte [irq_seen], 0
    mov byte [status16], 0
    mov bx, dma16_buffer
    call calc_phys
    mov bx, ax
    shr bx, 1
    test byte [phys_page], 0x01
    jz .addr_ok
    or bh, 0x80
.addr_ok:

    mov al, 0x05
    out 0xD4, al
    xor al, al
    out 0xD8, al
    mov al, 0x49
    out 0xD6, al
    mov dx, 0xC4
    mov al, bl
    out dx, al
    mov al, bh
    out dx, al
    mov dx, 0x8B
    mov al, [phys_page]
    shr al, 1
    out dx, al
    mov dx, 0xC6
    mov ax, DMA16_WORDS - 1
    out dx, al
    mov al, ah
    out dx, al
    mov al, 0x01
    out 0xD4, al

    mov al, 0xB0
    call sb_write
    jc .fail
    xor al, al
    call sb_write
    jc .fail
    mov ax, DMA16_WORDS - 1
    call sb_write_ax
    jc .fail
    call wait_irq
    ret
.fail:
    stc
    ret

sb_setup_biing:
    mov al, 0xD1
    call sb_write
    jc .fail
    mov al, 0x40
    call sb_write
    jc .fail
    mov al, 0xD2
    call sb_write
    jc .fail
    clc
    ret
.fail:
    stc
    ret

calc_phys:
    mov ax, cs
    mov dx, ax
    shr dx, 12
    shl ax, 4
    add ax, bx
    adc dx, 0
    mov [phys_page], dl
    ret

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
    mov al, 0x05
    out 0x0A, al
    out 0xD4, al
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
    cmp byte [cs:phase], 16
    je .save16
    cmp byte [cs:phase], 6
    je .save_auto
    mov [cs:status8], al
    jmp .ack
.save16:
    mov [cs:status16], al
    jmp .ack
.save_auto:
    mov [cs:status_auto], al
.ack:
    test al, 0x02
    jz .ack8
    mov dx, 0x22F
    in al, dx
    mov al, [cs:status16]
.ack8:
    test al, 0x01
    jz .eoi
    mov dx, 0x22E
    in al, dx
.eoi:
    mov al, 0x20
    out 0x20, al
    pop dx
    pop ax
    iret

print_diag:
    push ax
    push dx
    PRINT_DOLLAR diag_prefix
    mov al, [status8]
    call print_hex_byte
    PRINT_DOLLAR diag_16
    mov al, [status16]
    call print_hex_byte
    PRINT_DOLLAR diag_auto
    mov al, [status_auto]
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
phase: db 0
phys_page: db 0
status8: db 0
status16: db 0
status_auto: db 0

diag_prefix: db "SB16DMA ST8=", "$"
diag_16: db " ST16=", "$"
diag_auto: db " STAUTO=", "$"
crlf_msg: db 13, 10, "$"
pass_msg: db "PASS: SB16DMA", 13, 10, "$"
fail_reset_msg: db "FAIL: SB16DMA RESET", 13, 10, "$"
fail_write_msg: db "FAIL: SB16DMA WRITE", 13, 10, "$"
fail_dma8_msg: db "FAIL: SB16DMA DMA8", 13, 10, "$"
fail_status8_msg: db "FAIL: SB16DMA STATUS8", 13, 10, "$"
fail_dma16_msg: db "FAIL: SB16DMA DMA16", 13, 10, "$"
fail_status16_msg: db "FAIL: SB16DMA STATUS16", 13, 10, "$"
fail_auto8_msg: db "FAIL: SB16DMA AUTO8", 13, 10, "$"
fail_status_auto_msg: db "FAIL: SB16DMA STATUSAUTO", 13, 10, "$"

align 2
dma8_buffer:
    times DMA8_LEN db 0x80
dma16_buffer:
    times DMA16_BYTES db 0x00
