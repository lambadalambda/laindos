; DS = MZ header. DX:AX = image bytes including the header, derived
; from the page count [0x04] and last-page byte count [0x02].
mz_image_bytes:
    mov ax, [0x04]
    xor dx, dx
    cmp word [0x02], 0
    je .size_shift
    dec ax
.size_shift:
    mov cx, 9
.size_loop:
    shl ax, 1
    rcl dx, 1
    loop .size_loop
    mov cx, [0x02]
    test cx, cx
    jz .done
    add ax, cx
    adc dx, 0
.done:
    ret

; DX:AX = byte size, CX = extra paragraphs to add. Returns AX = load
; size in paragraphs (sector-rounded) plus the extra; CF set when the
; result does not fit in 16 bits.
image_paras_from_bytes:
    add ax, 511
    adc dx, 0
    push cx
    mov cx, 9
.shr9:
    shr dx, 1
    rcr ax, 1
    loop .shr9
    mov cx, 5
.shl5:
    shl ax, 1
    rcl dx, 1
    loop .shl5
    pop cx
    add ax, cx
    adc dx, 0
    test dx, dx
    jnz .overflow
    clc
    ret
.overflow:
    stc
    ret

; DS = MZ header. Sets kfsize/kfsize_hi from the header page count and
; computes exe_min_par (header-trimmed image + minalloc + PSP) and
; prog_par (the larger of the sector-rounded load size and exe_min_par).
; CF set with AX = 8 (too large) or AX = 11 (bad header) on error.
exe_compute_sizing:
    call mz_image_bytes
    mov [cs:kfsize], ax
    mov [cs:kfsize_hi], dx
    add ax, 15
    adc dx, 0
    mov cx, 4
.min_shift:
    shr dx, 1
    rcr ax, 1
    loop .min_shift
    test dx, dx
    jnz .too_large
    cmp ax, [0x08]
    jb .bad_header
    sub ax, [0x08]
    add ax, [0x0A]
    jc .too_large
    add ax, 0x10
    jc .too_large
    mov [cs:exe_min_par], ax
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    mov cx, 0x12
    call image_paras_from_bytes
    jc .too_large
    cmp ax, [cs:exe_min_par]
    jae .use_file
    mov ax, [cs:exe_min_par]
.use_file:
    mov [cs:prog_par], ax
    clc
    ret
.too_large:
    mov ax, 8
    stc
    ret
.bad_header:
    mov ax, 11
    stc
    ret

; DS = MZ header. Refines prog_par per maxalloc [0x0C]: zero keeps the
; minimum fit, 0xFFFF grabs the largest free block, anything else asks
; for min-without-minalloc plus maxalloc, capped by what is available.
exe_apply_maxalloc_policy:
    mov cx, [0x0C]
    test cx, cx
    jz .done
    cmp cx, 0xFFFF
    je .max_all
    mov ax, [cs:exe_min_par]
    sub ax, [0x0A]
    add ax, cx
    jc .max_all
    cmp ax, [cs:prog_par]
    jae .desired_ready
    mov ax, [cs:prog_par]
.desired_ready:
    call find_largest_free_block
    cmp bx, [cs:prog_par]
    jb .done
    cmp ax, bx
    jbe .use_desired
    mov ax, bx
.use_desired:
    mov [cs:prog_par], ax
    ret
.max_all:
    call find_largest_free_block
    cmp bx, [cs:prog_par]
    jb .done
    mov [cs:prog_par], bx
.done:
    ret

; AX = relocation count, DX = table offset, BX = header paragraphs.
; CF set if the table is invalid. A zero count is always valid; with
; entries the table must start at or after 0x1C and end within the
; header (header paragraphs must stay below 4096 so the byte bound
; fits in 16 bits).
validate_exe_reloc_table:
    test ax, ax
    jz .ok
    cmp dx, 0x1C
    jb .bad
    shl ax, 1
    jc .bad
    shl ax, 1
    jc .bad
    add ax, dx
    jc .bad
    cmp bx, 4096
    jae .bad
    push dx
    mov dx, bx
    shl dx, 1
    shl dx, 1
    shl dx, 1
    shl dx, 1
    cmp ax, dx
    pop dx
    ja .bad
.ok:
    clc
    ret
.bad:
    stc
    ret

load_exec_program:
    mov word [cs:exec_env_seg], 0
    mov byte [cs:exec_env_owned], 0
    mov word [cs:exec_cd_lba_hi], 0
    mov ds, [cs:exec_path_seg]
    mov si, [cs:exec_path_off]
    call activate_drive_for_path
    jc .not_found
    cmp byte [cs:kdrive_type], DRIVE_TYPE_CDROM
    je .cd_found
    mov ds, [cs:exec_path_seg]
    mov si, [cs:exec_path_off]
    call resolve_path
    jnc .found
.not_found:
    mov ax, 2
    stc
    ret
.cd_found:
    mov ds, [cs:exec_path_seg]
    mov si, [cs:exec_path_off]
    call cd_open_path
    jc .not_found
    mov byte [cs:exec_is_exe], 0
    mov ax, [cs:cd_file_lba_lo]
    mov [cs:exec_cluster], ax
    mov ax, [cs:cd_file_lba_hi]
    mov [cs:exec_cd_lba_hi], ax
    mov ax, [cs:cd_file_size_lo]
    mov [cs:kfsize], ax
    mov ax, [cs:cd_file_size_hi]
    mov [cs:kfsize_hi], ax
    call exec_read_first_sector_cd
    jc .io_err
    jmp .header_ready
