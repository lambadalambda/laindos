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

; DS:SI = MCB, BX = paragraphs to keep in the low part. When the block
; is large enough to leave a viable remainder, carve a free MCB above
; the kept part (inheriting the original signature) and mark the kept
; part 'M'. Owner is left untouched. Preserves all registers.
mcb_split_low:
    push ax
    push cx
    push di
    push es
    mov ax, [ds:3]
    sub ax, bx
    cmp ax, 2
    jb .done
    mov di, si
    add di, bx
    inc di
    mov es, di
    mov al, [ds:0]
    mov [es:0], al
    mov word [es:1], 0
    mov cx, [ds:3]
    sub cx, bx
    dec cx
    mov [es:3], cx
    mov byte [ds:0], MCB_SIG_M
    mov [ds:3], bx
.done:
    pop es
    pop di
    pop cx
    pop ax
    ret

; DS:SI = free MCB, BX = paragraphs to keep in the HIGH part. Carves
; the allocation out of the top of the block, leaving the low remainder
; free; DS and SI move to the kept high MCB. Owner is left untouched.
mcb_split_high:
    push ax
    push cx
    push di
    push es
    mov cx, [ds:3]
    sub cx, bx
    cmp cx, 2
    jb .done
    mov di, si
    add di, cx
    mov al, [ds:0]
    mov byte [ds:0], MCB_SIG_M
    dec cx
    mov [ds:3], cx
    mov es, di
    mov [es:0], al
    mov [es:3], bx
    mov si, di
    mov ds, di
.done:
    pop es
    pop di
    pop cx
    pop ax
    ret

; Walk the whole chain checking signatures. CF set with AX = 7 when a
; corrupt MCB is found.
mcb_chain_validate:
    push ds
    push si
    mov si, [cs:mcb_first]
    MCB_WALK_EACH .mcv_walk, .mcv_check, .mcv_next, .mcv_bad, .mcv_ok, .mcv_ok
.mcv_check:
    jmp .mcv_next
.mcv_ok:
    pop si
    pop ds
    clc
    ret
.mcv_bad:
    mov ax, 7
    pop si
    pop ds
    stc
    ret

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
    call mcb_split_low
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
    call mcb_split_high
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

; Best-fit variant: allocate from the smallest free block that satisfies
; the request (the AH=48h strategy-1 policy).
alloc_mem_direct_best:
    push ds
    push si
    mov [cs:am_req], bx
    mov word [cs:am_best_seg], 0
    mov word [cs:am_best_size], 0xFFFF
    mov si, [cs:mcb_first]
    MCB_WALK_EACH .amdb_walk, .amdb_check, .amdb_next, .amdb_nomem, .amdb_choose, .amdb_nomem
.amdb_check:
    cmp word [ds:1], 0
    jne .amdb_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .amdb_next
    cmp ax, [cs:am_best_size]
    jae .amdb_next
    mov [cs:am_best_size], ax
    mov [cs:am_best_seg], si
    jmp .amdb_next
.amdb_choose:
    mov si, [cs:am_best_seg]
    test si, si
    jz .amdb_nomem
    mov ds, si
    call mcb_split_low
    mov ax, [cs:cur_psp]
    mov word [ds:1], ax
    mov ax, si
    inc ax
    pop si
    pop ds
    clc
    ret
.amdb_nomem:
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
