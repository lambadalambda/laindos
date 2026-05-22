[bits 16]
[org 0x0100]

reloc_count equ 140

    mov bx, 0x0020
    mov ah, 0x48
    int 0x21
    jc fail_alloc

    mov [param], ax
    mov [param+2], ax
    push ds
    pop es
    mov bx, param
    mov dx, overlay_name
    mov ax, 0x4B03
    int 0x21
    jc fail_exec

    mov es, [param]
    cmp word [es:0], 0xBEEF
    jne fail_marker
    mov ax, [param+2]
    mov si, 2
    mov cx, reloc_count
check_relocs:
    cmp [es:si], ax
    jne fail_reloc
    add si, 2
    loop check_relocs

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_alloc:
    mov dx, fail_alloc_msg
    jmp print_fail
fail_exec:
    mov dx, fail_exec_msg
    jmp print_fail
fail_marker:
    mov dx, fail_marker_msg
    jmp print_fail
fail_reloc:
    mov dx, fail_reloc_msg
print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

param: dw 0, 0
overlay_name: db "OVERLAY.EXE", 0
pass_msg: db "PASS: OVERLAY", 13, 10, "$"
fail_alloc_msg: db "FAIL: OVERLAY ALLOC", 13, 10, "$"
fail_exec_msg: db "FAIL: OVERLAY EXEC", 13, 10, "$"
fail_marker_msg: db "FAIL: OVERLAY MARKER", 13, 10, "$"
fail_reloc_msg: db "FAIL: OVERLAY RELOC", 13, 10, "$"
