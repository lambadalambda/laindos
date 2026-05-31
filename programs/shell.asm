[bits 16]
[org 0x0100]

ATTR_DIR equ 0x10

start:
    push cs
    pop ds
    cli
    mov ax, cs
    mov ss, ax
    mov sp, shell_stack_top
    sti
    push cs
    pop es
    mov bx, shell_resident_paras
    mov ah, 0x4A
    int 0x21
    jc resize_failed
    push cs
    pop ds
    mov dx, banner
    mov ah, 0x09
    int 0x21
    call run_autoexec

prompt:
    call print_prompt
    call read_line
    call uppercase_line
    call execute_line
    jmp prompt

execute_line:
    cmp byte [line_buf], 0
    je .done
    mov si, line_buf
    call skip_command_prefix
    cmp byte [si], 0
    je .done
    call change_drive_command
    jc .done
    mov bx, command_table
.builtin_loop:
    mov di, [bx]
    test di, di
    jz .external
    mov si, line_buf
    call cmd_match
    jc .builtin_found
    add bx, 4
    jmp .builtin_loop
.builtin_found:
    jmp word [bx+2]
.external:
    call prepare_command
    call run_command
.done:
    ret

exit_shell:
    mov ax, 0x4C00
    int 0x21

resize_failed:
    mov dx, resize_fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

do_ver:
    mov dx, ver_msg
    mov ah, 0x09
    int 0x21
    ret

do_dir:
    call parse_dir_args
    xor ax, ax
    mov [dir_file_count], ax
    mov [dir_dir_count], ax
    mov [dir_bytes_lo], ax
    mov [dir_bytes_hi], ax
    mov [dir_free_lo], ax
    mov [dir_free_hi], ax
    mov [dir_lines], al
    call print_dir_header
    mov dx, dir_dta
    mov ah, 0x1A
    int 0x21
    mov dx, dir_pattern
    mov cx, ATTR_DIR
    mov ah, 0x4E
    int 0x21
    jc .summary
.entry:
    call print_dir_entry
    mov ah, 0x4F
    int 0x21
    jnc .entry
.summary:
    call print_dir_summary
    ret

parse_dir_args:
    mov byte [dir_pause], 0
.loop:
    call skip_spaces
    cmp byte [si], 0
    je .done
    cmp byte [si], '/'
    je .switch
    cmp byte [si], '-'
    je .switch
    jmp .skip_token
.switch:
    inc si
    cmp byte [si], 'P'
    jne .skip_token
    mov byte [dir_pause], 1
    inc si
.skip_token:
    cmp byte [si], 0
    je .loop
    cmp byte [si], ' '
    je .loop
    inc si
    jmp .skip_token
.done:
    ret

print_dir_header:
    mov dx, dir_volume_msg
    call print_dollar
    call print_current_drive_letter
    mov dx, dir_no_label_msg
    call print_dollar
    call dir_line_end
    mov dx, dir_of_msg
    call print_dollar
    call print_drive_root
    mov si, cwd_buf
    xor dl, dl
    mov ah, 0x47
    int 0x21
    jc .path_done
    cmp byte [cwd_buf], 0
    je .path_done
    mov si, cwd_buf
    call print_asciiz
.path_done:
    call dir_line_end
    call dir_line_end
    ret

print_dir_entry:
    call format_dir_name
    mov si, dir_name_buf
    mov cx, 8
    call print_fixed_chars
    mov al, ' '
    call print_char_al
    mov si, dir_name_buf + 8
    mov cx, 3
    call print_fixed_chars
    mov al, ' '
    call print_char_al
    mov al, ' '
    call print_char_al
    test byte [dir_dta + 21], ATTR_DIR
    jnz .directory
    call add_dir_file_total
    mov ax, [dir_dta + 26]
    mov dx, [dir_dta + 28]
    call print_dword_dec_width10
    jmp .date
.directory:
    inc word [dir_dir_count]
    mov dx, dir_dir_field
    call print_dollar
.date:
    mov al, ' '
    call print_char_al
    call print_dir_date
    mov al, ' '
    call print_char_al
    call print_dir_time
    call dir_line_end
    ret

format_dir_name:
    push ax
    push cx
    push si
    push di
    push es
    push cs
    pop es
    mov di, dir_name_buf
    mov al, ' '
    mov cx, 11
    rep stosb
    mov si, dir_dta + 30
    mov di, dir_name_buf
    cmp byte [si], '.'
    jne .regular
    lodsb
    stosb
    cmp byte [si], '.'
    jne .done
    lodsb
    stosb
    jmp .done
