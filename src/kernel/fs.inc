dir_lba_root_base:
    test dx, dx
    jnz .subdir
    cmp ax, [cs:krsta]
    jb .subdir
    cmp ax, [cs:kdsta]
    jae .subdir
    sub ax, [cs:krsta]
    mov bx, ax
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    clc
    ret
.subdir:
    stc
    ret

load_dir_slot:
    mov [cs:dir_flush_lba], ax
    mov [cs:dir_flush_lba_hi], dx
    mov [cs:dir_slot_off], di
    call dir_lba_root_base
    jc .subdir
    mov ax, ROOT_SEG
    mov es, ax
    mov di, bx
    add di, [cs:dir_slot_off]
    clc
    ret
.subdir:
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:dir_flush_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:dir_flush_lba]
    call read_sector
    jc .done
    mov ax, SEC_BUF
    mov es, ax
    mov di, [cs:dir_slot_off]
    clc
.done:
    ret

flush_dir_slot:
    mov [cs:kio_lba_hi], dx
    call flush_dir_sector
    ret

flush_root_sector:
    push ax
    push bx
    push dx
    push es
    mov [cs:dir_flush_lba], ax
    xor dx, dx
    call dir_lba_root_base
    jc .done
    mov ax, ROOT_SEG
    mov es, ax
    mov word [cs:kio_lba_hi], 0
    mov ax, [cs:dir_flush_lba]
    call write_sector
.done:
    pop es
    pop dx
    pop bx
    pop ax
    ret

flush_dir_sector:
    mov [cs:dir_flush_lba], ax
    mov dx, [cs:kio_lba_hi]
    mov [cs:dir_flush_lba_hi], dx
    mov word [cs:kio_lba_hi], 0
    mov ax, [cs:dir_flush_lba]
    call dir_lba_root_base
    jc .subdir
    mov ax, [cs:dir_flush_lba]
    call flush_root_sector
    ret
.subdir:
    push ax
    push bx
    push es
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:dir_flush_lba_hi]
    mov [cs:kio_lba_hi], ax
    mov ax, [cs:dir_flush_lba]
    call write_sector
    pop es
    pop bx
    pop ax
    ret

flush_handle_dir_entry:
    push ax
    push bx
    push dx
    push es
    push di
    mov [cs:dir_update_hoff], si
    mov ax, [cs:si+handles+H_DIR_LBA]
    mov dx, [cs:si+handles+H_DIR_LBA_HI]
    or ax, dx
    jnz .have_entry
    clc
    jmp .done
.have_entry:
    mov si, [cs:dir_update_hoff]
    mov ax, [cs:si+handles+H_DIR_LBA]
    mov dx, [cs:si+handles+H_DIR_LBA_HI]
    mov di, [cs:si+handles+H_DIR_OFF]
    call load_dir_slot
    jc .done
    mov si, [cs:dir_update_hoff]
    call store_handle_dir_fields
    mov ax, [cs:si+handles+H_DIR_LBA]
    mov dx, [cs:si+handles+H_DIR_LBA_HI]
    call flush_dir_slot
.done:
    pop di
    pop es
    pop dx
    pop bx
    pop ax
    ret

store_handle_dir_fields:
    push ax
    mov ax, [cs:si+handles+H_TIME]
    mov [es:di+22], ax
    mov ax, [cs:si+handles+H_DATE]
    mov [es:di+24], ax
    mov ax, [cs:si+handles+H_CLUSTER]
    mov [es:di+26], ax
    mov ax, [cs:si+handles+H_SIZE_LO]
    mov [es:di+28], ax
    mov ax, [cs:si+handles+H_SIZE_HI]
    mov [es:di+30], ax
    pop ax
    ret

entry_has_open_handle:
    push ax
    push bx
    push cx
    xor bx, bx
    mov cx, MAX_HANDLES
.loop:
    cmp byte [cs:bx+handles+H_USED], 0
    je .next
    mov ax, [cs:ff_entry_lba]
    cmp [cs:bx+handles+H_DIR_LBA], ax
    jne .next
    mov ax, [cs:ff_entry_lba_hi]
    cmp [cs:bx+handles+H_DIR_LBA_HI], ax
    jne .next
    mov ax, [cs:ff_entry_off]
    cmp [cs:bx+handles+H_DIR_OFF], ax
    je .found
.next:
    add bx, HANDLE_SIZE
    loop .loop
    pop cx
    pop bx
    pop ax
    clc
    ret
.found:
    pop cx
    pop bx
    pop ax
    stc
    ret

wf_get_cluster:
    push ax
    push bx
    push cx
    push dx
    mov bx, [cs:wf_hoff]
    mov si, [cs:bx+handles+H_LAST_CLUSTER]
    mov cx, [cs:bx+handles+H_LAST_INDEX]
    cmp si, 0
    je .from_start
    cmp cx, [cs:wf_cluster_index]
    jbe .walk
.from_start:
    mov bx, [cs:wf_hoff]
    mov si, [cs:bx+handles+H_CLUSTER]
    xor cx, cx
.walk:
    cmp cx, [cs:wf_cluster_index]
    je .found
    mov bx, si
    call fat_next
    cmp ax, [cs:kfat_eoc]
    jae .extend
    cmp ax, [cs:kfat_reserved]
    jae .err
    cmp ax, 2
    jb .err
    cmp ax, [cs:kmax_cluster]
    jae .err
    jmp .have_next
.extend:
    call fat_alloc_cluster
    jc .err
    push ax
    mov si, bx
    call fat_set
    pop ax
.have_next:
    mov si, ax
    inc cx
    jmp .walk
.found:
    mov bx, [cs:wf_hoff]
    mov [cs:bx+handles+H_LAST_CLUSTER], si
    mov [cs:bx+handles+H_LAST_INDEX], cx
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err:
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret
