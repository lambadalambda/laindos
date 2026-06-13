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

read_sector: PERF_INC perf_sector_reads
    call wf_flush_sector_cache
    jc .flush_err
    mov byte [cs:kio_op], 2
    call setup_sector_io
    jmp sector_io_loop
.flush_err:
    ret

write_sector: PERF_INC perf_sector_writes
    mov byte [cs:rf_cache_valid], 0
    mov byte [cs:kio_op], 3
    call setup_sector_io
    jmp sector_io_loop

sector_io_loop:
.next:
    call setup_bios_chs
    jc .geom_err
    mov ah, [cs:kio_op]
    mov al, 1
    int 0x13
    jnc .ok
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
    mov byte [cs:kcnt], 1
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
    inc dl
    mov [cs:ksc], dl
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
.geom_err:
    stc
    ret

finish_sector_io:
    add bx, 512
    jnc .no_wrap
    mov ax, es
    add ax, 0x1000
    mov es, ax
.no_wrap:
    INC_DWORD_CS klba, klba_hi
    dec byte [cs:kcnt]
    ret
