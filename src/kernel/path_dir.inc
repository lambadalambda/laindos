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

%macro LOAD_SUBDIR_SECTOR 3
    mov dx, [cs:%2]
    mov ax, [cs:%1]
    push cx
    call load_subdir_sector_cached
    pop cx
    jc %3
%endmacro

subdir_cache_invalidate:
    mov byte [cs:rf_cache_valid], 0
    push ax
    push cx
    push di
    push es
    push cs
    pop es
    mov di, subdir_cache_valid
    xor ax, ax
    mov cx, SUBDIR_CACHE_SLOTS
    cld
    rep stosb
    mov byte [cs:subdir_cache_next], 0
    pop es
    pop di
    pop cx
    pop ax
    ret

subdir_cache_slot_seg:
    push bx
    push cx
    xor bh, bh
    mov ax, bx
    mov cl, 5
    shl ax, cl
    add ax, SUBDIR_CACHE_BUF
    pop cx
    pop bx
    ret

; DX:AX = absolute sector LBA. Returns the sector in SEC_BUF with ES:DI at
; SEC_BUF:0. Preserves CX, DX, DS, and SI; clobbers AX, BX, ES, and DI.
load_subdir_sector_cached:
    mov [cs:subdir_cache_req_lba], ax
    mov [cs:subdir_cache_req_lba_hi], dx
    push cx
    push dx
    push ds
    push si
    call wf_flush_sector_cache
    jc .err
    xor bx, bx
.lookup:
    cmp bx, SUBDIR_CACHE_SLOTS
    jae .miss
    cmp byte [cs:subdir_cache_valid+bx], 1
    jne .next
    mov al, [cs:active_drive_num]
    cmp al, [cs:subdir_cache_drive+bx]
    jne .next
    mov si, bx
    shl si, 1
    mov ax, [cs:subdir_cache_req_lba]
    cmp ax, [cs:si+subdir_cache_lba]
    jne .next
    mov ax, [cs:subdir_cache_req_lba_hi]
    cmp ax, [cs:si+subdir_cache_lba_hi]
    je .hit
.next:
    inc bx
    jmp .lookup
.hit:
    PERF_INC perf_subdir_cache_hits
    call subdir_cache_slot_seg
    mov ds, ax
    mov ax, SEC_BUF
    mov es, ax
    xor si, si
    xor di, di
    mov cx, 256
    cld
    rep movsw
    jmp .ok
.miss:
    PERF_INC perf_subdir_cache_misses
    mov dx, [cs:subdir_cache_req_lba_hi]
    mov [cs:kio_lba_hi], dx
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:subdir_cache_req_lba]
    call read_sector
    jc .err
    xor bh, bh
    mov bl, [cs:subdir_cache_next]
    inc byte [cs:subdir_cache_next]
    and byte [cs:subdir_cache_next], SUBDIR_CACHE_SLOTS - 1
    call subdir_cache_slot_seg
    mov dx, ax
    mov ax, SEC_BUF
    mov ds, ax
    mov es, dx
    xor si, si
    xor di, di
    mov cx, 256
    cld
    rep movsw
    mov al, [cs:active_drive_num]
    mov [cs:subdir_cache_drive+bx], al
    mov si, bx
    shl si, 1
    mov ax, [cs:subdir_cache_req_lba]
    mov [cs:si+subdir_cache_lba], ax
    mov ax, [cs:subdir_cache_req_lba_hi]
    mov [cs:si+subdir_cache_lba_hi], ax
    mov byte [cs:subdir_cache_valid+bx], 1
.ok:
    pop si
    pop ds
    pop dx
    pop cx
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    xor di, di
    clc
    ret
.err:
    pop si
    pop ds
    pop dx
    pop cx
    stc
    ret


psp_mark_handle_open:
    push ax
    push bx
    push es
    mov bx, ax
    cmp bx, MAX_HANDLES
    jae .done
    mov ax, [cs:cur_psp]
    test ax, ax
    jz .done
    mov es, ax
    mov [es:bx+0x18], bl
.done:
    pop es
    pop bx
    pop ax
    ret

psp_mark_handle_closed:
    push ax
    push bx
    push es
    cmp bx, MAX_HANDLES
    jae .done
    mov ax, [cs:cur_psp]
    test ax, ax
    jz .done
    mov es, ax
    mov byte [es:bx+0x18], 0xFF
.done:
    pop es
    pop bx
    pop ax
    ret