.regular:
    mov cx, 8
.name:
    lodsb
    test al, al
    jz .done
    cmp al, '.'
    je .ext_start
    stosb
    loop .name
.seek_ext:
    lodsb
    test al, al
    jz .done
    cmp al, '.'
    jne .seek_ext
.ext_start:
    mov di, dir_name_buf + 8
    mov cx, 3
.ext:
    lodsb
    test al, al
    jz .done
    stosb
    loop .ext
.done:
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

add_dir_file_total:
    inc word [dir_file_count]
    mov ax, [dir_dta + 26]
    add [dir_bytes_lo], ax
    mov ax, [dir_dta + 28]
    adc [dir_bytes_hi], ax
    ret

print_dir_summary:
    mov ax, [dir_file_count]
    xor dx, dx
    call print_dword_dec_width10
    mov dx, dir_file_count_msg
    call print_dollar
    mov ax, [dir_bytes_lo]
    mov dx, [dir_bytes_hi]
    call print_dword_dec_width10
    mov dx, dir_bytes_msg
    call print_dollar
    call dir_line_end
    call get_dir_free_bytes
    mov ax, [dir_free_lo]
    mov dx, [dir_free_hi]
    call print_dword_dec_width10
    mov dx, dir_free_msg
    call print_dollar
    call dir_line_end
    ret

get_dir_free_bytes:
    push ax
    push bx
    push cx
    push dx
    xor dl, dl
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    jne .ok
    xor ax, ax
    mov [dir_free_lo], ax
    mov [dir_free_hi], ax
    jmp .done
.ok:
    mul cx
    mov [dir_mul_lo], ax
    mov [dir_mul_hi], dx
    mov ax, [dir_mul_lo]
    mul bx
    mov [dir_free_lo], ax
    mov [dir_free_hi], dx
    mov ax, [dir_mul_hi]
    mul bx
    add [dir_free_hi], ax
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_dir_date:
    push ax
    push bx
    push cx
    mov bx, [dir_dta + 24]
    mov ax, bx
    mov cl, 5
    shr ax, cl
    and ax, 0x000F
    call print_two_digits
    mov al, '-'
    call print_char_al
    mov ax, bx
    and ax, 0x001F
    call print_two_digits
    mov al, '-'
    call print_char_al
    mov ax, bx
    mov cl, 9
    shr ax, cl
    add ax, 80
.year_mod:
    cmp ax, 100
    jb .year_done
    sub ax, 100
    jmp .year_mod
.year_done:
    call print_two_digits
    pop cx
    pop bx
    pop ax
    ret

print_dir_time:
    push ax
    push bx
    push cx
    mov bx, [dir_dta + 22]
    mov byte [dir_ampm], 'a'
    mov ax, bx
    mov cl, 11
    shr ax, cl
    and ax, 0x001F
    cmp ax, 12
    jb .hour_mod_done
    mov byte [dir_ampm], 'p'
    sub ax, 12
.hour_mod_done:
    test ax, ax
    jnz .hour_done
    mov ax, 12
.hour_done:
    call print_hour_field
    mov al, ':'
    call print_char_al
    mov ax, bx
    mov cl, 5
    shr ax, cl
    and ax, 0x003F
    call print_two_digits
    mov al, [dir_ampm]
    call print_char_al
    pop cx
    pop bx
    pop ax
    ret

print_hour_field:
    push ax
    cmp ax, 10
    jae .two
    push ax
    mov al, ' '
    call print_char_al
    pop ax
    add al, '0'
    call print_char_al
    jmp .done
.two:
    call print_two_digits
.done:
    pop ax
    ret

print_two_digits:
    push ax
    push bx
    push dx
    xor dx, dx
    mov bx, 10
    div bx
    add al, '0'
    call print_char_al
    mov ax, dx
    add al, '0'
    call print_char_al
    pop dx
    pop bx
    pop ax
    ret

print_dword_dec_width10:
    push ax
    push bx
    push cx
    push dx
    push si
    mov [dir_dec_lo], ax
    mov [dir_dec_hi], dx
    mov byte [dir_dec_started], 0
    mov si, dir_pow10_table
    mov cx, dir_pow10_count
.power:
    xor bl, bl
.subtract:
    mov ax, [dir_dec_hi]
    cmp ax, [si + 2]
    jb .emit
    ja .can_subtract
    mov ax, [dir_dec_lo]
    cmp ax, [si]
    jb .emit