.found:
    mov byte [cs:exec_is_exe], 0
    mov ax, [es:di+26]
    mov [cs:exec_cluster], ax
    mov ax, [es:di+28]
    mov [cs:kfsize], ax
    mov ax, [es:di+30]
    mov [cs:kfsize_hi], ax
    call exec_read_first_sector
    jc .io_err
.header_ready:
    call update_exec_environment_path
    jnc .env_ready
    mov ax, 8
    stc
    ret
.env_ready:
    mov ax, SEC_BUF
    mov ds, ax
    cmp word [0], 0x5A4D
    jne .com_size
    mov byte [cs:exec_is_exe], 1
    call exe_compute_sizing
    jc .size_err
    call exe_apply_maxalloc_policy
    jmp .alloc
.com_size:
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    mov cx, COM_EXTRA_PAR
    call image_paras_from_bytes
    mov [cs:prog_par], ax
    mov ax, 8
    jnc .com_largest
.size_err:
    push ax
    call free_exec_environment
    pop ax
    stc
    ret
.com_largest:
    ; a .COM owns the largest free block, as on real DOS; if even the
    ; image does not fit, the allocation below fails with error 8
    push cs
    pop ds
    call find_largest_free_block
    cmp bx, [cs:prog_par]
    jb .alloc
    mov [cs:prog_par], bx
.alloc:
    push cs
    pop ds
    mov bx, [cs:prog_par]
    call alloc_mem_direct
    jnc .alloc_ok
    call free_exec_environment
    mov ax, 8
    stc
    ret
.alloc_ok:
    mov [cs:prog_seg], ax
    push ax
    dec ax
    mov es, ax
    pop ax
    mov [es:1], ax
    mov ax, [cs:prog_seg]
    add ax, 0x10
    mov es, ax
    xor bx, bx
    cmp byte [cs:kdrive_type], DRIVE_TYPE_CDROM
    je .load_cd
    mov si, [cs:exec_cluster]
; @anchor: exec_load_fat_file
    call load_file_direct
    jmp .load_done
.load_cd:
    call load_cd_file_direct
.load_done:
    cmp ax, 0
    je .loaded
    call free_prog_mcb
    call free_exec_environment
.io_err:
    mov ax, 1
    stc
    ret
.loaded:
    cmp byte [cs:exec_is_exe], 0
    jne .loaded_done
    mov ax, [cs:prog_seg]
    call build_psp
    call exec_copy_command_tail
    jnc .loaded_done
    call release_inherited_handles
    call free_prog_mcb
    call free_exec_environment
    mov ax, 8
    stc
    ret
.loaded_done:
    xor ax, ax
    clc
    ret

; AX = first cluster. Read its first sector into SEC_BUF.
read_first_cluster_sector:
    push bx
    push cx
    push dx
    push es
    cmp ax, 2
    jb .err
    xor bx, bx
    call cluster_lba
    mov [cs:kio_lba_hi], dx
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    jc .err
    pop es
    pop dx
    pop cx
    pop bx
    clc
    ret
.err:
    pop es
    pop dx
    pop cx
    pop bx
    stc
    ret

exec_read_first_sector:
    mov ax, [cs:exec_cluster]
    jmp read_first_cluster_sector

; AX/DX = CD LBA low/high. Read the sector into SEC_BUF via CD_BUF.
read_first_sector_cd:
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov si, ax
    mov ax, CD_BUF
    mov es, ax
    xor bx, bx
    mov ax, si
    call cd_read_sector_current
    jc .err
    mov ax, CD_BUF
    mov ds, ax
    mov ax, SEC_BUF
    mov es, ax
    xor si, si
    xor di, di
    mov cx, 256
    rep movsw
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    clc
    ret
.err:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    stc
    ret

exec_read_first_sector_cd:
    mov ax, [cs:exec_cluster]
    mov dx, [cs:exec_cd_lba_hi]
    jmp read_first_sector_cd

load_cd_file_direct:
    mov ax, [cs:kfsize]
    mov [cs:lf_left_lo], ax
    mov ax, [cs:kfsize_hi]
    mov [cs:lf_left_hi], ax
    mov ax, [cs:exec_cluster]
    mov [cs:.lba_lo], ax
    mov ax, [cs:exec_cd_lba_hi]
    mov [cs:.lba_hi], ax
.load:
    cmp word [cs:lf_left_hi], 0
    jne .have_left
    cmp word [cs:lf_left_lo], 0
    je .done
.have_left:
    push es
    push bx
    mov ax, CD_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:.lba_lo]
    mov dx, [cs:.lba_hi]
    call cd_read_sector_current
    pop bx
    pop es
    jc .err
    push ds
    push si
    push di
    mov ax, CD_BUF
    mov ds, ax
    xor si, si
    mov di, bx
    cmp word [cs:lf_left_hi], 0
    jne .copy_full_sector
    mov cx, [cs:lf_left_lo]
    cmp cx, 2048
    jb .copy_chunk_set
.copy_full_sector:
    mov cx, 2048
.copy_chunk_set:
    mov [cs:lf_chunk], cx
    PERF_INC perf_loader_copies
    COPY_BYTES_WORDS
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
    INC_DWORD_CS .lba_lo, .lba_hi
    jmp .load
.done:
    push cs
    pop ds
    xor ax, ax
    ret
.err:
    push cs
    pop ds
    mov ax, 1
    ret

.lba_lo: dw 0
.lba_hi: dw 0

