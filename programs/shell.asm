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
    mov ax, 0x2523
    mov dx, shell_int23
    int 0x21
    push cs
    pop es
    mov bx, shell_resident_paras
    mov ah, 0x4A
    int 0x21
    jc resize_failed
    push cs
    pop ds
    call run_command_tail
    jc exit_shell
    mov dx, banner
    call print_dollar
    call run_autoexec

prompt:
    call print_prompt
    call read_line
    call execute_line
    jmp prompt

execute_line:
    cmp byte [line_buf], 0
    je .skip
    call redir_setup
    push ax
    cmp byte [line_buf], 0
    je .done
    mov si, line_buf
    call skip_command_prefix
    cmp byte [si], 0
    je .done
    cmp byte [si], ':'
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
    call [bx+2]
    jmp .done
.external:
    call prepare_command
    call run_command
.done:
    pop ax
    test al, al
    jz .skip
    call redir_restore
.skip:
    ret

redir_setup:
    push bx
    push cx
    push dx
    push si
    push di
    mov si, line_buf
.scan:
    mov al, [si]
    test al, al
    jz .none
    cmp al, '>'
    je .found
    inc si
    jmp .scan
.none:
    xor al, al
.out:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
.found:
    mov di, si
    inc si
    mov byte [redir_append], 0
    cmp byte [si], '>'
    jne .skip_ws
    inc si
    mov byte [redir_append], 1
.skip_ws:
    cmp byte [si], ' '
    je .ws_next
    cmp byte [si], 9
    jne .copy_target
.ws_next:
    inc si
    jmp .skip_ws
.copy_target:
    mov bx, redir_path
.tgt_loop:
    mov al, [si]
    test al, al
    jz .tgt_done
    cmp al, ' '
    je .tgt_done
    cmp al, 9
    je .tgt_done
    cmp al, '<'
    je .tgt_done
    cmp al, '>'
    je .tgt_done
    cmp al, '|'
    je .tgt_done
    mov [bx], al
    inc bx
    inc si
    cmp bx, redir_path + 63
    jb .tgt_loop
.tgt_done:
    mov byte [bx], 0
.strip:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jnz .strip
    cmp byte [redir_path], 0
    je .none
    mov byte [redir_to_nul], 0
    mov al, [redir_path]
    and al, 0xDF
    cmp al, 'N'
    jne .not_nul
    mov al, [redir_path+1]
    and al, 0xDF
    cmp al, 'U'
    jne .not_nul
    mov al, [redir_path+2]
    and al, 0xDF
    cmp al, 'L'
    jne .not_nul
    cmp byte [redir_path+3], 0
    jne .not_nul
    mov byte [redir_to_nul], 1
.not_nul:
    mov bx, 1
    mov ah, 0x45
    int 0x21
    jc .none
    mov [redir_saved], ax
    mov dx, redir_path
    cmp byte [redir_append], 0
    je .create
    mov ax, 0x3D01
    int 0x21
    jc .create
    mov bx, ax
    xor cx, cx
    xor dx, dx
    mov ax, 0x4202
    int 0x21
    jmp .have_handle
.create:
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc .fail_close_saved
    mov bx, ax
.have_handle:
    mov cx, 1
    mov ah, 0x46
    int 0x21
    mov ah, 0x3E
    int 0x21
    mov al, 1
    jmp .out
.fail_close_saved:
    mov bx, [redir_saved]
    mov ah, 0x3E
    int 0x21
    jmp .none

redir_restore:
    push ax
    push bx
    push cx
    mov bx, [redir_saved]
    mov cx, 1
    mov ah, 0x46
    int 0x21
    mov ah, 0x3E
    int 0x21
    mov byte [redir_to_nul], 0
    pop cx
    pop bx
    pop ax
    ret

exit_shell:
    mov ax, 0x4C00
    int 0x21

resize_failed:
    mov dx, resize_fail_msg
    call print_dollar
    mov ax, 0x4C01
    int 0x21

do_ver:
    mov dx, ver_msg
    call print_dollar
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
    mov [dir_wide_cols], al
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
    cmp byte [dir_wide], 0
    jne .wide_entry
    call print_dir_entry
    jmp .next
.wide_entry:
    call print_dir_wide_entry
.next:
    mov ah, 0x4F
    int 0x21
    jnc .entry
.summary:
    call finish_dir_wide_row
    call print_dir_summary
    ret

parse_dir_args:
    mov byte [dir_pause], 0
    mov byte [dir_wide], 0
    mov byte [dir_has_operand], 0
    mov byte [dir_header_path], 0
    push si
    mov si, dir_default_pattern
    mov di, dir_pattern
    call copy_asciiz
    pop si
.loop:
    call skip_spaces
    cmp byte [si], 0
    je .done
    cmp byte [si], '/'
    je .switch
    cmp byte [si], '-'
    je .switch
    cmp byte [dir_has_operand], 0
    jne .skip_token
    call copy_dir_operand
    mov byte [dir_has_operand], 1
    jmp .loop
.switch:
    inc si
.switch_loop:
    cmp byte [si], 0
    je .done
    cmp byte [si], ' '
    je .loop
    mov al, [si]
    and al, 0xDF
    cmp al, 'P'
    je .set_pause
    cmp al, 'W'
    je .set_wide
    inc si
    jmp .switch_loop
.set_pause:
    mov byte [dir_pause], 1
    inc si
    jmp .switch_loop
.set_wide:
    mov byte [dir_wide], 1
    inc si
    jmp .switch_loop
.skip_token:
    cmp byte [si], 0
    je .done
    cmp byte [si], ' '
    je .loop
    inc si
    jmp .skip_token
.done:
    call finish_dir_pattern
    ret

copy_dir_operand:
    push ax
    push cx
    push di
    mov di, dir_pattern
    mov cx, dir_pattern_size - 1
.copy:
    mov al, [si]
    test al, al
    jz .end
    cmp al, ' '
    je .end
    test cx, cx
    jz .skip_rest
    stosb
    dec cx
    inc si
    jmp .copy
.skip_rest:
    inc si
.skip_rest_loop:
    cmp byte [si], 0
    je .end
    cmp byte [si], ' '
    je .end
    inc si
    jmp .skip_rest_loop
.end:
    xor al, al
    stosb
    pop di
    pop cx
    pop ax
    ret

finish_dir_pattern:
    cmp byte [dir_has_operand], 0
    je .done
    mov dx, dir_pattern
    xor al, al
    mov ah, 0x43
    int 0x21
    jc .pattern_operand
    test cl, ATTR_DIR
    jz .pattern_operand
    call copy_dir_pattern_to_header
    call append_dir_wildcard
    ret