init_handle_entry:
    mov byte [cs:bx+handles+H_USED], 1
    mov byte [cs:bx+handles+H_MODE], al
    xor ax, ax
    mov [cs:bx+handles+H_CLUSTER], ax
    mov [cs:bx+handles+H_POS_LO], ax
    mov [cs:bx+handles+H_POS_HI], ax
    mov [cs:bx+handles+H_SIZE_LO], ax
    mov [cs:bx+handles+H_SIZE_HI], ax
    mov [cs:bx+handles+H_LAST_CLUSTER], ax
    mov [cs:bx+handles+H_LAST_INDEX], ax
    mov [cs:bx+handles+H_DIR_LBA], ax
    mov [cs:bx+handles+H_DIR_LBA_HI], ax
    mov [cs:bx+handles+H_DIR_OFF], ax
    mov [cs:bx+handles+H_TIME], ax
    mov [cs:bx+handles+H_DATE], ax
    mov ax, [cs:cur_psp]
    mov [cs:bx+handles+H_OWNER], ax
    mov word [cs:bx+handles+H_REFCOUNT], 1
    mov word [cs:bx+handles+H_ALIAS], H_ALIAS_NONE
    mov al, [cs:active_drive_num]
    mov [cs:bx+handles+H_DRIVE], al
    mov byte [cs:bx+handles+H_DRIVE+1], 0
    ret

alloc_device_handle:
    cmp al, DEV_CON
    je .supported
    cmp al, DEV_NUL
    je .supported
%if ENABLE_EMS
    cmp al, DEV_EMM
    je .supported
%endif
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
    mov al, 2
    call init_handle_entry
    xor ah, ah
    mov al, [cs:dev_type]
    mov [cs:bx+handles+H_DIR_OFF], ax
    pop ax
    clc
    ret
.full:
    mov ax, 4
    stc
    ret

resolve_handle_for_use:
    cmp bx, MAX_HANDLES
    jae .bad
    push bx
    push cx
    push dx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 1
    jne .bad_pop
    mov ax, [cs:si+handles+H_ALIAS]
    cmp ax, H_ALIAS_NONE
    je .direct
    cmp ax, MAX_HANDLES
    jae .bad_pop
    mov bx, ax
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .bad_pop
    cmp word [cs:si+handles+H_ALIAS], H_ALIAS_NONE
    jne .bad_pop
    mov ax, bx
    pop dx
    pop cx
    pop bx
    clc
    ret
.direct:
    mov ax, bx
    pop dx
    pop cx
    pop bx
    clc
    ret
.bad_pop:
    pop dx
    pop cx
    pop bx
.bad:
    stc
    ret

make_alias_handle:
    push ax
    push bx
    push cx
    push dx
    push si
    mov ax, dx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    inc word [cs:si+handles+H_REFCOUNT]
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    push ax
    push bx
    push cx
    push dx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    xor al, al
    call init_handle_entry
    mov word [cs:bx+handles+H_REFCOUNT], 0
    pop dx
    mov [cs:bx+handles+H_ALIAS], dx
    pop cx
    pop bx
    pop ax
    clc
    ret

make_device_handle_at:
    push ax
    push bx
    push cx
    push dx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    mov al, 2
    call init_handle_entry
    pop dx
    xor dh, dh
    mov [cs:bx+handles+H_DIR_OFF], dx
    pop cx
    pop bx
    pop ax
    clc
    ret

; DX:AX = byte position. Returns AX = cluster index within the chain
; and DX = sector index within that cluster. Clobbers CX.
pos_to_cluster_sector:
    mov cx, 9
.shift:
    shr dx, 1
    rcr ax, 1
    loop .shift
    xor ch, ch
    mov cl, [cs:kspc]
    div cx
    ret

; SI = handle table offset. Clear the slot back to the free state.
release_handle_slot:
    mov byte [cs:si+handles+H_USED], 0
    mov byte [cs:si+handles+H_MODE], 0
    mov word [cs:si+handles+H_OWNER], 0
    mov word [cs:si+handles+H_REFCOUNT], 0
    mov word [cs:si+handles+H_ALIAS], H_ALIAS_NONE
    ret

