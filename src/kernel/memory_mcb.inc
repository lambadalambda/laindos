mcb_walk_next:
    mov ax, [ds:3]
    test ax, ax
    jz .mwn_fail
    add ax, si
    jb .mwn_fail
    inc ax
    jz .mwn_fail
    cmp ax, MEM_TOP
    jae .mwn_fail
    mov si, ax
    clc
    ret
.mwn_fail:
    stc
    ret

%macro MCB_WALK_EACH 6
%1:
    mov ds, si
    MCB_IS_VALID
    je %2
    jmp %4
%3:
    cmp byte [ds:0], MCB_SIG_Z
    je %5
    call mcb_walk_next
    jc %6
    jmp %1
%endmacro

alloc_mem_direct:
    push ds
    push si
    mov [cs:am_req], bx
    mov si, [cs:mcb_first]
    MCB_WALK_EACH .amd_walk, .amd_check, .amd_next, .amd_nomem, .amd_nomem, .amd_nomem
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
    MCB_WALK_EACH .flfb_walk, .flfb_check, .flfb_next, .flfb_done, .flfb_done, .flfb_done
.flfb_check:
    cmp word [ds:1], 0
    jne .flfb_next
    mov ax, [ds:3]
    cmp ax, bx
    jbe .flfb_next
    mov bx, ax
    jmp .flfb_next
.flfb_done:
    pop si
    pop ds
    pop ax
    ret

mcb_merge_free_forward:
    push ax
    push cx
    push di
    push es
.loop:
    mov ax, si
    inc ax
    add ax, [ds:3]
    jb .done
    cmp ax, MEM_TOP
    jae .done
    mov di, ax
    mov es, ax
    cmp byte [es:0], MCB_SIG_M
    je .next_valid
    cmp byte [es:0], MCB_SIG_Z
    jne .done
.next_valid:
    cmp word [es:1], 0
    jne .done
    mov cx, [es:3]
    inc cx
    add [ds:3], cx
    mov al, [es:0]
    mov [ds:0], al
    jmp .loop
.done:
    pop es
    pop di
    pop cx
    pop ax
    ret

mcb_coalesce_all_free:
    push ax
    push ds
    push si
    mov si, [cs:mcb_first]
    MCB_WALK_EACH .walk, .check, .next, .done, .done, .done
.check:
    cmp word [ds:1], 0
    jne .next
    call mcb_merge_free_forward
    jmp .next
.done:
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
    MCB_WALK_EACH .amdh_walk, .amdh_check, .amdh_next, .amdh_nomem, .amdh_choose, .amdh_nomem
.amdh_check:
    cmp word [ds:1], 0
    jne .amdh_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .amdh_next
    mov [cs:am_best_seg], si
    jmp .amdh_next
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
    MCB_WALK_EACH .aad_walk, .aad_check, .aad_next, .aad_nomem, .aad_nomem, .aad_nomem
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
.aad_nomem:
    stc
    pop si
    pop ds
    ret
