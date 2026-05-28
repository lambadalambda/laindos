fat_next:
    cmp si, 2
    jb .invalid
    cmp si, [cs:kmax_cluster]
    jae .invalid
    cmp byte [cs:kfat_bits], 16
    je fat16_next
    push bx
    mov bx, si
    shr bx, 1
    add bx, si
    push ds
    mov ax, FAT_SEG
    mov ds, ax
    mov ax, [bx]
    pop ds
    test si, 1
    jz .even
    shr ax, 4
    jmp .ret
.even:
    and ax, 0x0FFF
.ret:
    call fat_next_sanitize
    pop bx
    ret
.invalid:
    mov ax, [cs:kfat_eoc_value]
    ret

fat_next_sanitize:
    test ax, ax
    jz .done
    cmp ax, 2
    jb .done
    cmp ax, [cs:kfat_reserved]
    jae .done
    cmp ax, [cs:kmax_cluster]
    jb .done
    mov ax, [cs:kfat_eoc_value]
.done:
    ret

fat16_next:
    push bx
    push cx
    push dx
    push ds
    push es
    mov word [cs:kio_lba_hi], 0
    mov ax, si
    mov bx, ax
    mov cl, 8
    shr ax, cl
    cmp ax, [cs:kfat_secs]
    jae .err
    add ax, [cs:kfat_start]
    mov [cs:fat16_lba], ax
    and bx, 0x00FF
    shl bx, 1
    mov [cs:fat16_off], bx
    cmp byte [cs:fat16_cache_valid], 1
    jne .load_sector
    cmp ax, [cs:fat16_cache_lba]
    je .have_sector
.load_sector:
    mov dx, FAT_SEG
    mov es, dx
    xor bx, bx
    call read_sector
    jc .err
    mov ax, [cs:fat16_lba]
    mov [cs:fat16_cache_lba], ax
    mov byte [cs:fat16_cache_valid], 1
.have_sector:
    mov ax, FAT_SEG
    mov ds, ax
    mov bx, [cs:fat16_off]
    mov ax, [bx]
    jmp .done
.err:
    mov byte [cs:fat16_cache_valid], 0
    mov ax, [cs:kfat_eoc_value]
.done:
    call fat_next_sanitize
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    ret

fat_set:
    cmp si, 2
    jb .invalid
    cmp si, [cs:kmax_cluster]
    jae .invalid
    cmp byte [cs:kfat_bits], 16
    je fat16_set
    push bx
    push dx
    push ds
    mov dx, ax
    mov bx, si
    shr bx, 1
    add bx, si
    mov ax, FAT_SEG
    mov ds, ax
    mov ax, dx
    and ax, 0x0FFF
    test si, 1
    jnz .odd
    mov [bx], al
    mov dl, ah
    and dl, 0x0F
    and byte [bx+1], 0xF0
    or [bx+1], dl
    jmp .done
.odd:
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    and byte [bx], 0x0F
    or [bx], al
    mov [bx+1], ah
.done:
    mov byte [cs:fat_dirty], 1
    pop ds
    pop dx
    pop bx
    ret
.invalid:
    mov byte [cs:fat_io_error], 1
    ret

fat16_set:
    push ax
    push bx
    push cx
    push dx
    push es
    mov word [cs:kio_lba_hi], 0
    mov byte [cs:fat16_cache_valid], 0
    mov [cs:fat16_value], ax
    mov ax, si
    mov bx, ax
    mov cl, 8
    shr ax, cl
    mov [cs:fat16_sector], ax
    cmp ax, [cs:kfat_secs]
    jae .err
    and bx, 0x00FF
    shl bx, 1
    mov [cs:fat16_off], bx
    mov byte [cs:fat_copy_idx], 0
.copy_loop:
    xor ax, ax
    mov al, [cs:knum_fats]
    cmp [cs:fat_copy_idx], al
    jae .done
    mov ax, [cs:kfat_secs]
    xor dx, dx
    mov dl, [cs:fat_copy_idx]
    mul dx
    add ax, [cs:kfat_start]
    add ax, [cs:fat16_sector]
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    jc .err
    mov bx, [cs:fat16_off]
    mov ax, [cs:fat16_value]
    mov [es:bx], ax
    mov ax, [cs:kfat_secs]
    xor dx, dx
    mov dl, [cs:fat_copy_idx]
    mul dx
    add ax, [cs:kfat_start]
    add ax, [cs:fat16_sector]
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call write_sector
    jc .err
    inc byte [cs:fat_copy_idx]
    jmp .copy_loop
.err:
    mov byte [cs:fat_io_error], 1
.done:
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

fat_alloc_cluster:
    push bx
    push cx
    push si
    mov cx, [cs:fat_alloc_hint]
    cmp cx, 2
    jae .hint_ok
    mov cx, 2
.hint_ok:
    mov bx, [cs:kmax_cluster]
    sub bx, 2
    jbe .none
.loop:
    cmp cx, [cs:kmax_cluster]
    jb .try
    mov cx, 2
.try:
    mov si, cx
    call fat_next
    test ax, ax
    jz .found
    inc cx
    dec bx
    jnz .loop
    jmp .none
.found:
    mov si, cx
    mov ax, [cs:kfat_eoc_value]
    call fat_set
    mov ax, cx
    inc cx
    cmp cx, [cs:kmax_cluster]
    jb .store_hint
    mov cx, 2
.store_hint:
    mov [cs:fat_alloc_hint], cx
    pop si
    pop cx
    pop bx
    clc
    ret
.none:
    pop si
    pop cx
    pop bx
    stc
    ret

fat_free_chain:
    push ax
    push bx
    push si
    cmp si, 2
    jb .done
    cmp si, [cs:kmax_cluster]
    jae .done
.loop:
    mov bx, si
    call fat_next
    push ax
    mov si, bx
    xor ax, ax
    call fat_set
    pop ax
    cmp ax, [cs:kfat_eoc]
    jae .done
    cmp ax, 2
    jb .done
    mov si, ax
    jmp .loop
.done:
    pop si
    pop bx
    pop ax
    ret

flush_fat:
    cmp byte [cs:fat_io_error], 0
    jne .fat_err
    cmp byte [cs:kfat_bits], 16
    jne .fat12
    mov byte [cs:fat_dirty], 0
    clc
    ret
.fat_err:
    mov byte [cs:fat_dirty], 0
    mov byte [cs:fat_io_error], 0
    stc
    ret
.fat12:
    cmp byte [cs:fat_dirty], 0
    je .clean
    push ax
    push bx
    push cx
    push dx
    push es
    mov byte [cs:fat_copy_idx], 0
    mov ax, [cs:kfat_start]
    mov [cs:fat_flush_lba], ax
.copy_loop:
    xor ax, ax
    mov al, [cs:knum_fats]
    cmp [cs:fat_copy_idx], al
    jae .done
    mov word [cs:fat_flush_off], 0
    mov cx, [cs:kfat_secs]
.sector_loop:
    test cx, cx
    jz .next_copy
    mov ax, FAT_SEG
    mov es, ax
    mov bx, [cs:fat_flush_off]
    mov ax, [cs:fat_flush_lba]
    push cx
    call write_sector
    pop cx
    jc .err
    inc word [cs:fat_flush_lba]
    add word [cs:fat_flush_off], 512
    dec cx
    jmp .sector_loop
.next_copy:
    inc byte [cs:fat_copy_idx]
    jmp .copy_loop
.done:
    mov byte [cs:fat_dirty], 0
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
.clean:
    clc
    ret
.err:
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret
