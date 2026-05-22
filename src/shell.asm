[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov dx, banner
    mov ah, 0x09
    int 0x21

prompt:
    call print_prompt
    call read_line
    call uppercase_line
    cmp byte [line_buf], 0
    je prompt
    mov si, line_buf
    call skip_spaces
    cmp byte [si], 0
    je prompt
    mov si, line_buf
    mov di, exit_cmd
    call cmd_match
    jc exit_shell
    mov si, line_buf
    mov di, ver_cmd
    call cmd_match
    jc do_ver
    mov si, line_buf
    mov di, dir_cmd
    call cmd_match
    jc do_dir
    mov si, line_buf
    mov di, cd_cmd
    call cmd_match
    jc do_cd
    mov si, line_buf
    mov di, type_cmd
    call cmd_match
    jc do_type
    mov si, line_buf
    mov di, cls_cmd
    call cmd_match
    jc do_cls
    mov si, line_buf
    mov di, mem_cmd
    call cmd_match
    jc do_mem
    call prepare_command
    call run_command
    jmp prompt

exit_shell:
    mov ax, 0x4C00
    int 0x21

do_ver:
    mov dx, ver_msg
    mov ah, 0x09
    int 0x21
    jmp prompt

do_dir:
    mov dx, dir_dta
    mov ah, 0x1A
    int 0x21
    mov dx, dir_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc .done
.entry:
    mov si, dir_dta + 30
    call print_asciiz
    mov dx, crlf
    mov ah, 0x09
    int 0x21
    mov ah, 0x4F
    int 0x21
    jnc .entry
.done:
    jmp prompt

do_cd:
    cmp byte [si], 0
    je .show
    mov dx, si
    mov ah, 0x3B
    int 0x21
    jc .err
    jmp prompt
.show:
    mov dx, prompt_drive
    mov ah, 0x09
    int 0x21
    mov si, cwd_buf
    xor dl, dl
    mov ah, 0x47
    int 0x21
    jc .err
    cmp byte [cwd_buf], 0
    je .show_crlf
    mov si, cwd_buf
    call print_asciiz
.show_crlf:
    mov dx, crlf
    mov ah, 0x09
    int 0x21
    jmp prompt
.err:
    mov dx, path_not_found_msg
    mov ah, 0x09
    int 0x21
    jmp prompt

do_type:
    cmp byte [si], 0
    je .missing
    mov dx, si
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .open_err
    mov [type_handle], ax
.read:
    mov bx, [type_handle]
    mov dx, type_buf
    mov cx, type_buf_size
    mov ah, 0x3F
    int 0x21
    jc .io_err
    test ax, ax
    jz .done
    mov bx, 1
    mov cx, ax
    mov dx, type_buf
    mov ah, 0x40
    int 0x21
    jc .io_err
    jmp .read
.done:
    mov bx, [type_handle]
    mov ah, 0x3E
    int 0x21
    jmp prompt
.io_err:
    mov bx, [type_handle]
    mov ah, 0x3E
    int 0x21
    mov dx, file_error_msg
    mov ah, 0x09
    int 0x21
    jmp prompt
.open_err:
    mov dx, file_not_found_msg
    mov ah, 0x09
    int 0x21
    jmp prompt
.missing:
    mov dx, missing_arg_msg
    mov ah, 0x09
    int 0x21
    jmp prompt

do_cls:
    mov dl, 12
    mov ah, 0x02
    int 0x21
    jmp prompt

do_mem:
    mov bx, 0xFFFF
    mov ah, 0x48
    int 0x21
    jc .print
    mov es, ax
    mov ah, 0x49
    int 0x21
    mov bx, 0xFFFF
.print:
    mov dx, mem_msg
    mov ah, 0x09
    int 0x21
    mov ax, bx
    call print_hex_word
    mov dx, mem_suffix
    mov ah, 0x09
    int 0x21
    jmp prompt

print_prompt:
    mov dx, prompt_drive
    mov ah, 0x09
    int 0x21
    mov si, cwd_buf
    xor dl, dl
    mov ah, 0x47
    int 0x21
    jc .end
    cmp byte [cwd_buf], 0
    je .end
    mov si, cwd_buf
    call print_asciiz
.end:
    mov dx, prompt_end
    mov ah, 0x09
    int 0x21
    ret

read_line:
    mov dx, line_input
    mov ah, 0x0A
    int 0x21
    push ds
    pop es
    mov si, line_input + 2
    mov di, line_buf
    xor cx, cx
    mov cl, [line_input + 1]
    rep movsb
    xor al, al
    stosb
    ret

uppercase_line:
    mov si, line_buf
.loop:
    mov al, [si]
    test al, al
    jz .done
    cmp al, 'a'
    jb .next
    cmp al, 'z'
    ja .next
    sub byte [si], 32
.next:
    inc si
    jmp .loop
.done:
    ret

prepare_command:
    push ds
    pop es
    mov byte [command_has_ext], 0
    mov si, line_buf
    call skip_spaces
    mov di, command_name
.copy:
    lodsb
    cmp al, ' '
    je .end_name
    test al, al
    jz .end_name
    cmp al, '.'
    jne .not_dot
    mov byte [command_has_ext], 1
.not_dot:
    stosb
    jmp .copy
.end_name:
    cmp byte [command_has_ext], 0
    jne .terminate
    mov al, '.'
    stosb
    mov [command_ext_off], di
    mov al, 'C'
    stosb
    mov al, 'O'
    stosb
    mov al, 'M'
    stosb
.terminate:
    xor al, al
    stosb
    mov byte [cmd_tail], 0
    mov byte [cmd_tail+1], 13
    ret

run_command:
    call run_current_command
    jnc .ok
    cmp byte [command_has_ext], 0
    jne .bad
    mov di, [command_ext_off]
    mov byte [di], 'E'
    mov byte [di+1], 'X'
    mov byte [di+2], 'E'
    call run_current_command
    jc .bad
.ok:
    mov ah, 0x4D
    int 0x21
    ret
.bad:
    mov dx, bad_cmd_msg
    mov ah, 0x09
    int 0x21
    ret

run_current_command:
    mov word [exec_params], 0
    mov word [exec_params+2], cmd_tail
    mov word [exec_params+4], cs
    mov word [exec_params+6], 0
    mov word [exec_params+8], 0
    mov word [exec_params+10], 0
    mov word [exec_params+12], 0
    push cs
    pop es
    mov bx, exec_params
    mov dx, command_name
    mov ax, 0x4B00
    int 0x21
    ret

print_asciiz:
.loop:
    lodsb
    test al, al
    jz .done
    mov dl, al
    mov ah, 0x02
    int 0x21
    jmp .loop
.done:
    ret

skip_spaces:
.loop:
    cmp byte [si], ' '
    jne .done
    inc si
    jmp .loop
.done:
    ret

cmd_match:
    push ax
    call skip_spaces
.loop:
    mov al, [di]
    test al, al
    jz .cmd_end
    cmp al, [si]
    jne .no
    inc si
    inc di
    jmp .loop
.cmd_end:
    mov al, [si]
    test al, al
    jz .yes
    cmp al, ' '
    jne .no
.arg_spaces:
    inc si
    cmp byte [si], ' '
    je .arg_spaces
.yes:
    stc
    pop ax
    ret
.no:
    clc
    pop ax
    ret

print_hex_word:
    push ax
    push bx
    push cx
    push dx
    mov bx, ax
    mov cx, 4
.loop:
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
    loop .loop
    pop dx
    pop cx
    pop bx
    pop ax
    ret

banner: db "LainDOS Shell", 13, 10, "$"
prompt_drive: db "A:\$"
prompt_end: db ">$"
crlf: db 13, 10, "$"
bad_cmd_msg: db "Bad command or file name", 13, 10, "$"
ver_msg: db "LainDOS", 13, 10, "$"
path_not_found_msg: db "Path not found", 13, 10, "$"
file_not_found_msg: db "File not found", 13, 10, "$"
file_error_msg: db "File error", 13, 10, "$"
missing_arg_msg: db "Missing argument", 13, 10, "$"
mem_msg: db "Largest free block: $"
mem_suffix: db " paragraphs", 13, 10, "$"
exit_cmd: db "EXIT", 0
ver_cmd: db "VER", 0
dir_cmd: db "DIR", 0
cd_cmd: db "CD", 0
type_cmd: db "TYPE", 0
cls_cmd: db "CLS", 0
mem_cmd: db "MEM", 0
dir_pattern: db "*.*", 0
type_buf_size equ 128

line_buf: times 64 db 0
line_input: db 64, 0
times 64 db 0
cwd_buf: times 64 db 0
command_name: times 64 db 0
command_has_ext: db 0
command_ext_off: dw 0
cmd_tail: times 128 db 0
exec_params: times 14 db 0
dir_dta: times 64 db 0
type_handle: dw 0
type_buf: times type_buf_size db 0
