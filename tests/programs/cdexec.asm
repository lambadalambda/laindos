[bits 16]
[org 0x0100]

reloc_count equ 140
tail_marker_off equ 2 + reloc_count * 2 + 300

start:
    push cs
    pop ds
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    push cs
    pop es
    mov [exec_params+4], ds

    mov bx, exec_params
    mov dx, com_path
    mov ax, 0x4B00
    int 0x21
    jc fail_com_exec
    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_com_child

    mov bx, exec_params
    mov dx, exe_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exe_exec
    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_exe_child

    mov dl, 3
    mov ah, 0x0E
    int 0x21
    mov dx, subdir_path
    mov ah, 0x3B
    int 0x21
    jc fail_chdir
    mov bx, exec_params
    mov dx, rel_exe_path
    mov ax, 0x4B00
    int 0x21
    jc fail_rel_exe_exec
    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_rel_exe_child

    mov bx, 0x0040
    mov ah, 0x48
    int 0x21
    jc fail_overlay_alloc
    mov [overlay_params], ax
    mov [overlay_params+2], ax
    push ds
    pop es
    mov bx, overlay_params
    mov dx, overlay_path
    mov ax, 0x4B03
    int 0x21
    jc fail_overlay_exec_code
    mov es, [overlay_params]
    cmp word [es:0], 0xBEEF
    jne fail_overlay_marker
    cmp word [es:tail_marker_off], 0xCAFE
    jne fail_overlay_tail
    mov ax, [overlay_params+2]
    mov si, 2
    mov cx, reloc_count
check_overlay_relocs:
    cmp [es:si], ax
    jne fail_overlay_reloc
    add si, 2
    loop check_overlay_relocs

    mov dx, parent_path
    mov ah, 0x3B
    int 0x21
    jc fail_parent_chdir
    mov bx, exec_params
    mov dx, rel_com_path
    mov ax, 0x4B00
    int 0x21
    jc fail_parent_com_exec_code
    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_parent_com_child

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_com_exec:
    push cs
    pop ds
    mov dx, fail_com_exec_msg
    jmp fail
fail_com_child:
    push cs
    pop ds
    mov dx, fail_com_child_msg
    jmp fail
fail_exe_exec:
    push cs
    pop ds
    mov dx, fail_exe_exec_msg
    jmp fail
fail_exe_child:
    push cs
    pop ds
    mov dx, fail_exe_child_msg
    jmp fail
fail_chdir:
    push cs
    pop ds
    mov dx, fail_chdir_msg
    jmp fail
fail_rel_exe_exec:
    push cs
    pop ds
    mov dx, fail_rel_exe_exec_msg
    jmp fail
fail_rel_exe_child:
    push cs
    pop ds
    mov dx, fail_rel_exe_child_msg
    jmp fail
fail_overlay_alloc:
    push cs
    pop ds
    mov dx, fail_overlay_alloc_msg
    jmp fail
fail_overlay_exec_code:
    cmp ax, 1
    je fail_overlay_load
    cmp ax, 2
    je fail_overlay_not_found
    jmp fail_overlay_exec
fail_overlay_exec:
    push cs
    pop ds
    mov dx, fail_overlay_exec_msg
    jmp fail
fail_overlay_load:
    mov es, [overlay_params]
    cmp word [es:0], 0xBEEF
    jne fail_overlay_load_marker
    cmp word [es:tail_marker_off], 0xCAFE
    jne fail_overlay_load_tail
    mov ax, [overlay_params+2]
    mov si, 2
    mov cx, 121
check_failed_overlay_relocs_early:
    cmp [es:si], ax
    jne fail_overlay_load_reloc_early
    add si, 2
    loop check_failed_overlay_relocs_early
    mov cx, reloc_count - 121
check_failed_overlay_relocs_late:
    cmp [es:si], ax
    jne fail_overlay_load_reloc_late
    add si, 2
    loop check_failed_overlay_relocs_late
    push cs
    pop ds
    mov dx, fail_overlay_load_msg
    jmp fail
fail_overlay_load_marker:
    push cs
    pop ds
    mov dx, fail_overlay_load_marker_msg
    jmp fail
fail_overlay_load_tail:
    push cs
    pop ds
    mov dx, fail_overlay_load_tail_msg
    jmp fail
fail_overlay_load_reloc_early:
    push cs
    pop ds
    mov dx, fail_overlay_load_reloc_early_msg
    jmp fail
fail_overlay_load_reloc_late:
    push cs
    pop ds
    mov dx, fail_overlay_load_reloc_late_msg
    jmp fail