exec_copy_command_tail:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    mov ax, [cs:prog_seg]
    mov es, ax
    mov word [es:0x80], 0x0D00
    mov ax, [cs:exec_param_seg]
    test ax, ax
    jz .done
    mov ds, ax
    mov bx, [cs:exec_param_off]
    mov si, [bx+2]
    mov ax, [bx+4]
    test ax, ax
    jz .done
    cmp ax, MCB_START
    jb .err
    cmp ax, MEM_TOP
    jae .err
    mov ds, ax
    mov ax, [cs:prog_seg]
    mov es, ax
    xor cx, cx
    mov cl, [ds:si]
    cmp cl, 126
    jbe .len_ok
    mov cl, 126
.len_ok:
    mov [es:0x80], cl
    inc si
    mov di, 0x81
    rep movsb
    mov byte [es:di], 0x0D
.done:
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    clc
    ret
.err:
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    mov ax, 8
    stc
    ret

update_exec_environment_path:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    mov word [cs:exec_env_src_seg], 0
    mov ax, [cs:exec_param_seg]
    test ax, ax
    jz .inherit_parent_env
    mov ds, ax
    mov bx, [cs:exec_param_off]
    mov ax, [bx]
    test ax, ax
    jz .inherit_parent_env
    cmp ax, MCB_START
    jb .env_overflow
    cmp ax, MEM_TOP
    jae .env_overflow
    mov [cs:exec_env_src_seg], ax
    jmp .default_env
.inherit_parent_env:
    mov ax, [cs:cur_psp]
    test ax, ax
    jz .default_env
    cmp ax, MCB_START
    jb .default_env
    cmp ax, MEM_TOP
    jae .default_env
    mov ds, ax
    mov ax, [0x2C]
    test ax, ax
    jz .default_env
    cmp ax, MCB_START
    jb .default_env
    cmp ax, MEM_TOP
    jae .default_env
    mov [cs:exec_env_src_seg], ax
.default_env:
    mov bx, ENV_PARAS
    mov ax, [cs:exec_env_src_seg]
    test ax, ax
    jz .env_size_ready
    mov ds, ax
    xor si, si
.env_measure:
    cmp si, 0x7E00
    jae .env_overflow
    lodsb
    test al, al
    jnz .env_measure
    cmp byte [ds:si], 0
    jne .env_measure
    mov ax, si
    add ax, 1 + 192 + 15
    mov cl, 4
    shr ax, cl
    cmp ax, ENV_PARAS
    jbe .env_size_ready
    mov bx, ax
.env_size_ready:
    call alloc_exec_environment
    jc .fail
    mov ax, [cs:exec_env_seg]
    mov es, ax
    xor di, di
    mov bx, [cs:exec_env_bytes]
    mov ax, [cs:exec_env_src_seg]
    test ax, ax
    jz .write_default_vars
    mov ds, ax
    xor si, si
.copy_env:
    cmp di, bx
    jae .env_overflow
    lodsb
    stosb
    test al, al
    jnz .copy_env
    cmp byte [ds:si], 0
    jne .copy_env
    cmp di, bx
    jae .env_overflow
    lodsb
    stosb
    jmp .vars_done
.write_default_vars:
    call write_environment_vars
.vars_done:
    mov ax, bx
    dec ax
    cmp di, ax
    jae .env_overflow
    mov ax, 1
    stosw
    mov ds, [cs:exec_path_seg]
    mov si, [cs:exec_path_off]
    mov al, [cs:dos_drive_letter]
    cmp byte [ds:si+1], ':'
    jne .tail_drive_ready
    mov al, [ds:si]
    call ascii_upper
.tail_drive_ready:
    cmp di, bx
    jae .env_overflow
; @anchor: env_path_first_byte
    stosb
    mov al, ':'
    cmp di, bx
    jae .env_overflow
    stosb
    mov al, '\'
    cmp di, bx
    jae .env_overflow
    stosb
    cmp byte [ds:si], '\'
    je .skip_sep
    cmp byte [ds:si], '/'
    je .skip_sep
    cmp byte [ds:si+1], ':'
    jne .relative_prefix
    add si, 2
    cmp byte [ds:si], '\'
    je .skip_sep
    cmp byte [ds:si], '/'
    je .skip_sep
.relative_prefix:
    push ds
    push si
    push cs
    pop ds
    mov si, cur_dir_path
    cmp byte [ds:si], 0
    je .relative_no_cwd
.relative_cwd_loop:
    cmp di, bx
    jae .env_overflow_pop2
    lodsb
    test al, al
    jz .relative_cwd_done
    stosb
    jmp .relative_cwd_loop
.relative_cwd_done:
    mov al, '\'
    stosb
.relative_no_cwd:
    pop si
    pop ds
.skip_sep:
    cmp byte [ds:si], '\'
    je .skip_one_sep
    cmp byte [ds:si], '/'
    je .skip_one_sep
    cmp byte [ds:si], '.'
    jne .copy
    cmp byte [ds:si+1], '\'
    je .skip_dot_sep
    cmp byte [ds:si+1], '/'
    jne .copy
.skip_dot_sep:
    inc si
    jmp .skip_sep
.skip_one_sep:
    inc si
    jmp .skip_sep
.copy:
    mov cx, 80
.copy_loop:
    cmp di, bx
    jae .env_overflow
    lodsb
    test al, al
    jz .path_done
    cmp al, '/'
    je .slash
    cmp al, '\'
    je .slash
    call ascii_upper
    jmp .store
.slash:
    mov al, '\'
.store:
    stosb
    loop .copy_loop
.path_done:
    cmp di, bx
    jae .env_overflow
    xor al, al
    stosb
    clc
    jmp .done
.env_overflow_pop2:
    pop si
    pop ds
