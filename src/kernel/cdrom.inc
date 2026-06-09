cd_read_sector_drive:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    mov [cs:cd_lba_lo], ax
    mov [cs:cd_lba_hi], dx
    mov word [cs:cd_dap+2], 1
    mov [cs:cd_dap+4], bx
    mov ax, es
    mov [cs:cd_dap+6], ax
    mov ax, [cs:cd_lba_lo]
    mov [cs:cd_dap+8], ax
    mov ax, [cs:cd_lba_hi]
    mov [cs:cd_dap+10], ax
    mov word [cs:cd_dap+12], 0
    mov word [cs:cd_dap+14], 0
    push cs
    pop ds
    mov si, cd_dap
    mov dl, [cs:cd_io_drive]
    mov ah, 0x42
    int 0x13
    jc .err
    clc
    jmp .done
.err:
    stc
.done:
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cd_read_sector_current:
    push ax
    mov al, [cs:kdrv]
    mov [cs:cd_io_drive], al
    pop ax
    jmp cd_read_sector_drive

mount_bios_cdrom_d:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov byte [cs:drive_present+3], 0
    mov byte [cs:cd_present], 0
    mov dl, 0x80
.probe:
    cmp dl, 0xF0
    jae .err
    mov [cs:cd_probe_drive], dl
    mov ax, 0x4100
    mov bx, 0x55AA
    int 0x13
    jc .next
    cmp bx, 0xAA55
    jne .next
    mov ax, CD_BUF
    mov es, ax
    xor bx, bx
    mov al, [cs:cd_probe_drive]
    mov [cs:cd_io_drive], al
    mov ax, 16
    xor dx, dx
    call cd_read_sector_drive
    jc .next
    mov ax, CD_BUF
    mov ds, ax
    cmp byte [1], 'C'
    jne .next
    cmp byte [2], 'D'
    jne .next
    cmp byte [3], '0'
    jne .next
    cmp byte [4], '0'
    jne .next
    cmp byte [5], '1'
    jne .next
    mov si, 156
    mov ax, [si+2]
    mov [cs:cd_root_lba_lo], ax
    mov ax, [si+4]
    mov [cs:cd_root_lba_hi], ax
    mov ax, [si+10]
    mov [cs:cd_root_size_lo], ax
    mov ax, [si+12]
    mov [cs:cd_root_size_hi], ax
    mov al, [cs:cd_probe_drive]
    mov [cs:cd_bios_drive], al
    mov [cs:drive_bios+3], al
    mov byte [cs:drive_type+3], DRIVE_TYPE_CDROM
    mov byte [cs:drive_present+3], 1
    mov byte [cs:cd_present], 1
    mov word [cs:drive_cur_clusters+3*2], ROOT_CLUSTER
    push cs
    pop es
    mov di, drive_cur_paths + 3*64
    mov cx, 64
    xor ax, ax
    rep stosb
    clc
    jmp .done
.next:
    mov dl, [cs:cd_probe_drive]
    inc dl
    jmp .probe
.err:
    stc
.done:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cd_prepare_path:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    mov bx, si
    mov al, [ds:bx]
    call ascii_upper
    cmp al, 'A'
    jb .check_sep
    cmp al, 'Z'
    ja .check_sep
    cmp byte [ds:bx+1], ':'
    jne .check_sep
    add bx, 2
.check_sep:
    push cs
    pop es
    mov di, cd_full_path
    mov cx, 127
    cmp byte [ds:bx], '\'
    je .abs_skip_sep
    cmp byte [ds:bx], '/'
    je .abs_skip_sep
    push ds
    push cs
    pop ds
    mov si, cur_dir_path
.cwd_copy:
    lodsb
    test al, al
    jz .cwd_done
    call .store_char
    jc .cwd_err
    jmp .cwd_copy
.cwd_err:
    pop ds
    jmp .err
.cwd_done:
    pop ds
    cmp di, cd_full_path
    je .copy_input
    cmp byte [ds:bx], 0
    je .finish
    mov al, '\'
    call .store_char
    jc .err
    jmp .copy_input