.pattern_operand:
    call set_dir_header_from_pattern
.done:
    ret

copy_dir_pattern_to_header:
    push si
    push di
    push cx
    mov si, dir_pattern
    mov di, dir_header_path
    mov cx, dir_header_path_size - 1
    call copy_asciiz_bounded
    pop cx
    pop di
    pop si
    ret

set_dir_header_from_pattern:
    push ax
    push bx
    push si
    push di
    xor bx, bx
    mov si, dir_pattern
.scan:
    lodsb
    test al, al
    jz .scan_done
    cmp al, '\'
    je .sep
    cmp al, '/'
    jne .scan
.sep:
    mov bx, si
    dec bx
    jmp .scan
.scan_done:
    mov byte [dir_header_path], 0
    test bx, bx
    jz .done
    mov si, dir_pattern
    mov di, dir_header_path
    mov cx, dir_header_path_size - 1
.copy:
    cmp si, bx
    jae .end_copy
    test cx, cx
    jz .terminate
    lodsb
    stosb
    dec cx
    jmp .copy
.end_copy:
    cmp di, dir_header_path
    jne .terminate
    mov al, [bx]
    stosb
.terminate:
    xor al, al
    stosb
.done:
    pop di
    pop si
    pop bx
    pop ax
    ret

append_dir_wildcard:
    push ax
    push si
    push di
    mov di, dir_pattern
.find_end:
    cmp byte [di], 0
    je .at_end
    inc di
    jmp .find_end
.at_end:
    cmp di, dir_pattern + dir_pattern_size - 5
    ja .done
    cmp di, dir_pattern
    je .copy_wildcard
    mov al, [di-1]
    cmp al, '\'
    je .copy_wildcard
    cmp al, '/'
    je .copy_wildcard
    mov al, '\'
    stosb
.copy_wildcard:
    mov si, dir_default_pattern
    call copy_asciiz
.done:
    pop di
    pop si
    pop ax
    ret

copy_asciiz:
.copy:
    lodsb
    stosb
    test al, al
    jnz .copy
    ret

copy_asciiz_bounded:
.copy:
    test cx, cx
    jz .terminate
    lodsb
    test al, al
    jz .store_zero
    stosb
    dec cx
    jmp .copy
.store_zero:
    stosb
    ret
.terminate:
    xor al, al
    stosb
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
    cmp byte [dir_header_path], 0
    jne .operand_path
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
.operand_path:
    call print_dir_header_path
    jmp .path_done

print_dir_header_path:
    mov si, dir_header_path
    mov al, [si]
    cmp al, 'A'
    jb .not_drive
    cmp al, 'Z'
    ja .not_drive
    cmp byte [si+1], ':'
    jne .not_drive
    call print_asciiz
    ret
.not_drive:
    cmp byte [si], '\'
    je .rooted
    cmp byte [si], '/'
    je .rooted
    call print_drive_root
    mov si, cwd_buf
    xor dl, dl
    mov ah, 0x47
    int 0x21
    jc .print_operand
    cmp byte [cwd_buf], 0
    je .print_operand
    mov si, cwd_buf
    call print_asciiz
    mov al, '\'
    call print_char_al
.print_operand:
    mov si, dir_header_path
    call print_asciiz
    ret
.rooted:
    call print_current_drive_letter
    mov al, ':'
    call print_char_al
    mov si, dir_header_path
    call print_asciiz
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

print_dir_wide_entry:
    test byte [dir_dta + 21], ATTR_DIR
    jnz .directory
    call add_dir_file_total
    mov si, dir_dta + 30
    mov cx, dir_wide_width
    call print_wide_field_asciiz
    jmp .advance
.directory:
    inc word [dir_dir_count]
    call print_wide_dir_field
.advance:
    inc byte [dir_wide_cols]
    cmp byte [dir_wide_cols], dir_wide_columns
    jb .done
    mov byte [dir_wide_cols], 0
    call dir_line_end
.done:
    ret

print_wide_field_asciiz:
.loop:
    test cx, cx
    jz .done
    lodsb
    test al, al
    jz .pad
    call print_char_al
    dec cx
    jmp .loop
.pad:
    call print_spaces_cx
.done:
    ret

print_wide_dir_field:
    mov cx, dir_wide_width
    mov al, '['
    call print_char_al
    dec cx
    mov si, dir_dta + 30
.name:
    cmp cx, 1
    jbe .close
    lodsb
    test al, al
    jz .close
    call print_char_al
    dec cx
    jmp .name
.close:
    mov al, ']'
    call print_char_al
    dec cx
    call print_spaces_cx
    ret

print_spaces_cx:
    mov al, ' '
.loop:
    test cx, cx
    jz .done
    call print_char_al
    dec cx
    jmp .loop
.done:
    ret

finish_dir_wide_row:
    cmp byte [dir_wide], 0
    je .done
    cmp byte [dir_wide_cols], 0
    je .done
    mov byte [dir_wide_cols], 0
    call dir_line_end
.done:
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
    call print_char_dl
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
    call print_char_dl
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
    push bx
    push cx
    push si
    mov si, dx
.find_end:
    cmp byte [si], '$'
    je .got_end
    inc si
    jmp .find_end
.got_end:
    mov cx, si
    sub cx, dx
    jz .empty
    mov bx, 1
    mov ah, 0x40
    int 0x21
.empty:
    pop si
    pop cx
    pop bx
    pop ax
    ret

print_char_al:
    push dx
    mov dl, al
    call print_char_dl
    pop dx
    ret

print_char_dl:
    push ax
    push bx
    push cx
    push dx
    push ds
    push cs
    pop ds
    mov [stdout_char], dl
    mov dx, stdout_char
    mov cx, 1
    mov bx, 1
    mov ah, 0x40
    int 0x21
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

do_copy:
    call parse_copy_args
    cmp byte [copy_arg_count], 0
    je .missing
    mov si, copy_src_path
.wild_scan:
    mov al, [si]
    test al, al
    jz copy_one_file
    cmp al, '*'
    je .wildcard
    cmp al, '?'
    je .wildcard
    inc si
    jmp .wild_scan
.wildcard:
    call copy_src_basename_ptr
    mov [copy_src_base], si
    mov dx, copy_dta
    mov ah, 0x1A
    int 0x21
    mov dx, copy_src_path
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc .open_error
.wild_next:
    mov si, copy_dta + 0x1E
    mov di, [copy_src_base]
.splice:
    lodsb
    mov [di], al
    inc di
    test al, al
    jnz .splice
    call copy_one_file
    mov ah, 0x4F
    int 0x21
    jnc .wild_next
    ret
