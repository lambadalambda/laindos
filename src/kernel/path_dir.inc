alloc_handle:
    push bx
    push si
    mov bx, 5
.ah_loop:
    cmp bx, MAX_HANDLES
    jae .ah_full
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .ah_found
    inc bx
    jmp .ah_loop
.ah_found:
    mov ax, bx
    pop si
    pop bx
    clc
    ret
.ah_full:
    pop si
    pop bx
    stc
    ret

alloc_device_handle:
    cmp al, DEV_CON
    je .supported
    cmp al, DEV_NUL
    je .supported
    mov ax, 5
    stc
    ret
.supported:
    mov [cs:dev_type], al
    call alloc_handle
    jc .full
    push ax
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
    mov word [cs:bx+handles+H_DIR_LBA], 0
    mov word [cs:bx+handles+H_DIR_LBA_HI], 0
    xor ah, ah
    mov al, [cs:dev_type]
    mov [cs:bx+handles+H_DIR_OFF], ax
    mov word [cs:bx+handles+H_TIME], 0
    mov word [cs:bx+handles+H_DATE], 0
    mov ax, [cs:cur_psp]
    mov [cs:bx+handles+H_OWNER], ax
    pop ax
    clc
    ret
.full:
    mov ax, 4
    stc
    ret

detect_device_path:
    push bx
    push dx
    push si
    cmp byte [ds:si+1], ':'
    jne .skip_sep
    add si, 2
.skip_sep:
    cmp byte [ds:si], '\'
    je .skip_one
    cmp byte [ds:si], '/'
    jne .read_name
.skip_one:
    inc si
    jmp .skip_sep
.read_name:
    cmp byte [ds:si], 0
    je .not_found
    call dev_upper_lodsb
    mov bl, al
    cmp byte [ds:si], 0
    je .not_found
    call dev_upper_lodsb
    mov bh, al
    cmp byte [ds:si], 0
    je .not_found
    call dev_upper_lodsb
    mov dl, al
    call dev_name_end
    jc .not_found
    cmp bl, 'C'
    jne .try_nul
    cmp bh, 'O'
    jne .try_nul
    cmp dl, 'N'
    jne .try_nul
    mov al, DEV_CON
    jmp .found
.try_nul:
    cmp bl, 'N'
    jne .try_aux
    cmp bh, 'U'
    jne .try_aux
    cmp dl, 'L'
    jne .try_aux
    mov al, DEV_NUL
    jmp .found
.try_aux:
    cmp bl, 'A'
    jne .try_prn
    cmp bh, 'U'
    jne .try_prn
    cmp dl, 'X'
    jne .try_prn
    mov al, DEV_AUX
    jmp .found
.try_prn:
    cmp bl, 'P'
    jne .not_found
    cmp bh, 'R'
    jne .not_found
    cmp dl, 'N'
    jne .not_found
    mov al, DEV_PRN
.found:
    pop si
    pop dx
    pop bx
    clc
    ret
.not_found:
    pop si
    pop dx
    pop bx
    stc
    ret

dev_upper_lodsb:
    lodsb
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    sub al, 32
.done:
    ret

dev_name_end:
    mov al, [ds:si]
    test al, al
    jz .yes
    cmp al, '.'
    je .yes
    cmp al, ' '
    je .yes
    stc
    ret
.yes:
    clc
    ret

cur_dir_path_parent:
    push ax
    push bx
    push ds
    push si
    push cs
    pop ds
    mov si, cur_dir_path
    xor bx, bx
.cdpp_loop:
    mov al, [si]
    test al, al
    jz .cdpp_done
    cmp al, '\'
    jne .cdpp_next
    mov bx, si
.cdpp_next:
    inc si
    jmp .cdpp_loop
.cdpp_done:
    test bx, bx
    jz .cdpp_root
    mov byte [bx], 0
    jmp .cdpp_ret
.cdpp_root:
    mov byte [cur_dir_path], 0
.cdpp_ret:
    pop si
    pop ds
    pop bx
    pop ax
    ret

resolve_path:
    push bx
    mov [cs:rp_path], si
    mov [cs:rp_path_seg], ds
    cmp byte [ds:si], '\'
    je .rp_abs
    cmp byte [ds:si], '/'
    je .rp_abs
    cmp byte [ds:si], 'A'
    jb .rp_rel
    cmp byte [ds:si], 'Z'
    ja .rp_rel
    cmp byte [ds:si+1], ':'
    jne .rp_rel