.abs_skip_sep:
    cmp byte [ds:bx], '\'
    je .skip_sep
    cmp byte [ds:bx], '/'
    jne .copy_input
.skip_sep:
    inc bx
    jmp .abs_skip_sep
.copy_input:
    cmp byte [ds:bx], 0
    je .finish
    mov al, [ds:bx]
    inc bx
    cmp al, '/'
    je .slash
    cmp al, '\'
    je .slash
    call ascii_upper
    jmp .store_input
.slash:
    mov al, '\'
.store_input:
    call .store_char
    jc .err
    jmp .copy_input
.finish:
    mov byte [es:di], 0
    push cs
    pop ax
    mov [cs:cd_path_seg], ax
    mov word [cs:cd_path_off], cd_full_path
    mov ax, [cs:cd_root_lba_lo]
    mov [cs:cd_dir_lba_lo], ax
    mov ax, [cs:cd_root_lba_hi]
    mov [cs:cd_dir_lba_hi], ax
    mov ax, [cs:cd_root_size_lo]
    mov [cs:cd_dir_size_lo], ax
    mov ax, [cs:cd_root_size_hi]
    mov [cs:cd_dir_size_hi], ax
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    clc
    ret
.store_char:
    test cx, cx
    jz .store_err
    stosb
    dec cx
    clc
    ret
.store_err:
    stc
    ret
.err:
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    stc
    ret

cd_parse_next_component:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov ds, [cs:cd_path_seg]
    mov si, [cs:cd_path_off]
.skip_sep:
    cmp byte [ds:si], '\'
    je .skip_one
    cmp byte [ds:si], '/'
    jne .have_component
.skip_one:
    inc si
    jmp .skip_sep
.have_component:
    cmp byte [ds:si], 0
    je .err
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    mov al, ' '
    rep stosb
    mov byte [cs:cd_seen_name], 0
    mov di, name_buf
.copy:
    lodsb
    test al, al
    jz .done_name
    cmp al, '\'
    je .done_sep
    cmp al, '/'
    je .done_sep
    call ascii_upper
    cmp al, '.'
    je .dot
    cmp di, name_buf + 11
    jae .err
    stosb
    mov byte [cs:cd_seen_name], 1
    jmp .copy
.dot:
    mov di, name_buf + 8
    jmp .copy
.done_sep:
    mov byte [cs:cd_path_last], 0
    mov [cs:cd_path_off], si
    jmp .finish_name
.done_name:
    mov byte [cs:cd_path_last], 1
    mov [cs:cd_path_off], si
.finish_name:
    cmp byte [cs:cd_seen_name], 0
    je .err
    clc
    jmp .done
.err:
    stc
.done:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cd_open_path:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    call cd_prepare_path
    jc .err
    call cd_parse_next_component
    jc .err
.component_loop:
    call cd_scan_current_dir
    jc .err
    cmp byte [cs:cd_path_last], 0
    jne .last_component
    test byte [cs:cd_record_flags], 2
    jz .err
    mov ax, [cs:cd_file_lba_lo]
    mov [cs:cd_dir_lba_lo], ax
    mov ax, [cs:cd_file_lba_hi]
    mov [cs:cd_dir_lba_hi], ax
    mov ax, [cs:cd_file_size_lo]
    mov [cs:cd_dir_size_lo], ax
    mov ax, [cs:cd_file_size_hi]
    mov [cs:cd_dir_size_hi], ax
    call cd_parse_next_component
    jc .err
    jmp .component_loop
.last_component:
    test byte [cs:cd_record_flags], 2
    jnz .err
    clc
    jmp .done
.err:
    stc
.done:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cd_open_dir_path:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    call cd_prepare_path
    jc .err
    mov ds, [cs:cd_path_seg]
    mov si, [cs:cd_path_off]
    cmp byte [ds:si], 0
    je .root
    call cd_parse_next_component
    jc .err