.open_error:
    mov dx, file_not_found_msg
    call print_dollar
    ret
.missing:
    mov dx, missing_arg_msg
    call print_dollar
    ret

copy_one_file:
    call build_copy_destination
    jc .file_error
    mov dx, copy_src_path
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .open_error
    mov [copy_src_handle], ax
    call confirm_copy_overwrite
    jc .cancel
    xor cx, cx
    mov dx, copy_dst_final
    mov ah, 0x3C
    int 0x21
    jc .create_error
    mov [copy_dst_handle], ax
.read:
    mov bx, [copy_src_handle]
    mov dx, type_buf
    mov cx, type_buf_size
    mov ah, 0x3F
    int 0x21
    jc .io_error
    test ax, ax
    jz .success
    mov [copy_io_count], ax
    mov bx, [copy_dst_handle]
    mov cx, ax
    mov dx, type_buf
    mov ah, 0x40
    int 0x21
    jc .io_error
    cmp ax, [copy_io_count]
    jne .io_error
    jmp .read
.success:
    mov bx, [copy_dst_handle]
    mov ah, 0x3E
    int 0x21
    mov bx, [copy_src_handle]
    mov ah, 0x3E
    int 0x21
    mov dx, copy_success_msg
    call print_dollar
    ret
.cancel:
    mov bx, [copy_src_handle]
    mov ah, 0x3E
    int 0x21
    mov dx, copy_not_copied_msg
    call print_dollar
    ret
.create_error:
    mov bx, [copy_src_handle]
    mov ah, 0x3E
    int 0x21
    jmp .file_error
.io_error:
    mov bx, [copy_dst_handle]
    mov ah, 0x3E
    int 0x21
    mov bx, [copy_src_handle]
    mov ah, 0x3E
    int 0x21
.file_error:
    mov dx, file_error_msg
    call print_dollar
    ret
.open_error:
    mov dx, file_not_found_msg
    call print_dollar
    ret

parse_copy_args:
    mov byte [copy_yes], 0
    mov byte [copy_arg_count], 0
    mov byte [copy_dst_path], 0
.loop:
    call skip_spaces
    cmp byte [si], 0
    je .done
    cmp byte [si], '/'
    je .switch
    cmp byte [si], '-'
    je .switch
    cmp byte [copy_arg_count], 0
    je .src
    cmp byte [copy_arg_count], 1
    je .dst
    call skip_token_chars
    jmp .loop
.src:
    mov di, copy_src_path
    call copy_path_token
    inc byte [copy_arg_count]
    jmp .loop
.dst:
    mov di, copy_dst_path
    call copy_path_token
    inc byte [copy_arg_count]
    jmp .loop
.switch:
    inc si
    cmp byte [si], '-'
    je .switch_minus
    mov al, [si]
    and al, 0xDF
    cmp al, 'Y'
    jne .switch_skip
    mov byte [copy_yes], 1
    jmp .switch_skip
.switch_minus:
    mov al, [si+1]
    and al, 0xDF
    cmp al, 'Y'
    jne .switch_skip
    mov byte [copy_yes], 0
.switch_skip:
    call skip_token_chars
    jmp .loop
.done:
    ret

copy_path_token:
    push ax
    push cx
    push di
    mov cx, copy_path_size - 1
.copy:
    mov al, [si]
    test al, al
    jz .end
    cmp al, ' '
    je .end
    test cx, cx
    jz .skip_rest
    stosb
    dec cx
    inc si
    jmp .copy
.skip_rest:
    inc si
.skip_loop:
    cmp byte [si], 0
    je .end
    cmp byte [si], ' '
    je .end
    inc si
    jmp .skip_loop
.end:
    xor al, al
    stosb
    pop di
    pop cx
    pop ax
    ret

build_copy_destination:
    mov si, copy_dst_path
    mov di, copy_dst_final
    mov cx, copy_path_size - 1
    call copy_asciiz_bounded
    cmp byte [copy_dst_path], 0
    je append_copy_basename
    mov dx, copy_dst_path
    xor al, al
    mov ah, 0x43
    int 0x21
    jc .not_dir
    test cl, ATTR_DIR
    jz .not_dir
    call append_copy_basename
    ret
.not_dir:
    clc
    ret

append_copy_basename:
    mov di, copy_dst_final
.find_end:
    cmp byte [di], 0
    je .at_end
    inc di
    jmp .find_end
.at_end:
    cmp di, copy_dst_final
    je .basename
    mov al, [di-1]
    cmp al, '\'
    je .basename
    cmp al, '/'
    je .basename
    cmp al, ':'
    je .basename
    cmp di, copy_dst_final + copy_path_size - 1
    jae .err
    mov al, '\'
    stosb
.basename:
    call copy_src_basename_ptr
    cmp byte [si], 0
    je .err
.copy:
    lodsb
    test al, al
    jz .done
    cmp di, copy_dst_final + copy_path_size - 1
    jae .err
    stosb
    jmp .copy
.done:
    xor al, al
    stosb
    clc
    ret
.err:
    stc
    ret

copy_src_basename_ptr:
    mov si, copy_src_path

path_basename_ptr:
    push ax
    push bx
    mov bx, si
.scan:
    lodsb
    test al, al
    jz .done
    cmp al, '\'
    je .sep
    cmp al, '/'
    je .sep
    cmp al, ':'
    jne .scan
.sep:
    mov bx, si
    jmp .scan
.done:
    mov si, bx
    pop bx
    pop ax
    ret

confirm_copy_overwrite:
    cmp byte [copy_yes], 0
    jne .yes
    mov dx, copy_dst_final
    xor al, al
    mov ah, 0x43
    int 0x21
    jc .yes
    mov dx, copy_overwrite_msg
    call print_dollar
    mov si, copy_dst_final
    call print_asciiz
    mov dx, copy_overwrite_suffix
    call print_dollar
    mov ah, 0x08
    int 0x21
    push ax
    mov dx, crlf
    call print_dollar
    pop ax
    cmp al, 'Y'
    je .yes
    cmp al, 'y'
    je .yes
    stc
    ret
.yes:
    clc
    ret

skip_token_chars:
.loop:
    cmp byte [si], 0
    je .done
    cmp byte [si], ' '
    je .done
    inc si
    jmp .loop
.done:
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
    call print_dollar
    ret
.err:
    mov dx, path_not_found_msg
    call print_dollar
    ret

do_cd_parent:
    mov si, parent_arg
    jmp do_cd

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
    call print_dollar
    ret
.missing:
    mov dx, missing_arg_msg
    call print_dollar
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
    call print_dollar
    ret
.missing:
    mov dx, missing_arg_msg
    call print_dollar
    ret

