cluster_lba:
    push cx
    cmp ax, 2
    jb .invalid
    cmp ax, [cs:kmax_cluster]
    jae .invalid
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, bx
    adc dx, 0
    add ax, [cs:kdsta]
    adc dx, 0
    pop cx
    ret
.invalid:
    mov ax, [cs:kbio_spt]
    mul word [cs:kbio_heads]
    mov cx, 1024
    mul cx
    pop cx
    ret

read_sector:
    mov cx, 1

read_sectors:
    call wf_flush_sector_cache
    jc .flush_err
    mov byte [cs:kio_op], 2
    call setup_sector_io
    jmp sector_io_loop
.flush_err:
    ret

write_sector: PERF_INC perf_sector_writes
    call subdir_cache_invalidate
    mov byte [cs:kio_op], 3
    mov cx, 1
    call setup_sector_io
    jmp sector_io_loop

sector_io_loop:
.next:
    call setup_bios_chs
    jc .geom_err
%if PERF_IO_COUNTS
    cmp byte [cs:kio_op], 2
    jne .no_read_perf
    inc word [cs:perf_sector_reads]
.no_read_perf:
%endif
    mov ah, [cs:kio_op]
    mov al, [cs:kio_xfer_count]
    int 0x13
    jnc .ok
    cmp byte [cs:kio_xfer_count], 1
    je .single_failed
    mov byte [cs:kio_force_single], 1
    xor ax, ax
    mov dl, [cs:kdrv]
    int 0x13
    jmp .next
.single_failed:
    cmp ah, 0x06
    jne .no_media_change
    cmp byte [cs:kdrv], 0x80
    jae .no_media_change
    call floppy_media_remount
    jc .fail
    mov byte [cs:kret], 3
    jmp .next
.no_media_change:
    xor ax, ax
    mov dl, [cs:kdrv]
    int 0x13
    dec byte [cs:kret]
    jnz .next
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    mov al, [cs:kio_op]
    mov ah, [cs:kdrv]
    int 0x24
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    cmp al, 1
    jne .fail
    mov byte [cs:kret], 3
    jmp .next
.fail:
.geom_err:
    stc
    ret
.ok:
    call finish_sector_io
    jnz .next
    clc
    ret

setup_sector_io:
    mov [cs:klba], ax
    mov ax, [cs:kio_lba_hi]
    mov [cs:klba_hi], ax
    mov word [cs:kio_lba_hi], 0
    mov ax, [cs:kpart_lba]
    add [cs:klba], ax
    mov ax, [cs:kpart_lba_hi]
    adc [cs:klba_hi], ax
    test cx, cx
    jnz .count_ok
    mov cx, 1
.count_ok:
    cmp ch, 0
    je .count_byte
    mov cx, 255
.count_byte:
    mov [cs:kcnt], cl
    mov byte [cs:kio_force_single], 0
    mov byte [cs:kret], 3
    ret

setup_bios_chs:
    cmp word [cs:kbio_spt], 0
    je .geom_err
    cmp word [cs:kbio_heads], 0
    je .geom_err
    mov ax, [cs:klba]
    mov dx, [cs:klba_hi]
    cmp dx, [cs:kbio_spt]
    jae .geom_err
    div word [cs:kbio_spt]
    push ax
    inc dl
    mov [cs:ksc], dl
    mov al, [cs:kcnt]
    mov [cs:kio_xfer_count], al
    cmp byte [cs:kio_force_single], 0
    je .multi_caps
    mov byte [cs:kio_xfer_count], 1
    jmp .xfer_ready
.multi_caps:
    dec dl
    mov ax, [cs:kbio_spt]
    sub ax, dx
    cmp ah, 0
    jne .track_ready
    cmp al, [cs:kio_xfer_count]
    jae .track_ready
    mov [cs:kio_xfer_count], al
.track_ready:
    mov ax, es
    and ax, 0x0FFF
    mov cl, 4
    shl ax, cl
    add ax, bx
    jnz .dma_nonzero
    mov al, 127
    jmp .dma_cap
.dma_nonzero:
    neg ax
    mov cl, 9
    shr ax, cl
    test ax, ax
    jz .geom_err_pop
    cmp ah, 0
    jne .xfer_ready
.dma_cap:
    cmp al, [cs:kio_xfer_count]
    jae .xfer_ready
    mov [cs:kio_xfer_count], al
.xfer_ready:
    cmp byte [cs:kio_xfer_count], 0
    jne .xfer_nonzero
    mov byte [cs:kio_xfer_count], 1
.xfer_nonzero:
    pop ax
    xor dx, dx
    div word [cs:kbio_heads]
    cmp ax, 1024
    jae .geom_err
    mov [cs:khd], dl
    mov [cs:kcy], ax
    mov ax, [cs:kcy]
    mov ch, al
    mov cl, [cs:ksc]
    mov al, ah
    and al, 0x03
    shl al, 6
    or cl, al
    mov dh, [cs:khd]
    mov dl, [cs:kdrv]
    clc
    ret
.geom_err_pop:
    pop ax
.geom_err:
    stc
    ret

finish_sector_io:
%if PERF_IO_COUNTS
    cmp byte [cs:kio_op], 2
    jne .no_sector_perf
    xor ax, ax
    mov al, [cs:kio_xfer_count]
    add [cs:perf_read_sectors], ax
.no_sector_perf:
%endif
    mov ax, 512
    xor ch, ch
    mov cl, [cs:kio_xfer_count]
    mul cx
    add bx, ax
    adc dx, 0
    test dx, dx
    jz .no_wrap
    mov ax, es
.seg_advance:
    add ax, 0x1000
    dec dx
    jnz .seg_advance
    mov es, ax
.no_wrap:
    xor ch, ch
    mov cl, [cs:kio_xfer_count]
.lba_loop:
    INC_DWORD_CS klba, klba_hi
    loop .lba_loop
    mov al, [cs:kio_xfer_count]
    sub [cs:kcnt], al
    ret