.rp_abs:
    add si, 2
    cmp byte [ds:si-1], ':'
    je .rp_abs_skip
    sub si, 2
.rp_abs_skip:
    mov [cs:rp_path], si
    mov ax, ROOT_CLUSTER
    jmp .rp_walk
.rp_rel:
    mov ax, [cs:cur_dir_cluster]
.rp_walk:
    mov [cs:rp_cluster], ax
.rp_next:
    mov ds, [cs:rp_path_seg]
    mov si, [cs:rp_path]
.rp_skip_sep:
    cmp byte [ds:si], '\'
    je .rp_sep
    cmp byte [ds:si], '/'
    je .rp_sep
    jmp .rp_have_name
.rp_sep:
    inc si
    mov [cs:rp_path], si
    jmp .rp_skip_sep
.rp_have_name:
    cmp byte [ds:si], 0
    je .rp_empty
    cmp byte [ds:si], ':'
    jne .rp_parse_name
    inc si
    inc si
    mov [cs:rp_path], si
    jmp .rp_skip_sep
.rp_empty:
    cmp word [cs:rp_cluster], ROOT_CLUSTER
    je .rp_empty_root
    stc
    pop bx
    ret
.rp_empty_root:
    stc
    pop bx
    ret
.rp_parse_name:
    push ds
    push es
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    mov al, ' '
    rep stosb
    mov di, name_buf
    cld
    mov ds, [cs:rp_path_seg]
    mov si, [cs:rp_path]
    cmp byte [ds:si], '.'
    jne .rp_copy
    mov al, [ds:si+1]
    test al, al
    jz .rp_special_dot_end
    cmp al, '\'
    je .rp_special_dot_sep
    cmp al, '/'
    je .rp_special_dot_sep
    cmp al, '.'
    jne .rp_copy
    mov al, [ds:si+2]
    test al, al
    jz .rp_special_dotdot_end
    cmp al, '\'
    je .rp_special_dotdot_sep
    cmp al, '/'
    jne .rp_copy
.rp_special_dotdot_sep:
    add si, 3
    cmp word [cs:rp_cluster], ROOT_CLUSTER
    je .rp_skip_component
    mov byte [es:name_buf], '.'
    mov byte [es:name_buf+1], '.'
    jmp .rp_copy_sep
.rp_special_dotdot_end:
    mov byte [es:name_buf], '.'
    mov byte [es:name_buf+1], '.'
    add si, 2
    jmp .rp_copy_end
.rp_special_dot_sep:
    add si, 2
    jmp .rp_skip_component
.rp_special_dot_end:
    mov byte [es:name_buf], '.'
    inc si
    jmp .rp_copy_end
.rp_skip_component:
    mov [cs:rp_path], si
    pop es
    pop ds
    jmp .rp_next
.rp_copy:
    mov ds, [cs:rp_path_seg]
    mov si, [cs:rp_path]
    lodsb
    cmp al, 0
    je .rp_copy_end
    cmp al, '\'
    je .rp_copy_sep
    cmp al, '/'
    je .rp_copy_sep
    cmp al, 'a'
    jb .rp_no_lower
    cmp al, 'z'
    ja .rp_no_lower
    sub al, 32
.rp_no_lower:
    cmp al, '.'
    je .rp_dot
    stosb
    jmp .rp_adv
.rp_dot:
    mov di, name_buf + 8
    jmp .rp_adv
.rp_adv:
    mov [cs:rp_path], si
    jmp .rp_copy
.rp_copy_sep:
    mov [cs:rp_path], si
    pop es
    pop ds
    mov ax, [cs:rp_cluster]
    xor bx, bx
    xor dx, dx
    mov byte [cs:ff_attr_mask], 0
    call find_in_dir
    jc .rp_notfound
    test byte [es:di+11], ATTR_DIR
    jz .rp_notadir
    mov ax, [es:di+26]
    mov [cs:rp_cluster], ax
    jmp .rp_next
.rp_notadir:
    stc
    pop bx
    ret
.rp_copy_end:
    pop es
    pop ds
    mov ax, [cs:rp_cluster]
    xor bx, bx
    xor dx, dx
    mov byte [cs:ff_attr_mask], 0
    call find_in_dir
    jc .rp_notfound
    pop bx
    ret
