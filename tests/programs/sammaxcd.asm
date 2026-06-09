[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x1500
    int 0x2F
    cmp bx, 1
    jne fail_mscdex
    cmp cx, 3
    jne fail_mscdex

    mov dx, root_launcher
    call open_read_mz
    jc fail_root

    mov dx, game_exe
    call open_read_mz
    jc fail_game

    mov dx, monster_sou
    call open_read_some
    jc fail_monster

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

open_read_mz:
    call open_read_some
    jc .err
    cmp byte [buf], 'M'
    jne .err
    cmp byte [buf+1], 'Z'
    jne .err
    clc
    ret
.err:
    stc
    ret

open_read_some:
    mov ax, 0x3D00
    int 0x21
    jc .err
    mov [handle], ax
    mov bx, ax
    mov cx, 16
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    jc .close_err
    cmp ax, 16
    jne .close_err
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc .err
    clc
    ret
.close_err:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
.err:
    stc
    ret

fail_mscdex:
    mov dx, fail_mscdex_msg
    jmp fail
fail_root:
    mov dx, fail_root_msg
    jmp fail
fail_game:
    mov dx, fail_game_msg
    jmp fail
fail_monster:
    mov dx, fail_monster_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
root_launcher: db 'D:\SAM.EXE', 0
game_exe: db 'D:\SAMNMAX\SAMNMAX.EXE', 0
monster_sou: db 'D:\SAMNMAX\MONSTER.SOU', 0
pass_msg: db 'PASS: SAMMAXCD', 13, 10, '$'
fail_mscdex_msg: db 'FAIL: SAMMAXCD MSCDEX', 13, 10, '$'
fail_root_msg: db 'FAIL: SAMMAXCD ROOT', 13, 10, '$'
fail_game_msg: db 'FAIL: SAMMAXCD GAME', 13, 10, '$'
fail_monster_msg: db 'FAIL: SAMMAXCD MONSTER', 13, 10, '$'
buf: times 32 db 0