close_table_handle:
    cmp bx, MAX_HANDLES
    jae .bad
    push bx
    push cx
    push dx
    push si
    push di
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 1
    jne .bad_pop
    mov dx, [cs:si+handles+H_ALIAS]
    cmp dx, H_ALIAS_NONE
    je .master
    call release_handle_slot
    mov ax, dx
    mov cx, HANDLE_SIZE
    mul cx
    mov di, ax
    cmp byte [cs:di+handles+H_USED], 0
    je .ok_pop
    dec word [cs:di+handles+H_REFCOUNT]
    jnz .ok_pop
    mov si, di
    call close_root_handle
    jc .io_pop
    jmp .ok_pop
.master:
    cmp word [cs:si+handles+H_REFCOUNT], 1
    jbe .last_master
    dec word [cs:si+handles+H_REFCOUNT]
    mov byte [cs:si+handles+H_USED], 2
    jmp .ok_pop
.last_master:
    call close_root_handle
    jc .io_pop
.ok_pop:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    clc
    ret
.io_pop:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    mov ax, 5
    stc
    ret
.bad_pop:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
.bad:
    mov ax, 6
    stc
    ret

close_root_handle:
    push si
    mov ax, [cs:si+handles+H_DIR_LBA]
    or ax, [cs:si+handles+H_DIR_LBA_HI]
    je .mark_free
    ; flush-on-close is decided by the access bits alone; sharing bits
    ; (deny-none reads and friends) must not force a dir-entry flush --
    ; on read-only media that flush fails and would leak the slot
    mov al, [cs:si+handles+H_MODE]
    and al, 7
    jz .mark_free
    call wf_flush_handle_dir_entry
    jc .err
    call flush_fat
    jc .err
.mark_free:
    pop si
    call release_handle_slot
    clc
    ret
.err:
    pop si
    stc
    ret

close_handle_for_replace:
    cmp bx, MAX_HANDLES
    jae .bad
    push bx
    push cx
    push dx
    push si
    push di
    mov [cs:dup_dest], bx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .ok_pop
    cmp byte [cs:si+handles+H_USED], 1
    je .used
    cmp byte [cs:si+handles+H_USED], 2
    je .closed_root
    jmp .bad_pop
.used:
    mov dx, [cs:si+handles+H_ALIAS]
    cmp dx, H_ALIAS_NONE
    je .used_root
    call close_table_handle
    jc .io_pop
    jmp .ok_pop
.used_root:
    mov cx, [cs:si+handles+H_REFCOUNT]
    cmp cx, 1
    ja .used_root_shared
    call close_root_handle
    jc .io_pop
    jmp .ok_pop
.used_root_shared:
    dec cx
    jmp .promote_alias
.closed_root:
    mov cx, [cs:si+handles+H_REFCOUNT]
    test cx, cx
    jnz .promote_alias
    call release_handle_slot
    jmp .ok_pop
.promote_alias:
    mov [cs:dup_status], cx
    xor di, di
.find_alias_loop:
    cmp di, MAX_HANDLES
    jae .bad_pop
    mov ax, di
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    cmp byte [cs:bx+handles+H_USED], 1
    jne .find_alias_next
    mov ax, [cs:bx+handles+H_ALIAS]
    cmp ax, [cs:dup_dest]
    je .found_alias
.find_alias_next:
    inc di
    jmp .find_alias_loop
.found_alias:
    mov [cs:dup_new_root], di
    mov di, bx
    mov al, [cs:si+handles+H_MODE]
    mov [cs:di+handles+H_MODE], al
    mov ax, [cs:si+handles+H_CLUSTER]
    mov [cs:di+handles+H_CLUSTER], ax
    mov ax, [cs:si+handles+H_POS_LO]
    mov [cs:di+handles+H_POS_LO], ax
    mov ax, [cs:si+handles+H_POS_HI]
    mov [cs:di+handles+H_POS_HI], ax
    mov ax, [cs:si+handles+H_SIZE_LO]
    mov [cs:di+handles+H_SIZE_LO], ax
    mov ax, [cs:si+handles+H_SIZE_HI]
    mov [cs:di+handles+H_SIZE_HI], ax
    mov ax, [cs:si+handles+H_LAST_CLUSTER]
    mov [cs:di+handles+H_LAST_CLUSTER], ax
    mov ax, [cs:si+handles+H_LAST_INDEX]
    mov [cs:di+handles+H_LAST_INDEX], ax
    mov ax, [cs:si+handles+H_DIR_LBA]
    mov [cs:di+handles+H_DIR_LBA], ax
    mov ax, [cs:si+handles+H_DIR_OFF]
    mov [cs:di+handles+H_DIR_OFF], ax
    mov ax, [cs:si+handles+H_TIME]
    mov [cs:di+handles+H_TIME], ax
    mov ax, [cs:si+handles+H_DATE]
    mov [cs:di+handles+H_DATE], ax
    mov ax, [cs:si+handles+H_DIR_LBA_HI]
    mov [cs:di+handles+H_DIR_LBA_HI], ax
    mov ax, [cs:si+handles+H_DRIVE]
    mov [cs:di+handles+H_DRIVE], ax
    mov ax, [cs:dup_status]
    mov [cs:di+handles+H_REFCOUNT], ax
    mov word [cs:di+handles+H_ALIAS], H_ALIAS_NONE
    xor bx, bx