.rp_notfound:
    stc
    pop bx
    ret

find_in_dir:
    xor bx, bx
    mov byte [cs:ff_filter_attrs], 0
    jmp find_in_dir_from_common
find_in_dir_filtered:
    xor bx, bx
    mov byte [cs:ff_filter_attrs], 1
    jmp find_in_dir_from_common
find_in_dir_from:
    mov byte [cs:ff_filter_attrs], 1
find_in_dir_from_common:
    push ax
    push cx
    push ds
    push si
    mov [cs:fid_cluster], ax
    mov [cs:fid_idx], bx
.rid_loop:
    mov ax, [cs:fid_cluster]
    cmp ax, ROOT_CLUSTER
    jne .rid_subdir
    mov ax, ROOT_SEG
    mov es, ax
    mov cx, [cs:fid_idx]
    cmp cx, [cs:kroot_entries]
    jae .rid_notfound
    mov ax, cx
    mov dx, 32
    mul dx
    mov di, ax
    mov ax, cx
    push cx
    mov cl, 4
    shr ax, cl
    pop cx
    add ax, [cs:krsta]
    mov [cs:ff_entry_lba], ax
    mov word [cs:ff_entry_lba_hi], 0
    mov ax, di
    and ax, 511
    mov [cs:ff_entry_off], ax
    cmp di, [cs:kroot_bytes]
    jae .rid_notfound
    cmp byte [es:di], 0
    je .rid_notfound
    cmp byte [es:di], 0xE5
    je .rid_root_next
    cmp byte [cs:ff_filter_attrs], 0
    jne .rid_root_filtered
    test byte [es:di+11], ATTR_VOLUME
    jnz .rid_root_next
    jmp .rid_root_matchable
.rid_root_filtered:
    call dir_entry_attr_match
    jc .rid_root_next
.rid_root_matchable:
    call name_matches
    jnc .rid_found
.rid_root_next:
    inc cx
    mov [cs:fid_idx], cx
    jmp .rid_loop
.rid_subdir:
    push bx
    push dx
    mov [cs:rid_clus], ax
    xor cx, cx
.rid_cluster_loop:
    mov si, [cs:rid_clus]
    cmp si, [cs:kfat_eoc]
    jae .rid_notfound_pop
    mov ax, si
    push bx
    xor bx, bx
    call cluster_lba
    pop bx
    mov [cs:rid_lba], ax
    mov [cs:rid_lba_hi], dx
    mov byte [cs:rid_sec_idx], 0
.rid_sec_loop:
    xor bx, bx
    mov dx, SEC_BUF
    mov es, dx
    mov ax, [cs:rid_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:rid_lba]
    push cx
    call read_sector
    pop cx
    jc .rid_notfound_pop
    mov ax, SEC_BUF
    mov es, ax
    xor di, di
    mov bx, 16
.rid_entry:
    cmp byte [es:di], 0
    je .rid_notfound_pop
    cmp cx, [cs:fid_idx]
    jb .rid_subdir_next
    cmp byte [es:di], 0xE5
    je .rid_subdir_next
    cmp byte [cs:ff_filter_attrs], 0
    jne .rid_subdir_filtered
    test byte [es:di+11], ATTR_VOLUME
    jnz .rid_subdir_next
    jmp .rid_subdir_matchable
.rid_subdir_filtered:
    call dir_entry_attr_match
    jc .rid_subdir_next
.rid_subdir_matchable:
    mov ax, SEC_BUF
    mov es, ax
    call name_matches
    jnc .rid_found_subdir
.rid_subdir_next:
    inc cx
    add di, 32
    dec bx
    jnz .rid_entry
.rid_next_sec:
    inc word [cs:rid_lba]
    jnz .rid_lba_inc_done
    inc word [cs:rid_lba_hi]
.rid_lba_inc_done:
    inc byte [cs:rid_sec_idx]
    mov al, [cs:rid_sec_idx]
    cmp al, [cs:kspc]
    jb .rid_sec_loop
    mov si, [cs:rid_clus]
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .rid_notfound_pop
    cmp ax, [cs:kfat_reserved]
    jae .rid_notfound_pop
    cmp ax, 2
    jb .rid_notfound_pop
    mov [cs:rid_clus], ax
    jmp .rid_cluster_loop
