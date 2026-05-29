%macro INT21_POP_FRAME_DS_SI_ES_DI_BX 0
    pop bx
    pop di
    pop es
    pop si
    pop ds
%endmacro

%macro INT21_POP_FRAME_DS_SI_ES_DI_BX_CX 0
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
%endmacro

%macro INT21_POP_FRAME_DS_SI_ES_DI_BX_CX_DX 0
    pop dx
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
%endmacro

%macro INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI 0
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
%endmacro

%macro INT21_POP_FRAME_BX_CX_DX_DS_ES_SI_DI 0
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
%endmacro

%macro INT21_POP_FRAME_BX_CX_DX_ES_DI_DS_SI 0
    pop si
    pop ds
    pop di
    pop es
    pop dx
    pop cx
    pop bx
%endmacro

%macro INT21_POP_FRAME_DS_SI_ES_DI_CX 0
    pop cx
    pop di
    pop es
    pop si
    pop ds
%endmacro

%macro INT21_POP_FRAME_DS_SI_ES_DI_DX_CX 0
    pop cx
    pop dx
    pop di
    pop es
    pop si
    pop ds
%endmacro

%macro INT21_POP_FRAME_DS_SI_CX_BX_ES_DI 0
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
%endmacro

%macro INT21_POP_EXEC_PROGRAM_FRAME 0
    pop ax
    mov [cs:saved_sp], ax
    pop ax
    mov [cs:saved_ss], ax
    pop ax
    mov [cs:dta_off], ax
    pop ax
    mov [cs:dta_seg], ax
    pop ax
    mov [cs:cur_psp], ax
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
%endmacro

int21_handler:
    cld
    cmp ah, 0x4C
    je .terminate
    cmp ah, 0x09
    je .print_string
    cmp ah, 0x01
    je .read_char_echo
    cmp ah, 0x02
    je .print_char
    cmp ah, 0x06
    je .direct_console_io
    cmp ah, 0x07
    je .read_char_direct
    cmp ah, 0x08
    je .read_char_no_echo
    cmp ah, 0x0A
    je .read_line_buffered
    cmp ah, 0x0B
    je .stdin_status
    cmp ah, 0x0C
    je .flush_and_read
    cmp ah, 0x0E
    je .select_disk
    cmp ah, 0x00
    je .terminate
    cmp ah, 0x39
    je .make_dir
    cmp ah, 0x3A
    je .remove_dir
    cmp ah, 0x3B
    je .chdir
    cmp ah, 0x3C
    je .create_file
    cmp ah, 0x3D
    je .open_file
    cmp ah, 0x3E
    je .close_file
    cmp ah, 0x3F
    je .read_file
    cmp ah, 0x40
    je .write_file
    cmp ah, 0x41
    je .delete_file
    cmp ah, 0x42
    je .seek_file
    cmp ah, 0x43
    je .file_attrs
    cmp ah, 0x44
    je .ioctl
    cmp ah, 0x45
    je .duplicate_handle
    cmp ah, 0x46
    je .force_duplicate_handle
    cmp ah, 0x47
    je .get_curdir
    cmp ah, 0x48
    je .alloc_mem
    cmp ah, 0x49
    je .free_mem
    cmp ah, 0x4A
    je .resize_mem
    cmp ah, 0x4B
    je .exec
    cmp ah, 0x4D
    je .get_return_code
    cmp ah, 0x19
    je .get_drive
    cmp ah, 0x1A
    je .set_dta
    cmp ah, 0x1B
    je near .get_default_drive_data
    cmp ah, 0x1C
    je near .get_drive_data
    cmp ah, 0x25
    je .set_vector
    cmp ah, 0x29
    je .parse_fcb
    cmp ah, 0x2A
    je .get_date
    cmp ah, 0x2B
    je near .set_date
    cmp ah, 0x2C
    je .get_time
    cmp ah, 0x2D
    je near .set_time
    cmp ah, 0x2E
    je near .set_verify_flag
    cmp ah, 0x2F
    je .get_dta
    cmp ah, 0x30
    je .get_version
    cmp ah, 0x33
    je .break_check
    cmp ah, 0x35
    je .get_vector
    cmp ah, 0x36
    je .get_disk_free
    cmp ah, 0x38
    je .country_info
    cmp ah, 0x4E
    je .find_first
    cmp ah, 0x4F
    je .find_next
    cmp ah, 0x52
    je .get_list_of_lists
    cmp ah, 0x54
    je near .get_verify_flag
    cmp ah, 0x56
    je .rename_file
    cmp ah, 0x57
    je .file_time
    cmp ah, 0x58
    je .alloc_strategy
    cmp ah, 0x5A
    je .create_temp_file
    cmp ah, 0x5B
    je .create_new_file
    cmp ah, 0x62
    je .get_psp
    cmp ah, 0x67
    je .set_handle_count
    cmp ah, 0x68
    je .commit_file
    mov [cs:log_ax], ax
    mov [cs:log_bx], bx
    mov [cs:log_cx], cx
    mov [cs:log_dx], dx
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_unhandled
    call serial_print
    mov al, ah
    call serial_print_hex
    mov si, msg_reg_ax
    call serial_print
    mov ax, [cs:log_ax]
    call serial_print_hex_word
    mov si, msg_reg_bx
    call serial_print
    mov ax, [cs:log_bx]
    call serial_print_hex_word
    mov si, msg_reg_cx
    call serial_print
    mov ax, [cs:log_cx]
    call serial_print_hex_word
    mov si, msg_reg_dx
    call serial_print
    mov ax, [cs:log_dx]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
    mov ax, 1
    jmp iret_cy
.terminate:
    mov [cs:ret_code], al
    jmp do_terminate
.print_string:
    push ds
    push si
    push dx
    push ax
    mov si, dx
.lp:
    lodsb
    cmp al, '$'
    je .dn
    call console_putchar
    jmp .lp
.dn:
    pop ax
    pop dx
    pop si
    pop ds
    jmp iret_nc
.print_char:
    push ax
    mov al, dl
    call console_putchar
    pop ax
    mov al, dl
    jmp iret_nc
.read_char_echo:
    push bx
    push cx
    push dx
    call console_read_char
    jc .read_char_echo_no_echo
    mov dl, al
    call console_putchar
.read_char_echo_no_echo:
    mov ah, 0x01
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.direct_console_io:
    cmp dl, 0xFF
    je .direct_console_input
    push ax
    mov al, dl
    call console_putchar
    pop ax
    mov al, dl
    jmp iret_nc
.direct_console_input:
    push bx
    push cx
    push dx
    call console_input_status
    test al, al
    jz .direct_console_empty
    call console_read_char
    mov ah, 0x06
    pop dx
    pop cx
    pop bx
    jmp iret_nc_nz
.direct_console_empty:
    mov ax, 0x0600
    pop dx
    pop cx
    pop bx
    jmp iret_nc_zf
.read_char_direct:
    push bx
    push cx
    push dx
    call console_read_char
    mov ah, 0x07
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.read_char_no_echo:
    push bx
    push cx
    push dx
    call console_read_char
    mov ah, 0x08
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.read_line_buffered:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov byte [cs:console_ext_pending], 0
    mov si, dx
    xor cx, cx
    mov cl, [si]
    mov byte [si+1], 0
    test cl, cl
    jz .rl_done
    dec cl
    xor bx, bx
    mov di, si
    add di, 2
.rl_loop:
    xor ah, ah
    int 0x16
    test al, al
    jz .rl_loop
    cmp al, 13
    je .rl_enter
    cmp al, 8
    je .rl_backspace
    cmp bl, cl
    jae .rl_loop
    mov [di], al
    inc di
    inc bl
    call console_putchar
    jmp .rl_loop
.rl_backspace:
    test bl, bl
    jz .rl_loop
    dec di
    dec bl
    mov al, 8
    call console_putchar
    mov al, ' '
    call console_putchar
    mov al, 8
    call console_putchar
    jmp .rl_loop
.rl_enter:
    mov byte [di], 13
    mov [si+1], bl
    mov al, 13
    call console_putchar
    mov al, 10
    call console_putchar
.rl_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    jmp iret_nc
.stdin_status:
    push bx
    push cx
    push dx
    call console_input_status
    test al, al
    jz .stdin_empty
    mov ax, 0x0BFF
    jmp .stdin_done
.stdin_empty:
    mov ax, 0x0B00
.stdin_done:
    cmp word [cs:trace_left], 0
    je .stdin_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_stdin
    call serial_print
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.stdin_no_trace:
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.flush_and_read:
    call console_flush_input
    cmp al, 0x01
    je .flush_read_char_echo
    cmp al, 0x06
    je .flush_direct_console_io
    cmp al, 0x07
    je .flush_read_char_direct
    cmp al, 0x08
    je .flush_read_char_no_echo
    cmp al, 0x0A
    je .flush_read_line_buffered
    jmp iret_nc
.flush_read_char_echo:
    mov ah, 0x01
    jmp .read_char_echo
.flush_direct_console_io:
    mov ah, 0x06
    jmp .direct_console_io
.flush_read_char_direct:
    mov ah, 0x07
    jmp .read_char_direct
.flush_read_char_no_echo:
    mov ah, 0x08
    jmp .read_char_no_echo
.flush_read_line_buffered:
    mov ah, 0x0A
    jmp .read_line_buffered
.get_drive:
    mov al, [cs:dos_drive_num]
    jmp iret_nc
.select_disk:
    mov al, [cs:dos_drive_count]
    cmp dl, al
    jae .select_disk_return
    mov [cs:dos_drive_num], dl
    mov al, 'A'
    add al, dl
    mov [cs:dos_drive_letter], al
.select_disk_return:
    mov al, [cs:dos_drive_count]
    jmp iret_nc
.get_default_drive_data:
    xor dl, dl
.get_drive_data:
    test dl, dl
    jz .gdd_valid_drive
    mov al, [cs:dos_drive_count]
    cmp dl, al
    jbe .gdd_valid_drive
    mov al, 0xFF
    jmp iret_nc
.gdd_valid_drive:
    push cs
    pop ds
    mov bx, bpb_copy+21
    xor ax, ax
    mov al, [cs:kspc]
    mov cx, [cs:bpb_copy+11]
    mov dx, [cs:kmax_cluster]
    sub dx, 2
    jmp iret_nc
.set_dta:
    mov [cs:dta_off], dx
    mov [cs:dta_seg], ds
    jmp iret_nc
.get_dta:
    mov bx, [cs:dta_off]
    mov es, [cs:dta_seg]
    jmp iret_nc
.set_vector:
    cmp word [cs:trace_left], 0
    je .sv_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_setvec
    call serial_print
    call serial_print_hex
    mov si, msg_trace_eq
    call serial_print
    pop ax
    push ax
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, dx
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.sv_no_trace:
    push ds
    push bx
    push ax
    push ds
    mov bl, al
    xor bh, bh
    xor ax, ax
    cli
    mov ds, ax
    shl bx, 2
    mov [bx], dx
    pop ax
    mov [bx+2], ax
    sti
    pop ax
    pop bx
    pop ds
    jmp iret_nc
.get_version:
    mov ax, 0x1E03
    mov bx, 0x0000
    mov cx, 0x0000
    jmp iret_nc
.get_vector:
    push ax
    push si
    mov bl, al
    xor bh, bh
    xor ax, ax
    mov es, ax
    shl bx, 2
    mov si, [es:bx]
    mov bx, [es:bx+2]
    mov es, bx
    mov bx, si
    pop si
    pop ax
    cmp word [cs:trace_left], 0
    je .gv_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push es
    push cs
    pop ds
    mov si, msg_trace_getvec
    call serial_print
    call serial_print_hex
    mov si, msg_trace_ret
    call serial_print
    mov ax, es
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, bx
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop es
    pop ds
    popa
.gv_no_trace:
    jmp iret_nc
.get_disk_free:
    test dl, dl
    jz .gdf_valid_drive
    mov al, [cs:dos_drive_count]
    cmp dl, al
    jbe .gdf_valid_drive
    mov ax, 0xFFFF
    jmp iret_nc
.gdf_valid_drive:
    push si
    xor bx, bx
    mov si, 2
