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
    cmp ah, 0x25
    je .set_vector
    cmp ah, 0x29
    je .parse_fcb
    cmp ah, 0x2A
    je .get_date
    cmp ah, 0x2C
    je .get_time
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
    cmp ah, 0x56
    je .rename_file
    cmp ah, 0x57
    je .file_time
    cmp ah, 0x58
    je .alloc_strategy
    cmp ah, 0x62
    je .get_psp
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
    mov byte [es:bp], 0
    mov di, bp
    inc di
    mov cx, 11
    mov al, ' '
    rep stosb
.pf_skip:
    mov al, [ds:si]
    cmp al, ' '
    je .pf_skip_one
    cmp al, 9
    jne .pf_scan_start
.pf_skip_one:
    inc si
    jmp .pf_skip
.pf_scan_start:
    mov bx, si
.pf_scan:
    mov al, [ds:si]
    test al, al
    jz .pf_scan_done
    cmp al, 13
    je .pf_scan_done
    cmp al, ' '
    je .pf_scan_done
    cmp al, 9
    je .pf_scan_done
    inc si
    cmp al, '\'
    je .pf_component
    cmp al, '/'
    je .pf_component
    cmp al, ':'
    je .pf_drive
    jmp .pf_scan
.pf_drive:
    mov al, [ds:si-2]
    call .pf_store_char
    cmp al, 'A'
    jb .pf_component
    cmp al, 'Z'
    ja .pf_component
    sub al, 'A' - 1
    mov [es:bp], al
.pf_component:
    mov bx, si
    jmp .pf_scan
.pf_scan_done:
    mov dx, si
    mov di, bp
    mov al, [ds:bx+1]
    cmp al, ':'
    jne .pf_name
    mov al, [ds:bx]
    cmp al, 'a'
    jb .pf_drive_upper
    cmp al, 'z'
    ja .pf_drive_upper
    sub al, 32
.pf_drive_upper:
    cmp al, 'A'
    jb .pf_name
    cmp al, 'Z'
    ja .pf_name
    sub al, 'A' - 1
    mov [es:di], al
    add bx, 2
.pf_name:
    inc di
    mov cx, 8
.pf_name_loop:
    cmp bx, dx
    jae .pf_ext_blank
    mov al, [ds:bx]
    cmp al, '.'
    je .pf_dot
    cmp cx, 0
    je .pf_skip_name_extra
    call .pf_store_char
    mov [es:di], al
    inc di
    inc bx
    dec cx
    jmp .pf_name_loop
.pf_skip_name_extra:
    inc bx
    jmp .pf_name_loop
.pf_ext_blank:
    add di, cx
    jmp .pf_done
.pf_dot:
    add di, cx
    inc bx
    mov cx, 3
.pf_ext_loop:
    cmp bx, dx
    jae .pf_done
    cmp cx, 0
    je .pf_done
    mov al, [ds:bx]
    call .pf_store_char
    mov [es:di], al
    inc di
    inc bx
    dec cx
    jmp .pf_ext_loop
.pf_done:
    mov si, dx
    xor al, al
    pop bp
    pop di
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.pf_store_char:
    cmp al, 'a'
    jb .pfsc_done
    cmp al, 'z'
    ja .pfsc_done
    sub al, 32
.pfsc_done:
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
    jmp iret_nc
.as_get:
    xor ax, ax
    mov al, [cs:alloc_strat]
    jmp iret_nc
.as_set:
    mov [cs:alloc_strat], bl
    jmp iret_nc
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
    mov bx, 0x031E
    xor dx, dx
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
    pop si
    pop ds
    pop di
    pop es
    pop dx
    pop cx
    pop bx
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
    pop si
    pop ds
    pop di
    pop es
    pop dx
    pop cx
    pop bx
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
    pop cx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.fm_err:
    pop cx
    pop di
    pop es
    pop si
    pop ds
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
    pop cx
    pop dx
    pop di
    pop es
    pop si
    pop ds
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
    pop cx
    pop dx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_cy
.get_date:
    mov al, 0
    mov cx, 2026
    mov dh, 5
    mov dl, 21
    jmp iret_nc