.rid_found_subdir:
    mov ax, [cs:rid_lba]
    mov [cs:ff_entry_lba], ax
    mov ax, [cs:rid_lba_hi]
    mov [cs:ff_entry_lba_hi], ax
    mov ax, di
    mov [cs:ff_entry_off], ax
    pop dx
    pop bx
.rid_found:
    mov al, [es:di+11]
    mov [cs:ff_entry_attr], al
    mov ax, [es:di+22]
    mov [cs:ff_entry_time], ax
    mov ax, [es:di+24]
    mov [cs:ff_entry_date], ax
    mov ax, [es:di+26]
    mov [cs:ff_entry_cluster], ax
    mov ax, [es:di+28]
    mov [cs:ff_entry_size], ax
    mov ax, [es:di+30]
    mov [cs:ff_entry_size_hi], ax
    mov [cs:ff_entry_idx], cx
    push cx
    push ds
    push si
    push di
    push es
    push es
    pop ds
    mov si, di
    push cs
    pop es
    mov di, ff_entry_name
    mov cx, 11
    rep movsb
    pop es
    pop di
    pop si
    pop ds
    pop cx
    pop si
    pop ds
    pop cx
    pop ax
    clc
    ret

.rid_notfound_pop:
    pop dx
    pop bx
.rid_notfound:
    pop si
    pop ds
    pop cx
    pop ax
    stc
    ret

find_root_free:
    push ax
    mov ax, ROOT_SEG
    mov es, ax
    xor di, di
    xor cx, cx
.loop:
    cmp cx, [cs:kroot_entries]
    jae .full
    cmp byte [es:di], 0
    je .found
    cmp byte [es:di], 0xE5
    je .found
    add di, 32
    inc cx
    jmp .loop
.found:
    pop ax
    clc
    ret
.full:
    pop ax
    stc
    ret

root_entry_loc_from_cx:
    push ax
    push cx
    push dx
    mov ax, cx
    mov dx, ax
    shr ax, 1
    shr ax, 1
    shr ax, 1
    shr ax, 1
    add ax, [cs:krsta]
    mov [cs:ff_entry_lba], ax
    mov word [cs:ff_entry_lba_hi], 0
    mov ax, dx
    and ax, 0x000F
    mov dx, 32
    mul dx
    mov [cs:ff_entry_off], ax
    pop dx
    pop cx
    pop ax
    ret

find_dir_free:
    cmp ax, ROOT_CLUSTER
    jne .subdir
    call find_root_free
    jc .err
    call root_entry_loc_from_cx
    clc
    ret
.subdir:
    push bx
    push dx
    push si
    mov [cs:rid_clus], ax
    mov word [cs:ff_entry_idx], 0
.sd_cluster_loop:
    mov si, [cs:rid_clus]
    cmp si, [cs:kfat_eoc]
    jae .sd_full
    cmp si, 2
    jb .sd_full
    mov ax, si
    xor bx, bx
    call cluster_lba
    mov [cs:rid_lba], ax
    mov [cs:rid_lba_hi], dx
    mov byte [cs:rid_sec_idx], 0
.sd_sector:
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    mov ax, [cs:rid_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:rid_lba]
    call read_sector
    jc .sd_full
    mov ax, SEC_BUF
    mov es, ax
    xor di, di
    mov cx, 16
.sd_entry:
    cmp byte [es:di], 0
    je .sd_found
    cmp byte [es:di], 0xE5
    je .sd_found
    add di, 32
    inc word [cs:ff_entry_idx]
    loop .sd_entry
    inc word [cs:rid_lba]
    jnz .sd_lba_inc_done
    inc word [cs:rid_lba_hi]
.sd_lba_inc_done:
    inc byte [cs:rid_sec_idx]
    mov al, [cs:rid_sec_idx]
    cmp al, [cs:kspc]
    jb .sd_sector
    mov si, [cs:rid_clus]
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .sd_extend
    cmp ax, [cs:kfat_reserved]
    jae .sd_full
    cmp ax, 2
    jb .sd_full
    mov [cs:rid_clus], ax
    jmp .sd_cluster_loop
.sd_extend:
    mov [cs:dir_ext_old_next], ax
    call fat_alloc_cluster
    jc .sd_full
    mov [cs:dir_ext_cluster], ax
    mov si, [cs:rid_clus]
    call fat_set
    mov ax, [cs:dir_ext_cluster]
    xor bx, bx
    call cluster_lba
    mov [cs:rid_lba], ax
    mov [cs:rid_lba_hi], dx
    mov [cs:ff_entry_lba], ax
    mov [cs:ff_entry_lba_hi], dx
    mov byte [cs:rid_sec_idx], 0
