[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov dx, banner
    mov ah, 0x09
    int 0x21

prompt:
    mov dx, prompt_msg
    mov ah, 0x09
    int 0x21
    call read_line
    call uppercase_line
    cmp byte [line_buf], 0
    je prompt
    mov si, line_buf
    mov di, exit_cmd
    call streq
    jc exit_shell
    mov si, line_buf
    mov di, ver_cmd
    call streq
    jc do_ver
    mov si, line_buf
    mov di, dir_cmd
    call streq
    jc do_dir
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

streq:
.loop:
    mov al, [si]
    cmp al, [di]
    jne .no
    test al, al
    jz .yes
    inc si
    inc di
    jmp .loop
.yes:
    stc
    ret
.no:
    clc
    ret

banner: db "LainDOS Shell", 13, 10, "$"
prompt_msg: db "A:\>$"
crlf: db 13, 10, "$"
bad_cmd_msg: db "Bad command or file name", 13, 10, "$"
ver_msg: db "LainDOS", 13, 10, "$"
exit_cmd: db "EXIT", 0
ver_cmd: db "VER", 0
dir_cmd: db "DIR", 0
dir_pattern: db "*.*", 0

line_buf: times 64 db 0
line_input: db 64, 0
times 64 db 0
command_name: times 64 db 0
command_has_ext: db 0
command_ext_off: dw 0
cmd_tail: times 128 db 0
exec_params: times 14 db 0
dir_dta: times 64 db 0