.env_overflow:
    call free_exec_environment
    stc
    jmp .done
.fail:
    stc
.done:
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    ret

; @anchor: alloc_exec_environment_start
alloc_exec_environment:
    push bx
; @anchor: alloc_exec_environment_owner_seed
    push ds
    mov word [cs:exec_env_seg], 0
    mov byte [cs:exec_env_owned], 0
    mov ax, bx
    mov cl, 4
    shl ax, cl
    mov [cs:exec_env_bytes], ax
    call alloc_mem_direct
    jc .fail
    mov [cs:exec_env_seg], ax
    mov byte [cs:exec_env_owned], 1
    push ax
    dec ax
    mov ds, ax
; @anchor: alloc_exec_environment_temp_owner
    mov word [ds:1], ENV_OWNER_TEMP
    pop ax
    clc
    pop ds
    pop bx
    ret
.fail:
    stc
    pop ds
    pop bx
    ret

; @anchor: free_exec_environment_start
free_exec_environment:
    push ax
; @anchor: free_exec_environment_free_block
    push ds
    push si
    mov ax, [cs:exec_env_seg]
    test ax, ax
    jz .done
    cmp byte [cs:exec_env_owned], 1
    jne .clear
    dec ax
    mov ds, ax
    MCB_IS_VALID
    jne .clear
.free:
; @anchor: free_exec_environment_coalesce
    mov word [ds:1], 0
    mov si, ax
    call mcb_merge_free_forward
.clear:
; @anchor: free_exec_environment_clear
    mov word [cs:exec_env_seg], 0
    mov byte [cs:exec_env_owned], 0
.done:
    pop si
    pop ds
    pop ax
    ret

assign_exec_environment_owner:
    push ax
    push bx
    push ds
    mov bx, [cs:exec_env_seg]
    test bx, bx
    jz .done
    cmp byte [cs:exec_env_owned], 1
    jne .done
    dec bx
    mov ds, bx
    MCB_IS_VALID
    jne .done
.assign:
    mov ax, [cs:cur_psp]
; @anchor: env_owner_store
    mov [ds:1], ax
.done:
    pop ds
    pop bx
    pop ax
    ret

free_prog_mcb:
    push ax
    push ds
    push si
    mov ax, [cs:prog_seg]
    test ax, ax
    jz .done
    dec ax
    mov ds, ax
    MCB_IS_VALID
    jne .clear
.free:
    mov word [ds:1], 0
    mov si, ax
    call mcb_merge_free_forward
.clear:
    mov word [cs:prog_seg], 0
.done:
    pop si
    pop ds
    pop ax
    ret

load_overlay_direct:
    call overlay_read_first_sector
    jc .err
    push ds
    mov ax, SEC_BUF
    mov ds, ax
    cmp word [0], 0x5A4D
    je .mz
    pop ds
    mov word [cs:ov_skip], 0
    mov ax, [cs:ov_size_hi]
    mov [cs:ov_left_hi], ax
    mov ax, [cs:ov_size_lo]
    mov [cs:ov_left], ax
    mov ax, [cs:ov_load_seg]
    mov [cs:ov_dst_seg], ax
    mov word [cs:ov_dst_off], 0
    call overlay_copy_range
    ret
.mz:
    cmp word [0x08], 0x1000
    jae .mz_bad_pop
    mov ax, [0x08]
    mov cx, 4
.hdr_shift:
    shl ax, 1
    loop .hdr_shift
    mov [cs:ov_skip], ax
    call mz_image_bytes
    sub ax, [cs:ov_skip]
    sbb dx, 0
    jc .mz_bad_pop
    mov [cs:ov_left], ax
    mov [cs:ov_left_hi], dx
    mov ax, [0x06]
    mov [cs:ov_reloc_count], ax
    mov ax, [0x18]
    mov [cs:ov_reloc_off], ax
    mov ax, [cs:ov_reloc_count]
    mov dx, [cs:ov_reloc_off]
    mov bx, [0x08]
    call validate_exe_reloc_table
    jc .mz_bad_pop
    mov ax, [cs:ov_left]
    mov dx, [cs:ov_left_hi]
    add ax, 15
    adc dx, 0
    mov cx, 4
.ov_img_shift:
    shr dx, 1
    rcr ax, 1
    loop .ov_img_shift
    test dx, dx
    jnz .mz_bad_pop
    mov [cs:ov_image_par], ax
    pop ds
    mov ax, [cs:ov_load_seg]
    mov [cs:ov_dst_seg], ax
    mov word [cs:ov_dst_off], 0
    call overlay_copy_range
    jc .err
    call overlay_apply_relocs
    ret
.mz_bad_pop:
    pop ds
.err:
    stc
    ret

overlay_apply_relocs:
    push ax
    push bx
    push cx
    push ds
    push es
    push di
    mov word [cs:ov_rel_sec_idx], 0xFFFF
    mov word [cs:ov_rel_clus_base], 0xFFFF
    mov cx, [cs:ov_reloc_count]
    test cx, cx
    jz .done
    cmp word [cs:ov_image_par], 0
    je .err
.loop:
    call overlay_fetch_reloc_entry
    jc .err
    cmp di, 0xFFFE
    ja .err
    cmp ax, [cs:ov_image_par]
    jae .err
    add ax, [cs:ov_load_seg]
    jc .err
    mov es, ax
    mov ax, [es:di]
    add ax, [cs:ov_reloc_seg]
    mov [es:di], ax
    loop .loop
.done:
    pop di
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    clc
    ret
.err:
    pop di
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    stc
    ret