.gdf_loop:
    cmp si, [cs:kmax_cluster]
    jae .gdf_done
    call fat_next
    test ax, ax
    jnz .gdf_next
    inc bx
.gdf_next:
    inc si
    jmp .gdf_loop
.gdf_done:
    xor ax, ax
    mov al, [cs:kspc]
    mov dx, [cs:kmax_cluster]
    sub dx, 2
    mov cx, [cs:bpb_copy+11]
    pop si
    jmp iret_nc
.country_info:
    cmp al, 0xFF
    je .ci_set
    cmp al, 0
    je .ci_get
    cmp al, 1
    je .ci_get
    mov ax, 2
    jmp iret_cy
.ci_get:
    push cx
    push dx
    push si
    push di
    push ds
    push es
    push ds
    pop es
    mov di, dx
    push cs
    pop ds
    mov si, country_data
    mov cx, 17
    cld
    rep movsw
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    mov bx, 1
    jmp iret_nc
.ci_set:
    cmp bx, 1
    je .ci_set_ok
    mov ax, 2
    jmp iret_cy
.ci_set_ok:
    jmp iret_nc
.get_psp:
    mov bx, [cs:cur_psp]
    jmp iret_nc
.get_list_of_lists:
    push cs
    pop es
    mov bx, dos_list_of_lists
    jmp iret_nc
.parse_fcb:
    push bx
    push cx
    push dx
    push di
    push bp
    mov bp, di
    mov dl, al
    xor dh, dh
    test dl, 0x02
    jnz .pf_init_name
    mov byte [es:bp], 0
.pf_init_name:
    test dl, 0x04
    jnz .pf_init_ext
    mov di, bp
    inc di
    mov cx, 8
    mov al, ' '
    rep stosb
.pf_init_ext:
    test dl, 0x08
    jnz .pf_after_init
    mov di, bp
    add di, 9
    mov cx, 3
    mov al, ' '
    rep stosb
.pf_after_init:
    test dl, 0x01
    jz .pf_scan_start
.pf_skip:
    mov al, [ds:si]
    call .pf_is_separator
    jnc .pf_scan_start
.pf_skip_one:
    inc si
    jmp .pf_skip
.pf_scan_start:
    mov al, [ds:si]
    call .pf_is_end
    jc .pf_done
    mov al, [ds:si+1]
    cmp al, ':'
    jne .pf_parse_name
    mov al, [ds:si]
    call ascii_upper
    cmp al, 'A'
    jb .pf_bad_drive
    cmp al, 'Z'
    ja .pf_bad_drive
    sub al, 'A' - 1
    mov [es:bp], al
    add si, 2
    test dl, 0x01
    jz .pf_parse_name
.pf_drive_skip:
    mov al, [ds:si]
    call .pf_is_separator
    jnc .pf_parse_name
    inc si
    jmp .pf_drive_skip
.pf_parse_name:
    mov al, [ds:si]
    call .pf_is_end
    jc .pf_done
    cmp al, '.'
    je .pf_dot
    call .pf_is_separator
    jc .pf_done
    mov di, bp
    inc di
    mov cx, 8
    mov al, ' '
    push di
    rep stosb
    pop di
    mov cx, 8
.pf_name_loop:
    mov al, [ds:si]
    call .pf_is_end
    jc .pf_done
    cmp al, '.'
    je .pf_dot
    call .pf_is_separator
    jc .pf_done
    cmp al, '*'
    je .pf_name_star
    cmp al, '?'
    je .pf_name_question
    cmp cx, 0
    je .pf_name_advance
    call ascii_upper
    mov [es:di], al
    inc di
    dec cx
    inc si
    jmp .pf_name_loop
.pf_name_question:
    mov dh, 1
    cmp cx, 0
    je .pf_name_advance
    mov byte [es:di], '?'
    inc di
    dec cx
.pf_name_advance:
    inc si
    jmp .pf_name_loop
.pf_name_star:
    mov dh, 1
    mov al, '?'
    rep stosb
    inc si
.pf_name_star_skip:
    mov al, [ds:si]
    call .pf_is_end
    jc .pf_done
    cmp al, '.'
    je .pf_dot
    call .pf_is_separator
    jc .pf_done
    inc si
    jmp .pf_name_star_skip
.pf_dot:
    inc si
    mov di, bp
    add di, 9
    mov cx, 3
    mov al, ' '
    push di
    rep stosb
    pop di
    mov cx, 3
.pf_ext_loop:
    mov al, [ds:si]
    call .pf_is_end
    jc .pf_done
    call .pf_is_separator
    jc .pf_done
    cmp al, '*'
    je .pf_ext_star
    cmp al, '?'
    je .pf_ext_question
    cmp cx, 0
    je .pf_ext_advance
    call ascii_upper
    mov [es:di], al
    inc di
    dec cx
    inc si
    jmp .pf_ext_loop
.pf_ext_question:
    mov dh, 1
    cmp cx, 0
    je .pf_ext_advance
    mov byte [es:di], '?'
    inc di
    dec cx
.pf_ext_advance:
    inc si
    jmp .pf_ext_loop
.pf_ext_star:
    mov dh, 1
    mov al, '?'
    rep stosb
    inc si
.pf_ext_star_skip:
    mov al, [ds:si]
    call .pf_is_end
    jc .pf_done
    call .pf_is_separator
    jc .pf_done
    inc si
    jmp .pf_ext_star_skip
.pf_bad_drive:
    add si, 2
    mov dh, 0xFF
.pf_done:
    mov al, dh
    pop bp
    pop di
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.pf_is_end:
    test al, al
    jz .pf_char_yes
    cmp al, 13
    je .pf_char_yes
    cmp al, ' '
    jb .pf_char_yes
    clc
    ret
.pf_is_separator:
    cmp al, 9
    je .pf_char_yes
    cmp al, ' '
    je .pf_char_yes
    cmp al, ':'
    je .pf_char_yes
    cmp al, ';'
    je .pf_char_yes
    cmp al, '.'
    je .pf_char_yes
    cmp al, ','
    je .pf_char_yes
    cmp al, '='
    je .pf_char_yes
    cmp al, '+'
    je .pf_char_yes
    cmp al, '/'
    je .pf_char_yes
    cmp al, '"'
    je .pf_char_yes
    cmp al, '['
    je .pf_char_yes
    cmp al, ']'
    je .pf_char_yes
    cmp al, '\'
    je .pf_char_yes
    cmp al, '<'
    je .pf_char_yes
    cmp al, '>'
    je .pf_char_yes
    cmp al, '|'
    je .pf_char_yes
    clc
    ret
.pf_char_yes:
    stc
    ret
.alloc_strategy:
    mov [cs:log_ax], ax
    mov [cs:log_bx], bx
    cmp word [cs:trace_left], 0
    je .as_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_strategy_call
    call serial_print
    mov ax, [cs:log_ax]
    call serial_print_hex_word
    mov si, msg_reg_bx
    call serial_print
    mov ax, [cs:log_bx]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.as_no_trace:
    cmp al, 0
    je .as_get
    cmp al, 1
    je .as_set
    jmp .as_bad
.as_get:
    xor ax, ax
    mov al, [cs:alloc_strat]
    jmp iret_nc
.as_set:
    cmp bl, 2
    ja .as_bad
    mov [cs:alloc_strat], bl
    xor ax, ax
    jmp iret_nc
.as_bad:
    mov ax, 1
    jmp iret_cy
.break_check:
    cmp al, 0
    je .bc_get
    cmp al, 1
    je .bc_set
    cmp al, 5
    je .bc_boot_drive
    cmp al, 6
    je .bc_true_version
    mov ax, 1
    jmp iret_cy
.bc_get:
    mov dl, [cs:break_flag]
    jmp iret_nc
.bc_set:
    and dl, 1
    mov [cs:break_flag], dl
    jmp iret_nc
.bc_boot_drive:
    mov dl, [cs:dos_drive_num]
    inc dl
    jmp iret_nc
.bc_true_version:
    mov bx, 0x1E03
    xor dx, dx
    jmp iret_nc
.set_verify_flag:
    and al, 1
    mov [cs:verify_flag], al
    jmp iret_nc
.get_verify_flag:
    mov al, [cs:verify_flag]
    jmp iret_nc
.alloc_mem:
    push bx
    push cx
    push dx
    push es
    push di
    push ds
    push si
    mov [cs:am_req], bx
    mov al, [cs:alloc_strat]
    and al, 0x03
    cmp al, 2
    jne .am_not_last_strategy
    jmp near .am_find_last
.am_not_last_strategy:
    cmp al, 1
    jne .am_first_strategy
    jmp near .am_find_best
.am_first_strategy:
    cmp word [cs:am_req], 1
    jbe .am_first_walk
    cmp word [cs:am_req], SMALL_ALLOC_HIGH_MAX
    ja .am_first_walk
    jmp near .am_find_last
.am_first_walk:
    mov si, [cs:mcb_first]
.am_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .am_check
    cmp byte [ds:0], MCB_SIG_Z
    je .am_check
    mov ax, 7
    jmp .am_err
.am_check:
    cmp word [ds:1], 0
    jne .am_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .am_next
.am_use:
    mov ax, [ds:3]
    sub ax, [cs:am_req]
    cmp ax, 2
    jb .am_exact
    push si
    mov di, si
    add di, [cs:am_req]
    inc di
    push di
    mov es, di
    mov al, [ds:0]
    mov byte [es:0], al
    mov word [es:1], 0
    mov cx, [ds:3]
    sub cx, [cs:am_req]
    dec cx
    mov word [es:3], cx
    mov byte [ds:0], MCB_SIG_M
    mov ax, [cs:am_req]
    mov word [ds:3], ax
    pop di
    pop si
.am_exact:
    mov ax, [cs:cur_psp]
    mov word [ds:1], ax
    mov ax, si
    inc ax
    cmp word [cs:trace_left], 0
    je .am_no_trace
    dec word [cs:trace_left]
    push ax
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_alloc
    call serial_print
    mov ax, [cs:am_req]
    call serial_print_hex_word
    mov si, msg_trace_strategy
    call serial_print
    xor ax, ax
    mov al, [cs:alloc_strat]
    call serial_print_hex_word
    mov si, msg_trace_ret
    call serial_print
    pop ds
    popa
    pop ax
    call serial_print_hex_word
    push cs
    pop ds
    mov si, msg_crlf
    call serial_print
.am_no_trace:
    mov [cs:am_ret_seg], ax
    INT21_POP_FRAME_BX_CX_DX_ES_DI_DS_SI
    mov ax, [cs:am_ret_seg]
    jmp iret_nc
.am_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .am_nomem
    call mcb_walk_next
    jc .am_nomem
    jmp .am_walk
.am_find_last:
    mov word [cs:am_best_seg], 0
    mov si, [cs:mcb_first]
.am_last_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .am_last_check
    cmp byte [ds:0], MCB_SIG_Z
    je .am_last_check
    mov ax, 7
    jmp .am_err
.am_last_check:
    cmp word [ds:1], 0
    jne .am_last_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .am_last_next
    mov [cs:am_best_seg], si
.am_last_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .am_choose_last
    call mcb_walk_next
    jc .am_nomem
    jmp .am_last_walk
.am_find_best:
    mov word [cs:am_best_seg], 0
    mov word [cs:am_best_size], 0xFFFF
    mov si, [cs:mcb_first]
.am_best_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .am_best_check
    cmp byte [ds:0], MCB_SIG_Z
    je .am_best_check
    mov ax, 7
    jmp .am_err
.am_best_check:
    cmp word [ds:1], 0
    jne .am_best_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .am_best_next
    cmp ax, [cs:am_best_size]
    jae .am_best_next
    mov [cs:am_best_size], ax
    mov [cs:am_best_seg], si
.am_best_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .am_choose_best
    call mcb_walk_next
    jc .am_nomem
    jmp .am_best_walk
.am_choose_best:
    mov si, [cs:am_best_seg]
    test si, si
    jz .am_nomem
    mov ds, si
    jmp .am_use
.am_choose_last:
    mov si, [cs:am_best_seg]
    test si, si
    jz .am_nomem
    mov ds, si
