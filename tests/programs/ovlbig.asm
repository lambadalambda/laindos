[bits 16]
[org 0x0100]

DATA_BYTES equ 0x14000

start:
    push cs
    pop ds
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    mov ah, 0x3C
    xor cx, cx
    mov dx, ovl_name
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov ah, 0x40
    mov cx, 32
    mov dx, mz_header
    int 0x21
    jc fail_write
    cmp ax, 32
    jne fail_write

    mov word [counter], 0
.write_loop:
    mov di, buf
    mov cx, 256
    mov ax, [counter]
.fill:
    mov [di], ax
    inc ax
    add di, 2
    loop .fill
    mov [counter], ax
    mov bx, [handle]
    mov ah, 0x40
    mov cx, 512
    mov dx, buf
    int 0x21
    jc fail_write
    cmp ax, 512
    jne fail_write
    mov ax, [counter]
    cmp ax, DATA_BYTES / 2
    jb .write_loop

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov ah, 0x48
    mov bx, 0x1410
    int 0x21
    jc fail_alloc
    mov [load_seg], ax

    mov [ovl_params], ax
    mov [ovl_params+2], ax
    mov bx, ovl_params
    mov dx, ovl_name
    mov ax, 0x4B03
    int 0x21
    jc fail_load

    mov es, [load_seg]
    cmp word [es:0x0000], 0
    jne fail_start
    mov dx, msg_start
    mov ah, 0x09
    int 0x21

    mov ax, [load_seg]
    add ax, 0x0FFF
    mov es, ax
    cmp word [es:0x000E], 0x7FFF
    jne fail_below
    mov dx, msg_below
    mov ah, 0x09
    int 0x21

    mov ax, [load_seg]
    add ax, 0x1000
    mov es, ax
    cmp word [es:0x0000], 0x8000
    jne fail_above
    cmp word [es:0x0002], 0x8001
    jne fail_above
    mov dx, msg_above
    mov ah, 0x09
    int 0x21

    mov ax, [load_seg]
    add ax, 0x13FF
    mov es, ax
    cmp word [es:0x000E], 0x9FFF
    jne fail_tail
    mov dx, msg_tail
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_create:
    mov dx, msg_fail_create
    jmp fail
fail_write:
    mov dx, msg_fail_write
    jmp fail
fail_alloc:
    mov dx, msg_fail_alloc
    jmp fail
fail_load:
    mov dx, msg_fail_load
    jmp fail
fail_start:
    mov dx, msg_fail_start
    jmp fail
fail_below:
    mov dx, msg_fail_below
    jmp fail
fail_above:
    mov dx, msg_fail_above
    jmp fail
fail_tail:
    mov dx, msg_fail_tail
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

mz_header:
    dw 0x5A4D
    dw 0x0020
    dw 161
    dw 0
    dw 2
    dw 0
    dw 0xFFFF
    dw 0
    dw 0
    dw 0
    dw 0
    dw 0
    dw 0x001E
    dw 0
    dw 0, 0

handle: dw 0
counter: dw 0
load_seg: dw 0
ovl_params: dw 0, 0
ovl_name: db "OVLBIG.OVL", 0
msg_start:      db "PASS: OVLBIG START", 13, 10, '$'
msg_below:      db "PASS: OVLBIG BELOW", 13, 10, '$'
msg_above:      db "PASS: OVLBIG ABOVE", 13, 10, '$'
msg_tail:       db "PASS: OVLBIG TAIL", 13, 10, '$'
msg_fail_create: db "FAIL: OVLBIG CREATE", 13, 10, '$'
msg_fail_write:  db "FAIL: OVLBIG WRITE", 13, 10, '$'
msg_fail_alloc:  db "FAIL: OVLBIG ALLOC", 13, 10, '$'
msg_fail_load:   db "FAIL: OVLBIG LOAD", 13, 10, '$'
msg_fail_start:  db "FAIL: OVLBIG START", 13, 10, '$'
msg_fail_below:  db "FAIL: OVLBIG BELOW", 13, 10, '$'
msg_fail_above:  db "FAIL: OVLBIG ABOVE", 13, 10, '$'
msg_fail_tail:   db "FAIL: OVLBIG TAIL", 13, 10, '$'

buf: times 512 db 0