do_del:
    call parse_del_args
    cmp byte [del_has_arg], 0
    je .missing
    call del_path_has_wildcard
    jc .wildcard
    call del_one_file
    ret
.wildcard:
    mov si, del_path
    call path_basename_ptr
    mov [del_base], si
    mov dx, copy_dta
    mov ah, 0x1A
    int 0x21
    mov dx, del_path
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc .not_found
.wild_next:
    mov si, copy_dta + 0x1E
    mov di, [del_base]
.splice:
    lodsb
    mov [di], al
    inc di
    test al, al
    jnz .splice
    call del_one_file
    mov ah, 0x4F
    int 0x21
    jnc .wild_next
    ret
.not_found:
    mov dx, file_not_found_msg
    call print_dollar
    ret
.missing:
    mov dx, missing_arg_msg
    call print_dollar
    ret

del_one_file:
    call confirm_del_prompt
    jc .cancel
    mov dx, del_path
    mov ah, 0x41
    int 0x21
    jc .err
    ret
.cancel:
    mov dx, del_not_deleted_msg
    call print_dollar
    ret
.err:
    mov dx, file_error_msg
    call print_dollar
    ret

parse_del_args:
    mov byte [del_prompt], 0
    mov byte [del_has_arg], 0
.loop:
    call skip_spaces
    cmp byte [si], 0
    je .done
    cmp byte [si], '/'
    je .switch
    cmp byte [del_has_arg], 0
    jne .skip_token
    mov di, del_path
    call copy_path_token
    mov byte [del_has_arg], 1
    jmp .loop
.switch:
    inc si
.switch_loop:
    cmp byte [si], 0
    je .done
    cmp byte [si], ' '
    je .loop
    mov al, [si]
    and al, 0xDF
    cmp al, 'P'
    je .set_prompt
    inc si
    jmp .switch_loop
.set_prompt:
    mov byte [del_prompt], 1
    inc si
    jmp .switch_loop
.skip_token:
    call skip_token_chars
    jmp .loop
.done:
    ret

confirm_del_prompt:
    cmp byte [del_prompt], 0
    je .yes
    mov dx, del_confirm_msg
    call print_dollar
    mov si, del_path
    call print_asciiz
    mov dx, del_confirm_suffix
    call print_dollar
    mov ah, 0x08
    int 0x21
    push ax
    mov dx, crlf
    call print_dollar
    pop ax
    cmp al, 'Y'
    je .yes
    cmp al, 'y'
    je .yes
    stc
    ret
.yes:
    clc
    ret

del_path_has_wildcard:
    mov si, del_path
    jmp path_has_wildcard

path_has_wildcard:
.loop:
    lodsb
    test al, al
    jz .no
    cmp al, '*'
    je .yes
    cmp al, '?'
    je .yes
    jmp .loop
.yes:
    stc
    ret
.no:
    clc
    ret

do_ren:
    call parse_ren_args
    cmp byte [ren_arg_count], 2
    jb .missing
    ja .too_many
    call ren_paths_have_wildcard
    jc .wildcard
    call ren_dst_has_path
    jc .bad_dst
    push cs
    pop es
    mov dx, ren_src_path
    mov di, ren_dst_path
    mov ah, 0x56
    int 0x21
    jc .err
    ret
.missing:
    mov dx, missing_arg_msg
    call print_dollar
    ret
.too_many:
    mov dx, too_many_args_msg
    call print_dollar
    ret
.bad_dst:
    mov dx, invalid_dst_msg
    call print_dollar
    ret
.wildcard:
    mov dx, wildcard_not_supported_msg
    call print_dollar
    ret
.err:
    mov dx, file_error_msg
    call print_dollar
    ret

parse_ren_args:
    mov byte [ren_arg_count], 0
.loop:
    call skip_spaces
    cmp byte [si], 0
    je .done
    cmp byte [ren_arg_count], 0
    je .src
    cmp byte [ren_arg_count], 1
    je .dst
    mov byte [ren_arg_count], 3
    call skip_token_chars
    jmp .loop
.src:
    mov di, ren_src_path
    call copy_path_token
    inc byte [ren_arg_count]
    jmp .loop
.dst:
    mov di, ren_dst_path
    call copy_path_token
    inc byte [ren_arg_count]
    jmp .loop
.done:
    ret

ren_paths_have_wildcard:
    mov si, ren_src_path
    call path_has_wildcard
    jc .yes
    mov si, ren_dst_path
    call path_has_wildcard
    ret
.yes:
    stc
    ret

ren_dst_has_path:
    mov si, ren_dst_path
.loop:
    lodsb
    test al, al
    jz .no
    cmp al, ':'
    je .yes
    cmp al, '\'
    je .yes
    cmp al, '/'
    je .yes
    jmp .loop
.yes:
    stc
    ret
.no:
    clc
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
    call print_dollar
    ret
.open_err:
    mov dx, file_not_found_msg
    call print_dollar
    ret
.missing:
    mov dx, missing_arg_msg
    call print_dollar
    ret

do_cls:
    mov dl, 12
    call print_char_dl
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
    call print_dollar
.done:
    ret

do_rem:
    ret

do_goto:
    call skip_spaces
    cmp byte [si], 0
    je .done
    call batch_seek_label
.done:
    ret

do_if:
    call skip_spaces
    mov di, exist_arg
    call cmd_match
    jnc .done
    call skip_spaces
    mov di, if_path_buf
    xor cx, cx
.copy_path:
    mov al, [si]
    test al, al
    jz .done
    cmp al, ' '
    je .path_done
    cmp al, 9
    je .path_done
    cmp cx, 63
    jae .skip_path_store
    stosb
    inc cx
.skip_path_store:
    inc si
    jmp .copy_path
.path_done:
    xor al, al
    stosb
    call skip_spaces
    cmp byte [si], 0
    je .done
    push si
    mov dx, if_path_buf
    mov ax, 0x4300
    int 0x21
    pop si
    jc .done
    call if_tail_is_bare_label
    jc .goto_tail
    mov di, line_buf
.copy_tail:
    lodsb
    stosb
    test al, al
    jne .copy_tail
    mov si, line_buf
    call execute_line
    ret
.goto_tail:
    call batch_seek_label
.done:
    ret

if_tail_is_bare_label:
    cmp byte [batch_active], 0
    je .no
    push si
    mov di, goto_cmd
    call cmd_match
    pop si
    jc .no
    push si
    xor cx, cx
.scan:
    mov al, [si]
    test al, al
    jz .end
    cmp al, ' '
    je .no_pop
    cmp al, 9
    je .no_pop
    inc cx
    inc si
    jmp .scan
