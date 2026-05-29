load_exec_program:
    mov word [cs:exec_env_seg], 0
    mov byte [cs:exec_env_owned], 0
    mov ds, [cs:exec_path_seg]
    mov si, [cs:exec_path_off]
    call resolve_path
    jnc .found
    mov ax, 2
    stc
    ret
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
    mov ax, [0x04]
    xor dx, dx
    cmp word [0x02], 0
    je .exe_mz_size_shift
    dec ax
.exe_mz_size_shift:
    mov cx, 9
.exe_mz_size_loop:
    shl ax, 1
    rcl dx, 1
    loop .exe_mz_size_loop
    mov cx, [0x02]
    test cx, cx
    jz .exe_mz_size_store
    add ax, cx
    adc dx, 0
.exe_mz_size_store:
    mov [cs:kfsize], ax
    mov [cs:kfsize_hi], dx
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 15
    adc dx, 0
    mov cx, 4
.exe_min_shift:
    shr dx, 1
    rcr ax, 1
    loop .exe_min_shift
    test dx, dx
    jnz .exe_too_large
    sub ax, [0x08]
    add ax, [0x0A]
    add ax, 0x10
    mov [cs:exe_min_par], ax
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 511
    adc dx, 0
    mov cx, 9
.exe_file_shr:
    shr dx, 1
    rcr ax, 1
    loop .exe_file_shr
    mov cx, 5
.exe_file_shl:
    shl ax, 1
    rcl dx, 1
    loop .exe_file_shl
    add ax, 0x12
    adc dx, 0
    test dx, dx
    jz .exe_size_ok
.exe_too_large:
    call free_exec_environment
    mov ax, 8
    stc
    ret
.exe_size_ok:
    cmp ax, [cs:exe_min_par]
    jae .exe_use_file
    mov ax, [cs:exe_min_par]
.exe_use_file:
    mov [cs:prog_par], ax
    mov cx, [0x0C]
    test cx, cx
    jz .alloc
    cmp cx, 0xFFFF
    je .exe_max_all
    mov ax, [cs:exe_min_par]
    sub ax, [0x0A]
    add ax, cx
    jc .exe_max_all
    cmp ax, [cs:prog_par]
    jae .exe_max_desired_ready
    mov ax, [cs:prog_par]
.exe_max_desired_ready:
    call find_largest_free_block
    cmp bx, [cs:prog_par]
    jb .alloc
    cmp ax, bx
    jbe .exe_max_use_desired
    mov ax, bx
.exe_max_use_desired:
    mov [cs:prog_par], ax
    jmp .alloc
.exe_max_all:
    call find_largest_free_block
    cmp bx, [cs:prog_par]
    jb .alloc
    mov [cs:prog_par], bx
    jmp .alloc
.com_size:
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 511
    adc dx, 0
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
    add ax, COM_EXTRA_PAR
    adc dx, 0
    test dx, dx
    jz .com_size_ok
    call free_exec_environment
    mov ax, 8
    stc
    ret
.com_size_ok:
    mov [cs:prog_par], ax
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
    mov si, [cs:exec_cluster]
    call load_file_direct
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
.loaded_done:
    xor ax, ax
    clc
    ret

exec_read_first_sector:
    push bx
    push cx
    push dx
    push es
    mov ax, [cs:exec_cluster]
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
    mov ds, ax
    mov ax, [cs:prog_seg]
    mov es, ax
    mov di, 0x80
    mov cx, 128
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

update_exec_environment_path:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    mov ax, [cs:exec_param_seg]
    test ax, ax
    jz .default_env
    mov ds, ax
    mov bx, [cs:exec_param_off]
    mov ax, [bx]
    test ax, ax
    jz .default_env
    mov [cs:exec_env_seg], ax
    mov byte [cs:exec_env_owned], 0
    clc
    jmp .done
.default_env:
    call alloc_exec_environment
    jc .fail
    mov ax, [cs:exec_env_seg]
    mov es, ax
    xor di, di
    call write_environment_vars
    mov ax, 1
    stosw
    mov al, [cs:dos_drive_letter]
    stosb
    mov al, ':'
    stosb
    mov al, '\'
    stosb
    mov ds, [cs:exec_path_seg]
    mov si, [cs:exec_path_off]
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
    jne .copy
.skip_one_sep:
    inc si
    jmp .skip_sep
.copy:
    mov cx, 80
.copy_loop:
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
    xor al, al
    stosb
    clc
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

alloc_exec_environment:
    push bx
    push ds
    mov word [cs:exec_env_seg], 0
    mov byte [cs:exec_env_owned], 0
    mov bx, ENV_PARAS
    call alloc_mem_direct
    jc .fail
    mov [cs:exec_env_seg], ax
    mov byte [cs:exec_env_owned], 1
    push ax
    dec ax
    mov ds, ax
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

