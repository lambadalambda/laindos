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

    in al, 0x21
    mov [old_pic_mask], al
    and al, 0xDF
    out 0x21, al
    sti

    call sb_reset
    jc fail_reset

    ; QEMU SB16 treats F2h as a single 8-bit IRQ trigger.
    mov al, 0xF2
    call sb_write
    jc fail_write


    ; This is a discriminator spin, not a calibrated hardware timeout.
    mov cx, 0xFFFF
.wait_irq:
    cmp byte [irq_seen], 0
    jne pass
    loop .wait_irq

fail_irq:
    mov dx, fail_irq_msg
    jmp fail

fail_reset:
    mov dx, fail_reset_msg
    jmp fail

fail_write:
    mov dx, fail_write_msg
    jmp fail

pass:
    call restore_irq5
    PASS_WITH pass_msg

fail:
    call restore_irq5
    FAIL_WITH dx

restore_irq5:
    push ax
    push dx
    push ds
    cli
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

irq5_handler:
    push ax
    push dx
    mov byte [cs:irq_seen], 1
    mov dx, 0x22E
    in al, dx
    mov al, 0x20
    out 0x20, al
    pop dx
    pop ax
    iret

old_irq5_off: dw 0
old_irq5_seg: dw 0
old_pic_mask: db 0
irq_seen: db 0

pass_msg: db "PASS: SBIRQ IRQ5", 13, 10, "$"
fail_reset_msg: db "FAIL: SBIRQ RESET", 13, 10, "$"
fail_write_msg: db "FAIL: SBIRQ WRITE", 13, 10, "$"
fail_irq_msg: db "FAIL: SBIRQ IRQ", 13, 10, "$"