.end:
    pop si
    cmp cx, 0
    je .no
    stc
    ret
.no_pop:
    pop si
.no:
    clc
    ret

batch_seek_label:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    cmp byte [batch_active], 0
    je .done
    call copy_batch_label
    jc .done
    mov bx, [batch_handle]
    mov ax, 0x4200
    xor cx, cx
    xor dx, dx
    int 0x21
    jc .done
    mov word [batch_buf_pos], 0
    mov word [batch_buf_len], 0
.scan:
    call batch_read_line
    jc .done
    mov si, line_buf
    call skip_spaces
    cmp byte [si], ':'
    jne .scan
    inc si
    mov di, batch_label_buf
    call batch_label_match
    jnc .scan
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

copy_batch_label:
    mov di, batch_label_buf
    xor cx, cx
    cmp byte [si], ':'
    jne .copy
    inc si
.copy:
    mov al, [si]
    test al, al
    jz .end
    cmp al, ' '
    je .end
    cmp al, 9
    je .end
    cmp al, 13
    je .end
    cmp al, 10
    je .end
    cmp cx, 31
    jae .skip_store
    stosb
    inc cx
.skip_store:
    inc si
    jmp .copy
.end:
    xor al, al
    stosb
    cmp cx, 0
    je .empty
    clc
    ret
.empty:
    stc
    ret

batch_label_match:
.loop:
    mov al, [di]
    test al, al
    jz .end_label
    mov ah, [si]
    cmp al, 'a'
    jb .target_case_ok
    cmp al, 'z'
    ja .target_case_ok
    sub al, 32
.target_case_ok:
    cmp ah, 'a'
    jb .line_case_ok
    cmp ah, 'z'
    ja .line_case_ok
    sub ah, 32
.line_case_ok:
    cmp ah, al
    jne .no
    inc si
    inc di
    jmp .loop
.end_label:
    mov al, [si]
    test al, al
    jz .yes
    cmp al, ' '
    je .yes
    cmp al, 9
    je .yes
    cmp al, 13
    je .yes
    cmp al, 10
    je .yes
.no:
    clc
    ret
.yes:
    stc
    ret

do_pause:
    call parse_pause_args
    cmp byte [pause_quiet], 1
    je .no_prompt
    mov dx, pause_msg
    call print_dollar
    call wait_key
.no_prompt:
    ret

do_break:
    ret

do_mode:
    call parse_mode_args
    cmp byte [mode_co80], 1
    jne .done
    mov ax, 0x0003
    int 0x10
    cmp byte [mode_quiet], 1
    je .done
    call print_drive_root
    mov si, mode_status_msg
    call print_asciiz
.done:
    ret

do_more:
    call parse_more_args
    cmp byte [more_has_file], 0
    je .done
    cmp byte [more_quiet], 1
    je .done
    call more_display_file
.done:
    ret

parse_pause_args:
    mov al, [redir_to_nul]
    mov [pause_quiet], al
    mov si, line_buf
    call skip_command_prefix
    call skip_spaces
    call skip_shell_word
    jmp parse_pause_scan

parse_pause_scan:
.pause_scan_loop:
    call skip_spaces
    mov al, [si]
    test al, al
    jz .pause_done
    cmp al, 13
    je .pause_done
    cmp al, 10
    je .pause_done
    cmp al, '>'
    jne .pause_scan_advance
    inc si
    call skip_spaces
    push si
    mov di, nul_arg
    call cmd_match
    pop si
    jc .pause_set_quiet
    jmp .pause_done
.pause_scan_advance:
    inc si
    jmp .pause_scan_loop
.pause_set_quiet:
    mov byte [pause_quiet], 1
.pause_done:
    ret

parse_mode_args:
    mov byte [mode_co80], 0
    mov al, [redir_to_nul]
    mov [mode_quiet], al
    mov si, line_buf
    call skip_command_prefix
    call skip_spaces
    call skip_shell_word
    jmp parse_mode_scan

parse_mode_scan:
.mode_scan_loop:
    call skip_spaces
    mov al, [si]
    test al, al
    jz .mode_done
    cmp al, 13
    je .mode_done
    cmp al, 10
    je .mode_done
    cmp al, '>'
    jne .mode_scan_advance
    inc si
    call skip_spaces
    push si
    mov di, nul_arg
    call cmd_match
    pop si
    jc .mode_set_quiet
    jmp .mode_done
.mode_scan_advance:
    push si
    mov di, co80_arg
    call cmd_match
    pop si
    jc .mode_set_co80
    inc si
    jmp .mode_scan_loop
.mode_set_co80:
    mov byte [mode_co80], 1
    call skip_shell_word
    jmp .mode_scan_loop
.mode_set_quiet:
    mov byte [mode_quiet], 1
.mode_done:
    ret

parse_more_args:
    mov byte [more_has_file], 0
    mov al, [redir_to_nul]
    mov [more_quiet], al
    mov si, line_buf
    call skip_command_prefix
    call skip_spaces
    call skip_shell_word
    jmp parse_more_scan

parse_more_scan:
.more_scan_loop:
    call skip_spaces
    mov al, [si]
    test al, al
    jz .more_done
    cmp al, 13
    je .more_done
    cmp al, 10
    je .more_done
    cmp al, '<'
    jne .more_scan_redir
    inc si
    call skip_spaces
    call copy_more_filename
    mov byte [more_has_file], 1
    jmp .more_scan_loop
.more_scan_redir:
    cmp al, '>'
    jne .more_scan_advance
    inc si
    call skip_spaces
    push si
    mov di, nul_arg
    call cmd_match
    pop si
    jc .more_scan_set_quiet
    jmp .more_done
.more_scan_set_quiet:
    mov byte [more_quiet], 1
    jmp .more_done
.more_scan_advance:
    inc si
    jmp .more_scan_loop
.more_done:
    ret

skip_shell_word:
.skip_shell_word_loop:
    mov al, [si]
    test al, al
    jz .skip_shell_word_done
    cmp al, ' '
    je .skip_shell_word_done
    cmp al, 9
    je .skip_shell_word_done
    cmp al, 13
    je .skip_shell_word_done
    cmp al, 10
    je .skip_shell_word_done
    cmp al, '>'
    je .skip_shell_word_done
    cmp al, '<'
    je .skip_shell_word_done
    cmp al, '|'
    je .skip_shell_word_done
    inc si
    jmp .skip_shell_word_loop
.skip_shell_word_done:
    ret

copy_more_filename:
    push si
    push di
    mov di, more_path_buf
