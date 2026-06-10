[bits 16]
[org 0x0100]

%include "src/memory.inc"

CONV_TOTAL_KB equ (MEM_TOP / 64)
RESERVED_KB equ (1024 - CONV_TOTAL_KB)

start:
    push cs
    pop ds

    call collect_mcb
    call query_xms
    call query_ems
    call compute_totals
    call print_report

    mov ax, 0x4C00
    int 0x21

collect_mcb:
    xor ax, ax
    mov [free_paras], ax
    mov [largest_free], ax
    mov [bad_chain], al
    mov si, MCB_START
.walk:
    cmp si, MCB_START
    jb .bad
    cmp si, MEM_TOP
    jae .bad
    mov ds, si
    mov al, [0]
    cmp al, MCB_SIG_M
    je .valid
    cmp al, MCB_SIG_Z
    je .valid
.bad:
    push cs
    pop ds
    mov byte [bad_chain], 1
    ret
.valid:
    mov [cs:block_sig], al
    mov ax, [1]
    mov [cs:block_owner], ax
    mov ax, [3]
    mov [cs:block_size], ax
    push cs
    pop ds
    cmp word [block_owner], 0
    jne .next
    mov ax, [block_size]
    add [free_paras], ax
    cmp ax, [largest_free]
    jbe .next
    mov [largest_free], ax
.next:
    cmp byte [block_sig], MCB_SIG_Z
    je .done
    mov ax, si
    inc ax
    add ax, [block_size]
    cmp ax, si
    jbe .bad
    mov si, ax
    jmp .walk
.done:
    ret

query_xms:
    xor ax, ax
    mov [xms_total_kb], ax
    mov [xms_used_kb], ax
    mov [xms_free_kb], ax
    mov ax, 0x4300
    int 0x2F
    cmp al, 0x80
    jne .done
    mov ax, 0x4310
    int 0x2F
    mov [xms_entry], bx
    mov [xms_entry+2], es
    mov ax, es
    or ax, bx
    jz .done
    mov ah, 0x08
    call far [xms_entry]
    mov [xms_total_kb], dx
    mov [xms_free_kb], dx
    xor dx, dx
    mov ax, 0x43E0
    int 0x2F
    cmp al, 0x80
    jne .done
    cmp dx, [xms_free_kb]
    jb .done
    mov [xms_total_kb], dx
.done:
    ret

query_ems:
    xor ax, ax
    mov [ems_total_pages], ax
    mov [ems_free_pages], ax
    mov ah, 0x40
    int 0x67
    test ah, ah
    jnz .done
    mov ah, 0x42
    int 0x67
    test ah, ah
    jnz .done
    mov [ems_free_pages], bx
    mov [ems_total_pages], dx
.done:
    ret

compute_totals:
    mov ax, [free_paras]
    call paras_to_kb
    mov [conv_free_kb], ax
    mov ax, CONV_TOTAL_KB
    sub ax, [conv_free_kb]
    mov [conv_used_kb], ax

    mov ax, [xms_total_kb]
    sub ax, [xms_free_kb]
    mov [xms_used_kb], ax

    mov ax, CONV_TOTAL_KB
    add ax, RESERVED_KB
    add ax, [xms_total_kb]
    mov [total_kb], ax
    mov ax, [conv_used_kb]
    add ax, RESERVED_KB
    add ax, [xms_used_kb]
    mov [total_used_kb], ax
    mov ax, [conv_free_kb]
    add ax, [xms_free_kb]
    mov [total_free_kb], ax
    ret

print_report:
    mov dx, title_msg
    call print_string
    mov dx, separator_msg
    call print_string

    mov dx, conv_label
    mov ax, CONV_TOTAL_KB
    mov bx, [conv_used_kb]
    mov cx, [conv_free_kb]
    call print_kb_row

    mov dx, upper_label
    xor ax, ax
    xor bx, bx
    xor cx, cx
    call print_kb_row

    mov dx, reserved_label
    mov ax, RESERVED_KB
    mov bx, RESERVED_KB
    xor cx, cx
    call print_kb_row

    mov dx, xms_label
    mov ax, [xms_total_kb]
    mov bx, [xms_used_kb]
    mov cx, [xms_free_kb]
    call print_kb_row

    mov dx, separator_msg
    call print_string

    mov dx, total_label
    mov ax, [total_kb]
    mov bx, [total_used_kb]
    mov cx, [total_free_kb]
    call print_kb_row

    mov dx, under_label
    mov ax, 1024
    mov bx, [conv_used_kb]
    add bx, RESERVED_KB
    mov cx, [conv_free_kb]
    call print_kb_row

    mov dx, crlf_msg
    call print_string
    call print_ems_summary
    mov dx, crlf_msg
    call print_string
    call print_largest_summary
    cmp byte [bad_chain], 0
    je .resident
    mov dx, bad_chain_msg
    call print_string
.resident:
    mov dx, resident_msg
    call print_string
    ret

print_kb_row:
    mov [row_total], ax
    mov [row_used], bx
    mov [row_free], cx
    call print_string
    mov ax, [row_total]
    call print_kb_field
    mov dx, kb_col_gap_msg
    call print_string
    mov ax, [row_used]
    call print_kb_field
    mov dx, kb_free_gap_msg
    call print_string
    mov ax, [row_free]
    call print_kb_field
    mov dx, crlf_msg
    call print_string
    ret

print_ems_summary:
    mov dx, ems_total_msg
    call print_string
    mov ax, [ems_total_pages]
    call print_ems_amount
    mov dx, ems_free_msg
    call print_string
    mov ax, [ems_free_pages]
    call print_ems_amount
    ret