.update_alias_loop:
    cmp bx, MAX_HANDLES
    jae .free_old_root
    cmp bx, [cs:dup_new_root]
    je .update_alias_next
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov di, ax
    cmp byte [cs:di+handles+H_USED], 1
    jne .update_alias_next
    mov ax, [cs:di+handles+H_ALIAS]
    cmp ax, [cs:dup_dest]
    jne .update_alias_next
    mov ax, [cs:dup_new_root]
    mov [cs:di+handles+H_ALIAS], ax
.update_alias_next:
    inc bx
    jmp .update_alias_loop
.free_old_root:
    call release_handle_slot
.ok_pop:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    clc
    ret
.io_pop:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    mov ax, 5
    stc
    ret
.bad_pop:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
.bad:
    mov ax, 6
    stc
    ret

ascii_upper:
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    sub al, 32
.done:
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
%if ENABLE_EMS
    push si
    call match_emm_device
    pop si
    jnc .found_emm
%endif
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
    jmp .found
%if ENABLE_EMS
.found_emm:
    mov al, DEV_EMM
%endif
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
    call ascii_upper
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

%if ENABLE_EMS
match_emm_device:
    call dev_upper_lodsb
    cmp al, 'E'
    jne .no
    call dev_upper_lodsb
    cmp al, 'M'
    jne .no
    call dev_upper_lodsb
    cmp al, 'M'
    jne .no
    mov cx, 4
.x_loop:
    call dev_upper_lodsb
    cmp al, 'X'
    jne .no
    loop .x_loop
    lodsb
    cmp al, '0'
    jne .no
    call dev_name_end
    ret
.no:
    stc
    ret
%endif

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

store_cur_dir_path:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    mov bx, si
    xor dx, dx
    STRIP_DRIVE_PREFIX bx
.check_abs_sep:
    cmp byte [ds:bx], '\'
    je .absolute
    cmp byte [ds:bx], '/'
    jne .component_loop
.absolute:
    mov byte [cs:cur_dir_path], 0
.absolute_skip_sep:
    cmp byte [ds:bx], '\'
    je .absolute_advance
    cmp byte [ds:bx], '/'
    jne .component_loop
.absolute_advance:
    inc bx
    jmp .absolute_skip_sep
.component_loop:
    cmp byte [ds:bx], '\'
    je .skip_sep
    cmp byte [ds:bx], '/'
    je .skip_sep
    cmp byte [ds:bx], 0
    je .done
    cmp byte [ds:bx], '.'
    jne .append_component
    mov al, [ds:bx+1]
    test al, al
    jz .skip_dot_end
    cmp al, '\'
    je .skip_dot_one
    cmp al, '/'
    je .skip_dot_one
    cmp al, '.'
    jne .append_component
    mov al, [ds:bx+2]
    test al, al
    jz .parent_end
    cmp al, '\'
    je .parent_component
    cmp al, '/'
    jne .append_component
.parent_component:
    add bx, 2
    call cur_dir_path_parent
    jmp .component_loop
.parent_end:
    call cur_dir_path_parent
    jmp .done
.skip_dot_one:
    inc bx
    jmp .component_loop
.skip_dot_end:
    jmp .done
.skip_sep:
    inc bx
    jmp .component_loop
.append_component:
    push ds
    push cs
    pop es
    mov di, cur_dir_path
    mov cx, 63
.find_end:
    cmp byte [es:di], 0
    je .have_end
    inc di
    dec cx
    jnz .find_end
    mov byte [es:di], 0
.have_end:
    cmp di, cur_dir_path
    je .copy_component
    test cx, cx
    jz .skip_component_rest
    mov byte [es:di], '\'
    inc di
    dec cx