.cp_loop:
    lodsb
    test al, al
    jz .cp_done
    cmp al, ' '
    je .cp_done
    cmp al, 9
    je .cp_done
    cmp al, 13
    je .cp_done
    cmp al, 10
    je .cp_done
    cmp al, '<'
    je .cp_done
    cmp al, '>'
    je .cp_done
    cmp al, '|'
    je .cp_done
    stosb
    jmp .cp_loop
.cp_done:
    xor al, al
    stosb
    pop di
    pop si
    ret

more_display_file:
    push si
    push bx
    push cx
    push dx
    push ds
    push cs
    pop ds
    mov dx, more_path_buf
    mov ax, 0x3D00
    int 0x21
    jc .open_err
    mov [more_handle], ax
    mov word [more_line_count], 0
.read_loop:
    mov bx, [more_handle]
    mov dx, more_buf
    mov cx, more_buf_size
    mov ah, 0x3F
    int 0x21
    jc .read_err
    cmp ax, 0
    je .cleanup
    mov [more_bytes], ax
    mov word [more_pos], 0
    call more_pump
    cmp ax, 0
    jne .cleanup
    jmp .read_loop
.open_err:
    mov dx, more_open_err_msg
    call print_dollar
    jmp .cleanup
.read_err:
    mov dx, file_error_msg
    call print_dollar
.cleanup:
    cmp word [more_handle], 0
    je .skip_close
    mov bx, [more_handle]
    push ax
    mov ah, 0x3E
    int 0x21
    pop ax
    mov word [more_handle], 0
.skip_close:
    pop ds
    pop dx
    pop cx
    pop bx
    pop si
    ret

more_pump:
    push si
    push bx
    push cx
    push di
    push word [more_bytes]
    pop ax
    sub ax, [more_pos]
    jle .done
    mov si, [more_pos]
    mov bx, more_buf
    add bx, si
    mov cx, [more_bytes]
    sub cx, si
    jle .done
.more_line:
    cmp cx, 0
    jle .done
    mov al, [bx]
    cmp al, 13
    je .emit_cr
    cmp al, 10
    je .emit_lf_current
    mov dl, al
    call print_char_dl
    inc si
    inc bx
    dec cx
    jmp .more_line
.emit_cr:
    inc si
    inc bx
    dec cx
    mov dl, 13
    call print_char_dl
    jmp .more_line_check_lf
.more_line_check_lf:
    cmp cx, 0
    jle .emit_cr_line
    mov al, [bx]
    cmp al, 10
    jne .emit_cr_line
    inc si
    inc bx
    dec cx
    jmp .emit_lf
.emit_lf_current:
    inc si
    inc bx
    dec cx
.emit_lf:
    mov dl, 10
    call print_char_dl
    jmp .count_line
.emit_cr_line:
.count_line:
    inc word [more_line_count]
    mov ax, [more_line_count]
    cmp ax, [more_lines_per_page]
    jl .more_line
    mov word [more_line_count], 0
.check_more:
    push si
    push bx
    push cx
    call more_check_pause
    pop cx
    pop bx
    pop si
    cmp ax, 0
    jne .abort
    mov cx, [more_bytes]
    sub cx, si
    jg .more_line
.done:
    mov [more_pos], si
    mov ax, 0
    jmp .restore
.abort:
    mov [more_pos], si
    mov ax, 1
.restore:
    pop di
    pop cx
    pop bx
    pop si
    ret

more_check_pause:
    push bx
    push cx
    push dx
    mov dx, more_pause_msg
    call print_dollar
.more_pause:
    mov ah, 0x00
    int 0x16
    cmp al, 13
    je .more_resume
    cmp al, 3
    jne .more_pause
.more_resume:
    cmp al, 13
    je .more_emit_nl
    mov dx, crlf
    call print_dollar
    pop dx
    pop cx
    pop bx
    mov ax, 1
    ret
.more_emit_nl:
    mov dx, crlf
    call print_dollar
.more_done_pause:
    pop dx
    pop cx
    pop bx
    xor ax, ax
    ret

wait_key:
    mov ah, 0x00
    int 0x16
    ret

change_drive_command:
    push ax
    push dx
    push si
    mov al, [si]
    cmp al, 'a'
    jb .drive_case_ok
    cmp al, 'z'
    ja .drive_case_ok
    sub al, 32
.drive_case_ok:
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
    call print_dollar
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
    call print_dollar
    ret

print_drive_root:
    mov ah, 0x19
    int 0x21
    add al, 'A'
    mov dl, al
    call print_char_dl
    mov dx, prompt_drive
    call print_dollar
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

run_command_tail:
    push cs
    pop ds
    mov cl, [0x80]
    test cl, cl
    jz .none
    cmp cl, 127
    jbe .copy_len_ok
    mov cl, 127
.copy_len_ok:
    xor ch, ch
    mov si, 0x81
    mov di, line_buf
    rep movsb
    xor al, al
    stosb
    mov si, line_buf
    call skip_spaces
    cmp byte [si], '/'
    jne .none
    inc si
    cmp byte [si], 'C'
    je .run_once
    cmp byte [si], 'c'
    jne .none
.run_once:
    inc si
    mov al, [si]
    test al, al
    jz .run
    cmp al, ' '
    jne .none
    call skip_spaces
.run:
    mov di, line_buf
.move_command:
    lodsb
    stosb
    test al, al
    jnz .move_command
    call execute_line
    stc
    ret
.none:
    clc
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
    call print_dollar
    ret

command_ext_is_bat:
    push ax
    push si
    mov si, [command_ext_off]
    mov al, [si]
    and al, 0xDF
    cmp al, 'B'
    jne .no
    mov al, [si+1]
    and al, 0xDF
    cmp al, 'A'
    jne .no
    mov al, [si+2]
    and al, 0xDF
    cmp al, 'T'
    jne .no
    cmp byte [si+3], 0
    jne .no
    pop si
    pop ax
    stc
    ret
.no:
    pop si
    pop ax
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
    mov byte [cmd_tail], 0
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
    je .start
    call batch_sync_position
    jc .sync_err
.start:
    call batch_snapshot_args
    inc byte [batch_active]
    push word [batch_handle]
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc .open_err
    mov [batch_handle], ax
    mov word [batch_buf_pos], 0
    mov word [batch_buf_len], 0
    push cs
    pop ds
.next:
    call batch_read_line
    jc .done
    call batch_expand_params
    cmp byte [line_buf], 0
    je .next
    call execute_line
    push cs
    pop ds
    jmp .next
.done:
    mov bx, [batch_handle]
    mov ah, 0x3E
    int 0x21
    pop word [batch_handle]
    mov word [batch_buf_pos], 0
    mov word [batch_buf_len], 0
    dec byte [batch_active]
    clc
    ret