.sd_zero_sector:
    mov ax, SEC_BUF
    mov es, ax
    xor di, di
    xor ax, ax
    mov cx, 256
    cld
    rep stosw
    xor bx, bx
    mov ax, [cs:rid_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:rid_lba]
%ifdef TEST_DIR_EXT_ZERO_FAIL
    cmp byte [cs:dir_ext_fail_once], 0
    jne .sd_write_sector
    mov byte [cs:dir_ext_fail_once], 1
    stc
    jmp .sd_rollback
.sd_write_sector:
%endif
    call write_sector
    jc .sd_rollback
    inc word [cs:rid_lba]
    jnz .sd_ext_lba_inc_done
    inc word [cs:rid_lba_hi]
.sd_ext_lba_inc_done:
    inc byte [cs:rid_sec_idx]
    mov al, [cs:rid_sec_idx]
    cmp al, [cs:kspc]
    jb .sd_zero_sector
    call flush_fat
    jc .sd_rollback
    mov ax, SEC_BUF
    mov es, ax
    xor di, di
    mov word [cs:ff_entry_off], 0
    mov cx, [cs:ff_entry_idx]
    pop si
    pop dx
    pop bx
    clc
    ret
.sd_rollback:
    mov si, [cs:rid_clus]
    mov ax, [cs:dir_ext_old_next]
    call fat_set
    mov si, [cs:dir_ext_cluster]
    xor ax, ax
    call fat_set
    jmp .sd_full
.sd_found:
    mov ax, [cs:rid_lba]
    mov [cs:ff_entry_lba], ax
    mov ax, [cs:rid_lba_hi]
    mov [cs:ff_entry_lba_hi], ax
    mov [cs:ff_entry_off], di
    mov cx, [cs:ff_entry_idx]
    pop si
    pop dx
    pop bx
    clc
    ret
.sd_full:
    pop si
    pop dx
    pop bx
.err:
    stc
    ret

name_buf_is_blank:
    push ax
    push cx
    push ds
    push si
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
.nib_loop:
    cmp byte [si], ' '
    jne .nib_no
    inc si
    loop .nib_loop
    pop si
    pop ds
    pop cx
    pop ax
    stc
    ret
.nib_no:
    pop si
    pop ds
    pop cx
    pop ax
    clc
    ret

init_dir_cluster:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    mov ax, [cs:md_cluster]
    xor bx, bx
    call cluster_lba
    mov [cs:md_dir_lba], ax
    mov [cs:md_dir_lba_hi], dx
    mov byte [cs:md_sec_idx], 0
.idc_sector:
    mov ax, SEC_BUF
    mov es, ax
    xor di, di
    xor ax, ax
    mov cx, 256
    cld
    rep stosw
    cmp byte [cs:md_sec_idx], 0
    jne .idc_write
    mov ax, SEC_BUF
    mov es, ax
    mov byte [es:0], '.'
    mov di, 1
    mov al, ' '
    mov cx, 10
    rep stosb
    mov byte [es:11], ATTR_DIR
    mov word [es:22], FAT_TIME
    mov word [es:24], FAT_DATE
    mov ax, [cs:md_cluster]
    mov [es:26], ax
    mov byte [es:32], '.'
    mov byte [es:33], '.'
    mov di, 34
    mov al, ' '
    mov cx, 9
    rep stosb
    mov byte [es:43], ATTR_DIR
    mov word [es:54], FAT_TIME
    mov word [es:56], FAT_DATE
    mov ax, [cs:md_parent_cluster]
    mov [es:58], ax
.idc_write:
    xor bx, bx
    mov ax, [cs:md_dir_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:md_dir_lba]
    call write_sector
    jc .idc_err
    inc word [cs:md_dir_lba]
    jnz .idc_lba_inc_done
    inc word [cs:md_dir_lba_hi]
.idc_lba_inc_done:
    inc byte [cs:md_sec_idx]
    mov al, [cs:md_sec_idx]
    cmp al, [cs:kspc]
    jb .idc_sector
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.idc_err:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