.component_loop:
    call cd_scan_current_dir
    jc .err
    test byte [cs:cd_record_flags], 2
    jz .err
    mov ax, [cs:cd_file_lba_lo]
    mov [cs:cd_dir_lba_lo], ax
    mov ax, [cs:cd_file_lba_hi]
    mov [cs:cd_dir_lba_hi], ax
    mov ax, [cs:cd_file_size_lo]
    mov [cs:cd_dir_size_lo], ax
    mov ax, [cs:cd_file_size_hi]
    mov [cs:cd_dir_size_hi], ax
    cmp byte [cs:cd_path_last], 0
    jne .ok
    call cd_parse_next_component
    jc .err
    jmp .component_loop
.root:
    mov ax, [cs:cd_root_lba_lo]
    mov [cs:cd_file_lba_lo], ax
    mov ax, [cs:cd_root_lba_hi]
    mov [cs:cd_file_lba_hi], ax
    mov ax, [cs:cd_root_size_lo]
    mov [cs:cd_file_size_lo], ax
    mov ax, [cs:cd_root_size_hi]
    mov [cs:cd_file_size_hi], ax
.ok:
    clc
    jmp .done
.err:
    stc
.done:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cd_copy_full_path_to_cwd:
    push ax
    push cx
    push ds
    push es
    push si
    push di
    push cs
    pop ds
    push cs
    pop es
    mov si, cd_full_path
    mov di, cur_dir_path
    mov cx, 63
.copy:
    lodsb
    test al, al
    jz .done
    stosb
    loop .copy
.done:
    mov byte [es:di], 0
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop ax
    ret

cd_scan_current_dir:
    push ax
    push bx
    push cx
    push dx
    push es
    cmp word [cs:cd_dir_size_hi], 0
    jne .err
    mov ax, [cs:cd_dir_size_lo]
    add ax, 2047
    jc .err
    mov cx, 11
.sector_count_shift:
    shr ax, 1
    loop .sector_count_shift
    test ax, ax
    jz .err
    mov [cs:cd_scan_sectors], ax
    mov ax, [cs:cd_dir_lba_lo]
    mov [cs:cd_scan_lba_lo], ax
    mov ax, [cs:cd_dir_lba_hi]
    mov [cs:cd_scan_lba_hi], ax
.sector_loop:
    cmp word [cs:cd_scan_sectors], 0
    je .err
    mov ax, CD_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:cd_scan_lba_lo]
    mov dx, [cs:cd_scan_lba_hi]
    call cd_read_sector_current
    jc .err
    call cd_scan_sector
    jnc .ok
    inc word [cs:cd_scan_lba_lo]
    jnz .lba_ok
    inc word [cs:cd_scan_lba_hi]
.lba_ok:
    dec word [cs:cd_scan_sectors]
    jmp .sector_loop
.ok:
    clc
    jmp .done
.err:
    stc
.done:
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cd_scan_sector:
    push ax
    push bx
    push cx
    push dx
    push ds
    push si
    mov ax, CD_BUF
    mov ds, ax
    xor si, si
    mov word [cs:cd_sector_left], 2048
.record_loop:
    cmp word [cs:cd_sector_left], 0
    je .err
    xor ah, ah
    mov al, [si]
    test al, al
    jz .err
    mov [cs:cd_record_len], ax
    cmp ax, [cs:cd_sector_left]
    ja .err
    cmp al, 33
    jb .next
    call cd_record_name_match
    jc .next
    mov al, [si+25]
    mov [cs:cd_record_flags], al
    mov ax, [si+2]
    mov [cs:cd_file_lba_lo], ax
    mov ax, [si+4]
    mov [cs:cd_file_lba_hi], ax
    mov ax, [si+10]
    mov [cs:cd_file_size_lo], ax
    mov ax, [si+12]
    mov [cs:cd_file_size_hi], ax
    clc
    jmp .done
.next:
    mov ax, [cs:cd_record_len]
    add si, ax
    sub [cs:cd_sector_left], ax
    jmp .record_loop
.err:
    stc
.done:
    pop si
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cd_record_name_match:
    push ax
    push bx
    push cx
    call cd_record_name_to_83
    jc .err
.compare:
    xor bx, bx
.compare_loop:
    cmp bx, 11
    jae .match
    mov al, [cs:name_buf+bx]
    cmp al, [cs:cd_cmp_name+bx]
    jne .err
    inc bx
    jmp .compare_loop
