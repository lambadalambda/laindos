org 0x100

start:
    push cs
    pop ds
    mov ax, 0x3521
    int 0x21
    mov ax, es
    cmp ax, 0xFFFF
    jne fail_vec
    mov dx, msg_vec
    mov ah, 0x09
    int 0x21

    xor si, si
    xor ax, ax
    mov ds, ax
    mov ax, 0xFFFF
    mov es, ax
    mov di, 0x10
    mov cx, 16
    cld
    repe cmpsb
    push cs
    pop ds
    je fail_a20
    mov dx, msg_a20
    mov ah, 0x09
    int 0x21

    mov ah, 0x48
    mov bx, 0xFFFF
    int 0x21
    jnc fail_mem
    cmp bx, 0x9200
    jb fail_mem
    mov dx, msg_mem
    mov ah, 0x09
    int 0x21

    mov ax, 0x4300
    int 0x2F
    cmp al, 0x80
    jne fail_xms
    mov ax, 0x4310
    int 0x2F
    mov [xms_entry], bx
    mov [xms_entry+2], es
    push cs
    pop es

    mov ax, 0xFFFF
    mov ds, ax
    mov si, 0x10
    push cs
    pop es
    mov di, kernel_snap
    mov cx, 16
    rep movsb
    push cs
    pop ds

    mov ah, 0x09
    mov dx, 64
    call far [xms_entry]
    test ax, ax
    jz fail_xms
    mov [xms_handle], dx

    mov ax, [xms_handle]
    mov [move_dst_handle], ax
    mov ax, cs
    mov [move_src_ptr+2], ax
    mov ah, 0x0B
    mov si, move_desc
    call far [xms_entry]
    test ax, ax
    jz fail_xms

    mov ax, 0xFFFF
    mov ds, ax
    mov si, 0x10
    push cs
    pop es
    mov di, kernel_snap2
    mov cx, 16
    rep movsb
    push cs
    pop ds

    mov si, kernel_snap
    mov di, kernel_snap2
    mov cx, 16
    repe cmpsb
    jne fail_xms

    mov dx, [xms_handle]
    mov ah, 0x0A
    call far [xms_entry]

    mov dx, msg_xms
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_vec:
    mov dx, msg_fail_vec
    jmp fail
fail_a20:
    mov dx, msg_fail_a20
    jmp fail
fail_mem:
    mov dx, msg_fail_mem
    jmp fail
fail_xms:
    push cs
    pop ds
    mov dx, msg_fail_xms
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

xms_entry: dw 0, 0
xms_handle: dw 0
move_desc:
    dd 16
    dw 0
move_src_ptr: dw pattern, 0
move_dst_handle: dw 0
    dd 0
pattern: db 0xA5, 0x5A, 0xC3, 0x3C, 0x99, 0x66, 0x0F, 0xF0
         db 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88
kernel_snap: times 16 db 0
kernel_snap2: times 16 db 0

msg_vec:      db "PASS: HMA VEC", 13, 10, '$'
msg_a20:      db "PASS: HMA A20", 13, 10, '$'
msg_mem:      db "PASS: HMA MEM", 13, 10, '$'
msg_xms:      db "PASS: HMA XMS", 13, 10, '$'
msg_fail_vec: db "FAIL: HMA VEC", 13, 10, '$'
msg_fail_a20: db "FAIL: HMA A20", 13, 10, '$'
msg_fail_mem: db "FAIL: HMA MEM", 13, 10, '$'
msg_fail_xms: db "FAIL: HMA XMS", 13, 10, '$'
