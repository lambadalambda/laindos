[bits 16]
[org 0x0100]

MCB_START equ 0x0B00
MEM_TOP equ 0xA000
TSR_KEEP equ 0x0030

start:
    push cs
    pop ds
    push cs
    pop es
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    mov [exec_params+4], ds

    mov ah, 0x62
    int 0x21
    mov [parent_psp], bx

    mov dx, child_name
    mov bx, exec_params
    mov ax, 0x4B00
    int 0x21
    jc fail_exec

    mov ah, 0x4D
    int 0x21
    cmp ah, 0x03
    jne fail_retcode
    cmp al, 0x42
    jne fail_retcode

    call find_tsr_mcb
    jc fail_mcb

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

find_tsr_mcb:
    mov word [found_count], 0
    mov si, MCB_START
.loop:
    mov ds, si
    cmp byte [0], 'M'
    je .valid
    cmp byte [0], 'Z'
    je .valid
    stc
    ret
.valid:
    mov ax, si
    inc ax
    cmp [1], ax
    jne .next
    cmp ax, [cs:parent_psp]
    je .next
    cmp word [3], TSR_KEEP
    jne .next
    mov es, ax
    mov bx, ax
    add bx, TSR_KEEP
    cmp [es:0x02], bx
    jne .next
    inc word [cs:found_count]
.next:
    cmp byte [0], 'Z'
    je .done
    mov ax, [3]
    add ax, si
    jc .bad
    inc ax
    cmp ax, MEM_TOP
    jae .bad
    mov si, ax
    jmp .loop
.done:
    push cs
    pop ds
    cmp word [found_count], 1
    jne .bad
    clc
    ret
.bad:
    push cs
    pop ds
    stc
    ret

fail_exec:
    mov dx, fail_exec_msg
    jmp fail
fail_retcode:
    mov dx, fail_retcode_msg
    jmp fail
fail_mcb:
    mov dx, fail_mcb_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

child_name: db "TSRCHILD.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0
parent_psp: dw 0
found_count: dw 0
pass_msg: db "PASS: TSR", 13, 10, "$"
fail_exec_msg: db "FAIL: TSR EXEC", 13, 10, "$"
fail_retcode_msg: db "FAIL: TSR RETCODE", 13, 10, "$"
fail_mcb_msg: db "FAIL: TSR MCB", 13, 10, "$"