.am_use_last:
    mov cx, [ds:3]
    sub cx, [cs:am_req]
    cmp cx, 2
    jb .am_exact
    mov di, si
    add di, cx
    mov al, [ds:0]
    mov byte [ds:0], MCB_SIG_M
    dec cx
    mov [ds:3], cx
    mov es, di
    mov byte [es:0], al
    mov ax, [cs:am_req]
    mov [es:3], ax
    mov si, di
    mov ds, di
    jmp .am_exact
.am_nomem:
    mov bx, 0
    mov si, [cs:mcb_first]
.am_scan_largest:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .am_sl_check
    cmp byte [ds:0], MCB_SIG_Z
    je .am_sl_check
    jmp .am_sl_done
.am_sl_check:
    cmp word [ds:1], 0
    jne .am_sl_next
    mov ax, [ds:3]
    cmp ax, bx
    jbe .am_sl_next
    mov bx, ax
.am_sl_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .am_sl_done
    call mcb_walk_next
    jc .am_sl_done
    jmp .am_scan_largest
.am_sl_done:
    mov ax, 8
.am_err:
    cmp word [cs:trace_left], 0
    je .am_err_no_trace
    dec word [cs:trace_left]
    push ax
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_alloc
    call serial_print
    mov ax, [cs:am_req]
    call serial_print_hex_word
    mov si, msg_trace_fail
    call serial_print
    pop ds
    popa
    pop ax
.am_err_no_trace:
    mov [cs:am_ret_ax], ax
    mov [cs:am_ret_bx], bx
    INT21_POP_FRAME_BX_CX_DX_ES_DI_DS_SI
    mov ax, [cs:am_ret_ax]
    mov bx, [cs:am_ret_bx]
    jmp iret_cy
.free_mem:
    push ds
    push si
    push es
    push di
    push cx
    mov si, es
    dec si
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .fm_ok
    cmp byte [ds:0], MCB_SIG_Z
    je .fm_ok
    mov ax, 9
    jmp .fm_err
.fm_ok:
    mov word [ds:1], 0
.fm_fwd_merge:
    mov ax, si
    inc ax
    add ax, [ds:3]
    jb .fm_done
    cmp ax, MEM_TOP
    jae .fm_done
    mov di, ax
    mov es, ax
    cmp byte [es:0], MCB_SIG_M
    je .fm_next_valid
    cmp byte [es:0], MCB_SIG_Z
    jne .fm_done
.fm_next_valid:
    cmp word [es:1], 0
    jne .fm_done
    mov cx, [es:3]
    inc cx
    add word [ds:3], cx
    mov al, [es:0]
    mov byte [ds:0], al
    jmp .fm_fwd_merge
.fm_done:
    INT21_POP_FRAME_DS_SI_ES_DI_CX
    jmp iret_nc
.fm_err:
    INT21_POP_FRAME_DS_SI_ES_DI_CX
    jmp iret_cy
.resize_mem:
    push ds
    push si
    push es
    push di
    push dx
    push cx
    mov [cs:rm_req], bx
    mov si, es
    dec si
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .rm_ok
    cmp byte [ds:0], MCB_SIG_Z
    je .rm_ok
    mov ax, 9
    jmp .rm_err
.rm_ok:
    mov ax, [ds:3]
    cmp ax, bx
    jae .rm_shrink
    mov dx, si
    inc dx
    add dx, ax
    jb .rm_cant_grow
    cmp dh, 0xA0
    jae .rm_cant_grow
    mov es, dx
    cmp byte [es:0], MCB_SIG_M
    je .rm_next_ok
    cmp byte [es:0], MCB_SIG_Z
    jne .rm_cant_grow
.rm_next_ok:
    cmp word [es:1], 0
    jne .rm_cant_grow
    mov cx, [es:3]
    inc cx
    add ax, cx
    cmp ax, bx
    jb .rm_cant_grow
    mov dl, [es:0]
    mov byte [ds:0], dl
    add word [ds:3], cx
    mov ax, [ds:3]
    sub ax, bx
    cmp ax, 2
    jb .rm_shrink
    push es
    mov di, si
    add di, bx
    inc di
    mov es, di
    mov byte [es:0], dl
    mov byte [ds:0], MCB_SIG_M
    mov word [es:1], 0
    mov cx, [ds:3]
    sub cx, bx
    dec cx
    mov word [es:3], cx
    mov word [ds:3], bx
    pop es
    jmp .rm_done
.rm_shrink:
    mov ax, [ds:3]
    sub ax, bx
    cmp ax, 2
    jb .rm_done
    push es
    mov di, si
    add di, bx
    inc di
    mov es, di
    mov dl, [ds:0]
    mov byte [es:0], dl
    mov word [es:1], 0
    dec ax
    mov word [es:3], ax
    mov byte [ds:0], MCB_SIG_M
    mov word [ds:3], bx
    cmp dl, MCB_SIG_M
    jne .rm_shrink_merged
    push ds
    push es
    mov ax, es
    inc ax
    add ax, [es:3]
    jb .rm_shrink_no_merge
    cmp ax, MEM_TOP
    jae .rm_shrink_no_merge
    mov ds, ax
    cmp byte [ds:0], MCB_SIG_M
    je .rm_shrink_next_valid
    cmp byte [ds:0], MCB_SIG_Z
    jne .rm_shrink_no_merge
.rm_shrink_next_valid:
    cmp word [ds:1], 0
    jne .rm_shrink_no_merge
    mov cx, [ds:3]
    inc cx
    pop es
    add [es:3], cx
    mov al, [ds:0]
    mov [es:0], al
    pop ds
    jmp .rm_shrink_merged
.rm_shrink_no_merge:
    pop es
    pop ds
.rm_shrink_merged:
    pop es
.rm_done:
    push ax
    push cx
    push es
    mov ax, si
    inc ax
    cmp [ds:1], ax
    jne .rm_psp_done
    mov es, ax
    mov cx, [ds:3]
    add ax, cx
    mov [es:0x02], ax
.rm_psp_done:
    pop es
    pop cx
    pop ax
    cmp word [cs:trace_left], 0
    je .rm_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    xor ax, ax
    mov al, [ds:0]
    push ax
    mov ax, [ds:3]
    push ax
    mov ax, si
    inc ax
    push ax
    push cs
    pop ds
    mov si, msg_trace_resize
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_size
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_sig
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_req
    call serial_print
    mov ax, [cs:rm_req]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.rm_no_trace:
    INT21_POP_FRAME_DS_SI_ES_DI_DX_CX
    jmp iret_nc
.rm_cant_grow:
    mov bx, ax
    mov ax, 8
.rm_err:
    cmp word [cs:trace_left], 0
    je .rm_err_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    xor ax, ax
    mov al, [ds:0]
    push ax
    mov ax, [ds:3]
    push ax
    mov ax, si
    inc ax
    push ax
    push cs
    pop ds
    mov si, msg_trace_resize
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_size
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_sig
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_req
    call serial_print
    mov ax, [cs:rm_req]
    call serial_print_hex_word
    mov si, msg_trace_fail
    call serial_print
    pop ds
    popa
.rm_err_no_trace:
    INT21_POP_FRAME_DS_SI_ES_DI_DX_CX
    jmp iret_cy
.get_date:
    mov al, [cs:date_weekday]
    mov cx, [cs:date_year]
    mov dh, [cs:date_month]
    mov dl, [cs:date_day]
    jmp iret_nc
.set_date:
    cmp cx, 1980
    jb .sd_bad
    cmp cx, 2099
    ja .sd_bad
    cmp dh, 1
    jb .sd_bad
    cmp dh, 12
    ja .sd_bad
    cmp dl, 1
    jb .sd_bad
    mov al, 31
    cmp dh, 4
    je .sd_30
    cmp dh, 6
    je .sd_30
    cmp dh, 9
    je .sd_30
    cmp dh, 11
    je .sd_30
    cmp dh, 2
    jne .sd_check_day
    mov al, 28
    test cl, 3
    jnz .sd_check_day
    inc al
    jmp .sd_check_day
.sd_30:
    mov al, 30
.sd_check_day:
    cmp dl, al
    ja .sd_bad
    mov [cs:date_year], cx
    mov [cs:date_month], dh
    mov [cs:date_day], dl
    push bx
    push cx
    push dx
    push si
    call .compute_weekday
    mov [cs:date_weekday], al
    pop si
    pop dx
    pop cx
    pop bx
    xor al, al
    jmp iret_nc
.sd_bad:
    mov al, 0xFF
    jmp iret_nc
.compute_weekday:
    mov ax, [cs:date_year]
    sub ax, 1980
    mov bx, ax
    mov cx, 365
    mul cx
    mov si, ax
    mov ax, bx
    add ax, 3
    mov cl, 2
    shr ax, cl
    add si, ax
    xor bx, bx
    mov bl, [cs:date_month]
    dec bx
    shl bx, 1
    mov ax, [cs:date_month_offsets + bx]
    add si, ax
    cmp byte [cs:date_month], 3
    jb .cw_no_leap_day
    mov ax, [cs:date_year]
    test ax, 3
    jnz .cw_no_leap_day
    inc si
.cw_no_leap_day:
    xor ax, ax
    mov al, [cs:date_day]
    dec ax
    add si, ax
    add si, 2
    mov ax, si
    xor dx, dx
    mov bx, 7
    div bx
    mov al, dl
    ret
.get_time:
    cmp byte [cs:time_set], 0
    jne .gt_stored
    push ax
    push bx
    push si
    xor ah, ah
    int 0x1A
    xor si, si
.gt_hour_loop:
    cmp cx, 0
    jne .gt_sub_hour
    cmp dx, 0xFFF0
    jb .gt_hour_done
.gt_sub_hour:
    sub dx, 0xFFF0
    sbb cx, 0
    inc si
    cmp si, 24
    jb .gt_hour_loop
    xor si, si
.gt_hour_done:
    mov ax, si
    mov [cs:time_hour], al
    xor si, si
.gt_min_loop:
    cmp cx, 0
    jne .gt_sub_min
    cmp dx, 0x0444
    jb .gt_min_done
.gt_sub_min:
    sub dx, 0x0444
    sbb cx, 0
    inc si
    cmp si, 60
    jb .gt_min_loop
    xor si, si
.gt_min_done:
    mov ax, si
    mov [cs:time_min], al
    mov ax, dx
    mov bx, 6000
    mul bx
    mov bx, 0x0444
    div bx
    xor dx, dx
    mov bx, 100
    div bx
    mov [cs:time_sec], al
    mov [cs:time_hund], dl
    mov ch, [cs:time_hour]
    mov cl, [cs:time_min]
    mov dh, [cs:time_sec]
    mov dl, [cs:time_hund]
    pop si
    pop bx
    pop ax
    jmp iret_nc
.gt_stored:
    mov ch, [cs:time_hour]
    mov cl, [cs:time_min]
    mov dh, [cs:time_sec]
    mov dl, [cs:time_hund]
    jmp iret_nc
.set_time:
    cmp ch, 24
    jae .st_bad
    cmp cl, 60
    jae .st_bad
    cmp dh, 60
    jae .st_bad
    cmp dl, 100
    jae .st_bad
    mov [cs:time_hour], ch
    mov [cs:time_min], cl
    mov [cs:time_sec], dh
    mov [cs:time_hund], dl
    mov byte [cs:time_set], 1
    xor al, al
    jmp iret_nc
.st_bad:
    mov al, 0xFF
    jmp iret_nc
.exec:
    cmp al, 0
    je .exec_program
    cmp al, 3
    je .exec_overlay
    mov ax, 1
    jmp iret_cy
.get_return_code:
    xor ah, ah
    mov al, [cs:ret_code]
    mov byte [cs:ret_code], 0
    jmp iret_nc
.exec_program:
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    push word [cs:cur_psp]
    push word [cs:dta_seg]
    push word [cs:dta_off]
    push word [cs:saved_ss]
    push word [cs:saved_sp]
    mov [cs:exec_param_off], bx
    mov [cs:exec_param_seg], es
    mov [cs:exec_path_off], dx
    mov [cs:exec_path_seg], ds
    call load_exec_program
    jc .exec_program_err
    cmp byte [cs:exec_is_exe], 0
    jne .exec_run_exe
    call exec_com_dyn
    jmp .exec_program_returned