.copy_component:
    cmp byte [ds:bx], 0
    je .component_copied
    cmp byte [ds:bx], '\'
    je .component_copied
    cmp byte [ds:bx], '/'
    je .component_copied
    test cx, cx
    jz .skip_component_rest
    mov al, [ds:bx]
    call ascii_upper
    mov [es:di], al
    inc di
    inc bx
    dec cx
    jmp .copy_component
.skip_component_rest:
    cmp byte [ds:bx], 0
    je .component_copied
    cmp byte [ds:bx], '\'
    je .component_copied
    cmp byte [ds:bx], '/'
    je .component_copied
    inc bx
    jmp .skip_component_rest
.component_copied:
    mov byte [es:di], 0
    pop ds
    jmp .component_loop
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

chdir_dot_only_path:
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    call activate_drive_for_path
    jc .not_dot_only
    mov bx, si
    mov ax, [cs:cur_dir_cluster]
    mov [cs:cd_walk_cluster], ax
    xor dx, dx
    STRIP_DRIVE_PREFIX bx
.check_abs_sep:
    cmp byte [ds:bx], '\'
    je .set_root
    cmp byte [ds:bx], '/'
    jne .component_loop
.set_root:
    mov word [cs:cd_walk_cluster], ROOT_CLUSTER
.component_loop:
    cmp byte [ds:bx], '\'
    je .skip_sep
    cmp byte [ds:bx], '/'
    je .skip_sep
    cmp byte [ds:bx], 0
    je .success
    cmp byte [ds:bx], '.'
    jne .not_dot_only
    mov al, [ds:bx+1]
    test al, al
    jz .dot_end
    cmp al, '\'
    je .dot_one
    cmp al, '/'
    je .dot_one
    cmp al, '.'
    jne .not_dot_only
    mov al, [ds:bx+2]
    test al, al
    jz .dotdot_end
    cmp al, '\'
    je .dotdot_component
    cmp al, '/'
    jne .not_dot_only
.dotdot_component:
    mov dh, 1
    add bx, 2
    call chdir_walk_parent
    jc .not_dot_only
    jmp .component_loop
.dotdot_end:
    mov dh, 1
    call chdir_walk_parent
    jc .not_dot_only
    jmp .success
.dot_one:
    mov dh, 1
    inc bx
    jmp .component_loop
.dot_end:
    mov dh, 1
    jmp .success
.skip_sep:
    inc bx
    jmp .component_loop
.success:
    cmp dh, 1
    jne .not_dot_only
    mov ax, [cs:cd_walk_cluster]
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    clc
    ret
.not_dot_only:
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    stc
    ret

chdir_walk_parent:
    cmp word [cs:cd_walk_cluster], ROOT_CLUSTER
    je .root
    push ax
    push bx
    push cx
    push dx
    push es
    push si
    push di
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    mov al, ' '
    rep stosb
    mov byte [cs:name_buf], '.'
    mov byte [cs:name_buf+1], '.'
    mov ax, [cs:cd_walk_cluster]
    xor bx, bx
    xor dx, dx
    mov byte [cs:ff_attr_mask], 0
    call find_in_dir
    jc .err
    test byte [es:di+11], ATTR_DIR
    jz .err
    mov ax, [es:di+26]
    mov [cs:cd_walk_cluster], ax
    pop di
    pop si
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err:
    pop di
    pop si
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret
.root:
    clc
    ret

resolve_path:
    push bx
    call activate_drive_for_path
    jc .rp_drive_err
    mov [cs:rp_path], si
    mov [cs:rp_path_seg], ds
    cmp byte [ds:si], '\'
    je .rp_abs
    cmp byte [ds:si], '/'
    je .rp_abs
    STRIP_DRIVE_PREFIX si
    cmp byte [ds:si], '\'
    je .rp_abs_skip
    cmp byte [ds:si], '/'
    je .rp_abs_skip
    mov [cs:rp_path], si
    mov ax, [cs:cur_dir_cluster]
    jmp .rp_walk
.rp_abs:
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
    cmp byte [ds:si], 0
    je .rp_colon_bad
    inc si
    mov [cs:rp_path], si
    jmp .rp_skip_sep
.rp_colon_bad:
    stc
    pop bx
    ret
.rp_empty:
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
    xor bh, bh
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
    call ascii_upper
    cmp al, '.'
    je .rp_dot
    test bh, bh
    jnz .rp_ext_char
    cmp di, name_buf + 8
    jae .rp_adv
    stosb
    jmp .rp_adv