.open_err:
    pop word [batch_handle]
    mov word [batch_buf_pos], 0
    mov word [batch_buf_len], 0
    dec byte [batch_active]
    stc
    ret
.sync_err:
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
    push cs
    pop ds
    clc
    ret

find_path_value:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    push cs
    pop ds
    mov word [path_env_seg], 0
    mov word [path_ptr], 0
    mov ah, 0x62
    int 0x21
    jc .not_found
    mov es, bx
    mov ax, [es:0x2C]
    test ax, ax
    jz .not_found
    mov es, ax
    xor di, di
.entry:
    mov al, [es:di]
    test al, al
    jz .not_found
    push di
    mov si, path_env_name
.cmp:
    mov al, [cs:si]
    test al, al
    jz .found
    cmp al, [es:di]
    jne .skip
    inc si
    inc di
    jmp .cmp
.skip:
    pop di
.skip_loop:
    mov al, [es:di]
    inc di
    test al, al
    jne .skip_loop
    jmp .entry
.found:
    pop ax
    mov [path_env_seg], es
    mov [path_ptr], di
    clc
    jmp .done
.not_found:
    stc
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

build_path_candidate:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    push cs
    pop ds
    mov ax, [path_env_seg]
    test ax, ax
    jz .err
    mov es, ax
.next_element:
    mov si, [path_ptr]
    cmp byte [es:si], 0
    je .err
    mov di, path_command_name
    mov byte [path_last_char], 0
    mov byte [path_more], 0
    xor bx, bx
.copy_elem:
    mov al, [es:si]
    cmp al, ';'
    je .end_elem
    test al, al
    jz .end_elem_zero
    cmp di, path_command_name + 126
    jae .err
    mov [di], al
    mov [path_last_char], al
    inc di
    inc si
    inc bx
    jmp .copy_elem
.end_elem:
    inc si
    mov byte [path_more], 1
    jmp .finish_element
.end_elem_zero:
    mov byte [path_more], 0
.finish_element:
    mov [path_ptr], si
    cmp bx, 0
    jne .have_element
    cmp byte [path_more], 0
    jne .next_element
    jmp .err
.have_element:
    mov al, [path_last_char]
    cmp al, '\'
    je .copy_name
    cmp al, '/'
    je .copy_name
    cmp al, ':'
    je .copy_name
    cmp di, path_command_name + 126
    jae .err
    mov al, '\'
    mov [di], al
    inc di
.copy_name:
    mov si, command_name
.name_loop:
    lodsb
    test al, al
    jz .store_name_char
    cmp di, path_command_name + 127
    jae .err
.store_name_char:
    cmp di, path_command_name + 128
    jae .err
    mov [di], al
    inc di
    test al, al
    jne .name_loop
    clc
    jmp .done
.err:
    stc
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

run_candidate_exec:
    mov dx, path_command_name
    call run_exec_name
    ret

batch_snapshot_args:
    push ax
    push cx
    push si
    push di
    mov si, cmd_tail + 1
    xor cx, cx
    mov cl, [cmd_tail]
    mov di, batch_args
.copy:
    jcxz .done
    lodsb
    cmp al, 13
    je .done
    stosb
    dec cx
    jmp .copy
.done:
    xor al, al
    stosb
    pop di
    pop si
    pop cx
    pop ax
    ret

batch_expand_params:
    push ax
    push bx
    push cx
    push si
    push di
    mov si, line_buf
.scan:
    lodsb
    test al, al
    jz .out
    cmp al, '%'
    jne .scan
    mov si, line_buf
    mov di, batch_raw
    mov cx, 128
    rep movsb
    mov si, batch_raw
    mov di, line_buf
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, '%'
    jne .emit
    mov al, [si]
    cmp al, '%'
    je .pct
    cmp al, '0'
    jb .lit
    cmp al, '9'
    ja .lit
    inc si
    sub al, '0'
    call batch_emit_arg
    jmp .loop
.pct:
    inc si
    mov al, '%'
    jmp .emit
.lit:
    mov al, '%'
.emit:
    cmp di, line_buf + 127
    jae .done
    stosb
    jmp .loop
.done:
    xor al, al
    stosb
.out:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

batch_emit_arg:
    push si
    test al, al
    jz .end
    mov bl, al
    mov si, batch_args
.next_word:
    cmp byte [si], ' '
    jne .word_start
    inc si
    jmp .next_word
.word_start:
    cmp byte [si], 0
    je .end
    dec bl
    jz .copy_word
.skip_word:
    mov al, [si]
    test al, al
    jz .end
    cmp al, ' '
    je .next_word
    inc si
    jmp .skip_word
.copy_word:
    mov al, [si]
    test al, al
    jz .end
    cmp al, ' '
    je .end
    cmp di, line_buf + 127
    jae .end
    mov [di], al
    inc di
    inc si
    jmp .copy_word
.end:
    pop si
    ret

batch_read_line:
    push cx
    push di
.skip_eol:
    call batch_read_char
    jc .eof
    cmp al, 13
    je .skip_eol
    cmp al, 10
    je .skip_eol
    push ds
    pop es
    mov di, line_buf
    xor cx, cx
.copy:
    cmp cx, 127
    jae .read_next
    stosb
    inc cx
.read_next:
    call batch_read_char
    jc .end
    cmp al, 13
    je .end
    cmp al, 10
    je .end
    jmp .copy
.end:
    xor al, al
    stosb
    pop di
    pop cx
    clc
    ret
.eof:
    pop di
    pop cx
    stc
    ret

batch_read_char:
    push bx
    push cx
    push dx
    mov bx, [batch_buf_pos]
    cmp bx, [batch_buf_len]
    jb .have_char
    mov bx, [batch_handle]
    mov dx, batch_buf
    mov cx, batch_buf_size
    mov ah, 0x3F
    int 0x21
    jc .eof
    test ax, ax
    jz .eof
    mov [batch_buf_len], ax
    mov word [batch_buf_pos], 0
    xor bx, bx
.have_char:
    mov al, [batch_buf+bx]
    inc word [batch_buf_pos]
    pop dx
    pop cx
    pop bx
    clc
    ret
.eof:
    pop dx
    pop cx
    pop bx
    stc
    ret

batch_sync_position:
    push ax
    push bx
    push cx
    push dx
    mov ax, [batch_buf_len]
    sub ax, [batch_buf_pos]
    jbe .clear
    mov dx, ax
    neg dx
    mov cx, 0xFFFF
    mov bx, [batch_handle]
    mov ax, 0x4201
    int 0x21
    jc .err
.clear:
    mov word [batch_buf_pos], 0
    mov word [batch_buf_len], 0
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err:
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