.can_subtract:
    mov ax, [si]
    sub [dir_dec_lo], ax
    mov ax, [si + 2]
    sbb [dir_dec_hi], ax
    inc bl
    jmp .subtract
.emit:
    cmp byte [dir_dec_started], 0
    jne .digit
    test bl, bl
    jnz .start
    cmp cx, 1
    je .start
    mov al, ' '
    call print_char_al
    jmp .next
.start:
    mov byte [dir_dec_started], 1
.digit:
    mov al, bl
    add al, '0'
    call print_char_al
.next:
    add si, 4
    loop .power
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_fixed_chars:
    push ax
    push cx
    push dx
    push si
.loop:
    lodsb
    mov dl, al
    mov ah, 0x02
    int 0x21
    loop .loop
    pop si
    pop dx
    pop cx
    pop ax
    ret

print_current_drive_letter:
    push ax
    push dx
    mov ah, 0x19
    int 0x21
    add al, 'A'
    mov dl, al
    mov ah, 0x02
    int 0x21
    pop dx
    pop ax
    ret

dir_line_end:
    mov dx, crlf
    call print_dollar
    call dir_count_line
    ret

dir_count_line:
    cmp byte [dir_pause], 0
    je .done
    inc byte [dir_lines]
    cmp byte [dir_lines], dir_page_lines
    jb .done
    mov dx, dir_pause_msg
    call print_dollar
    mov ah, 0x08
    int 0x21
    mov byte [dir_lines], 0
    mov dx, crlf
    call print_dollar
.done:
    ret

print_dollar:
    push ax
    mov ah, 0x09
    int 0x21
    pop ax
    ret

print_char_al:
    push ax
    push dx
    mov dl, al
    mov ah, 0x02
    int 0x21
    pop dx
    pop ax
    ret

do_cd:
    cmp byte [si], 0
    je .show
    mov dx, si
    mov ah, 0x3B
    int 0x21
    jc .err
    ret
.show:
    call print_drive_root
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
    ret
.err:
    mov dx, path_not_found_msg
    mov ah, 0x09
    int 0x21
    ret

do_md:
    cmp byte [si], 0
    je .missing
    mov dx, si
    mov ah, 0x39
    int 0x21
    jc .err
    ret
.err:
    mov dx, path_not_found_msg
    mov ah, 0x09
    int 0x21
    ret
.missing:
    mov dx, missing_arg_msg
    mov ah, 0x09
    int 0x21
    ret

do_rd:
    cmp byte [si], 0
    je .missing
    mov dx, si
    mov ah, 0x3A
    int 0x21
    jc .err
    ret
.err:
    mov dx, path_not_found_msg
    mov ah, 0x09
    int 0x21
    ret
.missing:
    mov dx, missing_arg_msg
    mov ah, 0x09
    int 0x21
    ret

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
    ret
.io_err:
    mov bx, [type_handle]
    mov ah, 0x3E
    int 0x21
    mov dx, file_error_msg
    mov ah, 0x09
    int 0x21
    ret
.open_err:
    mov dx, file_not_found_msg
    mov ah, 0x09
    int 0x21
    ret
.missing:
    mov dx, missing_arg_msg
    mov ah, 0x09
    int 0x21
    ret

do_cls:
    mov dl, 12
    mov ah, 0x02
    int 0x21
    ret

do_echo:
    call skip_spaces
    cmp byte [si], 0
    je .done
    push si
    mov di, echo_off_arg
    call cmd_match
    pop si
    jc .done
    push si
    mov di, echo_on_arg
    call cmd_match
    pop si
    jc .done
    call print_asciiz
    mov dx, crlf
    mov ah, 0x09
    int 0x21
.done:
    ret

do_rem:
    ret

change_drive_command:
    push ax
    push dx
    push si
    mov al, [si]
    cmp al, 'A'
    jb .no
    cmp al, 'Z'
    ja .no
    cmp byte [si+1], ':'
    jne .no
    mov dx, si
    add dx, 2
.tail:
    mov si, dx
    cmp byte [si], 0
    je .change
    cmp byte [si], ' '
    jne .no
    inc dx
    jmp .tail
.change:
    mov dl, al
    sub dl, 'A'
    mov ah, 0x0E
    int 0x21
    cmp dl, al
    jb .handled
    mov dx, path_not_found_msg
    mov ah, 0x09
    int 0x21