.get_time:
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
    call update_exec_environment_path
    cmp byte [cs:exec_is_exe], 0
    jne .exec_run_exe
    call exec_com_dyn
    jmp .exec_program_returned
.exec_run_exe:
    call setup_exe_dyn
    jc .exec_program_err
.exec_program_returned:
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
    xor ax, ax
    jmp iret_nc
.exec_program_err:
    mov [cs:exec_status], ax
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
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    xor ax, ax
    jmp iret_nc
.exec_overlay_nf:
    mov word [cs:ov_status], 2
    jmp .exec_overlay_pop_err
.exec_overlay_err:
    mov word [cs:ov_status], 1
.exec_overlay_pop_err:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
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
    cmp byte [ds:si], 'A'
    jb .cd_check_root
    cmp byte [ds:si], 'Z'
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
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.cd_resolve:
    mov si, dx
    call resolve_path
    jc .cd_err
    test byte [es:di+11], ATTR_DIR
    jz .cd_err
    mov ax, [es:di+26]
    mov [cs:cur_dir_cluster], ax
    mov ds, [cs:cd_path_seg]
    mov si, [cs:cd_path_off]
    cmp byte [ds:si], 'A'
    jb .cd_check_dot_path
    cmp byte [ds:si], 'Z'
    ja .cd_check_dot_path
    cmp byte [ds:si+1], ':'
    jne .cd_check_dot_path
    add si, 2
.cd_check_dot_path:
    cmp byte [ds:si], '.'
    jne .cd_copy_path
    cmp byte [ds:si+1], 0
    je .cd_same_dir
    cmp byte [ds:si+1], '.'
    jne .cd_copy_path
    cmp byte [ds:si+2], 0
    jne .cd_copy_path
    call cur_dir_path_parent
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.cd_same_dir:
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.cd_copy_path:
    push cs
    pop es
    mov di, cur_dir_path
    mov cx, 62
    mov ds, [cs:cd_path_seg]
    mov si, [cs:cd_path_off]
    cmp byte [ds:si], 'A'
    jb .cd_skip_sep
    cmp byte [ds:si], 'Z'
    ja .cd_skip_sep
    cmp byte [ds:si+1], ':'
    jne .cd_skip_sep
    add si, 2
.cd_skip_sep:
    cmp byte [ds:si], '\'
    je .cd_ss
    cmp byte [ds:si], '/'
    je .cd_ss
    jmp .cd_copy
.cd_ss:
    inc si
    jmp .cd_skip_sep
.cd_copy:
    lodsb
    stosb
    dec cx
    jz .cd_trunc
    test al, al
    jnz .cd_copy
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.cd_trunc:
    mov byte [es:di-1], 0
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.cd_err:
    pop bx
    pop di
    pop es
    pop si
    pop ds
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
    cmp word [cs:md_entry_lba_hi], 0
    jne .md_load_subdir_slot
    mov ax, [cs:md_entry_lba]
    cmp ax, [cs:krsta]
    jb .md_load_subdir_slot
    cmp ax, [cs:kdsta]
    jae .md_load_subdir_slot
    sub ax, [cs:krsta]
    mov di, ax
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    add di, [cs:md_entry_off]
    mov ax, ROOT_SEG
    mov es, ax
    jmp .md_write_entry
.md_load_subdir_slot:
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:md_entry_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:md_entry_lba]
    call read_sector
    jc .md_free_err
    mov di, [cs:md_entry_off]
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
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:md_entry_lba]
    call flush_dir_sector
    jc .md_io_err
    pop dx
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
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
    pop dx
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
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
    cmp word [cs:rd_entry_lba_hi], 0
    jne .rd_load_subdir_slot
    mov ax, [cs:rd_entry_lba]
    cmp ax, [cs:krsta]
    jb .rd_load_subdir_slot
    cmp ax, [cs:kdsta]
    jae .rd_load_subdir_slot
    sub ax, [cs:krsta]
    mov di, ax
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    shl di, 1
    add di, [cs:rd_entry_off]
    mov ax, ROOT_SEG
    mov es, ax
    jmp .rd_delete_entry
