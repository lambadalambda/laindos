; The MCB arena must not extend past the BIOS conventional-memory size
; (INT 12h): the bytes between that line and 640K are the EBDA, which the
; BIOS (PS/2 mouse services among others) uses while DOS runs. The boot
; program is allocated at the top of the arena, so its PSP alloc-top word
; is exactly the arena top.
%include "tests/programs/common.inc"
COM_START
    mov ax, [0x02]         ; PSP: first segment beyond our allocation
    push ax
    int 0x12               ; BIOS conventional KB
    mov cl, 6
    shl ax, cl             ; KB -> top segment
    pop dx
    cmp dx, ax
    ja .fail
    ; sanity: the arena top should still be above 600K
    cmp dx, 0x9600
    jb .fail
    PASS_WITH pass_msg
.fail:
    FAIL_WITH fail_msg
pass_msg: db "PASS: MEMTOP", 13, 10, "$"
fail_msg: db "FAIL: MEMTOP", 13, 10, "$"