.handled:
    pop si
    pop dx
    pop ax
    stc
    ret
.no:
    pop si
    pop dx
    pop ax
    clc
    ret

print_prompt:
    call print_drive_root
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

print_drive_root:
    mov ah, 0x19
    int 0x21
    add al, 'A'
    mov dl, al
    mov ah, 0x02
    int 0x21
    mov dx, prompt_drive
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
    mov byte [command_has_path], 0
    mov word [command_ext_off], 0
    mov byte [tail_has_args], 0
    mov si, line_buf
    call skip_command_prefix
    mov di, command_name
.copy:
    lodsb
    cmp al, ' '
    je .end_name_space
    test al, al
    jz .end_name_zero
    cmp al, '.'
    jne .not_dot
    mov byte [command_has_ext], 1
    stosb
    mov [command_ext_off], di
    jmp .copy
.not_dot:
    cmp al, '\'
    je .path_char
    cmp al, '/'
    je .path_char
    cmp al, ':'
    jne .store_char
.path_char:
    mov byte [command_has_path], 1
.store_char:
    stosb
    jmp .copy
.end_name_space:
    mov [tail_src], si
    mov byte [tail_has_args], 1
    jmp .finish_name
.end_name_zero:
    mov byte [tail_has_args], 0
.finish_name:
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
    call build_cmd_tail
    ret

build_cmd_tail:
    mov byte [cmd_tail], 0
    mov byte [cmd_tail+1], 13
    cmp byte [tail_has_args], 0
    je .done
    mov si, [tail_src]
    call skip_spaces
    cmp byte [si], 0
    je .done
    mov di, cmd_tail + 1
    mov al, ' '
    stosb
    mov bl, 1
.copy:
    lodsb
    test al, al
    jz .end
    cmp bl, 126
    jae .end
    stosb
    inc bl
    jmp .copy
.end:
    mov [cmd_tail], bl
    mov al, 13
    stosb
.done:
    ret

run_command:
    cmp byte [command_has_ext], 0
    jne .explicit_ext
    call run_current_command
    push cs
    pop ds
    jnc .ok_exec
    mov di, [command_ext_off]
    mov byte [di], 'E'
    mov byte [di+1], 'X'
    mov byte [di+2], 'E'
    call run_current_command
    push cs
    pop ds
    jnc .ok_exec
    mov di, [command_ext_off]
    mov byte [di], 'B'
    mov byte [di+1], 'A'
    mov byte [di+2], 'T'
    call run_batch
    jnc .ok
    mov di, [command_ext_off]
    mov byte [di], 'C'
    mov byte [di+1], 'O'
    mov byte [di+2], 'M'
    call run_path_exec
    jnc .ok_exec
    mov di, [command_ext_off]
    mov byte [di], 'E'
    mov byte [di+1], 'X'
    mov byte [di+2], 'E'
    call run_path_exec
    jnc .ok_exec
    mov di, [command_ext_off]
    mov byte [di], 'B'
    mov byte [di+1], 'A'
    mov byte [di+2], 'T'
    call run_path_batch
    jnc .ok
    jmp .bad
.explicit_ext:
    call command_ext_is_bat
    jc .run_bat
    call run_current_command
    push cs
    pop ds
    jnc .ok_exec
    call run_path_exec
    jnc .ok_exec
    jmp .bad
.run_bat:
    call run_batch
    jnc .ok
    call run_path_batch
    jc .bad
.ok:
    push cs
    pop ds
    ret
.ok_exec:
    mov ah, 0x4D
    int 0x21
    push cs
    pop ds
    ret
.bad:
    push cs
    pop ds
    mov dx, bad_cmd_msg
    mov ah, 0x09
    int 0x21
    ret

command_ext_is_bat:
    push si
    mov si, [command_ext_off]
    cmp byte [si], 'B'
    jne .no
    cmp byte [si+1], 'A'
    jne .no
    cmp byte [si+2], 'T'
    jne .no
    cmp byte [si+3], 0
    jne .no
    pop si
    stc
    ret
.no:
    pop si
    clc
    ret

run_current_command:
    mov dx, command_name
    jmp run_exec_name

run_exec_name:
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
    mov ax, 0x4B00
    int 0x21
    ret

run_batch:
    push cs
    pop ds
    mov dx, command_name
    jmp run_batch_named

run_autoexec:
    push cs
    pop ds
    mov dx, autoexec_name
    call run_batch_named
    push cs
    pop ds
    clc
    ret