dir_entry_is_dot:
    push bx
    push cx
    cmp byte [es:di], '.'
    jne .deid_no
    mov bl, [es:di+1]
    cmp bl, ' '
    je .deid_dot
    cmp bl, '.'
    je .deid_dotdot
    jmp .deid_no
.deid_dot:
    mov bx, di
    inc bx
    mov cx, 10
    jmp .deid_spaces
.deid_dotdot:
    mov bx, di
    add bx, 2
    mov cx, 9
.deid_spaces:
    cmp byte [es:bx], ' '
    jne .deid_no
    inc bx
    loop .deid_spaces
    pop cx
    pop bx
    stc
    ret
.deid_no:
    pop cx
    pop bx
    clc
    ret

dir_is_empty:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    mov [cs:rd_scan_cluster], si
.die_cluster:
    mov si, [cs:rd_scan_cluster]
    cmp si, [cs:kfat_eoc]
    jae .die_empty
    cmp si, 2
    jb .die_not_empty
    mov ax, si
    xor bx, bx
    call cluster_lba
    mov [cs:rd_scan_lba], ax
    mov [cs:rd_scan_lba_hi], dx
    mov byte [cs:rd_scan_sec_idx], 0
.die_sector:
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:rd_scan_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:rd_scan_lba]
    call read_sector
    jc .die_not_empty
    mov ax, SEC_BUF
    mov es, ax
    xor di, di
    mov cx, 16
.die_entry:
    cmp byte [es:di], 0
    je .die_empty
    cmp byte [es:di], 0xE5
    je .die_next_entry
    call dir_entry_is_dot
    jc .die_next_entry
    jmp .die_not_empty
.die_next_entry:
    add di, 32
    loop .die_entry
    inc word [cs:rd_scan_lba]
    jnz .die_lba_inc_done
    inc word [cs:rd_scan_lba_hi]
.die_lba_inc_done:
    inc byte [cs:rd_scan_sec_idx]
    mov al, [cs:rd_scan_sec_idx]
    cmp al, [cs:kspc]
    jb .die_sector
    mov si, [cs:rd_scan_cluster]
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .die_empty
    cmp ax, [cs:kfat_reserved]
    jae .die_not_empty
    cmp ax, 2
    jb .die_not_empty
    mov [cs:rd_scan_cluster], ax
    jmp .die_cluster
.die_empty:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.die_not_empty:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

parse_83name:
    push ax
    push bx
    push cx
    push di
    push ds
    push es
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    mov al, ' '
    rep stosb
    mov di, name_buf
    xor bx, bx
.pl:
    lodsb
    test al, al
    jz .pl_done
    cmp al, '.'
    je .pl_dot
    cmp al, '*'
    je .pl_star
    cmp al, 'a'
    jb .pl_noupper
    cmp al, 'z'
    ja .pl_noupper
    sub al, 32
.pl_noupper:
    test bx, bx
    jnz .pl_ext_char
    cmp di, name_buf + 8
    jae .pl
    stosb
    jmp .pl
.pl_ext_char:
    cmp di, name_buf + 11
    jae .pl
    stosb
    jmp .pl
.pl_dot:
    mov bx, 1
    mov di, name_buf + 8
    jmp .pl
.pl_star:
    test bx, bx
    jnz .pl_ext_star
.pl_name_star_fill:
    cmp di, name_buf + 8
    jae .pl_skip_to_dot
    mov byte [es:di], '?'
    inc di
    jmp .pl_name_star_fill
.pl_skip_to_dot:
    lodsb
    test al, al
    jz .pl_done
    cmp al, '.'
    jne .pl_skip_to_dot
    jmp .pl_dot
.pl_ext_star:
    cmp di, name_buf + 11
    jae .pl_skip_ext
    mov byte [es:di], '?'
    inc di
    jmp .pl_ext_star
.pl_skip_ext:
    lodsb
    test al, al
    jnz .pl_skip_ext
.pl_done:
    pop es
    pop ds
    pop di
    pop cx
    pop bx
    pop ax
    ret

parse_root_path:
    push ax
    push bx
    push dx
    mov byte [cs:pr_abs], 0
    mov [cs:pr_path_off], si
    mov ax, [cs:cur_dir_cluster]
    mov [cs:pr_dir_cluster], ax
    mov word [cs:pr_last_sep], 0xFFFF
    mov bx, si
    cmp byte [ds:bx], 'A'
    jb .scan
    cmp byte [ds:bx], 'Z'
    ja .scan
    cmp byte [ds:bx+1], ':'
    jne .scan
    add bx, 2