.exec_run_exe:
    call setup_exe_dyn
    jnc .exec_program_returned
    mov [cs:exec_status], ax
    call free_prog_mcb
    call free_exec_environment
    mov ax, [cs:exec_status]
    jmp .exec_program_err
.exec_program_returned:
    INT21_POP_EXEC_PROGRAM_FRAME
    xor ax, ax
    jmp iret_nc
.exec_program_err:
    mov [cs:exec_status], ax
    INT21_POP_EXEC_PROGRAM_FRAME
    mov ax, [cs:exec_status]
    jmp iret_cy
.exec_overlay:
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov [cs:ov_param_off], bx
    mov [cs:ov_param_seg], es
    mov [cs:ov_path_off], dx
    mov [cs:ov_path_seg], ds
    mov bx, [cs:ov_param_off]
    mov ax, [es:bx]
    mov [cs:ov_load_seg], ax
    mov ax, [es:bx+2]
    mov [cs:ov_reloc_seg], ax
    mov ds, [cs:ov_path_seg]
    mov si, [cs:ov_path_off]
    call resolve_path
    jc .exec_overlay_nf
    mov ax, [es:di+26]
    mov [cs:ov_cluster], ax
    mov ax, [es:di+28]
    mov [cs:ov_size_lo], ax
    mov ax, [es:di+30]
    mov [cs:ov_size_hi], ax
    call load_overlay_direct
    jc .exec_overlay_err
    INT21_POP_FRAME_BX_CX_DX_DS_ES_SI_DI
    xor ax, ax
    jmp iret_nc
.exec_overlay_nf:
    mov word [cs:ov_status], 2
    jmp .exec_overlay_pop_err
.exec_overlay_err:
    mov word [cs:ov_status], 1
.exec_overlay_pop_err:
    INT21_POP_FRAME_BX_CX_DX_DS_ES_SI_DI
    mov ax, [cs:ov_status]
    jmp iret_cy
.chdir:
    push ds
    push si
    push es
    push di
    push bx
    mov [cs:cd_path_off], dx
    mov [cs:cd_path_seg], ds
    mov si, dx
    mov al, [ds:si]
    call ascii_upper
    cmp al, 'A'
    jb .cd_check_root
    cmp al, 'Z'
    ja .cd_check_root
    cmp byte [ds:si+1], ':'
    jne .cd_check_root
    add si, 2
.cd_check_root:
    cmp byte [ds:si], '\'
    je .cd_root_sep
    cmp byte [ds:si], '/'
    je .cd_root_sep
    cmp byte [ds:si], '.'
    jne .cd_resolve
    cmp byte [ds:si+1], 0
    je .cd_same_dir
    cmp byte [ds:si+1], '.'
    jne .cd_resolve
    cmp byte [ds:si+2], 0
    jne .cd_resolve
    cmp word [cs:cur_dir_cluster], ROOT_CLUSTER
    je .cd_same_dir
    jmp .cd_resolve
.cd_root_sep:
    inc si
.cd_root_skip:
    cmp byte [ds:si], '\'
    je .cd_root_advance
    cmp byte [ds:si], '/'
    je .cd_root_advance
    cmp byte [ds:si], 0
    je .cd_root
    jmp .cd_resolve
.cd_root_advance:
    inc si
    jmp .cd_root_skip
.cd_root:
    mov word [cs:cur_dir_cluster], ROOT_CLUSTER
    mov byte [cs:cur_dir_path], 0
    INT21_POP_FRAME_DS_SI_ES_DI_BX
    jmp iret_nc
.cd_resolve:
    mov si, dx
    call chdir_dot_only_path
    jc .cd_resolve_full
    mov [cs:cur_dir_cluster], ax
    mov ds, [cs:cd_path_seg]
    mov si, [cs:cd_path_off]
    call store_cur_dir_path
    INT21_POP_FRAME_DS_SI_ES_DI_BX
    jmp iret_nc
.cd_resolve_full:
    mov si, dx
    call resolve_path
    jc .cd_err
    test byte [es:di+11], ATTR_DIR
    jz .cd_err
    mov ax, [es:di+26]
    mov [cs:cur_dir_cluster], ax
    mov ds, [cs:cd_path_seg]
    mov si, [cs:cd_path_off]
    call store_cur_dir_path
    INT21_POP_FRAME_DS_SI_ES_DI_BX
    jmp iret_nc
.cd_same_dir:
    INT21_POP_FRAME_DS_SI_ES_DI_BX
    jmp iret_nc
.cd_err:
    INT21_POP_FRAME_DS_SI_ES_DI_BX
    mov ax, 3
    jmp iret_cy

.make_dir:
    push ds
    push si
    push es
    push di
    push bx
    push cx
    push dx
    mov si, dx
    call parse_root_path
    jc .md_path_err
    call name_buf_is_blank
    jc .md_access
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:pr_dir_cluster]
    call find_in_dir
    jnc .md_access
    mov ax, [cs:pr_dir_cluster]
    call find_dir_free
    jc .md_no_slot
    mov ax, [cs:ff_entry_lba]
    mov [cs:md_entry_lba], ax
    mov ax, [cs:ff_entry_lba_hi]
    mov [cs:md_entry_lba_hi], ax
    mov ax, [cs:ff_entry_off]
    mov [cs:md_entry_off], ax
    mov ax, [cs:pr_dir_cluster]
    mov [cs:md_parent_cluster], ax
    call fat_alloc_cluster
    jc .md_no_slot
    mov [cs:md_cluster], ax
    call init_dir_cluster
    jc .md_free_err
    call flush_fat
    jc .md_free_err
    mov ax, [cs:md_entry_lba]
    mov dx, [cs:md_entry_lba_hi]
    mov di, [cs:md_entry_off]
    call load_dir_slot
    jc .md_free_err
.md_write_entry:
    push di
    xor ax, ax
    mov cx, 16
    cld
    rep stosw
    pop di
    push di
    push ds
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    pop ds
    pop di
    mov byte [es:di+11], ATTR_DIR
    mov word [es:di+22], FAT_TIME
    mov word [es:di+24], FAT_DATE
    mov ax, [cs:md_cluster]
    mov [es:di+26], ax
    mov word [es:di+28], 0
    mov word [es:di+30], 0
    mov ax, [cs:md_entry_lba_hi]
    mov dx, ax
    mov ax, [cs:md_entry_lba]
    call flush_dir_slot
    jc .md_io_err
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX_DX
    jmp iret_nc
.md_free_err:
    mov si, [cs:md_cluster]
    call fat_free_chain
    call flush_fat
.md_io_err:
    mov ax, 5
    jmp .md_err
.md_path_err:
    mov ax, 3
    jmp .md_err
.md_no_slot:
    mov ax, 5
    jmp .md_err
.md_access:
    mov ax, 5
.md_err:
    mov [cs:md_status], ax
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX_DX
    mov ax, [cs:md_status]
    jmp iret_cy

.remove_dir:
    push ds
    push si
    push es
    push di
    push bx
    push cx
    push dx
    mov si, dx
    call parse_root_path
    jc .rd_path_err
    call name_buf_is_blank
    jc .rd_access
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:pr_dir_cluster]
    call find_in_dir
    jc .rd_not_found
    test byte [es:di+11], ATTR_DIR
    jz .rd_access
    mov ax, [es:di+26]
    cmp ax, 2
    jb .rd_access
    cmp ax, [cs:cur_dir_cluster]
    je .rd_access
    mov [cs:rd_cluster], ax
    mov ax, [cs:ff_entry_lba]
    mov [cs:rd_entry_lba], ax
    mov ax, [cs:ff_entry_lba_hi]
    mov [cs:rd_entry_lba_hi], ax
    mov ax, [cs:ff_entry_off]
    mov [cs:rd_entry_off], ax
    mov si, [cs:rd_cluster]
    call dir_is_empty
    jc .rd_access
    mov ax, [cs:rd_entry_lba]
    mov dx, [cs:rd_entry_lba_hi]
    mov di, [cs:rd_entry_off]
    call load_dir_slot
    jc .rd_io_err
.rd_delete_entry:
    mov byte [es:di], 0xE5
    mov dx, [cs:rd_entry_lba_hi]
    mov ax, [cs:rd_entry_lba]
    call flush_dir_slot
    jc .rd_io_err
    mov si, [cs:rd_cluster]
    call fat_free_chain
    call flush_fat
    jc .rd_io_err
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX_DX
    jmp iret_nc
.rd_not_found:
    mov ax, 3
    jmp .rd_err
.rd_path_err:
    mov ax, 3
    jmp .rd_err
.rd_access:
    mov ax, 5
    jmp .rd_err
.rd_io_err:
    mov ax, 5
.rd_err:
    mov [cs:rd_status], ax
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX_DX
    mov ax, [cs:rd_status]
    jmp iret_cy
.create_file:
    mov byte [cs:cf_new_only], 0
    jmp .create_file_start
.create_new_file:
    mov byte [cs:cf_new_only], 1
.create_file_start:
    push ds
    push si
    push es
    push di
    push bx
    push cx
    mov [cs:cf_attr], cl
    mov si, dx
    call detect_device_path
    jnc .cr_device
    mov si, dx
    call parse_root_path
    jc .cr_path_err
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:pr_dir_cluster]
    call find_in_dir
    jnc .cr_existing
    mov ax, [cs:pr_dir_cluster]
    call find_dir_free
    jc .cr_no_slot
    mov ax, [cs:ff_entry_off]
    mov [cs:cf_entry_off], ax
    mov byte [cs:cf_found], 0
    jmp .cr_alloc_handle
.cr_existing:
    cmp byte [cs:cf_new_only], 0
    jne .cr_exists
    test byte [es:di+11], ATTR_DIR
    jnz .cr_access_denied
    test byte [es:di+11], ATTR_RDONLY
    jnz .cr_access_denied
    call entry_has_open_handle
    jc .cr_access_denied
    mov ax, [cs:ff_entry_cluster]
    mov [cs:cf_first_cluster], ax
    mov ax, [cs:ff_entry_off]
    mov [cs:cf_entry_off], ax
    mov byte [cs:cf_found], 1
.cr_alloc_handle:
    mov ax, [cs:ff_entry_lba]
    mov [cs:cf_entry_lba], ax
    mov ax, [cs:ff_entry_lba_hi]
    mov [cs:cf_entry_lba_hi], ax
    call alloc_handle
    jc .cr_no_handles
    mov [cs:cf_handle], ax
    cmp byte [cs:cf_found], 0
    je .cr_load_entry
    mov si, [cs:cf_first_cluster]
    call fat_free_chain
    call flush_fat
    jc .cr_io_err
.cr_load_entry:
    mov ax, [cs:cf_entry_lba]
    mov dx, [cs:cf_entry_lba_hi]
    mov di, [cs:cf_entry_off]
    call load_dir_slot
    jc .cr_io_err
.cr_clear_entry:
    push di
    xor ax, ax
    mov cx, 16
    cld
    rep stosw
    pop di
    push di
    push ds
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    pop ds
    pop di
    mov al, [cs:cf_attr]
    mov [es:di+11], al
    mov word [es:di+22], FAT_TIME
    mov word [es:di+24], FAT_DATE
    mov word [es:di+26], 0
    mov word [es:di+28], 0
    mov word [es:di+30], 0
    mov dx, [cs:cf_entry_lba_hi]
    mov ax, [cs:cf_entry_lba]
    call flush_dir_slot
    jc .cr_io_err
    mov ax, [cs:cf_handle]
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    mov al, 2
    call init_handle_entry
    mov ax, [cs:cf_entry_lba]
    mov [cs:bx+handles+H_DIR_LBA], ax
    mov ax, [cs:cf_entry_lba_hi]
    mov [cs:bx+handles+H_DIR_LBA_HI], ax
    mov ax, [cs:cf_entry_off]
    mov [cs:bx+handles+H_DIR_OFF], ax
    mov word [cs:bx+handles+H_TIME], FAT_TIME
    mov word [cs:bx+handles+H_DATE], FAT_DATE
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX
    mov ax, [cs:cf_handle]
    jmp iret_nc
.cr_device:
    call alloc_device_handle
    jc .cr_device_err
    mov [cs:cf_handle], ax
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX
    mov ax, [cs:cf_handle]
    jmp iret_nc