run_batch_path:
    push cs
    pop ds
    mov dx, path_command_name

run_batch_named:
    cmp byte [batch_active], 0
    jne .busy
    mov byte [batch_active], 1
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .err_clear
    mov [batch_handle], ax
    push cs
    pop ds
    mov bx, ax
    mov dx, batch_buf
    mov cx, batch_buf_size - 1
    mov ah, 0x3F
    int 0x21
    jc .read_err
    mov si, batch_buf
    add si, ax
    mov byte [si], 0
    mov bx, [batch_handle]
    mov ah, 0x3E
    int 0x21
    jc .err_clear
    push cs
    pop ds
    mov si, batch_buf
.next:
    call batch_read_line
    jc .done
    cmp byte [line_buf], 0
    je .next
    mov [batch_ptr], si
    call uppercase_line
    call execute_line
    push cs
    pop ds
    mov si, [batch_ptr]
    jmp .next
.done:
    mov byte [batch_active], 0
    clc
    ret
.read_err:
    mov bx, [batch_handle]
    mov ah, 0x3E
    int 0x21
.err_clear:
    mov byte [batch_active], 0
.busy:
    stc
    ret

run_path_exec:
    mov byte [path_run_mode], 0
    jmp run_path_command

run_path_batch:
    mov byte [path_run_mode], 1

run_path_command:
    cmp byte [command_has_path], 0
    jne .err
    call find_path_value
    jc .err
.next:
    call build_path_candidate
    jc .err
    cmp byte [path_run_mode], 0
    jne .batch
    call run_candidate_exec
    jmp .after_try
.batch:
    call run_batch_path
.after_try:
    push cs
    pop ds
    jnc .ok
    cmp byte [path_more], 0
    jne .next
.err:
    push cs
    pop ds
    stc
    ret
.ok:
    clc
    ret

run_candidate_exec:
    mov dx, path_command_name
    jmp run_exec_name

find_path_value:
    push ax
    push bx
    push dx
    push si
    push di
    push es
    mov ah, 0x62
    int 0x21
    push cs
    pop ds
    mov ax, bx
    mov es, ax
    mov ax, [es:0x2C]
    test ax, ax
    jz .not_found
    mov es, ax
    xor bx, bx
.next_string:
    cmp byte [es:bx], 0
    je .not_found
    mov si, path_env_name
    mov di, bx
.compare:
    lodsb
    test al, al
    jz .found
    cmp al, [es:di]
    jne .skip_string
    inc di
    jmp .compare
.skip_string:
    mov di, bx
.skip_loop:
    cmp byte [es:di], 0
    je .skipped
    inc di
    jmp .skip_loop
.skipped:
    lea bx, [di+1]
    jmp .next_string
.found:
    mov ax, es
    mov [path_env_seg], ax
    mov [path_ptr], di
    pop es
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    clc
    ret
.not_found:
    pop es
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    stc
    ret

build_path_candidate:
    push ax
    push bx
    push ds
    push es
    push si
    push di
.next_element:
    mov ax, [cs:path_env_seg]
    mov ds, ax
    push cs
    pop es
    mov si, [cs:path_ptr]
    mov di, path_command_name
    xor bx, bx
    mov byte [cs:path_last_char], 0
.copy_path:
    lodsb
    test al, al
    jz .end_zero
    cmp al, ';'
    je .end_sep
    cmp di, path_command_name + 128
    jae .err
    stosb
    mov [cs:path_last_char], al
    inc bl
    jmp .copy_path
.end_sep:
    mov [cs:path_ptr], si
    mov byte [cs:path_more], 1
    jmp .finish_element
.end_zero:
    mov [cs:path_ptr], si
    mov byte [cs:path_more], 0
.finish_element:
    test bl, bl
    jnz .have_element
    cmp byte [cs:path_more], 0
    jne .next_element
    jmp .err
.have_element:
    mov al, [cs:path_last_char]
    cmp al, '\'
    je .append_command
    cmp al, '/'
    je .append_command
    mov al, '\'
    cmp di, path_command_name + 128
    jae .err
    stosb
.append_command:
    push cs
    pop ds
    mov si, command_name
.copy_command:
    lodsb
    cmp di, path_command_name + 128
    jae .err
    stosb
    test al, al
    jnz .copy_command
    clc
    jmp .done
.err:
    stc
.done:
    pop di
    pop si
    pop es
    pop ds
    pop bx
    pop ax
    ret

