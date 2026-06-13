fat_walk_reset:
    push ax
    mov ax, [cs:kmax_cluster]
    mov [cs:fat_walk_left], ax
    pop ax
    ret

fat_next_checked:
    cmp word [cs:fat_walk_left], 0
    je .cycle
    dec word [cs:fat_walk_left]
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .stop
    cmp ax, [cs:kfat_reserved]
    jae .bad
    cmp ax, 2
    jb .bad
    cmp ax, [cs:kmax_cluster]
    jae .bad
    clc
    ret
.cycle:
.bad:
    xor ax, ax
    stc
    ret
.stop:
    stc
    ret

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
    mov ax, si
    mov bx, ax
    mov cl, 8
    shr ax, cl
    cmp ax, [cs:kfat_secs]
    jae .err
    call fat16_window_load          ; ax = FAT-relative sector
    jc .err
    and bx, 0x00FF
    shl bx, 1
    mov ax, FAT_SEG
    mov ds, ax
    mov ax, [bx]
    jmp .done
.err:
    mov ax, [cs:kfat_eoc_value]
.done:
    call fat_next_sanitize
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    ret

; Ensure FAT_SEG holds FAT-relative sector AX of the active FAT16 volume.
; If a different sector is currently cached and dirty, flush it to every
; FAT copy first (write-back). CF set on read error. Preserves BX/CX/DX/ES
; and the caller's SI; clobbers AX.
fat16_window_load:
    push bx
    push cx
    push dx
    push es
    cmp byte [cs:fat16_cache_valid], 1
    jne .miss
    cmp ax, [cs:fat16_cache_sector]
    je .hit
.miss:
    PERF_INC perf_fat16_misses
    push ax
    call fat16_window_flush
    pop ax
    mov [cs:fat16_cache_sector], ax
    add ax, [cs:kfat_start]
    mov word [cs:kio_lba_hi], 0
    mov dx, FAT_SEG
    mov es, dx
    xor bx, bx
    call read_sector
    jc .err
    mov byte [cs:fat16_cache_valid], 1
    mov byte [cs:fat16_cache_dirty], 0
    clc
    jmp .ret
.hit:
    PERF_INC perf_fat16_hits
    clc
    jmp .ret
.err:
    mov byte [cs:fat16_cache_valid], 0
    mov byte [cs:fat16_cache_dirty], 0
    stc
.ret:
    pop es
    pop dx
    pop cx
    pop bx
    ret

; Write the cached FAT16 window back to every FAT copy if it is dirty.
; No-op when the window is clean or invalid. Sets fat_io_error on failure.
fat16_window_flush:
    cmp byte [cs:fat16_cache_valid], 1
    jne .none
    cmp byte [cs:fat16_cache_dirty], 1
    jne .none
    PERF_INC_THEN_PUSH_AX perf_fat16_flushes
    push bx
    push cx
    push dx
    push es
    mov byte [cs:fat_copy_idx], 0
.copy:
    xor ax, ax
    mov al, [cs:knum_fats]
    cmp [cs:fat_copy_idx], al
    jae .done
    mov ax, [cs:kfat_secs]
    xor dx, dx
    mov dl, [cs:fat_copy_idx]
    mul dx
    add ax, [cs:kfat_start]
    add ax, [cs:fat16_cache_sector]
    mov word [cs:kio_lba_hi], 0
    mov dx, FAT_SEG
    mov es, dx
    xor bx, bx
    PERF_INC perf_fat_mirror_writes
    call write_sector
    jc .ioerr
    inc byte [cs:fat_copy_idx]
    jmp .copy
.ioerr:
    mov byte [cs:fat_io_error], 1
.done:
    mov byte [cs:fat16_cache_dirty], 0
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
.none:
    ret

fat16_find_first_free_hint:
    push ax
    push bx
    push cx
    push si
    mov word [cs:fat_alloc_hint], 2
    cmp byte [cs:kfat_bits], 16
    jne .done
    cmp byte [cs:kdrv], 0x80
    jb .done
    mov cx, 2
    mov bx, [cs:kmax_cluster]
    sub bx, 2
    jbe .done
.loop:
    mov si, cx
    call fat_next
    test ax, ax
    jz .found
    inc cx
    dec bx
    jnz .loop
    jmp .done
.found:
    mov [cs:fat_alloc_hint], cx
.done:
    pop si
    pop cx
    pop bx
    pop ax
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

; FAT16 cluster update: load the FAT sector holding the entry into the
; window (flushing any other dirty sector first), patch the entry in
; memory, and mark the window dirty. The actual disk write is deferred to
; the next window eviction or to flush_fat -- the same write-back model
; the FAT12 path uses. Updating both FAT copies on every entry (the old
; write-through) turned a multi-megabyte file's cluster chain into tens of
; thousands of sector read-modify-writes (the Red Alert swap-file stall on
; real-speed IDE).
fat16_set:
    push ax
    push bx
    push cx
    push dx
    push es
    mov [cs:fat16_value], ax
    mov ax, si
    mov bx, ax
    mov cl, 8
    shr ax, cl
    cmp ax, [cs:kfat_secs]
    jae .err
    call fat16_window_load          ; ax = FAT-relative sector
    jc .err
    and bx, 0x00FF
    shl bx, 1
    mov ax, FAT_SEG
    mov es, ax
    mov ax, [cs:fat16_value]
    mov [es:bx], ax
    mov byte [cs:fat16_cache_dirty], 1
    jmp .done
.err:
    mov byte [cs:fat_io_error], 1
.done:
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

fat_alloc_cluster: PERF_INC perf_fat_allocs
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
    PERF_INC perf_fat_scan_steps
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
    cmp ax, [cs:kfat_reserved]
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

flush_fat: PERF_INC perf_fat_flushes
    cmp byte [cs:fat_io_error], 0
    jne .fat_err
    cmp byte [cs:kfat_bits], 16
    jne .fat12
    ; FAT16 keeps one write-back window; persist it to all FAT copies
    call fat16_window_flush
    cmp byte [cs:fat_io_error], 0
    jne .fat_err
    mov byte [cs:fat_dirty], 0
    clc
    ret
.fat_err:
    mov byte [cs:fat_dirty], 0
    mov byte [cs:fat_io_error], 0
    stc
    ret

; `fat_io_error` is a consumed-on-flush diagnostic: it latches a pending
; FAT I/O error between the most recent fat_set/fat_next and this call,
; and flush_fat clears it (both in the success path via implicit carry=0
; fallthrough and explicitly in .fat_err). Callers should consult the
; carry return, not the flag, after flush_fat. Future diagnostics that
; need a sticky flag should use a separate variable; do not change this
; consume-on-flush contract without auditing every flush_fat caller.
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
