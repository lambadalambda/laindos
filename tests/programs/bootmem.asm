[bits 16]
[org 0x0100]

; A .COM program owns the largest free block, like real DOS: SP at
; 0xFFFE, the PSP's MCB sized well past the file image (this file is
; ~1 KB; demand at least 64 KiB), and the block owned by this PSP.

start:
    push cs
    pop ds
    cld

    cmp sp, 0xFFFE
    jne fail_sp

    mov ax, cs
    dec ax
    mov es, ax
    cmp byte [es:0], 'M'
    je .mcb_ok
    cmp byte [es:0], 'Z'
    jne fail_mcb
.mcb_ok:
    mov ax, [es:1]
    mov bx, cs
    cmp ax, bx
    jne fail_owner
    cmp word [es:3], 0x1000
    jb fail_size

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_sp:
    mov dx, fail_sp_msg
    jmp fail
fail_mcb:
    mov dx, fail_mcb_msg
    jmp fail
fail_owner:
    mov dx, fail_owner_msg
    jmp fail
fail_size:
    mov dx, fail_size_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db 'PASS: BOOTMEM', 13, 10, '$'
fail_sp_msg: db 'FAIL: BOOTMEM SP', 13, 10, '$'
fail_mcb_msg: db 'FAIL: BOOTMEM MCB', 13, 10, '$'
fail_owner_msg: db 'FAIL: BOOTMEM OWNER', 13, 10, '$'
fail_size_msg: db 'FAIL: BOOTMEM SIZE', 13, 10, '$'