.scan:
    mov al, [ds:bx]
    test al, al
    jz .scan_done
    cmp al, '\'
    je .saw_sep
    cmp al, '/'
    jne .scan_next
.saw_sep:
    mov [cs:pr_last_sep], bx
.scan_next:
    inc bx
    jmp .scan
.scan_done:
    mov bx, [cs:pr_last_sep]
    cmp bx, 0xFFFF
    jne .have_parent
    mov si, [cs:pr_path_off]
    cmp byte [ds:si], 'A'
    jb .no_parent_name
    cmp byte [ds:si], 'Z'
    ja .no_parent_name
    cmp byte [ds:si+1], ':'
    jne .no_parent_name
    add si, 2
.no_parent_name:
    cmp byte [ds:si], 0
    je .err
    jmp .parse
.have_parent:
    cmp byte [ds:bx+1], 0
    je .err
    mov si, [cs:pr_path_off]
    cmp byte [ds:si], 'A'
    jb .root_check
    cmp byte [ds:si], 'Z'
    ja .root_check
    cmp byte [ds:si+1], ':'
    jne .root_check
    add si, 2
.root_check:
    cmp si, bx
    jae .parent_root
    mov al, [ds:si]
    cmp al, '\'
    je .root_check_next
    cmp al, '/'
    jne .resolve_parent
.root_check_next:
    inc si
    jmp .root_check
.parent_root:
    mov word [cs:pr_dir_cluster], ROOT_CLUSTER
    mov byte [cs:pr_abs], 1
    mov si, bx
    inc si
    jmp .parse
.resolve_parent:
    mov al, [ds:bx]
    mov [cs:pr_sep_char], al
    mov byte [ds:bx], 0
    mov si, [cs:pr_path_off]
    cmp byte [ds:si], '\'
    je .set_abs_parent
    cmp byte [ds:si], '/'
    je .set_abs_parent
    cmp byte [ds:si], 'A'
    jb .call_resolve_parent
    cmp byte [ds:si], 'Z'
    ja .call_resolve_parent
    cmp byte [ds:si+1], ':'
    jne .call_resolve_parent
.set_abs_parent:
    mov byte [cs:pr_abs], 1
.call_resolve_parent:
    call resolve_path
    mov bx, [cs:pr_last_sep]
    mov al, [cs:pr_sep_char]
    mov [ds:bx], al
    jc .err
    test byte [es:di+11], ATTR_DIR
    jz .err
    mov ax, [es:di+26]
    mov [cs:pr_dir_cluster], ax
    mov si, [cs:pr_last_sep]
    inc si
.parse:
    mov [cs:pr_name_off], si
    call parse_83name
    pop dx
    pop bx
    pop ax
    clc
    ret
.err:
    pop dx
    pop bx
    pop ax
    stc
    ret

name_matches:
    push ax
    push bx
    push cx
    push ds
    push si
    push cs
    pop ds
    mov si, name_buf
    mov bx, di
    mov cx, 11
.nm_loop:
    lodsb
    cmp al, '?'
    je .nm_ok
    cmp al, [es:bx]
    jne .nm_no
.nm_ok:
    inc bx
    loop .nm_loop
    clc
    jmp .nm_done
.nm_no:
    stc
.nm_done:
    pop si
    pop ds
    pop cx
    pop bx
    pop ax
    ret

dir_entry_attr_match:
    push ax
    mov al, [es:di+11]
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

store_find_dta:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    mov ax, [cs:dta_seg]
    mov es, ax
    mov di, [cs:dta_off]
    mov ax, [cs:ff_entry_idx]
    mov [es:di+13], ax
    mov ax, [cs:ff_dir_cluster]
    mov [es:di+15], ax
    mov al, [cs:ff_entry_attr]
    mov [es:di+21], al
    mov ax, [cs:ff_entry_time]
    mov [es:di+22], ax
    mov ax, [cs:ff_entry_date]
    mov [es:di+24], ax
    mov ax, [cs:ff_entry_size]
    mov [es:di+26], ax
    mov ax, [cs:ff_entry_size_hi]
    mov [es:di+28], ax
    add di, 30
    push cs
    pop ds
    mov si, ff_entry_name
    mov cx, 8