overlay_fetch_reloc_entry:
    push bx
    push cx
    push ds
    mov word [cs:ov_rel_stage_n], 0
.byte_loop:
    call overlay_load_reloc_sector
    jc .err
    mov bx, [cs:ov_reloc_off]
    and bx, 511
    mov ax, SEC_BUF
    mov ds, ax
    mov al, [bx]
    mov bx, [cs:ov_rel_stage_n]
    mov [cs:ov_rel_stage+bx], al
    inc word [cs:ov_rel_stage_n]
    inc word [cs:ov_reloc_off]
    cmp word [cs:ov_rel_stage_n], 4
    jb .byte_loop
    mov di, [cs:ov_rel_stage]
    mov ax, [cs:ov_rel_stage+2]
    pop ds
    pop cx
    pop bx
    clc
    ret
.err:
    pop ds
    pop cx
    pop bx
    stc
    ret

overlay_load_reloc_sector:
    push ax
    mov ax, [cs:ov_reloc_off]
    shr ax, 9
    cmp ax, [cs:ov_rel_sec_idx]
    je .cached
    mov [cs:ov_rel_sec_idx], ax
    pop ax
    call overlay_read_reloc_sector
    jnc .ok
    mov word [cs:ov_rel_sec_idx], 0xFFFF
    stc
    ret
.ok:
    clc
    ret
.cached:
    pop ax
    clc
    ret

overlay_read_reloc_sector:
    cmp byte [cs:kdrive_type], DRIVE_TYPE_CDROM
    je overlay_read_reloc_sector_cd
    push ax
    push bx
    push cx
    push dx
    push si
    push es
    mov si, [cs:ov_cluster]
    mov ax, [cs:ov_reloc_off]
    mov cx, 9
.sector_shift:
    shr ax, 1
    loop .sector_shift
    mov bx, ax
    xor dx, dx
    cmp word [cs:ov_rel_clus_base], 0xFFFF
    je .walk_ready
    cmp bx, [cs:ov_rel_clus_base]
    jb .walk_ready
    mov si, [cs:ov_rel_clus]
    mov dx, [cs:ov_rel_clus_base]
    sub bx, dx
.walk_ready:
.cluster_walk:
    xor ch, ch
    mov cl, [cs:kspc]
    cmp bx, cx
    jb .read_sector
    sub bx, cx
    add dx, cx
    push dx
    call fat_next
    pop dx
    cmp ax, [cs:kfat_eoc]
    jae .err
    cmp ax, 2
    jb .err
    mov si, ax
    jmp .cluster_walk
.read_sector:
    mov [cs:ov_rel_clus], si
    mov [cs:ov_rel_clus_base], dx
    mov ax, si
    call cluster_lba
    mov [cs:kio_lba_hi], dx
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    jc .err
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err:
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

overlay_read_reloc_sector_cd:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov ax, [cs:ov_reloc_off]
    mov cx, 9
.logical_shift:
    shr ax, 1
    loop .logical_shift
    mov bx, ax
    mov cl, 2
    shr ax, cl
    mov dx, [cs:ov_cd_lba_hi]
    add ax, [cs:ov_cluster]
    adc dx, 0
    push bx
    push ax
    mov ax, CD_BUF
    mov es, ax
    xor bx, bx
    pop ax
    call cd_read_sector_current
    pop bx
    jc .err
    and bx, 3
    mov cl, 9
    shl bx, cl
    mov ax, CD_BUF
    mov ds, ax
    mov si, bx
    mov ax, SEC_BUF
    mov es, ax
    xor di, di
    mov cx, 256
    rep movsw
    pop di
    pop si
    pop es
    pop ds
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
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

overlay_read_first_sector:
    cmp byte [cs:kdrive_type], DRIVE_TYPE_CDROM
    je .cd
    mov ax, [cs:ov_cluster]
    jmp read_first_cluster_sector
.cd:
    mov ax, [cs:ov_cluster]
    mov dx, [cs:ov_cd_lba_hi]
    jmp read_first_sector_cd

overlay_copy_range:
    cmp byte [cs:kdrive_type], DRIVE_TYPE_CDROM
    je overlay_copy_range_cd
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    mov si, [cs:ov_cluster]
    mov ax, [cs:ov_skip]
    mov dx, ax
    and dx, 511
    mov [cs:ov_sector_offset], dx
    mov cx, 9
.sector_shift:
    shr ax, 1
    loop .sector_shift
    mov bx, ax
.skip_cluster_loop:
    xor ch, ch
    mov cl, [cs:kspc]
    cmp bx, cx
    jb .have_sector
    sub bx, cx
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .err_pop
    cmp ax, 2
    jb .err_pop
    mov si, ax
    jmp .skip_cluster_loop
.have_sector:
    mov [cs:ov_sec_in_cluster], bx
.copy_loop:
    mov ax, [cs:ov_left]
    or ax, [cs:ov_left_hi]
    jz .done
    cmp si, [cs:kfat_eoc]
    jae .err_pop
    cmp si, 2
    jb .err_pop
    cmp word [cs:ov_sector_offset], 0
    jne .bounce_sector
    xor ax, ax
    mov al, [cs:kspc]
    sub ax, [cs:ov_sec_in_cluster]
    mov [cs:ov_direct_count], ax
    cmp word [cs:ov_direct_count], 2
    jb .bounce_sector
    cmp word [cs:ov_left_hi], 0
    jne .direct_file_ready
    mov ax, [cs:ov_left]
    mov cl, 9
    shr ax, cl
    cmp ax, [cs:ov_direct_count]
    jae .direct_file_ready
    mov [cs:ov_direct_count], ax