.rp_ext_char:
    cmp di, name_buf + 11
    jae .rp_adv
    stosb
    jmp .rp_adv
.rp_dot:
    mov bh, 1
    mov di, name_buf + 8
    jmp .rp_adv
.rp_adv:
    mov [cs:rp_path], si
    jmp .rp_copy
.rp_copy_sep:
    mov [cs:rp_path], si
.rp_sep_peek:
    cmp byte [ds:si], '\'
    je .rp_sep_peek_next
    cmp byte [ds:si], '/'
    je .rp_sep_peek_next
    cmp byte [ds:si], 0
    je .rp_trailing_final
    jmp .rp_descend
.rp_sep_peek_next:
    inc si
    jmp .rp_sep_peek
.rp_descend:
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
.rp_trailing_final:
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
    pop bx
    ret
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
.rp_drive_err:
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
    push dx
    mov ax, cx
    mov dx, 32
    mul dx
    mov di, ax
    pop dx
    call root_entry_loc_from_cx
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
    call fat_walk_reset
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
    LOAD_SUBDIR_SECTOR rid_lba, rid_lba_hi, .rid_notfound_pop
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
    INC_DWORD_CS rid_lba, rid_lba_hi
    inc byte [cs:rid_sec_idx]
    mov al, [cs:rid_sec_idx]
    cmp al, [cs:kspc]
    jb .rid_sec_loop
    mov si, [cs:rid_clus]
    call fat_next_checked
    jc .rid_notfound_pop
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
    call fat_walk_reset
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
    LOAD_SUBDIR_SECTOR rid_lba, rid_lba_hi, .sd_full
    mov cx, 16
.sd_entry:
    cmp byte [es:di], 0
    je .sd_found
    cmp byte [es:di], 0xE5
    je .sd_found
    add di, 32
    inc word [cs:ff_entry_idx]
    loop .sd_entry
    INC_DWORD_CS rid_lba, rid_lba_hi
    inc byte [cs:rid_sec_idx]
    mov al, [cs:rid_sec_idx]
    cmp al, [cs:kspc]
    jb .sd_sector
    mov si, [cs:rid_clus]
    call fat_next_checked
    jnc .sd_next_ok
    cmp ax, [cs:kfat_eoc]
    jae .sd_extend
    jmp .sd_full
.sd_next_ok:
    mov [cs:rid_clus], ax
    jmp .sd_cluster_loop
.sd_extend:
    mov [cs:dir_ext_old_next], ax
    call fat_alloc_cluster
    jc .sd_full
    mov [cs:dir_ext_cluster], ax
    mov si, [cs:rid_clus]
    call fat_set
%ifdef TEST_DIR_EXT_FLUSH_BEFORE_ZERO_FAIL
    call flush_fat
%endif
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
    INC_DWORD_CS rid_lba, rid_lba_hi
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
    call flush_fat
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

name_buf_is_valid:
    call name_buf_is_blank
    jc .niv_bad
    push cx
    push ds
    push si
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
.niv_loop:
    cmp byte [si], '?'
    je .niv_bad_pop
    inc si
    loop .niv_loop
    pop si
    pop ds
    pop cx
    clc
    ret
.niv_bad_pop:
    pop si
    pop ds
    pop cx
.niv_bad:
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
    INC_DWORD_CS md_dir_lba, md_dir_lba_hi
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
    call fat_walk_reset
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
    LOAD_SUBDIR_SECTOR rd_scan_lba, rd_scan_lba_hi, .die_not_empty
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
    INC_DWORD_CS rd_scan_lba, rd_scan_lba_hi
    inc byte [cs:rd_scan_sec_idx]
    mov al, [cs:rd_scan_sec_idx]
    cmp al, [cs:kspc]
    jb .die_sector
    mov si, [cs:rd_scan_cluster]
    call fat_next_checked
    jnc .die_next_ok
    cmp ax, [cs:kfat_eoc]
    jae .die_empty
    jmp .die_not_empty
.die_next_ok:
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
    call ascii_upper
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
    jz .pl_name_star_ext_fill_start
    cmp al, '.'
    jne .pl_skip_to_dot
    jmp .pl_dot
.pl_name_star_ext_fill_start:
    mov di, name_buf + 8