.match:
    clc
    jmp .done
.err:
    stc
.done:
    pop cx
    pop bx
    pop ax
    ret

cd_record_name_to_83:
    push ax
    push bx
    push cx
    push es
    push si
    push di
    push cs
    pop es
    mov di, cd_cmp_name
    mov cx, 11
    mov al, ' '
    rep stosb
    xor ch, ch
    mov cl, [si+32]
    jcxz .err
    mov bx, si
    add bx, 33
    cmp cl, 1
    jne .normal
    cmp byte [bx], 0
    je .err
    cmp byte [bx], 1
    je .err
.normal:
    mov si, bx
    mov di, cd_cmp_name
.copy:
    test cx, cx
    jz .ok
    lodsb
    dec cx
    cmp al, ';'
    je .ok
    cmp al, '.'
    je .dot
    call ascii_upper
    cmp di, cd_cmp_name + 11
    jae .copy
    stosb
    jmp .copy
.dot:
    mov di, cd_cmp_name + 8
    jmp .copy
.ok:
    clc
    jmp .done
.err:
    stc
.done:
    pop di
    pop si
    pop es
    pop cx
    pop bx
    pop ax
    ret

cd_find_root_from:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov [cs:cd_find_start], bx
    mov word [cs:fid_idx], 0
    cmp word [cs:cd_root_size_hi], 0
    jne .err
    mov ax, [cs:cd_root_size_lo]
    add ax, 2047
    jc .err
    mov cx, 11
.sector_count_shift:
    shr ax, 1
    loop .sector_count_shift
    test ax, ax
    jz .err
    mov [cs:cd_scan_sectors], ax
    mov ax, [cs:cd_root_lba_lo]
    mov [cs:cd_scan_lba_lo], ax
    mov ax, [cs:cd_root_lba_hi]
    mov [cs:cd_scan_lba_hi], ax
.sector_loop:
    cmp word [cs:cd_scan_sectors], 0
    je .err
    mov ax, CD_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:cd_scan_lba_lo]
    mov dx, [cs:cd_scan_lba_hi]
    call cd_read_sector_current
    jc .err
    call cd_find_scan_sector
    jnc .ok
    inc word [cs:cd_scan_lba_lo]
    jnz .lba_ok
    inc word [cs:cd_scan_lba_hi]
.lba_ok:
    dec word [cs:cd_scan_sectors]
    jmp .sector_loop
.ok:
    clc
    jmp .done
.err:
    stc
.done:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cd_find_scan_sector:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov ax, CD_BUF
    mov ds, ax
    xor si, si
    mov word [cs:cd_sector_left], 2048
.record_loop:
    cmp word [cs:cd_sector_left], 0
    je .err
    xor ah, ah
    mov al, [si]
    test al, al
    jz .err
    mov [cs:cd_record_len], ax
    cmp ax, [cs:cd_sector_left]
    ja .err
    cmp al, 33
    jb .next
    mov ax, [cs:fid_idx]
    cmp ax, [cs:cd_find_start]
    jb .next
    call cd_record_name_to_83
    jc .next
    mov al, [si+25]
    test al, 2
    jz .file_attr
    mov al, ATTR_RDONLY | ATTR_DIR
    jmp .have_attr
.file_attr:
    mov al, ATTR_RDONLY
.have_attr:
    mov [cs:ff_entry_attr], al
    call cd_attr_match
    jc .next
    push cs
    pop es
    mov di, cd_cmp_name
    call name_matches
    jc .next
    mov ax, [si+10]
    mov [cs:ff_entry_size], ax
    mov ax, [si+12]
    mov [cs:ff_entry_size_hi], ax
    mov word [cs:ff_entry_cluster], ROOT_CLUSTER
    mov word [cs:ff_entry_time], FAT_TIME
    mov word [cs:ff_entry_date], FAT_DATE
    mov ax, [cs:fid_idx]
    mov [cs:ff_entry_idx], ax
    mov ax, [cs:cd_scan_lba_lo]
    mov [cs:ff_entry_lba], ax
    mov ax, [cs:cd_scan_lba_hi]
    mov [cs:ff_entry_lba_hi], ax
    mov ax, si
    mov [cs:ff_entry_off], ax
    push ds
    push es
    push cs
    pop ds
    push cs
    pop es
    mov si, cd_cmp_name
    mov di, ff_entry_name
    mov cx, 11
    rep movsb
    pop es
    pop ds
    clc
    jmp .done
