[bits 16]
[org 0x0100]

%include "src/memory.inc"

start:
    push cs
    pop ds
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    mov ah, 0x62
    int 0x21
    mov [psp_seg], bx

    mov ax, MCB_START
    mov es, ax
    cmp byte [es:0], 'M'
    jne fail_first_sig
    mov ax, [es:1]
    cmp ax, [psp_seg]
    jne fail_first_owner
    cmp word [es:3], ENV_PARAS
    jb fail_first_size

    ; the program owns the next block: the largest-block COM load,
    ; trimmed to 0x200 paragraphs by the prologue above
    mov ax, MCB_START
    add ax, [es:3]
    inc ax
    mov es, ax
    cmp byte [es:0], 'M'
    jne fail_prog_sig
    mov ax, [es:1]
    cmp ax, [psp_seg]
    jne fail_prog_owner
    cmp word [es:3], 0x0200
    jne fail_prog_size
    ; the freed remainder follows, last in the arena
    mov ax, es
    add ax, [es:3]
    inc ax
    mov es, ax
    cmp byte [es:0], 'Z'
    jne fail_free_sig
    cmp word [es:1], 0
    jne fail_free_owner
    cmp word [es:3], 2
    jb fail_free_size

    mov ax, [psp_seg]
    dec ax
    mov es, ax
    cmp byte [es:0], 'M'
    jne fail_prog_sig
    mov ax, [es:1]
    cmp ax, [psp_seg]
    jne fail_prog_owner

    mov bx, 1
    mov ah, 0x48
    int 0x21
    jc fail_one_alloc
    mov [probe_seg], ax

    mov es, ax
    mov bx, 0xFFFF
    mov ah, 0x4A
    int 0x21
    jnc fail_one_resize
    cmp ax, 8
    jne fail_one_resize
    cmp bx, 0x0100
    jbe fail_one_resize

    mov es, [probe_seg]
    mov ah, 0x49
    int 0x21
    jc fail_one_free

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_first_sig:
    mov dx, fail_first_sig_msg
    jmp fail
fail_first_owner:
    mov dx, fail_first_owner_msg
    jmp fail
fail_first_size:
    mov dx, fail_first_size_msg
    jmp fail
fail_free_sig:
    mov dx, fail_free_sig_msg
    jmp fail
fail_free_owner:
    mov dx, fail_free_owner_msg
    jmp fail
fail_free_size:
    mov dx, fail_free_size_msg
    jmp fail
fail_prog_sig:
    mov dx, fail_prog_sig_msg
    jmp fail
fail_prog_owner:
    mov dx, fail_prog_owner_msg
    jmp fail
fail_prog_size:
    mov dx, fail_prog_size_msg
    jmp fail
fail_one_alloc:
    mov dx, fail_one_alloc_msg
    jmp fail
fail_one_resize:
    mov dx, fail_one_resize_msg
    jmp fail
fail_one_free:
    mov dx, fail_one_free_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

psp_seg: dw 0
probe_seg: dw 0
pass_msg: db "PASS: HIGHMCB", 13, 10, "$"
fail_first_sig_msg: db "FAIL: HIGHMCB FIRST SIG", 13, 10, "$"
fail_first_owner_msg: db "FAIL: HIGHMCB FIRST OWNER", 13, 10, "$"
fail_first_size_msg: db "FAIL: HIGHMCB FIRST SIZE", 13, 10, "$"
fail_free_sig_msg: db "FAIL: HIGHMCB FREE SIG", 13, 10, "$"
fail_free_owner_msg: db "FAIL: HIGHMCB FREE OWNER", 13, 10, "$"
fail_free_size_msg: db "FAIL: HIGHMCB FREE SIZE", 13, 10, "$"
fail_prog_sig_msg: db "FAIL: HIGHMCB PROG SIG", 13, 10, "$"
fail_prog_owner_msg: db "FAIL: HIGHMCB PROG OWNER", 13, 10, "$"
fail_prog_size_msg: db 'FAIL: HIGHMCB PROG SIZE', 13, 10, '$'
fail_one_alloc_msg: db "FAIL: HIGHMCB ONE ALLOC", 13, 10, "$"
fail_one_resize_msg: db "FAIL: HIGHMCB ONE RESIZE", 13, 10, "$"
fail_one_free_msg: db "FAIL: HIGHMCB ONE FREE", 13, 10, "$"
