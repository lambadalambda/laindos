%include "tests/programs/common.inc"

TOTAL_SECTORS equ 2160

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
.write_try:
    mov bx, [handle]
    mov dx, buf
    mov cx, 512
    mov ah, 0x40
    int 0x21
    jc .write_error
    cmp ax, 512
    jne fail_write
    inc word [sector_index]
    jmp .write_loop
.write_error:
    cmp byte [write_retry_seen], 0
    jne fail_write
    mov byte [write_retry_seen], 1
    jmp .write_try

.writes_done:
.close_try:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jnc .done
    cmp byte [close_retry_seen], 0
    jne fail_close
    mov byte [close_retry_seen], 1
    jmp .close_try
.done:
    PASS_WITH msg_pass

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
fail_close:
    FAIL_WITH msg_fail_close

fname: db "C:\F16FERR.DAT", 0
msg_pass: db "PASS: F16FERR", 13, 10, "$"
msg_fail_create: db "FAIL: F16FERR CREATE", 13, 10, "$"
msg_fail_write: db "FAIL: F16FERR WRITE", 13, 10, "$"
msg_fail_close: db "FAIL: F16FERR CLOSE", 13, 10, "$"
handle: dw 0
sector_index: dw 0
write_retry_seen: db 0
close_retry_seen: db 0
buf: times 512 db 0
