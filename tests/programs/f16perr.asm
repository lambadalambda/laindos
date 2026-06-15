%include "tests/programs/common.inc"

TOTAL_SECTORS equ 16

COM_START
    push cs
    pop es
    cld

    mov dx, fname
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov word [sector_index], 0
.write_loop:
    cmp word [sector_index], TOTAL_SECTORS
    jae .writes_done
    call fill_buf
    mov bx, [handle]
    mov dx, buf
    mov cx, 512
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 512
    jne fail_write
    inc word [sector_index]
    jmp .write_loop

.writes_done:
    mov ax, 0xF002
    int 0x21
    jc fail_api

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jnc fail_close_ok

    PRINT_DOLLAR msg_pass
    PRINT_DOLLAR msg_halt
.halt:
    hlt
    jmp .halt

fill_buf:
    push ax
    push cx
    push di
    mov al, [sector_index]
    mov di, buf
    mov cx, 512
    rep stosb
    pop di
    pop cx
    pop ax
    ret

fail_create:
    FAIL_WITH msg_fail_create
fail_write:
    FAIL_WITH msg_fail_write
fail_api:
    FAIL_WITH msg_fail_api
fail_close_ok:
    FAIL_WITH msg_fail_close_ok

fname: db "C:\F16PERR.DAT", 0
msg_pass: db "PASS: F16PERR", 13, 10, "$"
msg_halt: db "HALT", 13, 10, "$"
msg_fail_create: db "FAIL: F16PERR CREATE", 13, 10, "$"
msg_fail_write: db "FAIL: F16PERR WRITE", 13, 10, "$"
msg_fail_api: db "FAIL: F16PERR API", 13, 10, "$"
msg_fail_close_ok: db "FAIL: F16PERR CLOSEOK", 13, 10, "$"
handle: dw 0
sector_index: dw 0
buf: times 512 db 0