free_exec_environment:
    push ax
    push ds
    mov ax, [cs:exec_env_seg]
    test ax, ax
    jz .done
    cmp byte [cs:exec_env_owned], 1
    jne .clear
    dec ax
    mov ds, ax
    cmp byte [ds:0], MCB_SIG_M
    je .free
    cmp byte [ds:0], MCB_SIG_Z
    jne .clear
.free:
    mov word [ds:1], 0
.clear:
    mov word [cs:exec_env_seg], 0
    mov byte [cs:exec_env_owned], 0
.done:
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
    cmp byte [ds:0], MCB_SIG_M
    je .assign
    cmp byte [ds:0], MCB_SIG_Z
    jne .done
.assign:
    mov ax, [cs:cur_psp]
    mov [ds:1], ax
.done:
    pop ds
    pop bx
    pop ax
    ret

free_prog_mcb:
    push ax
    push ds
    mov ax, [cs:prog_seg]
    test ax, ax
    jz .done
    dec ax
    mov ds, ax
    cmp byte [ds:0], MCB_SIG_M
    je .free
    cmp byte [ds:0], MCB_SIG_Z
    jne .done
.free:
    mov word [ds:1], 0
.done:
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
    cmp word [cs:ov_size_hi], 0
    jne .err
    mov ax, [cs:ov_size_lo]
    mov [cs:ov_left], ax
    mov ax, [cs:ov_load_seg]
    mov [cs:ov_dst_seg], ax
    mov word [cs:ov_dst_off], 0
    call overlay_copy_range
    ret
.mz:
    mov ax, [0x08]
    mov cx, 4
.hdr_shift:
    shl ax, 1
    loop .hdr_shift
    mov [cs:ov_skip], ax
    mov ax, [0x04]
    xor dx, dx
    cmp word [0x02], 0
    je .mz_size_shift
    dec ax
.mz_size_shift:
    mov cx, 9
.mz_size_loop:
    shl ax, 1
    rcl dx, 1
    loop .mz_size_loop
    mov cx, [0x02]
    test cx, cx
    jz .mz_size_ready
    add ax, cx
    adc dx, 0
.mz_size_ready:
    sub ax, [cs:ov_skip]
    sbb dx, 0
    jc .mz_bad_pop
    test dx, dx
    jnz .mz_bad_pop
    mov [cs:ov_left], ax
    mov ax, [0x06]
    mov [cs:ov_reloc_count], ax
    mov ax, [0x18]
    mov [cs:ov_reloc_off], ax
    cmp word [cs:ov_reloc_off], 0x1C
    jb .mz_bad_pop
    mov ax, [cs:ov_reloc_count]
    shl ax, 1
    jc .mz_bad_pop
    shl ax, 1
    jc .mz_bad_pop
    add ax, [cs:ov_reloc_off]
    jc .mz_bad_pop
    cmp ax, [cs:ov_skip]
    ja .mz_bad_pop
    mov ax, [cs:ov_left]
    add ax, 15
    mov cx, 4
.ov_img_shift:
    shr ax, 1
    loop .ov_img_shift
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
    mov cx, [cs:ov_reloc_count]
    test cx, cx
    jz .done
    cmp word [cs:ov_image_par], 0
    je .err
.loop:
    call overlay_read_reloc_sector
    jc .err
    push ds
    mov ax, SEC_BUF
    mov ds, ax
    mov bx, [cs:ov_reloc_off]
    and bx, 511
    cmp bx, 508
    ja .entry_crosses_sector
    mov di, [bx]
    mov ax, [bx+2]
    pop ds
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
    add word [cs:ov_reloc_off], 4
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
.entry_crosses_sector:
    pop ds
.err:
    pop di
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    stc
    ret

overlay_read_reloc_sector:
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
.cluster_walk:
    xor ch, ch
    mov cl, [cs:kspc]
    cmp bx, cx
    jb .read_sector
    sub bx, cx
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .err
    cmp ax, 2
    jb .err
    mov si, ax
    jmp .cluster_walk
.read_sector:
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

overlay_read_first_sector:
    push bx
    push cx
    push dx
    push es
    mov ax, [cs:ov_cluster]
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

overlay_copy_range:
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
    test ax, ax
    jz .done
    cmp si, [cs:kfat_eoc]
    jae .err_pop
    cmp si, 2
    jb .err_pop
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
    mov ax, [cs:ov_left]
    cmp cx, ax
    jbe .chunk_ok
    mov cx, ax