.direct_file_ready:
    cmp word [cs:ov_direct_count], 2
    jb .bounce_sector
    cmp word [cs:ov_direct_count], 127
    jbe .direct_count_ready
    mov word [cs:ov_direct_count], 127
.direct_count_ready:
    mov ax, [cs:ov_dst_seg]
    and ax, 0x0FFF
    mov cl, 4
    shl ax, cl
    add ax, [cs:ov_dst_off]
    jz .direct_dma_ready
    neg ax
    mov cl, 9
    shr ax, cl
    cmp ax, 2
    jb .bounce_sector
    cmp [cs:ov_direct_count], ax
    jbe .direct_dma_ready
    mov [cs:ov_direct_count], ax
.direct_dma_ready:
    cmp word [cs:ov_direct_count], 2
    jb .bounce_sector
    push si
    mov ax, si
    mov bx, [cs:ov_sec_in_cluster]
    call cluster_lba
    mov [cs:kio_lba_hi], dx
    mov es, [cs:ov_dst_seg]
    mov bx, [cs:ov_dst_off]
    mov cx, [cs:ov_direct_count]
    call read_sectors
    mov [cs:ov_dst_seg], es
    mov [cs:ov_dst_off], bx
    pop si
    jc .err_pop
    mov ax, [cs:ov_direct_count]
    mov cx, 512
    mul cx
    mov [cs:ov_chunk], ax
    sub [cs:ov_left], ax
    sbb word [cs:ov_left_hi], 0
    mov ax, [cs:ov_direct_count]
    add [cs:ov_sec_in_cluster], ax
    xor ch, ch
    mov cl, [cs:kspc]
    cmp [cs:ov_sec_in_cluster], cx
    jb .copy_loop
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .done
    cmp ax, 2
    jb .err_pop
    mov si, ax
    mov word [cs:ov_sec_in_cluster], 0
    jmp .copy_loop
.bounce_sector:
    push si
    mov ax, si
    mov bx, [cs:ov_sec_in_cluster]
    call cluster_lba
    mov [cs:kio_lba_hi], dx
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    pop si
    jc .err_pop
    mov cx, 512
    sub cx, [cs:ov_sector_offset]
    cmp word [cs:ov_left_hi], 0
    jne .clamp_dst
    mov ax, [cs:ov_left]
    cmp cx, ax
    jbe .clamp_dst
    mov cx, ax
.clamp_dst:
    mov ax, [cs:ov_dst_off]
    neg ax
    jz .chunk_ok
    cmp cx, ax
    jbe .chunk_ok
    mov cx, ax
.chunk_ok:
    mov [cs:ov_chunk], cx
    PERF_INC perf_loader_copies
    push si
    mov ax, SEC_BUF
    mov ds, ax
    mov si, [cs:ov_sector_offset]
    mov ax, [cs:ov_dst_seg]
    mov es, ax
    mov di, [cs:ov_dst_off]
    COPY_BYTES_WORDS
    pop si
    mov ax, [cs:ov_dst_off]
    add ax, [cs:ov_chunk]
    mov [cs:ov_dst_off], ax
    jnc .dst_no_wrap
    add word [cs:ov_dst_seg], 0x1000
.dst_no_wrap:
    mov ax, [cs:ov_chunk]
    sub [cs:ov_left], ax
    sbb word [cs:ov_left_hi], 0
    add [cs:ov_sector_offset], ax
    cmp word [cs:ov_sector_offset], 512
    jb .copy_loop
    mov word [cs:ov_sector_offset], 0
    inc word [cs:ov_sec_in_cluster]
    xor ch, ch
    mov cl, [cs:kspc]
    cmp [cs:ov_sec_in_cluster], cx
    jb .copy_loop
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .done
    cmp ax, 2
    jb .err_pop
    mov si, ax
    mov word [cs:ov_sec_in_cluster], 0
    jmp .copy_loop
.done:
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err_pop:
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

overlay_copy_range_cd:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    mov ax, [cs:ov_skip]
    mov dx, ax
    and dx, 2047
    mov [cs:ov_sector_offset], dx
    mov cx, 11
.sector_shift:
    shr ax, 1
    loop .sector_shift
    mov dx, [cs:ov_cd_lba_hi]
    add ax, [cs:ov_cluster]
    adc dx, 0
    mov [cs:.lba_lo], ax
    mov [cs:.lba_hi], dx
.copy_loop:
    mov ax, [cs:ov_left]
    or ax, [cs:ov_left_hi]
    jz .done
    mov ax, CD_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:.lba_lo]
    mov dx, [cs:.lba_hi]
    call cd_read_sector_current
    jc .err_pop
    mov cx, 2048
    sub cx, [cs:ov_sector_offset]
    cmp word [cs:ov_left_hi], 0
    jne .clamp_dst
    mov ax, [cs:ov_left]
    cmp cx, ax
    jbe .clamp_dst
    mov cx, ax
.clamp_dst:
    mov ax, [cs:ov_dst_off]
    neg ax
    jz .chunk_ok
    cmp cx, ax
    jbe .chunk_ok
    mov cx, ax
.chunk_ok:
    mov [cs:ov_chunk], cx
    PERF_INC perf_loader_copies
    push ds
    mov ax, CD_BUF
    mov ds, ax
    mov si, [cs:ov_sector_offset]
    mov ax, [cs:ov_dst_seg]
    mov es, ax
    mov di, [cs:ov_dst_off]
    COPY_BYTES_WORDS
    pop ds
    mov ax, [cs:ov_dst_off]
    add ax, [cs:ov_chunk]
    mov [cs:ov_dst_off], ax
    jnc .dst_no_wrap
    add word [cs:ov_dst_seg], 0x1000