.pl_name_star_ext_fill:
    cmp di, name_buf + 11
    jae .pl_done
    mov byte [es:di], '?'
    inc di
    jmp .pl_name_star_ext_fill
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
    call activate_drive_for_path
    jc .err
    mov byte [cs:pr_abs], 0
    mov [cs:pr_path_off], si
    mov ax, [cs:cur_dir_cluster]
    mov [cs:pr_dir_cluster], ax
    mov word [cs:pr_last_sep], 0xFFFF
    mov bx, si
    STRIP_DRIVE_PREFIX bx
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
    STRIP_DRIVE_PREFIX si
.no_parent_name:
    cmp byte [ds:si], 0
    je .err
    jmp .parse
.have_parent:
    cmp byte [ds:bx+1], 0
    je .err
    mov si, [cs:pr_path_off]
    STRIP_DRIVE_PREFIX si
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
    mov al, [cs:active_drive_num]
    mov [es:di], al
    mov ax, [cs:ff_entry_idx]
    mov [es:di+13], ax
    cmp byte [cs:kdrive_type], DRIVE_TYPE_CDROM
    je .sfd_cd_dir_state
    mov ax, [cs:ff_dir_cluster]
    mov [es:di+15], ax
    jmp .sfd_after_dir_state
.sfd_cd_dir_state:
    mov ax, [cs:cd_dir_size_lo]
    mov [es:di+15], ax
    mov ax, [cs:cd_dir_lba_lo]
    mov [es:di+17], ax
    mov ax, [cs:cd_dir_lba_hi]
    mov [es:di+19], ax
.sfd_after_dir_state:
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
     cmp cx, 8
     jne .sfd_name_sanitize
     cmp al, 0x05
     jne .sfd_name_sanitize
     mov al, 0xE5
.sfd_name_sanitize:
     call sanitize_dta_byte
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
     call sanitize_dta_byte
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

sanitize_dta_byte:
     cmp al, 0xE5
     jne .sdb_check_ctrl
     mov al, 0x05
     ret
.sdb_check_ctrl:
     cmp al, ' '
     jb .sdb_subst
     cmp al, 0x7F
     je .sdb_subst
     ret
.sdb_subst:
     mov al, '?'
     ret

load_file_direct:
    call fat_walk_reset
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
    mov [cs:lf_direct_count], cx
    cmp word [cs:lf_direct_count], 2
    jb .direct_no
    cmp word [cs:lf_left_hi], 0
    jne .direct_file_ready
    mov ax, [cs:lf_left_lo]
    mov cl, 9
    shr ax, cl
    cmp ax, [cs:lf_direct_count]
    jae .direct_file_ready
    mov [cs:lf_direct_count], ax
.direct_file_ready:
    cmp word [cs:lf_direct_count], 2
    jb .direct_no
    cmp word [cs:lf_direct_count], 127
    jbe .direct_count_ready
    mov word [cs:lf_direct_count], 127
.direct_count_ready:
    mov ax, es
    and ax, 0x0FFF
    mov cl, 4
    shl ax, cl
    add ax, bx
    jz .direct_dma_ready
    neg ax
    mov cl, 9
    shr ax, cl
    cmp ax, 2
    jb .direct_no
    cmp [cs:lf_direct_count], ax
    jbe .direct_dma_ready
    mov [cs:lf_direct_count], ax
.direct_dma_ready:
    cmp word [cs:lf_direct_count], 2
    jb .direct_no
    push si
    mov ax, [cs:.sec_num]
    mov dx, [cs:.sec_num_hi]
    mov [cs:kio_lba_hi], dx
    mov cx, [cs:lf_direct_count]
    call read_sectors
    pop si
    jc .direct_err_pop
    mov ax, [cs:lf_direct_count]
    mov cx, 512
    mul cx
    mov [cs:lf_chunk], ax
    sub [cs:lf_left_lo], ax
    sbb word [cs:lf_left_hi], 0
    mov ax, [cs:lf_direct_count]
    add [cs:.sec_num], ax
    adc word [cs:.sec_num_hi], 0
    pop cx
    sub cx, [cs:lf_direct_count]
    jnz .sec_loop
    call fat_next_checked
    mov si, ax
    jmp .load
.direct_err_pop:
    pop cx
    jmp .err
.direct_no:
    pop cx
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
    PERF_INC perf_loader_copies
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
    call fat_next_checked
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