.rd_load_subdir_slot:
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:rd_entry_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:rd_entry_lba]
    call read_sector
    jc .rd_io_err
    mov di, [cs:rd_entry_off]
.rd_delete_entry:
    mov byte [es:di], 0xE5
    mov ax, [cs:rd_entry_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:rd_entry_lba]
    call flush_dir_sector
    jc .rd_io_err
    mov si, [cs:rd_cluster]
    call fat_free_chain
    call flush_fat
    jc .rd_io_err
    pop dx
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
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
    pop dx
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, [cs:rd_status]
    jmp iret_cy
.create_file:
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
    mov [cs:cf_entry_idx], cx
    mov [cs:cf_entry_off], di
    mov byte [cs:cf_found], 0
    jmp .cr_alloc_handle
.cr_existing:
    test byte [es:di+11], ATTR_DIR
    jnz .cr_access_denied
    test byte [es:di+11], ATTR_RDONLY
    jnz .cr_access_denied
    call entry_has_open_handle
    jc .cr_access_denied
    mov ax, [cs:ff_entry_idx]
    mov [cs:cf_entry_idx], ax
    mov [cs:cf_entry_off], di
    mov byte [cs:cf_found], 1
.cr_alloc_handle:
    mov ax, es
    mov [cs:cf_entry_seg], ax
    mov ax, [cs:ff_entry_lba]
    mov [cs:cf_entry_lba], ax
    mov ax, [cs:ff_entry_lba_hi]
    mov [cs:cf_entry_lba_hi], ax
    call alloc_handle
    jc .cr_no_handles
    mov [cs:cf_handle], ax
    mov ax, [cs:cf_entry_seg]
    mov es, ax
    mov di, [cs:cf_entry_off]
    cmp byte [cs:cf_found], 0
    je .cr_clear_entry
    mov si, [es:di+26]
    call fat_free_chain
    call flush_fat
    jc .cr_io_err
    mov ax, [cs:cf_entry_seg]
    cmp ax, SEC_BUF
    jne .cr_clear_entry
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:cf_entry_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:cf_entry_lba]
    call read_sector
    jc .cr_io_err
.cr_clear_entry:
    mov di, [cs:cf_entry_off]
    push di
    xor ax, ax
    mov cx, 16
    cld
    rep stosw
    pop di
    push ds
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    pop ds
    mov di, [cs:cf_entry_off]
    mov al, [cs:cf_attr]
    mov [es:di+11], al
    mov word [es:di+22], FAT_TIME
    mov word [es:di+24], FAT_DATE
    mov word [es:di+26], 0
    mov word [es:di+28], 0
    mov word [es:di+30], 0
    mov ax, [cs:cf_entry_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:cf_entry_lba]
    call flush_dir_sector
    jc .cr_io_err
    mov ax, [cs:cf_handle]
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    mov byte [cs:bx+handles+H_USED], 1
    mov byte [cs:bx+handles+H_MODE], 2
    mov word [cs:bx+handles+H_CLUSTER], 0
    mov word [cs:bx+handles+H_POS_LO], 0
    mov word [cs:bx+handles+H_POS_HI], 0
    mov word [cs:bx+handles+H_SIZE_LO], 0
    mov word [cs:bx+handles+H_SIZE_HI], 0
    mov word [cs:bx+handles+H_LAST_CLUSTER], 0
    mov word [cs:bx+handles+H_LAST_INDEX], 0
    mov ax, [cs:cf_entry_lba]
    mov [cs:bx+handles+H_DIR_LBA], ax
    mov ax, [cs:cf_entry_lba_hi]
    mov [cs:bx+handles+H_DIR_LBA_HI], ax
    mov ax, [cs:cf_entry_off]
    mov [cs:bx+handles+H_DIR_OFF], ax
    mov word [cs:bx+handles+H_TIME], FAT_TIME
    mov word [cs:bx+handles+H_DATE], FAT_DATE
    mov ax, [cs:cur_psp]
    mov [cs:bx+handles+H_OWNER], ax
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, [cs:cf_handle]
    jmp iret_nc