.dst_no_wrap:
    mov ax, [cs:ov_chunk]
    sub [cs:ov_left], ax
    sbb word [cs:ov_left_hi], 0
    add [cs:ov_sector_offset], ax
    cmp word [cs:ov_sector_offset], 2048
    jb .copy_loop
    mov word [cs:ov_sector_offset], 0
    inc word [cs:.lba_lo]
    jnz .copy_loop
    inc word [cs:.lba_hi]
    jmp .copy_loop
.done:
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err_pop:
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

.lba_lo: dw 0
.lba_hi: dw 0

; Terminate lands here after restoring saved_ss:saved_sp; the ret pops
; the suspended exec caller's return address (the INT 21h EXEC handler
; or the boot launcher), resuming it as if exec_*_dyn just returned.
exec_resume_parent:
    ret

; Shared child-launch prologue for exec_exe_dyn/exec_com_dyn. saved_sp
; must record the SP at the exec_*_dyn entry (so exec_resume_parent's
; ret returns to its caller), hence the +2 over this helper's frame.
exec_begin_child:
    mov byte [cs:ret_code], 0
    mov word [cs:running], 1
    push ss
    pop ax
    mov [cs:saved_ss], ax
    mov ax, sp
    add ax, 2
    mov [cs:saved_sp], ax
    call reset_keyboard_buffer
    fninit
    ret

build_psp:
    mov es, ax
    push ax
    xor di, di
    mov cx, 128
    xor ax, ax
    rep stosw

    mov byte [es:0x00], 0xCD
    mov byte [es:0x01], 0x20
    push ds
    mov ax, es
    dec ax
    mov ds, ax
    mov ax, es
    add ax, [ds:3]
    mov [es:0x02], ax
    pop ds

    push ds
    xor ax, ax
    mov ds, ax
    mov ax, [0x22*4]
    mov [es:0x0A], ax
    mov ax, [0x22*4+2]
    mov [es:0x0C], ax
    mov ax, [0x23*4]
    mov [es:0x0E], ax
    mov ax, [0x23*4+2]
    mov [es:0x10], ax
    mov ax, [0x24*4]
    mov [es:0x12], ax
    mov ax, [0x24*4+2]
    mov [es:0x14], ax
    pop ds

    pop ax
    push ax
    mov word [es:0x32], MAX_HANDLES
    mov word [es:0x34], 0x0018
    mov [es:0x36], ax
    mov bx, [cs:cur_psp]
    test bx, bx
    jz .default_jft
    push ds
    mov ds, bx
    mov si, 0x0018
    mov di, 0x0018
    mov cx, MAX_HANDLES
    cld
    rep movsb
    mov di, 0x0018
    mov cx, MAX_HANDLES
.inherit_jft_refs:
    mov al, [es:di]
    cmp al, 0xFF
    je .inherit_jft_next
    cmp al, MAX_HANDLES
    jae .inherit_jft_next
    push cx
    push di
    xor ah, ah
    mov cx, HANDLE_SIZE
    mul cx
    mov di, ax
    cmp byte [cs:di+handles+H_USED], 1
    jne .inherit_jft_pop
    mov ax, [cs:di+handles+H_ALIAS]
    cmp ax, H_ALIAS_NONE
    je .inherit_jft_ref
    cmp ax, MAX_HANDLES
    jae .inherit_jft_pop
    mov cx, HANDLE_SIZE
    mul cx
    mov di, ax
    cmp byte [cs:di+handles+H_USED], 0
    je .inherit_jft_pop
.inherit_jft_ref:
    inc word [cs:di+handles+H_REFCOUNT]
.inherit_jft_pop:
    pop di
    pop cx
.inherit_jft_next:
    inc di
    loop .inherit_jft_refs
    pop ds
    jmp .jft_ready
.default_jft:
    mov byte [es:0x18], 0
    mov byte [es:0x19], 1
    mov byte [es:0x1A], 2
    mov byte [es:0x1B], 3
    mov byte [es:0x1C], 4
    mov di, 0x001D
    mov cx, MAX_HANDLES - 5
    mov al, 0xFF
    rep stosb
.jft_ready:
    pop ax
    mov bx, [cs:cur_psp]
    mov [es:0x16], bx
    mov bx, [cs:exec_env_seg]
    mov [es:0x2C], bx
    mov [cs:dta_seg], ax
    mov word [cs:dta_off], 0x0080
    mov [cs:cur_psp], ax
    call assign_exec_environment_owner
; @anchor: build_psp_copy_fcbs
    call exec_copy_default_fcbs
    ret

exec_copy_default_fcbs:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    mov ax, [cs:exec_param_seg]
    test ax, ax
    jz .done
    mov ds, ax
    mov bx, [cs:exec_param_off]
    mov si, [bx+6]
    mov ax, [bx+8]
    test ax, ax
    jz .second
    mov ds, ax
    mov ax, [cs:prog_seg]
    mov es, ax
    mov di, 0x5C
    mov cx, 16
    cld
    rep movsb
.second:
    mov ax, [cs:exec_param_seg]
    mov ds, ax
    mov bx, [cs:exec_param_off]
    mov si, [bx+10]
    mov ax, [bx+12]
    test ax, ax
    jz .done
    mov ds, ax
    mov ax, [cs:prog_seg]
    mov es, ax
    mov di, 0x6C
    mov cx, 16
    cld
    rep movsb
.done:
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    ret