.cr_device_err:
    mov [cs:cf_status], ax
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX
    mov ax, [cs:cf_status]
    jmp iret_cy
.cr_path_err:
    mov ax, 3
    jmp .cr_err
.cr_no_slot:
    mov ax, 4
    jmp .cr_err
.cr_no_handles:
    mov ax, 4
    jmp .cr_err
.cr_access_denied:
    mov ax, 5
    jmp .cr_err
.cr_exists:
    mov ax, 80
    jmp .cr_err
.cr_io_err:
    mov ax, 5
.cr_err:
    mov [cs:cf_status], ax
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX
    mov ax, [cs:cf_status]
    jmp iret_cy

.create_temp_file:
    push ax
    push bx
    push cx
    push dx
    push es
    push si
    push di
    mov si, dx
.ct_find_end:
    cmp byte [ds:si], 0
    je .ct_have_end
    inc si
    jmp .ct_find_end
.ct_have_end:
    mov [cs:tm_end_off], si
    mov word [cs:tm_tries], 0
.ct_try:
    mov di, [cs:tm_end_off]
    mov ax, [cs:temp_counter]
    mov bx, ax
    mov byte [ds:di], 'L'
    inc di
    mov byte [ds:di], 'D'
    inc di
    mov cl, 12
    call .ct_store_digit
    mov cl, 8
    call .ct_store_digit
    mov cl, 4
    call .ct_store_digit
    xor cl, cl
    call .ct_store_digit
    mov byte [ds:di], '.'
    inc di
    mov byte [ds:di], 'T'
    inc di
    mov byte [ds:di], 'M'
    inc di
    mov byte [ds:di], 'P'
    inc di
    mov byte [ds:di], 0
    inc word [cs:temp_counter]
    mov si, dx
    call parse_root_path
    jc .ct_path_err
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:pr_dir_cluster]
    call find_in_dir
    jc .ct_unique
    inc word [cs:tm_tries]
    cmp word [cs:tm_tries], 256
    jb .ct_try
    mov ax, 80
    jmp .ct_restore_err_pop
.ct_unique:
    pop di
    pop si
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    mov byte [cs:cf_new_only], 1
    jmp .create_file_start
.ct_path_err:
    mov ax, 3
.ct_restore_err_pop:
    mov di, [cs:tm_end_off]
    mov byte [ds:di], 0
.ct_err_pop:
    mov [cs:cf_status], ax
    pop di
    pop si
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    mov ax, [cs:cf_status]
    jmp iret_cy
.ct_store_digit:
    push ax
    mov ax, bx
    shr ax, cl
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .ct_digit_ok
    add al, 7
.ct_digit_ok:
    mov [ds:di], al
    inc di
    pop ax
    ret
.open_file:
    cmp word [cs:trace_left], 0
    je .of_no_path_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push si
    push cs
    pop ds
    mov si, msg_trace_open
    call serial_print
    pop si
    pop ds
    push ds
    push si
    mov si, dx
    call serial_print
    push cs
    pop ds
    mov si, msg_crlf
    call serial_print
    pop si
    pop ds
    popa
.of_no_path_trace:
    push es
    push ds
    push bx
    push cx
    push dx
    push si
    push di
    mov [cs:of_mode], al
    mov si, dx
    call detect_device_path
    jnc .of_device
    mov si, dx
    call resolve_path
    jnc .of_found
    INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI
    mov ax, 2
    jmp iret_cy
.of_found:
    call alloc_handle
    jc .of_no_handles
    push ax
    push di
    mov di, ax
    mov cx, HANDLE_SIZE
    mul cx
    mov di, ax
    mov al, [cs:of_mode]
    mov bx, di
    call init_handle_entry
    pop si
    mov ax, [es:si+26]
    mov [cs:di+handles+H_CLUSTER], ax
    mov [cs:di+handles+H_LAST_CLUSTER], ax
    mov word [cs:di+handles+H_LAST_INDEX], 0
    mov ax, [es:si+28]
    mov [cs:di+handles+H_SIZE_LO], ax
    mov ax, [es:si+30]
    mov [cs:di+handles+H_SIZE_HI], ax
    mov word [cs:di+handles+H_POS_LO], 0
    mov word [cs:di+handles+H_POS_HI], 0
    mov ax, [cs:ff_entry_lba]
    mov [cs:di+handles+H_DIR_LBA], ax
    mov ax, [cs:ff_entry_lba_hi]
    mov [cs:di+handles+H_DIR_LBA_HI], ax
    mov ax, [cs:ff_entry_off]
    mov [cs:di+handles+H_DIR_OFF], ax
    mov ax, [es:si+22]
    mov [cs:di+handles+H_TIME], ax
    mov ax, [es:si+24]
    mov [cs:di+handles+H_DATE], ax
    pop ax
    cmp word [cs:trace_left], 0
    je .of_no_handle_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_handle
    call serial_print
    call serial_print_hex_word
    mov si, msg_trace_size
    call serial_print
    mov ax, [cs:di+handles+H_SIZE_HI]
    call serial_print_hex_word
    mov ax, [cs:di+handles+H_SIZE_LO]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.of_no_handle_trace:
    INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI
    jmp iret_nc
.of_device:
    call alloc_device_handle
    jc .of_device_err
    push ax
    cmp word [cs:trace_left], 0
    je .of_device_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_handle
    call serial_print
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.of_device_no_trace:
    pop ax
    INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI
    jmp iret_nc
.of_device_err:
    mov [cs:of_status], ax
    INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI
    mov ax, [cs:of_status]
    jmp iret_cy
.of_no_handles:
    INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI
    mov ax, 4
    jmp iret_cy
.close_file:
    cmp bx, MAX_HANDLES
    jae .cf_err
    cmp word [cs:trace_left], 0
    je .cf_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_close
    call serial_print
    mov ax, bx
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.cf_no_trace:
    cmp bx, 5
    jae .cf_table_handle
    push ax
    push cx
    push dx
    push si
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    pop si
    pop dx
    pop cx
    pop ax
    je .cf_std_handle
.cf_table_handle:
    call close_table_handle
    jc .cf_status_err
    jmp iret_nc
.cf_status_err:
    jmp iret_cy
.cf_std_handle:
    jmp iret_nc
.cf_err:
    mov ax, 6
    jmp iret_cy
.read_file:
    cmp bx, MAX_HANDLES
    jae .rf_err
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov [cs:rf_handle], bx
    mov [cs:rf_req], cx
    mov [cs:rf_count], cx
    mov [cs:rf_buf_off], dx
    mov [cs:rf_buf_seg], ds
    mov [cs:rf_start_buf_off], dx
    mov [cs:rf_start_buf_seg], ds
    mov word [cs:rf_read], 0
    call resolve_handle_for_use
    jc .rf_err_pop
    mov [cs:rf_hoff], si
    mov ax, [cs:si+handles+H_DIR_LBA]
    or ax, [cs:si+handles+H_DIR_LBA_HI]
    je .rf_device
    mov ax, [cs:si+handles+H_POS_LO]
    mov [cs:rf_start_lo], ax
    mov ax, [cs:si+handles+H_POS_HI]
    mov [cs:rf_start_hi], ax
.rf_loop:
    mov cx, [cs:rf_count]
    test cx, cx
    jz .rf_done
    mov bx, [cs:rf_hoff]
    mov ax, [cs:bx+handles+H_POS_HI]
    cmp ax, [cs:bx+handles+H_SIZE_HI]
    ja .rf_done
    jb .rf_do_read
    mov ax, [cs:bx+handles+H_POS_LO]
    cmp ax, [cs:bx+handles+H_SIZE_LO]
    jae .rf_done
.rf_do_read:
    mov si, [cs:bx+handles+H_CLUSTER]
    mov ax, [cs:bx+handles+H_POS_LO]
    mov dx, [cs:bx+handles+H_POS_HI]
    mov cx, 9
.rf_sector_shift:
    shr dx, 1
    rcr ax, 1
    loop .rf_sector_shift
    xor ch, ch
    mov cl, [cs:kspc]
    div cx
    mov [cs:rf_sec_in_cluster], dx
    mov [cs:rf_cluster_index], ax
    mov si, [cs:bx+handles+H_LAST_CLUSTER]
    mov cx, [cs:bx+handles+H_LAST_INDEX]
    test si, si
    jz .rf_walk_from_start
    cmp cx, [cs:rf_cluster_index]
    je .rf_have_cluster
    jbe .rf_walk_from_cache
    jmp .rf_walk_from_start
.rf_walk_from_cache:
    cmp cx, [cs:rf_cluster_index]
    je .rf_cache_cluster
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .rf_done
    cmp ax, 2
    jb .rf_err_pop
    mov si, ax
    inc cx
    jmp .rf_walk_from_cache
.rf_walk_from_start:
    mov si, [cs:bx+handles+H_CLUSTER]
    xor cx, cx
.rf_cluster_walk:
    cmp cx, [cs:rf_cluster_index]
    je .rf_cache_cluster
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .rf_done
    cmp ax, 2
    jb .rf_err_pop
    mov si, ax
    inc cx
    jmp .rf_cluster_walk
.rf_cache_cluster:
    mov bx, [cs:rf_hoff]
    mov [cs:bx+handles+H_LAST_CLUSTER], si
    mov ax, [cs:rf_cluster_index]
    mov [cs:bx+handles+H_LAST_INDEX], ax
.rf_have_cluster:
    mov ax, si
    mov bx, [cs:rf_sec_in_cluster]
    call cluster_lba
    cmp byte [cs:rf_cache_valid], 1
    jne .rf_read_sector
    cmp ax, [cs:rf_cache_lba]
    jne .rf_read_sector
    cmp dx, [cs:rf_cache_lba_hi]
    je .rf_have_sector
.rf_read_sector:
    mov byte [cs:rf_cache_valid], 0
    mov [cs:rf_cache_lba], ax
    mov [cs:rf_cache_lba_hi], dx
    mov [cs:kio_lba_hi], dx
    push es
    push bx
    xor bx, bx
    mov dx, READ_CACHE_BUF
    mov es, dx
    call read_sector
    pop bx
    pop es
    jc .rf_err_pop
    mov byte [cs:rf_cache_valid], 1
.rf_have_sector:
    mov si, [cs:rf_hoff]
    mov ax, [cs:si+handles+H_POS_LO]
    and ax, 511
    mov cx, 512
    sub cx, ax
    mov ax, [cs:rf_count]
    cmp cx, ax
    jbe .rf_got2
    mov cx, ax
.rf_got2:
    mov ax, [cs:si+handles+H_POS_HI]
    cmp ax, [cs:si+handles+H_SIZE_HI]
    jne .rf_copy_limit_done
    mov ax, [cs:si+handles+H_SIZE_LO]
    sub ax, [cs:si+handles+H_POS_LO]
    cmp cx, ax
    jbe .rf_copy_limit_done
    mov cx, ax
.rf_copy_limit_done:
    push ds
    push si
    mov dx, [cs:rf_buf_seg]
    mov es, dx
    mov di, [cs:rf_buf_off]
    mov dx, READ_CACHE_BUF
    mov ds, dx
    xor si, si
    mov bx, [cs:rf_hoff]
    add si, [cs:bx+handles+H_POS_LO]
    and si, 511
    mov ax, 512
    sub ax, si
    cmp cx, ax
    jbe .rf_copy
    mov cx, ax
.rf_copy:
    mov ax, [cs:rf_buf_off]
    test ax, ax
    jz .rf_copy_now
    neg ax
    cmp cx, ax
    jbe .rf_copy_now
    mov cx, ax
.rf_copy_now:
    push cx
    rep movsb
    pop cx
    pop si
    pop ds
    mov bx, [cs:rf_hoff]
    add [cs:bx+handles+H_POS_LO], cx
    adc word [cs:bx+handles+H_POS_HI], 0
    mov ax, [cs:rf_buf_off]
    add ax, cx
    mov [cs:rf_buf_off], ax
    jnc .rf_buf_no_wrap
    add word [cs:rf_buf_seg], 0x1000
.rf_buf_no_wrap:
    mov ax, [cs:rf_count]
    sub ax, cx
    mov [cs:rf_count], ax
    add [cs:rf_read], cx
    jmp .rf_loop