.cr_device:
    call alloc_device_handle
    jc .cr_device_err
    mov [cs:cf_handle], ax
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, [cs:cf_handle]
    jmp iret_nc
.cr_device_err:
    mov [cs:cf_status], ax
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
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
.cr_io_err:
    mov ax, 5
.cr_err:
    mov [cs:cf_status], ax
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, [cs:cf_status]
    jmp iret_cy
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
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
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
    mov byte [cs:di+handles+H_USED], 1
    mov al, [cs:of_mode]
    mov byte [cs:di+handles+H_MODE], al
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
    mov ax, [cs:cur_psp]
    mov [cs:di+handles+H_OWNER], ax
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
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
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
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
    jmp iret_nc
.of_device_err:
    mov [cs:of_status], ax
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
    mov ax, [cs:of_status]
    jmp iret_cy
.of_no_handles:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
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
    jb .cf_std_handle
    push bx
    push cx
    push dx
    push si
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    cmp byte [cs:bx+handles+H_USED], 0
    je .cf_invalid_pop
    mov ax, [cs:bx+handles+H_DIR_LBA]
    or ax, [cs:bx+handles+H_DIR_LBA_HI]
    je .cf_mark_free
    cmp byte [cs:bx+handles+H_MODE], 0
    je .cf_mark_free
    mov si, bx
    call flush_handle_dir_entry
    jc .cf_flush_err_pop
    call flush_fat
    jc .cf_flush_err_pop
.cf_mark_free:
    mov byte [cs:bx+handles+H_USED], 0
    mov byte [cs:bx+handles+H_MODE], 0
    mov word [cs:bx+handles+H_OWNER], 0
    pop si
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.cf_flush_err_pop:
    pop si
    pop dx
    pop cx
    pop bx
    mov ax, 5
    jmp iret_cy
.cf_invalid_pop:
    pop si
    pop dx
    pop cx
    pop bx
    jmp .cf_err
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
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov [cs:rf_hoff], ax
    mov si, ax
    mov word [cs:rf_read], 0
    cmp byte [cs:si+handles+H_USED], 0
    je .rf_err_pop
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
    mov [cs:rf_cache_lba], ax
    mov [cs:rf_cache_lba_hi], dx
    mov [cs:kio_lba_hi], dx
    push es
    push bx
    xor bx, bx
    mov dx, SEC_BUF
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
    mov dx, SEC_BUF
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
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.rf_device:
    mov ax, [cs:si+handles+H_DIR_OFF]
    cmp ax, DEV_NUL
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
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
.rf_err:
    mov ax, 6
    jmp iret_cy

.write_file:
    cmp bx, MAX_HANDLES
    jae .wf_invalid
    cmp bx, 5
    jb .wf_stdio
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
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov [cs:wf_hoff], ax
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .wf_file_invalid_pop
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
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.wf_device:
    mov ax, [cs:si+handles+H_DIR_OFF]
    cmp ax, DEV_NUL
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
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
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
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
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
    mov ax, [cs:ff_entry_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:ff_entry_lba]
    call flush_dir_sector
    jc .df_io_err
    mov si, [cs:df_first_cluster]
    call fat_free_chain
    call flush_fat
    jc .df_io_err
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
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
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, [cs:df_status]
    jmp iret_cy

.seek_file:
    cmp bx, MAX_HANDLES
    jae .sf_err
    push si
    mov [cs:sf_origin], al
    mov [cs:sf_req_lo], dx
    mov [cs:sf_req_hi], cx
    push cx
    push dx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    pop dx
    pop cx
    cmp byte [cs:si+handles+H_USED], 0
    je .sf_err_saved
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
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
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
    mov [es:di+11], al
    mov ax, [cs:ff_entry_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:ff_entry_lba]
    call flush_dir_sector
    jc .fa_set_io_err
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
    jmp iret_nc
.fa_get_nf:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
    mov ax, 2
    jmp iret_cy
.fa_set_io_err:
    mov ax, 5
    jmp .fa_set_err
.fa_set_nf:
    mov ax, 2