fail_overlay_not_found:
    push cs
    pop ds
    mov dx, fail_overlay_not_found_msg
    jmp fail
fail_overlay_marker:
    push cs
    pop ds
    mov dx, fail_overlay_marker_msg
    jmp fail
fail_overlay_tail:
    push cs
    pop ds
    mov dx, fail_overlay_tail_msg
    jmp fail
fail_overlay_reloc:
    push cs
    pop ds
    mov dx, fail_overlay_reloc_msg
    jmp fail
fail_parent_chdir:
    push cs
    pop ds
    mov dx, fail_parent_chdir_msg
    jmp fail
fail_parent_com_exec_code:
    cmp ax, 1
    je fail_parent_com_load
    cmp ax, 2
    je fail_parent_com_not_found
    jmp fail_parent_com_exec
fail_parent_com_exec:
    push cs
    pop ds
    mov dx, fail_parent_com_exec_msg
    jmp fail
fail_parent_com_load:
    push cs
    pop ds
    mov dx, fail_parent_com_load_msg
    jmp fail
fail_parent_com_not_found:
    push cs
    pop ds
    mov dx, fail_parent_com_not_found_msg
    jmp fail
fail_parent_com_child:
    push cs
    pop ds
    mov dx, fail_parent_com_child_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

com_path: db 'D:\CDHELLO.COM', 0
exe_path: db 'D:\SUBDIR\HELLO.EXE', 0
subdir_path: db '\SUBDIR', 0
parent_path: db '..', 0
rel_exe_path: db 'HELLO.EXE', 0
rel_com_path: db 'CDHELLO.COM', 0
overlay_path: db 'OVERLAY.EXE', 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0
overlay_params: dw 0, 0
pass_msg: db 'PASS: CDEXEC', 13, 10, '$'
fail_com_exec_msg: db 'FAIL: CDEXEC COM EXEC', 13, 10, '$'
fail_com_child_msg: db 'FAIL: CDEXEC COM CHILD', 13, 10, '$'
fail_exe_exec_msg: db 'FAIL: CDEXEC EXE EXEC', 13, 10, '$'
fail_exe_child_msg: db 'FAIL: CDEXEC EXE CHILD', 13, 10, '$'
fail_chdir_msg: db 'FAIL: CDEXEC CHDIR', 13, 10, '$'
fail_rel_exe_exec_msg: db 'FAIL: CDEXEC REL EXE EXEC', 13, 10, '$'
fail_rel_exe_child_msg: db 'FAIL: CDEXEC REL EXE CHILD', 13, 10, '$'
fail_overlay_alloc_msg: db 'FAIL: CDEXEC OVERLAY ALLOC', 13, 10, '$'
fail_overlay_exec_msg: db 'FAIL: CDEXEC OVERLAY EXEC', 13, 10, '$'
fail_overlay_load_msg: db 'FAIL: CDEXEC OVERLAY LOAD', 13, 10, '$'
fail_overlay_load_marker_msg: db 'FAIL: CDEXEC OVERLAY LOAD MARKER', 13, 10, '$'
fail_overlay_load_tail_msg: db 'FAIL: CDEXEC OVERLAY LOAD TAIL', 13, 10, '$'
fail_overlay_load_reloc_early_msg: db 'FAIL: CDEXEC OVERLAY LOAD RELOC EARLY', 13, 10, '$'
fail_overlay_load_reloc_late_msg: db 'FAIL: CDEXEC OVERLAY LOAD RELOC LATE', 13, 10, '$'
fail_overlay_not_found_msg: db 'FAIL: CDEXEC OVERLAY NOT FOUND', 13, 10, '$'
fail_overlay_marker_msg: db 'FAIL: CDEXEC OVERLAY MARKER', 13, 10, '$'
fail_overlay_tail_msg: db 'FAIL: CDEXEC OVERLAY TAIL', 13, 10, '$'
fail_overlay_reloc_msg: db 'FAIL: CDEXEC OVERLAY RELOC', 13, 10, '$'
fail_parent_chdir_msg: db 'FAIL: CDEXEC PARENT CHDIR', 13, 10, '$'
fail_parent_com_exec_msg: db 'FAIL: CDEXEC PARENT COM EXEC', 13, 10, '$'
fail_parent_com_load_msg: db 'FAIL: CDEXEC PARENT COM LOAD', 13, 10, '$'
fail_parent_com_not_found_msg: db 'FAIL: CDEXEC PARENT COM NOT FOUND', 13, 10, '$'
fail_parent_com_child_msg: db 'FAIL: CDEXEC PARENT COM CHILD', 13, 10, '$'
