; LOADFIX: run a program with its load address forced above the first
; 64 KiB, like the MS-DOS 5 utility of the same name. EXEPACK-compressed
; executables corrupt themselves ("Packed file is corrupt") when loaded
; below segment 1000h, which is where a lean DOS-in-HMA layout puts the
; first program.
[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    mov si, 0x81
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    cmp al, 9
    je .skip_spaces
    cmp al, 0x0D
    je usage

    mov di, name_buf
    mov byte [dot_seen], 0
.name_loop:
    cmp al, '.'
    jne .chk_sep
    mov byte [dot_seen], 1
    jmp .store
.chk_sep:
    cmp al, '\'
    je .sep
    cmp al, '/'
    je .sep
    cmp al, ':'
    jne .store
.sep:
    mov byte [dot_seen], 0
.store:
    stosb
    cmp di, name_end_max
    jae usage
    lodsb
    cmp al, 0x0D
    je .name_done
    cmp al, ' '
    je .name_done
    cmp al, 9
    jne .name_loop
.name_done:
    mov [name_end], di
    dec si
    call build_tail
    call fill_low_memory
    jc cannot_run

    cmp byte [dot_seen], 0
    jne .as_is
    mov si, ext_com
    call append_ext
    call do_exec
    jnc child_done
    mov si, ext_exe
    call append_ext
    call do_exec
    jnc child_done
    jmp cannot_run
.as_is:
    mov di, [name_end]
    mov byte [di], 0
    call do_exec
    jnc child_done

cannot_run:
    mov dx, cannot_msg
    jmp exit_error

usage:
    mov dx, usage_msg
exit_error:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

child_done:
    mov ah, 0x4D
    int 0x21
    mov ah, 0x4C
    int 0x21

; Copy the rest of the command line (from the delimiter at DS:SI) into
; tail_buf as a DOS command tail: length byte, characters, CR.
build_tail:
    mov di, tail_buf + 1
    xor cx, cx
.copy:
    lodsb
    cmp al, 0x0D
    je .done
    stosb
    inc cx
    cmp cx, 126
    jb .copy
.done:
    mov [tail_buf], cl
    mov al, 0x0D
    stosb
    ret

; Allocate the free conventional memory below segment 1000h so the next
; program DOS loads starts at or above it. One-paragraph probes stay on
; the first-fit path (larger small requests are biased high), and each
; low probe is grown to fill its gap up to 0FFFh; everything stays owned
; by this PSP and is released when LOADFIX terminates.
fill_low_memory:
.probe:
    mov ah, 0x48
    mov bx, 1
    int 0x21
    jc .fail
    cmp ax, 0x1000
    jae .done
    mov es, ax
    mov bx, 0x0FFF
    sub bx, ax
    jz .probe
    mov ah, 0x4A
    int 0x21
    jmp .probe
.done:
    mov es, ax
    mov ah, 0x49
    int 0x21
    clc
    ret
.fail:
    stc
    ret

; Append the 5 bytes at DS:SI (".COM",0 / ".EXE",0) after the name.
append_ext:
    push cs
    pop es
    mov di, [name_end]
    mov cx, 5
    rep movsb
    ret

do_exec:
    mov ax, cs
    mov [exec_params+4], ax
    mov [exec_params+8], ax
    mov [exec_params+12], ax
    mov ax, ss
    mov [save_ss], ax
    mov [save_sp], sp
    push cs
    pop es
    mov bx, exec_params
    mov dx, name_buf
    mov ax, 0x4B00
    int 0x21
    mov bx, ax
    cli
    mov ax, [cs:save_ss]
    mov ss, ax
    mov sp, [cs:save_sp]
    sti
    push cs
    pop ds
    mov ax, bx
    ret

exec_params:
    dw 0
    dw tail_buf, 0
    dw 0x5C, 0
    dw 0x6C, 0

ext_com: db ".COM", 0
ext_exe: db ".EXE", 0
usage_msg: db "Usage: LOADFIX program [args]", 13, 10, "$"
cannot_msg: db "LOADFIX: cannot run program", 13, 10, "$"
dot_seen: db 0
save_ss: dw 0
save_sp: dw 0
name_end: dw 0
name_buf: times 80 db 0
name_end_max equ name_buf + 74
tail_buf: times 130 db 0