.rf_done:
    mov ax, [cs:rf_read]
    cmp word [cs:trace_left], 0
    je .rf_no_trace
    dec word [cs:trace_left]
    push ax
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_read
    call serial_print
    mov ax, [cs:rf_handle]
    call serial_print_hex_word
    mov si, msg_trace_req
    call serial_print
    mov ax, [cs:rf_req]
    call serial_print_hex_word
    mov si, msg_trace_pos
    call serial_print
    mov ax, [cs:rf_start_hi]
    call serial_print_hex_word
    mov ax, [cs:rf_start_lo]
    call serial_print_hex_word
    mov si, msg_trace_buf
    call serial_print
    mov ax, [cs:rf_start_buf_seg]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:rf_start_buf_off]
    call serial_print_hex_word
    mov si, msg_trace_ret
    call serial_print
    mov ax, [cs:rf_read]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
    pop ax
.rf_no_trace:
    INT21_POP_FRAME_BX_CX_DX_DS_ES_SI_DI
    jmp iret_nc
.rf_device:
    mov ax, [cs:si+handles+H_DIR_OFF]
    cmp ax, DEV_NUL
    je .rf_done
    cmp ax, DEV_EMM
    je .rf_done
    cmp ax, DEV_CON
    je .rf_con
    jmp .rf_err_pop
.rf_con:
    cmp word [cs:rf_count], 0
    je .rf_done
    mov ax, [cs:rf_buf_seg]
    mov es, ax
    mov di, [cs:rf_buf_off]
    call console_read_char
    stosb
    inc word [cs:rf_read]
    mov bx, [cs:rf_hoff]
    add word [cs:bx+handles+H_POS_LO], 1
    adc word [cs:bx+handles+H_POS_HI], 0
    add word [cs:rf_buf_off], 1
    jnc .rf_con_no_wrap
    add word [cs:rf_buf_seg], 0x1000
.rf_con_no_wrap:
    sub word [cs:rf_count], 1
    jmp .rf_con
.rf_err_pop:
    INT21_POP_FRAME_BX_CX_DX_DS_ES_SI_DI
.rf_err:
    mov ax, 6
    jmp iret_cy

.write_file:
    cmp bx, MAX_HANDLES
    jae .wf_invalid
    cmp bx, 5
    jae .wf_file
    push ax
    push cx
    push dx
    push si
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    pop si
    pop dx
    pop cx
    pop ax
    je .wf_stdio
.wf_file:
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov [cs:wf_req], cx
    mov [cs:wf_count], cx
    mov word [cs:wf_written], 0
    mov [cs:wf_buf_off], dx
    mov [cs:wf_buf_seg], ds
    call resolve_handle_for_use
    jc .wf_file_invalid_pop
    mov [cs:wf_hoff], si
    mov ax, [cs:si+handles+H_DIR_LBA]
    or ax, [cs:si+handles+H_DIR_LBA_HI]
    je .wf_device
    cmp byte [cs:si+handles+H_MODE], 0
    je .wf_file_access_pop
    mov ax, [cs:si+handles+H_POS_HI]
    cmp ax, [cs:si+handles+H_SIZE_HI]
    ja .wf_gap_start
    jb .wf_file_loop
    mov ax, [cs:si+handles+H_POS_LO]
    cmp ax, [cs:si+handles+H_SIZE_LO]
    ja .wf_gap_start
    jmp .wf_file_loop
.wf_gap_start:
    mov ax, [cs:si+handles+H_POS_LO]
    mov [cs:wf_target_lo], ax
    mov ax, [cs:si+handles+H_POS_HI]
    mov [cs:wf_target_hi], ax
    mov ax, [cs:si+handles+H_SIZE_LO]
    mov [cs:si+handles+H_POS_LO], ax
    mov ax, [cs:si+handles+H_SIZE_HI]
    mov [cs:si+handles+H_POS_HI], ax
.wf_gap_loop:
    mov si, [cs:wf_hoff]
    mov ax, [cs:wf_target_hi]
    cmp [cs:si+handles+H_POS_HI], ax
    jb .wf_gap_more
    ja .wf_file_loop
    mov ax, [cs:wf_target_lo]
    cmp [cs:si+handles+H_POS_LO], ax
    jb .wf_gap_more
    jmp .wf_file_loop
.wf_gap_more:
    cmp word [cs:si+handles+H_CLUSTER], 0
    jne .wf_gap_have_start
    call fat_alloc_cluster
    jc .wf_file_io_pop
    mov si, [cs:wf_hoff]
    mov [cs:si+handles+H_CLUSTER], ax
    mov [cs:si+handles+H_LAST_CLUSTER], ax
    mov word [cs:si+handles+H_LAST_INDEX], 0
.wf_gap_have_start:
    mov ax, [cs:si+handles+H_POS_LO]
    mov dx, [cs:si+handles+H_POS_HI]
    mov cx, 9
.wf_gap_sector_shift:
    shr dx, 1
    rcr ax, 1
    loop .wf_gap_sector_shift
    xor ch, ch
    mov cl, [cs:kspc]
    div cx
    mov [cs:wf_cluster_index], ax
    mov [cs:wf_sec_in_cluster], dx
    call wf_get_cluster
    jc .wf_file_io_pop
    mov ax, si
    mov bx, [cs:wf_sec_in_cluster]
    call cluster_lba
    mov [cs:wf_sector_lba], ax
    mov [cs:wf_sector_lba_hi], dx
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:wf_sector_lba]
    mov dx, [cs:wf_sector_lba_hi]
    mov [cs:kio_lba_hi], dx
    call read_sector
    jc .wf_file_io_pop
    mov ax, SEC_BUF
    mov es, ax
    mov si, [cs:wf_hoff]
    mov di, [cs:si+handles+H_POS_LO]
    and di, 511
    mov cx, 512
    sub cx, di
    mov ax, [cs:wf_target_hi]
    cmp ax, [cs:si+handles+H_POS_HI]
    jne .wf_gap_chunk_ok
    mov ax, [cs:wf_target_lo]
    sub ax, [cs:si+handles+H_POS_LO]
    cmp cx, ax
    jbe .wf_gap_chunk_ok
    mov cx, ax
.wf_gap_chunk_ok:
    push cx
    xor ax, ax
    cld
    rep stosb
    pop cx
    push cx
    xor bx, bx
    mov ax, [cs:wf_sector_lba]
    mov dx, [cs:wf_sector_lba_hi]
    mov [cs:kio_lba_hi], dx
    call write_sector
    pop cx
    jc .wf_file_io_pop
    mov byte [cs:rf_cache_valid], 0
    mov si, [cs:wf_hoff]
    add [cs:si+handles+H_POS_LO], cx
    adc word [cs:si+handles+H_POS_HI], 0
    mov ax, [cs:si+handles+H_POS_LO]
    mov [cs:si+handles+H_SIZE_LO], ax
    mov ax, [cs:si+handles+H_POS_HI]
    mov [cs:si+handles+H_SIZE_HI], ax
    jmp .wf_gap_loop
.wf_file_loop:
    cmp word [cs:wf_count], 0
    je .wf_file_done
    mov si, [cs:wf_hoff]
    cmp word [cs:si+handles+H_CLUSTER], 0
    jne .wf_have_start
    call fat_alloc_cluster
    jc .wf_file_done
    mov si, [cs:wf_hoff]
    mov [cs:si+handles+H_CLUSTER], ax
    mov [cs:si+handles+H_LAST_CLUSTER], ax
    mov word [cs:si+handles+H_LAST_INDEX], 0
.wf_have_start:
    mov ax, [cs:si+handles+H_POS_LO]
    mov dx, [cs:si+handles+H_POS_HI]
    mov cx, 9
.wf_sector_shift:
    shr dx, 1
    rcr ax, 1
    loop .wf_sector_shift
    xor ch, ch
    mov cl, [cs:kspc]
    div cx
    mov [cs:wf_cluster_index], ax
    mov [cs:wf_sec_in_cluster], dx
    mov cx, ax
    call wf_get_cluster
    jc .wf_file_done
    mov [cs:wf_cluster], si
    mov ax, si
    mov bx, [cs:wf_sec_in_cluster]
    call cluster_lba
    mov [cs:wf_sector_lba], ax
    mov [cs:wf_sector_lba_hi], dx
    push es
    push bx
    mov [cs:kio_lba_hi], dx
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    pop bx
    pop es
    jc .wf_file_io_pop
    mov si, [cs:wf_hoff]
    mov di, [cs:si+handles+H_POS_LO]
    and di, 511
    mov cx, 512
    sub cx, di
    mov ax, [cs:wf_count]
    cmp cx, ax
    jbe .wf_chunk_ok
    mov cx, ax
.wf_chunk_ok:
    push cx
    push ds
    push es
    mov ax, SEC_BUF
    mov es, ax
    mov ax, [cs:wf_buf_seg]
    mov ds, ax
    mov si, [cs:wf_buf_off]
    rep movsb
    pop es
    pop ds
    pop cx
    push cx
    push es
    push bx
    mov ax, [cs:wf_sector_lba]
    mov dx, [cs:wf_sector_lba_hi]
    mov [cs:kio_lba_hi], dx
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call write_sector
    pop bx
    pop es
    pop cx
    jc .wf_file_io_pop
    mov byte [cs:rf_cache_valid], 0
    mov si, [cs:wf_hoff]
    add [cs:si+handles+H_POS_LO], cx
    adc word [cs:si+handles+H_POS_HI], 0
    mov ax, [cs:si+handles+H_POS_HI]
    cmp ax, [cs:si+handles+H_SIZE_HI]
    jb .wf_size_ok
    ja .wf_update_size
    mov ax, [cs:si+handles+H_POS_LO]
    cmp ax, [cs:si+handles+H_SIZE_LO]
    jbe .wf_size_ok
.wf_update_size:
    mov ax, [cs:si+handles+H_POS_LO]
    mov [cs:si+handles+H_SIZE_LO], ax
    mov ax, [cs:si+handles+H_POS_HI]
    mov [cs:si+handles+H_SIZE_HI], ax
.wf_size_ok:
    add [cs:wf_buf_off], cx
    sub [cs:wf_count], cx
    add [cs:wf_written], cx
    jmp .wf_file_loop
.wf_file_done:
    mov ax, [cs:wf_written]
    INT21_POP_FRAME_BX_CX_DX_DS_ES_SI_DI
    jmp iret_nc
.wf_device:
    mov ax, [cs:si+handles+H_DIR_OFF]
    cmp ax, DEV_NUL
    je .wf_device_done
    cmp ax, DEV_EMM
    je .wf_device_done
    cmp ax, DEV_CON
    je .wf_device_con
    mov ax, 5
    jmp .wf_file_err_pop
.wf_device_con:
    cmp word [cs:wf_count], 0
    je .wf_device_done
    mov ax, [cs:wf_buf_seg]
    mov ds, ax
    mov si, [cs:wf_buf_off]
    lodsb
    call console_putchar
    mov bx, [cs:wf_hoff]
    add word [cs:bx+handles+H_POS_LO], 1
    adc word [cs:bx+handles+H_POS_HI], 0
    add word [cs:wf_buf_off], 1
    jnc .wf_device_con_no_wrap
    add word [cs:wf_buf_seg], 0x1000
.wf_device_con_no_wrap:
    sub word [cs:wf_count], 1
    jmp .wf_device_con
.wf_device_done:
    mov ax, [cs:wf_req]
    INT21_POP_FRAME_BX_CX_DX_DS_ES_SI_DI
    jmp iret_nc
.wf_file_invalid_pop:
    mov ax, 6
    jmp .wf_file_err_pop
.wf_file_access_pop:
    mov ax, 5
    jmp .wf_file_err_pop
.wf_file_io_pop:
    mov ax, 5
.wf_file_err_pop:
    mov [cs:wf_status], ax
    INT21_POP_FRAME_BX_CX_DX_DS_ES_SI_DI
    mov ax, [cs:wf_status]
    jmp iret_cy
.wf_invalid:
    mov ax, 6
    jmp iret_cy
.wf_stdio:
    push ds
    push si
    push cx
    mov si, dx
    mov [cs:wf_count], cx
.wf_loop:
    jcxz .wf_done
    lodsb
    call console_putchar
    loop .wf_loop