print_asciiz:
.loop:
    lodsb
    test al, al
    jz .done
    mov dl, al
    call print_char_dl
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
    jz .end_cmd
    mov ah, [si]
    cmp ah, 'a'
    jb .cmp_char
    cmp ah, 'z'
    ja .cmp_char
    sub ah, 32
.cmp_char:
    cmp ah, al
    jne .no
    inc si
    inc di
    jmp .loop
.end_cmd:
    mov al, [si]
    test al, al
    jz .yes
    cmp al, ' '
    je .arg_spaces
    cmp al, '/'
    je .yes
    cmp al, '\'
    je .yes
    cmp al, 13
    je .yes
    cmp al, 10
    je .yes
    cmp al, '>'
    je .yes
    cmp al, '<'
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
wildcard_not_supported_msg: db "Wildcard not supported", 13, 10, "$"
resize_fail_msg: db "Shell resize failed", 13, 10, "$"
exit_cmd: db "EXIT", 0
ver_cmd: db "VER", 0
dir_cmd: db "DIR", 0
cd_cmd: db "CD", 0
cd_parent_cmd: db "CD..", 0
chdir_cmd: db "CHDIR", 0
md_cmd: db "MD", 0
mkdir_cmd: db "MKDIR", 0
rd_cmd: db "RD", 0
rmdir_cmd: db "RMDIR", 0
copy_cmd: db "COPY", 0
del_cmd: db "DEL", 0
erase_cmd: db "ERASE", 0
ren_cmd: db "REN", 0
rename_cmd: db "RENAME", 0
type_cmd: db "TYPE", 0
cls_cmd: db "CLS", 0
echo_cmd: db "ECHO", 0
rem_cmd: db "REM", 0
if_cmd: db "IF", 0
goto_cmd: db "GOTO", 0
pause_cmd: db "PAUSE", 0
break_cmd: db "BREAK", 0
mode_cmd: db "MODE", 0
more_cmd: db "MORE", 0
parent_arg: db "..", 0
shell_int23:
    iret

command_table:
    dw exit_cmd, exit_shell
    dw ver_cmd, do_ver
    dw dir_cmd, do_dir
    dw cd_cmd, do_cd
    dw cd_parent_cmd, do_cd_parent
    dw chdir_cmd, do_cd
    dw md_cmd, do_md
    dw mkdir_cmd, do_md
    dw rd_cmd, do_rd
    dw rmdir_cmd, do_rd
    dw copy_cmd, do_copy
    dw del_cmd, do_del
    dw erase_cmd, do_del
    dw ren_cmd, do_ren
    dw rename_cmd, do_ren
    dw type_cmd, do_type
    dw cls_cmd, do_cls
    dw echo_cmd, do_echo
    dw rem_cmd, do_rem
    dw if_cmd, do_if
    dw goto_cmd, do_goto
    dw pause_cmd, do_pause
    dw break_cmd, do_break
    dw mode_cmd, do_mode
    dw more_cmd, do_more
    dw 0, 0
echo_off_arg: db "OFF", 0
echo_on_arg: db "ON", 0
exist_arg: db "EXIST", 0
nul_arg: db "NUL", 0
stdout_char: db 0
redir_saved: dw 0
redir_to_nul: db 0
redir_append: db 0
redir_path: times 64 db 0
copy_src_base: dw 0
del_base: dw 0
copy_dta: times 64 db 0
batch_args: times 128 db 0
batch_raw: times 128 db 0
co80_arg: db "CO80", 0
pause_msg: db "Press any key to continue . . .", 13, 10, "$"
mode_status_msg: db " is the current mode", 13, 10, 0
more_pause_msg: db "-- More --", "$"
more_open_err_msg: db "File not found", 13, 10, "$"
pause_quiet: db 0
mode_co80: db 0
mode_quiet: db 0
more_has_file: db 0
more_quiet: db 0
if_path_buf: times 64 db 0
batch_label_buf: times 32 db 0
more_path_buf: times 64 db 0
more_handle: dw 0
more_bytes: dw 0
more_pos: dw 0
more_line_count: dw 0
more_lines_per_page: dw 24
more_buf_size equ 4096
more_buf: times more_buf_size db 0
autoexec_name: db "AUTOEXEC.BAT", 0
dir_default_pattern: db "*.*", 0
dir_volume_msg: db " Volume in drive ", "$"
dir_no_label_msg: db " has no label", "$"
dir_of_msg: db " Directory of ", "$"
dir_dir_field: db "     <DIR>", "$"
dir_file_count_msg: db " File(s) ", "$"
dir_bytes_msg: db " bytes", "$"
dir_free_msg: db " bytes free", "$"
dir_pause_msg: db "Press any key to continue . . .", "$"
copy_success_msg: db "        1 File(s) copied.", 13, 10, "$"
copy_not_copied_msg: db "File not copied.", 13, 10, "$"
copy_overwrite_msg: db "Overwrite ", "$"
copy_overwrite_suffix: db "? (Y/N)", "$"
del_confirm_msg: db "Delete ", "$"
del_confirm_suffix: db "? (Y/N)", "$"
del_not_deleted_msg: db "File not deleted.", 13, 10, "$"
invalid_dst_msg: db "Invalid destination", 13, 10, "$"
too_many_args_msg: db "Too many arguments", 13, 10, "$"
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
dir_pattern_size equ 80
dir_header_path_size equ 64
dir_wide_columns equ 5
dir_wide_width equ 15
copy_path_size equ 80
type_buf_size equ 128
batch_buf_size equ 512

line_buf: times 128 db 0
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
copy_src_path: times copy_path_size db 0
copy_dst_path: times copy_path_size db 0
copy_dst_final: times copy_path_size db 0
del_path: times copy_path_size db 0
ren_src_path: times copy_path_size db 0
ren_dst_path: times copy_path_size db 0
copy_yes: db 0
copy_arg_count: db 0
del_prompt: db 0
del_has_arg: db 0
ren_arg_count: db 0
copy_src_handle: dw 0
copy_dst_handle: dw 0
copy_io_count: dw 0
dir_pattern: times dir_pattern_size db 0
dir_header_path: times dir_header_path_size db 0
dir_pause: db 0
dir_wide: db 0
dir_has_operand: db 0
dir_wide_cols: db 0
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
batch_active: db 0
batch_buf_pos: dw 0
batch_buf_len: dw 0
batch_buf: times batch_buf_size db 0
shell_stack: times 1024 db 0
shell_stack_top:
shell_resident_end:
shell_resident_paras equ ((shell_resident_end - start + 0x100 + 15) / 16)