.next:
    inc word [cs:fid_idx]
    mov ax, [cs:cd_record_len]
    add si, ax
    sub [cs:cd_sector_left], ax
    jmp .record_loop
.err:
    stc
.done:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cd_attr_match:
    push ax
    mov ah, [cs:ff_attr_mask]
    test ah, ATTR_VOLUME
    jz .not_volume_search
    test al, ATTR_VOLUME
    jnz .yes
    jmp .no
.not_volume_search:
    test al, ATTR_VOLUME
    jnz .no
    test al, ATTR_HIDDEN
    jz .check_system
    test ah, ATTR_HIDDEN
    jz .no
.check_system:
    test al, ATTR_SYSTEM
    jz .check_dir
    test ah, ATTR_SYSTEM
    jz .no
.check_dir:
    test al, ATTR_DIR
    jz .yes
    test ah, ATTR_DIR
    jz .no
.yes:
    pop ax
    clc
    ret
.no:
    pop ax
    stc
    ret

cd_read_handle:
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
.loop:
    mov cx, [cs:rf_count]
    test cx, cx
    jz .done
    mov bx, [cs:rf_hoff]
    mov ax, [cs:bx+handles+H_POS_HI]
    cmp ax, [cs:bx+handles+H_SIZE_HI]
    ja .done
    jb .read_more
    mov ax, [cs:bx+handles+H_POS_LO]
    cmp ax, [cs:bx+handles+H_SIZE_LO]
    jae .done
.read_more:
    mov ax, [cs:bx+handles+H_POS_LO]
    mov dx, [cs:bx+handles+H_POS_HI]
    mov cx, 11
.sector_shift:
    shr dx, 1
    rcr ax, 1
    loop .sector_shift
    add ax, [cs:bx+handles+H_CLUSTER]
    adc dx, [cs:bx+handles+H_LAST_CLUSTER]
    mov bx, CD_BUF
    mov es, bx
    xor bx, bx
    call cd_read_sector_current
    jc .err
    mov bx, [cs:rf_hoff]
    mov ax, [cs:bx+handles+H_POS_LO]
    and ax, 2047
    mov si, ax
    mov cx, 2048
    sub cx, si
    mov ax, [cs:rf_count]
    cmp cx, ax
    jbe .request_limited
    mov cx, ax
.request_limited:
    mov ax, [cs:bx+handles+H_POS_HI]
    cmp ax, [cs:bx+handles+H_SIZE_HI]
    jne .size_limited
    mov ax, [cs:bx+handles+H_SIZE_LO]
    sub ax, [cs:bx+handles+H_POS_LO]
    cmp cx, ax
    jbe .size_limited
    mov cx, ax
.size_limited:
    mov ax, [cs:rf_buf_seg]
    mov es, ax
    mov di, [cs:rf_buf_off]
    mov ax, CD_BUF
    mov ds, ax
    mov ax, [cs:rf_buf_off]
    test ax, ax
    jz .copy
    neg ax
    cmp cx, ax
    jbe .copy
    mov cx, ax
.copy:
    push cx
    rep movsb
    pop cx
    mov bx, [cs:rf_hoff]
    add [cs:bx+handles+H_POS_LO], cx
    adc word [cs:bx+handles+H_POS_HI], 0
    mov ax, [cs:rf_buf_off]
    add ax, cx
    mov [cs:rf_buf_off], ax
    jnc .buf_ok
    add word [cs:rf_buf_seg], 0x1000
.buf_ok:
    sub [cs:rf_count], cx
    add [cs:rf_read], cx
    jmp .loop
.done:
    clc
    jmp .finish
.err:
    stc
.finish:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    ret
