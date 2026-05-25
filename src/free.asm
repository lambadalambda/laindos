[bits 16]
[org 0x0100]

%include "src/memory.inc"

start:
    push cs
    pop ds
    mov ah, 0x62
    int 0x21
    mov [current_psp], bx

    mov dx, title_msg
    call print_string
    mov dx, header_msg
    call print_string

    xor ax, ax
    mov [total_paras], ax
    mov [used_paras], ax
    mov [free_paras], ax
    mov [largest_free], ax

    mov si, MCB_START
.walk:
    cmp si, MCB_START
    jb .bad_chain
    cmp si, MEM_TOP
    jae .bad_chain
    mov ds, si
    mov al, [0]
    cmp al, MCB_SIG_M
    je .valid
    cmp al, MCB_SIG_Z
    je .valid
.bad_chain:
    push cs
    pop ds
    mov dx, bad_chain_msg
    call print_string
    jmp .summary
.valid:
    mov [cs:block_sig], al
    mov ax, [1]
    mov [cs:block_owner], ax
    mov ax, [3]
    mov [cs:block_size], ax
    push cs
    pop ds

    mov ax, [block_size]
    add [total_paras], ax
    cmp word [block_owner], 0
    je .free_block
    add [used_paras], ax
    mov dx, used_msg
    mov ax, [block_owner]
    cmp ax, [current_psp]
    jne .print_block
    mov dx, self_msg
    jmp .print_block
.free_block:
    add [free_paras], ax
    cmp ax, [largest_free]
    jbe .free_size_ok
    mov [largest_free], ax
.free_size_ok:
    mov dx, free_msg

.print_block:
    mov [status_ptr], dx
    mov ax, si
    call print_hex_word
    mov dl, ' '
    call print_char
    mov dx, [status_ptr]
    call print_string
    mov ax, [block_owner]
    call print_hex_word
    mov dl, ' '
    call print_char
    mov ax, si
    inc ax
    call print_hex_word
    mov dl, ' '
    call print_char
    mov ax, [block_size]
    call print_hex_word
    mov dx, space_msg
    call print_string
    mov ax, [block_size]
    call paras_to_kb
    call print_dec_word
    mov dx, kb_msg
    call print_string

    cmp byte [block_sig], MCB_SIG_Z
    je .summary
    mov ax, si
    inc ax
    add ax, [block_size]
    mov si, ax
    jmp .walk

.summary:
    mov dx, crlf_msg
    call print_string
    mov dx, total_msg
    call print_string
    mov ax, [total_paras]
    call paras_to_kb
    call print_dec_word
    mov dx, kb_crlf_msg
    call print_string

    mov dx, used_total_msg
    call print_string
    mov ax, [used_paras]
    call paras_to_kb
    call print_dec_word
    mov dx, kb_crlf_msg
    call print_string

    mov dx, free_total_msg
    call print_string
    mov ax, [free_paras]
    call paras_to_kb
    call print_dec_word
    mov dx, kb_crlf_msg
    call print_string

    mov dx, largest_msg
    call print_string
    mov ax, [largest_free]
    call paras_to_kb
    call print_dec_word
    mov dx, kb_crlf_msg
    call print_string

    mov ax, 0x4C00
    int 0x21

paras_to_kb:
    mov cx, 6
.shift:
    shr ax, 1
    loop .shift
    ret

print_string:
    push ax
    mov ah, 0x09
    int 0x21
    pop ax
    ret

print_char:
    push ax
    push dx
    mov ah, 0x02
    int 0x21
    pop dx
    pop ax
    ret

print_hex_word:
    push ax
    push bx
    push cx
    push dx
    mov bx, ax
    mov cx, 4
.digit_loop:
    rol bx, 4
    mov dl, bl
    and dl, 0x0F
    cmp dl, 9
    jbe .digit
    add dl, 'A' - 10
    jmp .out
.digit:
    add dl, '0'
.out:
    mov ah, 0x02
    int 0x21
    loop .digit_loop
    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_dec_word:
    push ax
    push bx
    push cx
    push dx
    test ax, ax
    jnz .nonzero
    mov dl, '0'
    mov ah, 0x02
    int 0x21
    jmp .done
.nonzero:
    xor cx, cx
    mov bx, 10
.div_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div_loop
.out_loop:
    pop dx
    add dl, '0'
    mov ah, 0x02
    int 0x21
    loop .out_loop
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

current_psp: dw 0
block_owner: dw 0
block_size: dw 0
block_sig: db 0
total_paras: dw 0
used_paras: dw 0
free_paras: dw 0
largest_free: dw 0
status_ptr: dw 0

title_msg: db "LainDOS memory report", 13, 10, "$"
header_msg: db "MCB  Stat Owner Block Paras KB", 13, 10, "$"
used_msg: db "USED ", "$"
self_msg: db "SELF ", "$"
free_msg: db "FREE ", "$"
space_msg: db " ", "$"
kb_msg: db "K", 13, 10, "$"
crlf_msg: db 13, 10, "$"
kb_crlf_msg: db "K", 13, 10, "$"
total_msg: db "Total managed memory: $"
used_total_msg: db "Used memory: $"
free_total_msg: db "Total free memory: $"
largest_msg: db "Largest free block: $"
bad_chain_msg: db "Invalid MCB chain", 13, 10, "$"
