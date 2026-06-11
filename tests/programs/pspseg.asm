; Print the program's PSP segment and command tail so tests can verify
; where DOS placed it (LOADFIX must move children to segment 1000h+).
%include "tests/programs/common.inc"
COM_START
    mov ah, 0x62
    int 0x21
    mov ax, bx
    mov di, seg_digits
    call store_hex_word
    PRINT_DOLLAR seg_msg

    PRINT_DOLLAR tail_msg
    mov si, 0x81
    xor ch, ch
    mov cl, [0x80]
    jcxz .tail_done
.tail_loop:
    lodsb
    cmp al, 0x0D
    je .tail_done
    mov dl, al
    mov ah, 0x02
    int 0x21
    loop .tail_loop
.tail_done:
    PRINT_DOLLAR crlf_msg
    EXIT_CODE 0

store_hex_word:
    mov cx, 4
.digit:
    rol ax, 4
    push ax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .store
    add al, 'A' - '0' - 10
.store:
    mov [di], al
    inc di
    pop ax
    loop .digit
    ret

seg_msg: db "PSPSEG="
seg_digits: db "0000", 13, 10, "$"
tail_msg: db "PSPTAIL=$"
crlf_msg: db "<", 13, 10, "$"