batch_read_line:
.skip_eol:
    lodsb
    test al, al
    jz .eof
    cmp al, 13
    je .skip_eol
    cmp al, 10
    je .skip_eol
    dec si
    push ds
    pop es
    mov di, line_buf
    xor cx, cx
.copy:
    lodsb
    test al, al
    jz .end
    cmp al, 13
    je .end
    cmp al, 10
    je .end
    cmp cx, 63
    jae .copy
    stosb
    inc cx
    jmp .copy
.end:
    xor al, al
    stosb
    clc
    ret
.eof:
    stc
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

skip_command_prefix:
    call skip_spaces
    cmp byte [si], '@'
    jne .done
    inc si
    call skip_spaces
.done:
    ret

cmd_match:
    push ax
    call skip_command_prefix
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
    je .arg_spaces
    cmp al, '/'
    je .yes
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

banner: db "LainDOS Shell", 13, 10, "$"
prompt_drive: db ":\$"
prompt_end: db ">$"
crlf: db 13, 10, "$"
bad_cmd_msg: db "Bad command or file name", 13, 10, "$"
ver_msg: db "LainDOS", 13, 10, "$"
path_not_found_msg: db "Path not found", 13, 10, "$"
file_not_found_msg: db "File not found", 13, 10, "$"
file_error_msg: db "File error", 13, 10, "$"
missing_arg_msg: db "Missing argument", 13, 10, "$"
resize_fail_msg: db "Shell resize failed", 13, 10, "$"
exit_cmd: db "EXIT", 0
ver_cmd: db "VER", 0
dir_cmd: db "DIR", 0
cd_cmd: db "CD", 0
md_cmd: db "MD", 0
rd_cmd: db "RD", 0
type_cmd: db "TYPE", 0
cls_cmd: db "CLS", 0
echo_cmd: db "ECHO", 0
rem_cmd: db "REM", 0
command_table:
    dw exit_cmd, exit_shell
    dw ver_cmd, do_ver
    dw dir_cmd, do_dir
    dw cd_cmd, do_cd
    dw md_cmd, do_md
    dw rd_cmd, do_rd
    dw type_cmd, do_type
    dw cls_cmd, do_cls
    dw echo_cmd, do_echo
    dw rem_cmd, do_rem
    dw 0, 0
echo_off_arg: db "OFF", 0
echo_on_arg: db "ON", 0
autoexec_name: db "AUTOEXEC.BAT", 0
dir_pattern: db "*.*", 0
dir_volume_msg: db " Volume in drive ", "$"
dir_no_label_msg: db " has no label", "$"
dir_of_msg: db " Directory of ", "$"
dir_dir_field: db "     <DIR>", "$"
dir_file_count_msg: db " File(s) ", "$"
dir_bytes_msg: db " bytes", "$"
dir_free_msg: db " bytes free", "$"
dir_pause_msg: db "Press any key to continue . . .", "$"
dir_page_lines equ 22
dir_pow10_table:
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
dir_pow10_count equ 10
type_buf_size equ 128
batch_buf_size equ 512

line_buf: times 64 db 0
line_input: db 64, 0
times 64 db 0
cwd_buf: times 64 db 0
command_name: times 64 db 0
command_has_ext: db 0
command_has_path: db 0
command_ext_off: dw 0
tail_src: dw 0
tail_has_args: db 0
cmd_tail: times 128 db 0
exec_params: times 14 db 0
path_env_name: db "PATH=", 0
path_env_seg: dw 0
path_ptr: dw 0
path_more: db 0
path_last_char: db 0
path_run_mode: db 0
path_command_name: times 128 db 0
dir_pause: db 0
dir_lines: db 0
dir_file_count: dw 0
dir_dir_count: dw 0
dir_bytes_lo: dw 0
dir_bytes_hi: dw 0
dir_free_lo: dw 0
dir_free_hi: dw 0
dir_mul_lo: dw 0
dir_mul_hi: dw 0
dir_dec_lo: dw 0
dir_dec_hi: dw 0
dir_dec_started: db 0
dir_ampm: db 0
dir_name_buf: times 11 db 0
dir_dta: times 64 db 0
type_handle: dw 0
type_buf: times type_buf_size db 0
batch_handle: dw 0
batch_ptr: dw 0
batch_active: db 0
batch_buf: times batch_buf_size db 0
shell_stack: times 1024 db 0
shell_stack_top:
shell_resident_end:
shell_resident_paras equ ((shell_resident_end - start + 0x100 + 15) / 16)