.fa_set_err:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ds
    pop es
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
    cmp al, 6
    je .ioctl_input_status
    cmp al, 7
    je .ioctl_output_status
    mov ax, 1
    jmp iret_cy
.ioctl_get:
    cmp bx, 5
    jb .ioctl_stdio
    cmp bx, MAX_HANDLES
    jae .ioctl_bad_handle
    push bx
    push ax
    push cx
    push dx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    pop dx
    pop cx
    pop ax
    cmp byte [cs:bx+handles+H_USED], 0
    je .ioctl_bad_handle_pop
    mov dx, [cs:bx+handles+H_DIR_LBA]
    or dx, [cs:bx+handles+H_DIR_LBA_HI]
    pop bx
    je .ioctl_stdio
    xor dh, dh
    mov dl, [cs:dos_drive_num]
    jmp iret_nc
.ioctl_stdio:
    mov dx, 0x80D3
    jmp iret_nc
.ioctl_bad_handle_pop:
    pop bx
.ioctl_bad_handle:
    mov ax, 6
    jmp iret_cy

.ioctl_input_status:
    cmp bx, 5
    jb .ioctl_input_stdio
    cmp bx, MAX_HANDLES
    jae .ioctl_bad_handle
    push bx
    push cx
    push dx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    cmp byte [cs:bx+handles+H_USED], 0
    je .ioctl_input_bad_pop
    mov ax, [cs:bx+handles+H_DIR_LBA]
    or ax, [cs:bx+handles+H_DIR_LBA_HI]
    je .ioctl_input_device_pop
    mov ax, [cs:bx+handles+H_POS_HI]
    cmp ax, [cs:bx+handles+H_SIZE_HI]
    jb .ioctl_input_ready_pop
    ja .ioctl_input_empty_pop
    mov ax, [cs:bx+handles+H_POS_LO]
    cmp ax, [cs:bx+handles+H_SIZE_LO]
    jb .ioctl_input_ready_pop
.ioctl_input_empty_pop:
    pop dx
    pop cx
    pop bx
    xor ax, ax
    jmp iret_nc
.ioctl_input_ready_pop:
    pop dx
    pop cx
    pop bx
    mov ax, 0xFFFF
    jmp iret_nc
.ioctl_input_device_pop:
    mov ax, [cs:bx+handles+H_DIR_OFF]
    pop dx
    pop cx
    pop bx
    cmp ax, DEV_CON
    je .ioctl_input_stdio
    xor ax, ax
    jmp iret_nc
.ioctl_input_bad_pop:
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
    jb .ioctl_output_ready
    push bx
    push cx
    push dx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    cmp byte [cs:bx+handles+H_USED], 0
    je .ioctl_output_bad_pop
    pop dx
    pop cx
    pop bx
.ioctl_output_ready:
    mov ax, 0xFFFF
    jmp iret_nc
.ioctl_output_bad_pop:
    pop dx
    pop cx
    pop bx
    jmp .ioctl_bad_handle

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
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
    mov ax, 2
    jmp iret_cy
.ff_err:
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
    mov ax, 3
    jmp iret_cy
.ff_found:
    call store_find_dta
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
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
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
    mov ax, 2
    jmp iret_cy
.fn_found:
    call store_find_dta
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
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
    mov ax, [cs:ff_entry_idx]
    mov [cs:rn_src_idx], ax
    mov [cs:rn_src_off], di
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
    cmp word [cs:rn_src_lba_hi], 0
    jne .rn_load_subdir
    mov ax, [cs:rn_src_lba]
    cmp ax, [cs:krsta]
    jb .rn_load_subdir
    cmp ax, [cs:kdsta]
    jae .rn_load_subdir
    mov ax, ROOT_SEG
    mov es, ax
    mov di, [cs:rn_src_off]
    jmp .rn_write_name
.rn_load_subdir:
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:rn_src_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:rn_src_lba]
    call read_sector
    jc .rn_access
    mov di, [cs:rn_src_dir_off]
.rn_write_name:
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    mov ax, [cs:rn_src_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:rn_src_lba]
    call flush_dir_sector
    jc .rn_access
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
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
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
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
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .ft_bad_handle_saved
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
