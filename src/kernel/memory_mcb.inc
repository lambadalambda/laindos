alloc_mem_direct:
    push ds
    push si
    mov [cs:am_req], bx
    mov si, [cs:mcb_first]
.amd_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .amd_check
    cmp byte [ds:0], MCB_SIG_Z
    je .amd_check
    stc
    pop si
    pop ds
    ret
.amd_check:
    cmp word [ds:1], 0
    jne .amd_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .amd_next
    mov ax, [ds:3]
    sub ax, [cs:am_req]
    cmp ax, 2
    jb .amd_exact
    push si
    mov di, si
    add di, [cs:am_req]
    inc di
    push di
    mov es, di
    mov al, [ds:0]
    mov byte [es:0], al
    mov word [es:1], 0
    mov cx, [ds:3]
    sub cx, [cs:am_req]
    dec cx
    mov word [es:3], cx
    mov byte [ds:0], MCB_SIG_M
    mov ax, [cs:am_req]
    mov word [ds:3], ax
    pop di
    pop si
.amd_exact:
    mov ax, [cs:cur_psp]
    mov word [ds:1], ax
    mov ax, si
    inc ax
    pop si
    pop ds
    clc
    ret
.amd_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .amd_nomem
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .amd_walk
.amd_nomem:
    stc
    pop si
    pop ds
    ret

find_largest_free_block:
    push ax
    push ds
    push si
    xor bx, bx
    mov si, [cs:mcb_first]
.flfb_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .flfb_check
    cmp byte [ds:0], MCB_SIG_Z
    je .flfb_check
    jmp .flfb_done
.flfb_check:
    cmp word [ds:1], 0
    jne .flfb_next
    mov ax, [ds:3]
    cmp ax, bx
    jbe .flfb_next
    mov bx, ax
.flfb_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .flfb_done
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .flfb_walk
.flfb_done:
    pop si
    pop ds
    pop ax
    ret

alloc_mem_direct_high:
    push ds
    push si
    mov [cs:am_req], bx
    mov word [cs:am_best_seg], 0
    mov si, [cs:mcb_first]
.amdh_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .amdh_check
    cmp byte [ds:0], MCB_SIG_Z
    je .amdh_check
    stc
    pop si
    pop ds
    ret
.amdh_check:
    cmp word [ds:1], 0
    jne .amdh_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .amdh_next
    mov [cs:am_best_seg], si
.amdh_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .amdh_choose
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .amdh_walk
.amdh_choose:
    mov si, [cs:am_best_seg]
    test si, si
    jz .amdh_nomem
    mov ds, si
    mov cx, [ds:3]
    sub cx, [cs:am_req]
    cmp cx, 2
    jb .amdh_exact
    mov di, si
    add di, cx
    mov al, [ds:0]
    mov byte [ds:0], MCB_SIG_M
    dec cx
    mov [ds:3], cx
    mov es, di
    mov byte [es:0], al
    mov ax, [cs:cur_psp]
    mov [es:1], ax
    mov ax, [cs:am_req]
    mov [es:3], ax
    mov si, di
    mov ds, di
.amdh_exact:
    mov ax, [cs:cur_psp]
    mov word [ds:1], ax
    mov ax, si
    inc ax
    pop si
    pop ds
    clc
    ret
.amdh_nomem:
    stc
    pop si
    pop ds
    ret

alloc_all_mem_direct:
    push ds
    push si
    mov [cs:am_req], bx
    mov si, [cs:mcb_first]
.aad_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .aad_check
    cmp byte [ds:0], MCB_SIG_Z
    je .aad_check
    stc
    pop si
    pop ds
    ret
.aad_check:
    cmp word [ds:1], 0
    jne .aad_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .aad_next
    mov ax, [cs:cur_psp]
    mov word [ds:1], ax
    mov ax, si
    inc ax
    pop si
    pop ds
    clc
    ret
.aad_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .aad_nomem
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .aad_walk
.aad_nomem:
    stc
    pop si
    pop ds
    ret