.chunk_ok:
    mov [cs:ov_chunk], cx
    push si
    mov ax, SEC_BUF
    mov ds, ax
    mov si, [cs:ov_sector_offset]
    mov ax, [cs:ov_dst_seg]
    mov es, ax
    mov di, [cs:ov_dst_off]
    rep movsb
    pop si
    mov ax, [cs:ov_dst_off]
    add ax, [cs:ov_chunk]
    mov [cs:ov_dst_off], ax
    jnc .dst_no_wrap
    add word [cs:ov_dst_seg], 0x1000
.dst_no_wrap:
    mov ax, [cs:ov_chunk]
    sub [cs:ov_left], ax
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

exec_com:
    mov byte [cs:ret_code], 0
    mov word [cs:running], 1
    push ss
    pop ax
    mov [cs:saved_ss], ax
    mov [cs:saved_sp], sp
    call reset_keyboard_buffer
    fninit

    mov ax, PSP_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    push word 0x0000
    jmp far PSP_SEG:0x0100

.back:
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
    mov bx, [cs:cur_psp]
    mov [es:0x16], bx
    mov bx, [cs:exec_env_seg]
    mov [es:0x2C], bx
    mov [cs:dta_seg], ax
    mov word [cs:dta_off], 0x0080
    mov [cs:cur_psp], ax
    call assign_exec_environment_owner
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

setup_exe:
    mov ax, TEMP_SEG
    mov ds, ax

    mov ax, [0x08]
    mov [cs:exe_hdr_par], ax
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

    mov ax, PSP_SEG
    add ax, 0x10
    mov [cs:exe_load_seg], ax

    mov ax, [cs:exe_hdr_par]
    mov cx, 16
    mul cx
    mov si, ax

    mov ax, TEMP_SEG
    mov ds, ax
    mov ax, [cs:exe_load_seg]
    mov es, ax
    xor di, di
    mov cx, [cs:kfsize]
    sub cx, si
    rep movsb

    mov cx, [cs:exe_reloc_count]
    test cx, cx
    jz .no_reloc
.reloc_loop:
    push cx
    mov bx, [cs:exe_reloc_off]
    mov ax, TEMP_SEG
    mov ds, ax
    mov di, [bx]
    mov ax, [bx+2]
    pop cx

    push ax
    add ax, [cs:exe_load_seg]
    mov es, ax
    pop ax
    mov ax, [es:di]
    add ax, [cs:exe_load_seg]
    mov [es:di], ax

    add word [cs:exe_reloc_off], 4
    loop .reloc_loop
.no_reloc:
    push cs
    pop ds
    call exec_exe
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
    cmp word [cs:exe_reloc_off], 0x1C
    jb .reloc_err
    mov ax, [cs:exe_reloc_count]
    shl ax, 1
    jc .reloc_err
    shl ax, 1
    jc .reloc_err
    add ax, [cs:exe_reloc_off]
    jc .reloc_err
    mov dx, [cs:exe_hdr_par]
    cmp dx, 4096
    jae .reloc_err
    shl dx, 1
    shl dx, 1
    shl dx, 1
    shl dx, 1
    cmp ax, dx
    ja .reloc_err

    mov ax, [cs:prog_seg]
    call build_psp
    call exec_copy_command_tail

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
    call exec_exe_dyn
    ret
.reloc_err_pop:
    pop cx
.reloc_err:
    push cs
    pop ds
    mov ax, 11
    stc
    ret

exec_exe_dyn:
    mov byte [cs:ret_code], 0
    mov word [cs:running], 1
    push ss
    pop ax
    mov [cs:saved_ss], ax
    mov [cs:saved_sp], sp
    call reset_keyboard_buffer
    fninit
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
    retf

exec_com_dyn:
    mov byte [cs:ret_code], 0
    mov word [cs:running], 1
    push ss
    pop ax
    mov [cs:saved_ss], ax
    mov [cs:saved_sp], sp
    call reset_keyboard_buffer
    fninit

    mov ax, [cs:prog_seg]
    dec ax
    mov ds, ax
    mov ax, [ds:3]
    cmp ax, 0x1000
    jb .small_stack
    mov ax, 0xFFFE
    jmp .stack_ready
.small_stack:
    mov cx, 4
.stack_shift:
    shl ax, 1
    loop .stack_shift
    sub ax, 2
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
    retf

exec_exe:
    mov byte [cs:ret_code], 0
    mov word [cs:running], 1
    push ss
    pop ax
    mov [cs:saved_ss], ax
    mov [cs:saved_sp], sp
    call reset_keyboard_buffer
    fninit

    mov ax, PSP_SEG
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