setup_exe_dyn:
    mov ax, [cs:prog_seg]
    add ax, 0x10
    mov ds, ax

    mov ax, [0x08]
    mov [cs:exe_hdr_par], ax
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 15
    adc dx, 0
    mov cx, 4
.img_par_shift:
    shr dx, 1
    rcr ax, 1
    loop .img_par_shift
    cmp ax, [cs:exe_hdr_par]
    jb .reloc_err
    sub ax, [cs:exe_hdr_par]
    mov [cs:exe_image_par], ax
    mov ax, [0x0E]
    mov [cs:exe_ss], ax
    mov ax, [0x10]
    mov [cs:exe_sp], ax
    mov ax, [0x14]
    mov [cs:exe_ip], ax
    mov ax, [0x16]
    mov [cs:exe_cs], ax
    mov ax, [0x06]
    mov [cs:exe_reloc_count], ax
    mov ax, [0x18]
    mov [cs:exe_reloc_off], ax

    cmp word [cs:exe_image_par], 0
    je .reloc_err
    mov ax, [cs:exe_reloc_count]
    mov dx, [cs:exe_reloc_off]
    mov bx, [cs:exe_hdr_par]
    call validate_exe_reloc_table
    jc .reloc_err

    mov ax, [cs:prog_seg]
    call build_psp
    call exec_copy_command_tail
    jc .tail_err

    mov ax, [cs:prog_seg]
    add ax, 0x10
    mov [cs:exe_load_seg], ax

    mov cx, [cs:exe_reloc_count]
    test cx, cx
    jz .copy_image
    mov bx, [cs:exe_reloc_off]
    mov ax, [cs:prog_seg]
    add ax, 0x10
    mov ds, ax
.reloc_source:
    push cx
    mov di, [bx]
    mov ax, [bx+2]
    cmp di, 0xFFFE
    ja .reloc_err_pop
    cmp ax, [cs:exe_image_par]
    jae .reloc_err_pop
    add ax, [cs:exe_hdr_par]
    add ax, [cs:exe_load_seg]
    jc .reloc_err_pop
    mov es, ax
    mov ax, [es:di]
    add ax, [cs:exe_load_seg]
    mov [es:di], ax
    add bx, 4
    pop cx
    loop .reloc_source

.copy_image:
    mov ax, [cs:prog_seg]
    add ax, 0x10
    add ax, [cs:exe_hdr_par]
    mov [cs:copy_src_seg], ax
    mov ax, [cs:exe_load_seg]
    mov [cs:copy_dst_seg], ax
    mov cx, [cs:exe_image_par]
.copy_par:
    test cx, cx
    jz .copy_done
    push cx
    mov ax, [cs:copy_src_seg]
    mov ds, ax
    mov ax, [cs:copy_dst_seg]
    mov es, ax
    xor si, si
    xor di, di
    mov cx, 8
    rep movsw
    inc word [cs:copy_src_seg]
    inc word [cs:copy_dst_seg]
    pop cx
    loop .copy_par
.copy_done:
    push cs
    pop ds
    cmp byte [cs:exec_no_run], 0
    jne .load_only
    call exec_exe_dyn
    ret
.load_only:
    clc
    ret
.reloc_err_pop:
    pop cx
    call release_inherited_handles
.reloc_err:
    push cs
    pop ds
    mov ax, 11
    stc
    ret
.tail_err:
    call release_inherited_handles
    mov ax, 8
    stc
    ret

exec_exe_dyn:
    call exec_begin_child
%if TRACE_EXEC_STATE
    call trace_exec_state
%endif

    mov ax, [cs:prog_seg]
    mov ds, ax
    mov es, ax

    mov ax, [cs:exe_load_seg]
    add ax, [cs:exe_ss]
    mov ss, ax
    mov sp, [cs:exe_sp]

    mov ax, [cs:exe_load_seg]
    add ax, [cs:exe_cs]
    push ax
    push word [cs:exe_ip]
    dec byte [cs:indos_flag]
    mov ax, [cs:kstack_base]
    mov [cs:saved_kbase], ax
    mov ax, [cs:saved_sp]
    sub ax, 32
    mov [cs:kstack_base], ax
    xor ax, ax
    sti
    retf

exec_com_dyn:
    call exec_begin_child

    mov ax, [cs:prog_seg]
    dec ax
    mov ds, ax
    mov ax, [ds:3]
    cmp ax, 0x1000
    jb .small_stack
    ; the first push wraps to 0xFFFE, leaving SP there with the zero
    ; word at [SP], exactly as real DOS enters a .COM
    xor ax, ax
    jmp .stack_ready
.small_stack:
    mov cx, 4
.stack_shift:
    shl ax, 1
    loop .stack_shift
.stack_ready:
    mov [cs:com_stack_top], ax

    mov ax, [cs:prog_seg]
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, [cs:com_stack_top]
    push word 0x0000
    push ax
    push word 0x0100
    dec byte [cs:indos_flag]
    mov ax, [cs:kstack_base]
    mov [cs:saved_kbase], ax
    mov ax, [cs:saved_sp]
    sub ax, 32
    mov [cs:kstack_base], ax
    xor ax, ax
    sti
; @anchor: exec_com_entry_jump
    retf

reset_keyboard_buffer:
    push ax
    push es
    mov byte [cs:console_ext_pending], 0
    mov ax, 0x0040
    mov es, ax
    mov ax, [es:0x001A]
    cmp ax, [es:0x001C]
    jne .done
    cmp ax, 0x001E
    je .done
    mov word [es:0x001A], 0x001E
    mov word [es:0x001C], 0x001E
.done:
    pop es
    pop ax
    ret
