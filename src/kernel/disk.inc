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
    mov byte [cs:rf_cache_valid], 0
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
.r1:
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
    mov ah, 2
    mov al, 1
    mov dh, [cs:khd]
    mov dl, [cs:kdrv]
    int 0x13
    jnc .ok
    xor ax, ax
    mov dl, [cs:kdrv]
    int 0x13
    dec byte [cs:kret]
    jnz .r1
.geom_err:
    stc
    ret
.ok:
    add bx, 512
    jnc .rnb
    mov ax, es
    add ax, 0x1000
    mov es, ax
.rnb:
    inc word [cs:klba]
    jnz .rnb_hi
    inc word [cs:klba_hi]
.rnb_hi:
    dec byte [cs:kcnt]
    jnz .r1
    clc
    ret

write_sector:
    mov byte [cs:rf_cache_valid], 0
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
.w1:
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
    mov ah, 3
    mov al, 1
    mov dh, [cs:khd]
    mov dl, [cs:kdrv]
    int 0x13
    jnc .ok
    xor ax, ax
    mov dl, [cs:kdrv]
    int 0x13
    dec byte [cs:kret]
    jnz .w1
.geom_err:
    stc
    ret
.ok:
    add bx, 512
    jnc .wnb
    mov ax, es
    add ax, 0x1000
    mov es, ax
.wnb:
    inc word [cs:klba]
    jnz .wnb_hi
    inc word [cs:klba_hi]
.wnb_hi:
    dec byte [cs:kcnt]
    jnz .w1
    clc
    ret