print_ems_amount:
    push ax
    mov cl, 6
    shr ax, cl
    call print_dec_word
    mov dx, mb_open_msg
    call print_string
    pop ax
    call pages_to_bytes
    call print_dword_dec
    mov dx, bytes_close_msg
    call print_string
    ret

print_largest_summary:
    mov dx, largest_msg
    call print_string
    mov ax, [largest_free]
    call paras_to_kb
    call print_dec_word
    mov dx, kb_open_msg
    call print_string
    mov ax, [largest_free]
    call paras_to_bytes
    call print_dword_dec
    mov dx, bytes_close_msg
    call print_string

    mov dx, upper_largest_msg
    call print_string
    xor ax, ax
    call print_dec_word
    mov dx, kb_open_msg
    call print_string
    xor ax, ax
    xor dx, dx
    call print_dword_dec
    mov dx, bytes_close_msg
    call print_string
    ret

paras_to_kb:
    mov cx, 6
.shift:
    shr ax, 1
    loop .shift
    ret

paras_to_bytes:
    xor dx, dx
    mov cx, 4
.shift:
    shl ax, 1
    rcl dx, 1
    loop .shift
    ret

pages_to_bytes:
    xor dx, dx
    mov cx, 14
.shift:
    shl ax, 1
    rcl dx, 1
    loop .shift
    ret

print_string:
    push ax
    mov ah, 0x09
    int 0x21
    pop ax
    ret

print_dec_word:
    xor dx, dx
    call print_dword_dec
    ret

print_kb_field:
    call print_dec_word_width5
    mov dl, 'K'
    mov ah, 0x02
    int 0x21
    ret

print_dec_word_width5:
    push ax
    push bx
    push cx
    push dx
    push si
    mov [dec_lo], ax
    mov byte [dec_started], 0
    mov si, pow10_word_table
    mov cx, 5
.power:
    xor bl, bl
    mov ax, [dec_lo]
    mov dx, [si]
.subtract:
    cmp ax, dx
    jb .emit
    sub ax, dx
    inc bl
    jmp .subtract
.emit:
    mov [dec_lo], ax
    cmp byte [dec_started], 0
    jne .digit
    test bl, bl
    jnz .start
    cmp cx, 1
    je .start
    mov dl, ' '
    jmp .put
.start:
    mov byte [dec_started], 1
.digit:
    mov dl, bl
    add dl, '0'
.put:
    mov ah, 0x02
    int 0x21
    add si, 2
    loop .power
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_dword_dec:
    push ax
    push bx
    push cx
    push dx
    push si
    mov [dec_lo], ax
    mov [dec_hi], dx
    mov byte [dec_started], 0
    mov si, pow10_table
    mov cx, pow10_count
.power:
    xor bl, bl
.subtract:
    mov ax, [dec_hi]
    cmp ax, [si+2]
    jb .emit
    ja .can_subtract
    mov ax, [dec_lo]
    cmp ax, [si]
    jb .emit
.can_subtract:
    mov ax, [si]
    sub [dec_lo], ax
    mov ax, [si+2]
    sbb [dec_hi], ax
    inc bl
    jmp .subtract
.emit:
    cmp byte [dec_started], 0
    jne .print
    test bl, bl
    jnz .start
    cmp cx, 1
    jne .next
.start:
    mov byte [dec_started], 1
.print:
    mov dl, bl
    add dl, '0'
    mov ah, 0x02
    int 0x21
.next:
    add si, 4
    loop .power
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

block_owner: dw 0
block_size: dw 0
block_sig: db 0
bad_chain: db 0
free_paras: dw 0
largest_free: dw 0
conv_used_kb: dw 0
conv_free_kb: dw 0
xms_entry: dw 0, 0
xms_total_kb: dw 0
xms_used_kb: dw 0
xms_free_kb: dw 0
ems_total_pages: dw 0
ems_free_pages: dw 0
total_kb: dw 0
total_used_kb: dw 0
total_free_kb: dw 0
row_total: dw 0
row_used: dw 0
row_free: dw 0
dec_lo: dw 0
dec_hi: dw 0
dec_started: db 0

pow10_table:
    dd 1000000000
    dd 100000000
    dd 10000000
    dd 1000000
    dd 100000
    dd 10000
    dd 1000
    dd 100
    dd 10
    dd 1
pow10_count equ 10

pow10_word_table: dw 10000, 1000, 100, 10, 1

title_msg: db "Memory type        Total       Used    Free", 13, 10, "$"
separator_msg: db "---------------    ------      ------  ------", 13, 10, "$"
conv_label: db "Conventional       $"
upper_label: db "Upper              $"
reserved_label: db "Reserved           $"
xms_label: db "Extended (XMS)     $"
total_label: db "Total memory       $"
under_label: db "Total under 1 MB   $"
kb_col_gap_msg: db "      $"
kb_free_gap_msg: db "  $"
crlf_msg: db 13, 10, "$"
ems_total_msg: db "Total Expanded (EMS)       $"
ems_free_msg: db "Free Expanded (EMS)        $"
mb_open_msg: db " M (", "$"
kb_open_msg: db " K (", "$"
bytes_close_msg: db " bytes)", 13, 10, "$"
largest_msg: db "Largest executable program size            $"
upper_largest_msg: db "Largest free upper memory block            $"
resident_msg: db "LainDOS is resident in conventional memory.", 13, 10, "$"
bad_chain_msg: db "Invalid MCB chain", 13, 10, "$"