.sfd_name:
    lodsb
    cmp al, ' '
    je .sfd_name_done
    stosb
    loop .sfd_name
.sfd_name_done:
    mov si, ff_entry_name + 8
    mov bx, si
    mov cx, 3
.sfd_ext_check:
    cmp byte [bx], ' '
    jne .sfd_ext_yes
    inc bx
    loop .sfd_ext_check
    jmp .sfd_term
.sfd_ext_yes:
    mov al, '.'
    stosb
    mov si, ff_entry_name + 8
    mov cx, 3
.sfd_ext:
    lodsb
    cmp al, ' '
    je .sfd_term
    stosb
    loop .sfd_ext
.sfd_term:
    xor al, al
    stosb
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    ret

load_file_direct:
    mov ax, [cs:kfsize]
    mov [cs:lf_left_lo], ax
    mov ax, [cs:kfsize_hi]
    mov [cs:lf_left_hi], ax
.load:
    cmp word [cs:lf_left_hi], 0
    jne .have_left
    cmp word [cs:lf_left_lo], 0
    je .done
.have_left:
    cmp si, [cs:kfat_eoc]
    jae .err
    cmp si, 2
    jb .err
    push si
    push bx
    mov ax, si
    xor bx, bx
    call cluster_lba
    mov [cs:.sec_num], ax
    mov [cs:.sec_num_hi], dx
    pop bx
    pop si
    xor ch, ch
    mov cl, [cs:kspc]
.sec_loop:
    cmp word [cs:lf_left_hi], 0
    jne .sec_have_left
    cmp word [cs:lf_left_lo], 0
    je .done
.sec_have_left:
    push cx
    push si
    mov ax, [cs:.sec_num]
    mov dx, [cs:.sec_num_hi]
    mov [cs:kio_lba_hi], dx
    push es
    push bx
    mov bx, 0
    mov dx, SEC_BUF
    mov es, dx
    mov cx, 1
    call read_sector
    pop bx
    pop es
    jc .err_pop2
    push ds
    push si
    push di
    mov dx, SEC_BUF
    mov ds, dx
    xor si, si
    mov di, bx
    cmp word [cs:lf_left_hi], 0
    jne .copy_full_sector
    mov cx, [cs:lf_left_lo]
    cmp cx, 512
    jb .copy_chunk_set
.copy_full_sector:
    mov cx, 512
.copy_chunk_set:
    mov [cs:lf_chunk], cx
    rep movsb
    pop di
    pop si
    pop ds
    mov ax, [cs:lf_chunk]
    sub [cs:lf_left_lo], ax
    sbb word [cs:lf_left_hi], 0
    add bx, ax
    jnc .adv_ok
    mov ax, es
    add ax, 0x1000
    mov es, ax
.adv_ok:
    inc word [cs:.sec_num]
    jnz .sec_num_inc_done
    inc word [cs:.sec_num_hi]
.sec_num_inc_done:
    pop si
    pop cx
    dec cx
    jnz .sec_loop
    call fat_next
    mov si, ax
    jmp .load
.done:
    push cs
    pop ds
    xor ax, ax
    ret
.err_pop2:
    pop si
    pop cx
.err:
    push cs
    pop ds
    mov ax, 1
    ret

.sec_num: dw 0
.sec_num_hi: dw 0

load_file:
    mov [cs:load_name], si
    mov [cs:load_seg], ax
    mov [cs:load_off], bx

    push cs
    pop ds
    mov si, [cs:load_name]
    call resolve_path
    jc .notfound
    mov ax, [es:di+26]
    mov [cs:kclus], ax
    mov ax, [es:di+28]
    mov [cs:kfsize], ax

    mov ax, [cs:load_seg]
    mov es, ax
    mov bx, [cs:load_off]
    mov si, [cs:kclus]
.load:
    cmp si, [cs:kfat_eoc]
    jae .done
    cmp si, 2
    jb .notfound
    push si
    mov ax, si
    push bx
    xor bx, bx
    call cluster_lba
    mov [cs:kio_lba_hi], dx
    pop bx
    mov cx, 1
    call read_sector
    pop si
    jc .notfound
    call fat_next
    mov si, ax
    jmp .load
.done:
    push cs
    pop ds
    xor ax, ax
    ret
.notfound:
    push cs
    pop ds
    mov si, msg_nofile
    call serial_print
    mov ax, 1
    ret