; Shared direct-mapped FAT chain-position cache. Entries are keyed by logical
; drive and first cluster so aliases and reopens of the same file can share hits.
; Close keeps entries warm; FAT-chain mutation invalidates them.
; BX = handle table offset, CX = file cluster index, SI = FAT cluster.
handle_chain_cache_store:
    push ax
    push dx
    push di
    xor ah, ah
    mov al, [cs:bx+handles+H_DRIVE]
    cmp al, MAX_DRIVES
    jae .fat_handle
    mov di, ax
    cmp byte [cs:drive_type+di], DRIVE_TYPE_CDROM
    je .done
.fat_handle:
    mov [cs:bx+handles+H_LAST_CLUSTER], si
    mov [cs:bx+handles+H_LAST_INDEX], cx
    cmp word [cs:bx+handles+H_CLUSTER], 2
    jb .done
    mov ax, cx
    and ax, 3
    mov di, ax
    mov dl, [cs:bx+handles+H_DRIVE]
    mov [cs:chain_cache_drive+di], dl
    shl di, 1
    mov dx, [cs:bx+handles+H_CLUSTER]
    mov [cs:chain_cache_first+di], dx
    mov [cs:chain_cache_index+di], cx
    mov [cs:chain_cache_cluster+di], si
.done:
    pop di
    pop dx
    pop ax
    ret

; BX = handle table offset, AX = target file cluster index.
; CF clear: CX/SI = cached start index/cluster. CF set: no usable entry.
handle_chain_cache_lookup:
    push ax
    push bx
    push dx
    push di
    mov dx, ax
    xor ah, ah
    mov al, [cs:bx+handles+H_DRIVE]
    cmp al, MAX_DRIVES
    jae .fat_handle
    mov di, ax
    cmp byte [cs:drive_type+di], DRIVE_TYPE_CDROM
    je .miss
.fat_handle:
    mov di, 0xFFFF
    xor si, si
    mov ax, [cs:bx+handles+H_LAST_CLUSTER]
    mov cx, [cs:bx+handles+H_LAST_INDEX]
    call handle_chain_cache_consider
    xor ax, ax
    call handle_chain_cache_consider_slot
    mov ax, 1
    call handle_chain_cache_consider_slot
    mov ax, 2
    call handle_chain_cache_consider_slot
    mov ax, 3
    call handle_chain_cache_consider_slot
    test si, si
    jz .miss
    mov cx, di
    clc
    jmp .out
.miss:
    stc
.out:
    pop di
    pop dx
    pop bx
    pop ax
    ret

; AX = cache slot, BX = handle, DX = target, DI/SI = current best.
handle_chain_cache_consider_slot:
    push bp
    mov bp, ax
    mov al, [cs:chain_cache_drive+bp]
    cmp al, [cs:bx+handles+H_DRIVE]
    jne .done
    shl bp, 1
    mov ax, [cs:chain_cache_first+bp]
    cmp ax, [cs:bx+handles+H_CLUSTER]
    jne .done
    mov cx, [cs:chain_cache_index+bp]
    mov ax, [cs:chain_cache_cluster+bp]
    call handle_chain_cache_consider
.done:
    pop bp
    ret

handle_chain_cache_consider:
    test ax, ax
    jz .ret
    ; FFFFh is reserved as the invalid index sentinel; huge files merely miss.
    cmp cx, 0xFFFF
    je .ret
    cmp cx, dx
    ja .ret
    cmp di, 0xFFFF
    je .take
    cmp cx, di
    jbe .ret
.take:
    mov di, cx
    mov si, ax
.ret:
    ret

handle_chain_cache_invalidate_all:
    push ax
    push bx
    push cx
    push di
    xor ax, ax
    mov [cs:chain_cache_cluster], ax
    mov [cs:chain_cache_cluster+2], ax
    mov [cs:chain_cache_cluster+4], ax
    mov [cs:chain_cache_cluster+6], ax
    xor bx, bx
    mov cx, MAX_HANDLES
.loop:
    xor ah, ah
    mov al, [cs:bx+handles+H_DRIVE]
    cmp al, MAX_DRIVES
    jae .clear
    mov di, ax
    cmp byte [cs:drive_type+di], DRIVE_TYPE_CDROM
    je .next
.clear:
    xor ax, ax
    mov [cs:bx+handles+H_LAST_CLUSTER], ax
    mov [cs:bx+handles+H_LAST_INDEX], ax
.next:
    add bx, HANDLE_SIZE
    loop .loop
    pop di
    pop cx
    pop bx
    pop ax
    ret

chain_cache_drive: times 4 db 0
chain_cache_first: times 4 dw 0
chain_cache_index: times 4 dw 0
chain_cache_cluster: times 4 dw 0