.wf_done:
    mov ax, [cs:wf_count]
    pop cx
    pop si
    pop ds
    jmp iret_nc

.delete_file:
    push ds
    push si
    push es
    push di
    push bx
    push cx
    mov si, dx
    call parse_root_path
    jc .df_path_err
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:pr_dir_cluster]
    call find_in_dir
    jc .df_not_found
    test byte [es:di+11], ATTR_DIR
    jnz .df_access
    test byte [es:di+11], ATTR_RDONLY
    jnz .df_access
    call entry_has_open_handle
    jc .df_access
    mov si, [es:di+26]
    mov [cs:df_first_cluster], si
    mov byte [es:di], 0xE5
    mov dx, [cs:ff_entry_lba_hi]
    mov ax, [cs:ff_entry_lba]
    call flush_dir_slot
    jc .df_io_err
    mov si, [cs:df_first_cluster]
    call fat_free_chain
    call flush_fat
    jc .df_io_err
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX
    jmp iret_nc
.df_not_found:
    mov ax, 2
    jmp .df_err
.df_path_err:
    mov ax, 3
    jmp .df_err
.df_access:
    mov ax, 5
    jmp .df_err
.df_io_err:
    mov ax, 5
.df_err:
    mov [cs:df_status], ax
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX
    mov ax, [cs:df_status]
    jmp iret_cy

.seek_file:
    cmp bx, MAX_HANDLES
    jae .sf_err
    push si
    mov [cs:sf_origin], al
    mov [cs:sf_req_lo], dx
    mov [cs:sf_req_hi], cx
    call resolve_handle_for_use
    jc .sf_err_saved
    cmp byte [cs:sf_origin], 0
    je .sf_start
    cmp byte [cs:sf_origin], 1
    je .sf_cur
    cmp byte [cs:sf_origin], 2
    je .sf_end
    jmp .sf_err_saved
.sf_start:
    mov [cs:si+handles+H_POS_LO], dx
    mov [cs:si+handles+H_POS_HI], cx
    jmp .sf_ok
.sf_cur:
    add [cs:si+handles+H_POS_LO], dx
    adc [cs:si+handles+H_POS_HI], cx
    jmp .sf_ok
.sf_end:
    mov ax, [cs:si+handles+H_SIZE_LO]
    add ax, dx
    mov [cs:si+handles+H_POS_LO], ax
    mov ax, [cs:si+handles+H_SIZE_HI]
    adc ax, cx
    mov [cs:si+handles+H_POS_HI], ax
.sf_ok:
    mov ax, [cs:si+handles+H_POS_LO]
    mov dx, [cs:si+handles+H_POS_HI]
    mov [cs:sf_ret_lo], ax
    mov [cs:sf_ret_hi], dx
    cmp word [cs:trace_left], 0
    je .sf_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_seek
    call serial_print
    mov ax, bx
    call serial_print_hex_word
    mov si, msg_trace_org
    call serial_print
    xor ax, ax
    mov al, [cs:sf_origin]
    call serial_print_hex_word
    mov si, msg_trace_off
    call serial_print
    mov ax, [cs:sf_req_hi]
    call serial_print_hex_word
    mov ax, [cs:sf_req_lo]
    call serial_print_hex_word
    mov si, msg_trace_pos
    call serial_print
    mov ax, [cs:sf_ret_hi]
    call serial_print_hex_word
    mov ax, [cs:sf_ret_lo]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.sf_no_trace:
    pop si
    jmp iret_nc
.sf_err_saved:
    pop si
.sf_err:
    mov ax, 1
    jmp iret_cy

.file_attrs:
    cmp al, 0
    je .fa_get
    cmp al, 1
    je .fa_set
    mov ax, 1
    jmp iret_cy
.fa_get:
    push es
    push ds
    push bx
    push cx
    push dx
    push si
    push di
    mov si, dx
    call resolve_path
    jc .fa_get_nf
    xor ch, ch
    mov cl, [es:di+11]
    mov [cs:fa_ret_attr], cx
    INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI
    mov cx, [cs:fa_ret_attr]
    jmp iret_nc
.fa_set:
    mov [cs:fa_attr], cl
    push es
    push ds
    push bx
    push cx
    push dx
    push si
    push di
    mov si, dx
    call resolve_path
    jc .fa_set_nf
    mov al, [cs:fa_attr]
    test al, ~ATTR_MUTABLE & 0xFF
    jnz .fa_set_access
    and al, ATTR_MUTABLE
    and byte [es:di+11], ATTR_IMMUTABLE
    or [es:di+11], al
    mov dx, [cs:ff_entry_lba_hi]
    mov ax, [cs:ff_entry_lba]
    call flush_dir_slot
    jc .fa_set_io_err
    INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI
    jmp iret_nc
.fa_get_nf:
    INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI
    mov ax, 2
    jmp iret_cy
.fa_set_io_err:
    mov ax, 5
    jmp .fa_set_err
.fa_set_access:
    mov ax, 5
    jmp .fa_set_err
.fa_set_nf:
    mov ax, 2
.fa_set_err:
    INT21_POP_FRAME_ES_DS_BX_CX_DX_SI_DI
    jmp iret_cy

.ioctl:
    mov [cs:ioctl_func], al
    cmp byte [cs:ioctl_func], 0
    je .ioctl_no_trace
    cmp word [cs:trace_left], 0
    je .ioctl_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_ioctl
    call serial_print
    xor ax, ax
    mov al, [cs:ioctl_func]
    call serial_print_hex_word
    mov si, msg_trace_handle
    call serial_print
    mov ax, bx
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.ioctl_no_trace:
    cmp al, 0
    je .ioctl_get
    cmp al, 1
    je .ioctl_set
    cmp al, 6
    je .ioctl_input_status
    cmp al, 7
    je .ioctl_output_status
    cmp al, 8
    je .ioctl_removable_drive
    cmp al, 9
    je .ioctl_local_drive
    cmp al, 0x0A
    je .ioctl_local_handle
    mov ax, 1
    jmp iret_cy
.ioctl_set:
    jmp .ioctl_get
.ioctl_get:
    cmp bx, MAX_HANDLES
    jae .ioctl_bad_handle
    cmp bx, 5
    jae .ioctl_get_table
    push bx
    push ax
    push cx
    push dx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    cmp byte [cs:bx+handles+H_USED], 0
    pop dx
    pop cx
    pop ax
    pop bx
    je .ioctl_stdio
.ioctl_get_table:
    push bx
    push ax
    push cx
    push si
    call resolve_handle_for_use
    jc .ioctl_get_bad_pop
    mov dx, [cs:si+handles+H_DIR_LBA]
    or dx, [cs:si+handles+H_DIR_LBA_HI]
    pop si
    pop cx
    pop ax
    pop bx
    je .ioctl_stdio
    xor dh, dh
    mov dl, [cs:dos_drive_num]
    jmp iret_nc
.ioctl_stdio:
    mov dx, 0x80D3
    jmp iret_nc
.ioctl_get_bad_pop:
    pop si
    pop cx
    pop ax
    pop bx
.ioctl_bad_handle:
    mov ax, 6
    jmp iret_cy

.ioctl_input_status:
    cmp bx, MAX_HANDLES
    jae .ioctl_bad_handle
    cmp bx, 5
    jae .ioctl_input_table
    push bx
    push cx
    push dx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    cmp byte [cs:bx+handles+H_USED], 0
    pop dx
    pop cx
    pop bx
    je .ioctl_input_stdio
.ioctl_input_table:
    push bx
    push cx
    push dx
    push si
    call resolve_handle_for_use
    jc .ioctl_input_bad_pop
    mov ax, [cs:si+handles+H_DIR_LBA]
    or ax, [cs:si+handles+H_DIR_LBA_HI]
    je .ioctl_input_device_pop
    mov ax, [cs:si+handles+H_POS_HI]
    cmp ax, [cs:si+handles+H_SIZE_HI]
    jb .ioctl_input_ready_pop
    ja .ioctl_input_empty_pop
    mov ax, [cs:si+handles+H_POS_LO]
    cmp ax, [cs:si+handles+H_SIZE_LO]
    jb .ioctl_input_ready_pop
.ioctl_input_empty_pop:
    pop si
    pop dx
    pop cx
    pop bx
    xor ax, ax
    jmp iret_nc
.ioctl_input_ready_pop:
    pop si
    pop dx
    pop cx
    pop bx
    mov ax, 0xFFFF
    jmp iret_nc
.ioctl_input_device_pop:
    mov ax, [cs:si+handles+H_DIR_OFF]
    pop si
    pop dx
    pop cx
    pop bx
    cmp ax, DEV_CON
    je .ioctl_input_stdio
    xor ax, ax
    jmp iret_nc
.ioctl_input_bad_pop:
    pop si
    pop dx
    pop cx
    pop bx
    jmp .ioctl_bad_handle
.ioctl_input_stdio:
    call console_input_status
    test al, al
    jz .ioctl_input_stdio_empty
    mov ax, 0xFFFF
    jmp iret_nc
.ioctl_input_stdio_empty:
    xor ax, ax
    jmp iret_nc

.ioctl_output_status:
    cmp bx, MAX_HANDLES
    jae .ioctl_bad_handle
    cmp bx, 5
    jae .ioctl_output_table
    push ax
    push cx
    push dx
    push si
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    pop si
    pop dx
    pop cx
    pop ax
    je .ioctl_output_ready
.ioctl_output_table:
    push bx
    push cx
    push dx
    push si
    call resolve_handle_for_use
    jc .ioctl_output_bad_pop
    cmp byte [cs:si+handles+H_USED], 0
    je .ioctl_output_bad_pop
    pop si
    pop dx
    pop cx
    pop bx
.ioctl_output_ready:
    mov ax, 0xFFFF
    jmp iret_nc
.ioctl_output_bad_pop:
    pop si
    pop dx
    pop cx
    pop bx
    jmp .ioctl_bad_handle

.ioctl_removable_drive:
    call .ioctl_validate_drive_bl
    jc .ioctl_bad_drive
    xor ax, ax
    cmp byte [cs:kdrv], 0x80
    jb .ioctl_removable_done
    mov ax, 1
.ioctl_removable_done:
    jmp iret_nc
.ioctl_local_drive:
    call .ioctl_validate_drive_bl
    jc .ioctl_bad_drive
    xor dx, dx
    jmp iret_nc
.ioctl_bad_drive:
    mov ax, 15
    jmp iret_cy
.ioctl_validate_drive_bl:
    test bl, bl
    jz .ioctl_drive_ok
    mov al, [cs:dos_drive_count]
    cmp bl, al
    jbe .ioctl_drive_ok
    stc
    ret
.ioctl_drive_ok:
    clc
    ret
.ioctl_local_handle:
    cmp bx, MAX_HANDLES
    jae .ioctl_bad_handle
    cmp bx, 5
    jae .ioctl_local_handle_table
    push bx
    push cx
    push si
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    pop si
    pop cx
    pop bx
    je .ioctl_local_handle_ok
.ioctl_local_handle_table:
    push bx
    push cx
    push dx
    push si
    call resolve_handle_for_use
    jc .ioctl_local_handle_bad_pop
    pop si
    pop dx
    pop cx
    pop bx
.ioctl_local_handle_ok:
    xor dx, dx
    jmp iret_nc
.ioctl_local_handle_bad_pop:
    pop si
    pop dx
    pop cx
    pop bx
    jmp .ioctl_bad_handle

.duplicate_handle:
    cmp bx, MAX_HANDLES
    jae .dh_bad_handle
    push bx
    push dx
    push si
    cmp bx, 5
    jae .dh_table_source
    mov ax, bx
    mov dx, HANDLE_SIZE
    mul dx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .dh_implicit_std
.dh_table_source:
    call resolve_handle_for_use
    jc .dh_bad_handle_pop
    mov [cs:dup_root], ax
    call alloc_handle
    jc .dh_no_handles_pop
    mov dx, [cs:dup_root]
    call make_alias_handle
    pop si
    pop dx
    pop bx
    jmp iret_nc
.dh_implicit_std:
    mov al, DEV_CON
    call alloc_device_handle
    jc .dh_device_err_pop
    pop si
    pop dx
    pop bx
    jmp iret_nc
.dh_device_err_pop:
    mov [cs:dup_status], ax
    pop si
    pop dx
    pop bx
    mov ax, [cs:dup_status]
    jmp iret_cy
.dh_no_handles_pop:
    pop si
    pop dx
    pop bx
    mov ax, 4
    jmp iret_cy
.dh_bad_handle_pop:
    pop si
    pop dx
    pop bx
.dh_bad_handle:
    mov ax, 6
    jmp iret_cy

.force_duplicate_handle:
    cmp bx, MAX_HANDLES
    jae .fdh_bad_handle
    cmp cx, MAX_HANDLES
    jae .fdh_bad_handle
    cmp bx, cx
    je .fdh_same_handle
    push bx
    push cx
    push dx
    push si
    mov [cs:dup_dest], cx
    mov byte [cs:dup_is_device], 0
    cmp bx, 5
    jae .fdh_table_source
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    jne .fdh_table_source
    mov byte [cs:dup_is_device], 1
    jmp .fdh_source_ready
.fdh_table_source:
    call resolve_handle_for_use
    jc .fdh_bad_handle_pop
    mov [cs:dup_root], ax
    cmp ax, [cs:dup_dest]
    jne .fdh_source_ready
    mov si, ax
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 2
    jne .fdh_ok_pop
    inc word [cs:si+handles+H_REFCOUNT]
    mov byte [cs:si+handles+H_USED], 1
    jmp .fdh_ok_pop
.fdh_source_ready:
    mov bx, [cs:dup_dest]
    call close_handle_for_replace
    jc .fdh_close_err_pop
.fdh_dest_free:
    cmp byte [cs:dup_is_device], 0
    je .fdh_make_alias
    mov ax, [cs:dup_dest]
    mov dl, DEV_CON
    call make_device_handle_at
    jmp .fdh_ok_pop
.fdh_make_alias:
    mov ax, [cs:dup_dest]
    mov dx, [cs:dup_root]
    call make_alias_handle
.fdh_ok_pop:
    pop si
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.fdh_same_handle:
    cmp bx, 5
    jae .fdh_same_table
    push ax
    push cx
    push dx
    push si
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    pop si
    pop dx
    pop cx
    pop ax
    je .fdh_same_ok
.fdh_same_table:
    push si
    call resolve_handle_for_use
    pop si
    jc .fdh_bad_handle
.fdh_same_ok:
    jmp iret_nc
.fdh_close_err_pop:
    mov [cs:dup_status], ax
    pop si
    pop dx
    pop cx
    pop bx
    mov ax, [cs:dup_status]
    jmp iret_cy
.fdh_bad_handle_pop:
    pop si
    pop dx
    pop cx
    pop bx
.fdh_bad_handle:
    mov ax, 6
    jmp iret_cy

.get_curdir:
    test dl, dl
    jz .gc_drive_ok
    mov al, [cs:dos_drive_count]
    cmp dl, al
    jbe .gc_drive_ok
    jmp .gc_bad_drive
.gc_drive_ok:
    push ds
    push si
    push es
    push di
    mov ax, ds
    mov es, ax
    mov di, si
    push cs
    pop ds
    mov si, cur_dir_path
.cdl:
    lodsb
    stosb
    test al, al
    jnz .cdl
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.gc_bad_drive:
    mov ax, 0x000F
    jmp iret_cy

.find_first:
    push ds
    push si
    push cx
    push bx
    push es
    push di
    mov [cs:ff_path_off], dx
    mov [cs:ff_path_seg], ds
    mov ax, ds
    mov es, ax
    mov di, dx
    mov word [cs:ff_sep_off], 0
.ff_scan:
    mov al, [es:di]
    test al, al
    jz .ff_scan_done
    cmp al, '\'
    je .ff_sep
    cmp al, '/'
    je .ff_sep
    inc di
    jmp .ff_scan
.ff_sep:
    mov [cs:ff_sep_off], di
    inc di
    jmp .ff_scan
.ff_scan_done:
    cmp word [cs:ff_sep_off], 0
    je .ff_bare_name
.ff_has_path:
    mov ds, [cs:ff_path_seg]
    mov di, [cs:ff_sep_off]
    mov ax, [cs:ff_path_off]
    cmp ax, di
    je .ff_root_path
    mov bl, [ds:di]
    push bx
    push di
    mov byte [ds:di], 0
    mov si, [cs:ff_path_off]
    call resolve_path
    mov [cs:ff_res_es], es
    mov [cs:ff_res_di], di
    pop di
    pop bx
    mov ds, [cs:ff_path_seg]
    mov [ds:di], bl
    jc .ff_err
    mov es, [cs:ff_res_es]
    mov di, [cs:ff_res_di]
    test byte [es:di+11], ATTR_DIR
    jnz .ff_got_dir_entry
    stc
    jmp .ff_err
.ff_root_path:
    mov ds, [cs:ff_path_seg]
    mov di, [cs:ff_sep_off]
    mov bl, [ds:di]
    push bx
    push di
    mov byte [ds:di], 0
    mov si, [cs:ff_path_off]
    call resolve_path
    mov [cs:ff_res_es], es
    mov [cs:ff_res_di], di
    pop di
    pop bx
    mov ds, [cs:ff_path_seg]
    mov [ds:di], bl
    jc .ff_root_fallback
    mov es, [cs:ff_res_es]
    mov di, [cs:ff_res_di]
    test byte [es:di+11], ATTR_DIR
    jnz .ff_got_dir_entry
.ff_root_fallback:
    mov ax, ROOT_CLUSTER
    mov [cs:ff_dir_cluster], ax
    jmp .ff_after_dir
.ff_got_dir_entry:
    mov ax, [es:di+26]
    mov [cs:ff_dir_cluster], ax
.ff_after_dir:
    mov ds, [cs:ff_path_seg]
    mov si, [cs:ff_sep_off]
    inc si
    jmp .ff_parse_name
.ff_bare_name:
    mov ax, [cs:cur_dir_cluster]
    mov [cs:ff_dir_cluster], ax
    mov ds, [cs:ff_path_seg]
    mov si, [cs:ff_path_off]
.ff_parse_name:
    call parse_83name
    mov ax, [cs:dta_seg]
    mov es, ax
    mov di, [cs:dta_off]
    mov byte [es:di], 0
    mov [es:di+12], cl
    mov word [es:di+13], 0
    mov ax, [cs:ff_dir_cluster]
    mov [es:di+15], ax
    mov [cs:ff_attr_mask], cl
    inc di
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    mov ax, [cs:ff_dir_cluster]
    xor dx, dx
    call find_in_dir_filtered
    jnc .ff_found
    INT21_POP_FRAME_DS_SI_CX_BX_ES_DI
    mov ax, 2
    jmp iret_cy
.ff_err:
    INT21_POP_FRAME_DS_SI_CX_BX_ES_DI
    mov ax, 3
    jmp iret_cy
.ff_found:
    call store_find_dta
    INT21_POP_FRAME_DS_SI_CX_BX_ES_DI
    jmp iret_nc

.find_next:
    push ds
    push si
    push cx
    push bx
    push es
    push di
    mov ax, [cs:dta_seg]
    mov ds, ax
    mov si, [cs:dta_off]
    mov cl, [ds:si+12]
    mov [cs:ff_attr_mask], cl
    mov bx, [ds:si+13]
    mov ax, [ds:si+15]
    mov [cs:ff_dir_cluster], ax
    inc si
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    rep movsb
    inc bx
    mov ax, [cs:ff_dir_cluster]
    call find_in_dir_from
    jnc .fn_found
    INT21_POP_FRAME_DS_SI_CX_BX_ES_DI
    mov ax, 2
    jmp iret_cy
.fn_found:
    call store_find_dta
    INT21_POP_FRAME_DS_SI_CX_BX_ES_DI
    jmp iret_nc

.rename_file:
    push ds
    push si
    push es
    push di
    push bx
    push cx
    mov [cs:rn_new_off], di
    mov ax, es
    mov [cs:rn_new_seg], ax
    mov si, dx
    call parse_root_path
    jc .rn_path_err
    mov ax, [cs:pr_dir_cluster]
    mov [cs:rn_dir_cluster], ax
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:rn_dir_cluster]
    call find_in_dir
    jc .rn_not_found
    test byte [es:di+11], ATTR_DIR
    jnz .rn_access
    test byte [es:di+11], ATTR_RDONLY
    jnz .rn_access
    call entry_has_open_handle
    jc .rn_access
    mov ax, [cs:ff_entry_lba]
    mov [cs:rn_src_lba], ax
    mov ax, [cs:ff_entry_lba_hi]
    mov [cs:rn_src_lba_hi], ax
    mov ax, [cs:ff_entry_off]
    mov [cs:rn_src_dir_off], ax
    mov ax, [cs:rn_new_seg]
    mov ds, ax
    mov si, [cs:rn_new_off]
    call parse_root_path
    jc .rn_path_err
    mov ax, [cs:pr_dir_cluster]
    cmp ax, [cs:rn_dir_cluster]
    jne .rn_access
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:rn_dir_cluster]
    call find_in_dir
    jnc .rn_access
    mov ax, [cs:rn_src_lba]
    mov dx, [cs:rn_src_lba_hi]
    mov di, [cs:rn_src_dir_off]
    call load_dir_slot
    jc .rn_access
.rn_write_name:
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    mov dx, [cs:rn_src_lba_hi]
    mov ax, [cs:rn_src_lba]
    call flush_dir_slot
    jc .rn_access
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX
    jmp iret_nc
.rn_not_found:
    mov ax, 2
    jmp .rn_err
.rn_path_err:
    mov ax, 3
    jmp .rn_err
.rn_access:
    mov ax, 5
.rn_err:
    mov [cs:rn_status], ax
    INT21_POP_FRAME_DS_SI_ES_DI_BX_CX
    mov ax, [cs:rn_status]
    jmp iret_cy

.file_time:
    cmp bx, MAX_HANDLES
    jae .ft_bad_handle
    push si
    push cx
    push dx
    mov [cs:ft_mode], al
    mov [cs:ft_time], cx
    mov [cs:ft_date], dx
    call resolve_handle_for_use
    jc .ft_bad_handle_saved
    cmp byte [cs:ft_mode], 0
    je .ft_get
    cmp byte [cs:ft_mode], 1
    je .ft_set
    pop dx
    pop cx
    pop si
    mov ax, 1
    jmp iret_cy
.ft_get:
    pop ax
    pop ax
    mov cx, [cs:si+handles+H_TIME]
    mov dx, [cs:si+handles+H_DATE]
    pop si
    jmp iret_nc
.ft_set:
    mov ax, [cs:ft_time]
    mov [cs:si+handles+H_TIME], ax
    mov ax, [cs:ft_date]
    mov [cs:si+handles+H_DATE], ax
    call flush_handle_dir_entry
    jc .ft_io_err_saved
    pop dx
    pop cx
    pop si
    jmp iret_nc
.ft_io_err_saved:
    pop dx
    pop cx
    pop si
    mov ax, 5
    jmp iret_cy
.ft_bad_handle_saved:
    pop dx
    pop cx
    pop si
.ft_bad_handle:
    mov ax, 6
    jmp iret_cy

.commit_file:
    cmp bx, MAX_HANDLES
    jae .cm_bad_handle
    cmp bx, 5
    jae .cm_table_handle
    push ax
    push cx
    push dx
    push si
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    pop si
    pop dx
    pop cx
    pop ax
    je .cm_ok
.cm_table_handle:
    push ax
    push bx
    push cx
    push dx
    push si
    call resolve_handle_for_use
    jc .cm_bad_pop
    mov ax, [cs:si+handles+H_DIR_LBA]
    or ax, [cs:si+handles+H_DIR_LBA_HI]
    je .cm_ok_pop
    call flush_handle_dir_entry
    jc .cm_io_pop
    call flush_fat
    jc .cm_io_pop
.cm_ok_pop:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
.cm_ok:
    jmp iret_nc
.cm_io_pop:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    mov ax, 5
    jmp iret_cy
.cm_bad_pop:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
.cm_bad_handle:
    mov ax, 6
    jmp iret_cy

.set_handle_count:
    jmp iret_nc
