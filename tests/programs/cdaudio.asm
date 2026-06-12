[bits 16]
[org 0x0100]

; MSCDEX INT 2Fh AX=1510h device requests against the generated
; single-data-track ISO: TOC-backed audio IOCTLs and the play/stop
; command path must answer like a real CD-ROM device driver.

DONE_BIT equ 0x0100
ERR_BIT  equ 0x8000

start:
    push cs
    pop ds
    cld

    mov ax, 0x1500
    xor bx, bx
    int 0x2F
    cmp bx, 1
    jne fail_install

    ; bogus device command -> done + error + code 3 (unknown command)
    mov byte [req+2], 200
    call send_req
    mov ax, [req+3]
    and ax, ERR_BIT | DONE_BIT | 0x00FF
    cmp ax, ERR_BIT | DONE_BIT | 0x0003
    jne fail_badcmd

    ; bad unit (CX=2 is not the CD) -> done + error + code 1
    mov byte [req+2], 3
    mov byte [cb], 10
    mov word [req+18], 7
    call set_cb_ptr
    mov cx, 2
    call send_req_cx
    mov ax, [req+3]
    and ax, ERR_BIT | DONE_BIT | 0x00FF
    cmp ax, ERR_BIT | DONE_BIT | 0x0001
    jne fail_badunit

    ; IOCTL Input 10: Audio Disc Info -> tracks 1..1, nonzero lead-out
    mov byte [req+2], 3
    mov byte [cb], 10
    mov word [req+18], 7
    call set_cb_ptr
    call send_req
    call check_done_ok
    jc fail_discinfo
    cmp byte [cb+1], 1
    jne fail_discinfo
    cmp byte [cb+2], 1
    jne fail_discinfo
    mov ax, [cb+3]
    or ax, [cb+5]
    test ax, ax
    jz fail_discinfo

    ; IOCTL Input 11: Audio Track Info for track 1 -> data-track control
    mov byte [cb], 11
    mov byte [cb+1], 1
    mov word [req+18], 7
    call set_cb_ptr
    call send_req
    call check_done_ok
    jc fail_trackinfo
    test byte [cb+6], 0x40
    jz fail_trackinfo

    ; Play Audio (132, HSG addressing) on a data disc must come back
    ; with the done bit set, wedging neither the driver nor the drive
    mov byte [req+2], 132
    mov byte [req+13], 0
    mov word [req+14], 0
    mov word [req+16], 0
    mov word [req+18], 16
    mov word [req+20], 0
    call send_req
    test word [req+3], DONE_BIT
    jz fail_play

    ; Stop Audio (133) -> done, no error
    mov byte [req+2], 133
    call send_req
    mov ax, [req+3]
    test ax, DONE_BIT
    jz fail_stop
    test ax, ERR_BIT
    jnz fail_stop

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

; request header at DS:req, drive D: (unit via MSCDEX drive number in CX)
send_req:
    mov cx, 3
send_req_cx:
    push cs
    pop es
    mov bx, req
    mov word [req+3], 0
    mov ax, 0x1510
    int 0x2F
    ret

; IOCTLs carry the control-block pointer in the transfer-address field;
; Play reuses those bytes as its start sector, so only IOCTLs set it
set_cb_ptr:
    mov word [req+14], cb
    mov [req+16], cs
    ret

check_done_ok:
    mov ax, [req+3]
    test ax, DONE_BIT
    jz .bad
    test ax, ERR_BIT
    jnz .bad
    clc
    ret
.bad:
    stc
    ret

fail_install:
    mov dx, fail_install_msg
    jmp fail
fail_badcmd:
    mov dx, fail_badcmd_msg
    jmp fail
fail_badunit:
    mov dx, fail_badunit_msg
    jmp fail
fail_discinfo:
    mov dx, fail_discinfo_msg
    jmp fail
fail_trackinfo:
    mov dx, fail_trackinfo_msg
    jmp fail
fail_play:
    mov dx, fail_play_msg
    jmp fail
fail_stop:
    mov dx, fail_stop_msg
fail:
    push dx
    mov ax, [req+3]
    call print_hex16
    pop dx
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

; AX -> four hex digits + CRLF on stdout
print_hex16:
    mov cx, 4
.digit:
    rol ax, 4
    push ax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .emit
    add al, 'A' - '0' - 10
.emit:
    mov dl, al
    mov ah, 0x02
    int 0x21
    pop ax
    loop .digit
    mov dl, 13
    mov ah, 0x02
    int 0x21
    mov dl, 10
    mov ah, 0x02
    int 0x21
    ret

req: db 26, 0, 0
     dw 0
     times 8 db 0
     db 0
     dw 0, 0
     dw 0
     dw 0, 0, 0
cb:  times 16 db 0

pass_msg: db 'PASS: CDAUDIO', 13, 10, '$'
fail_install_msg: db 'FAIL: CDAUDIO INSTALL', 13, 10, '$'
fail_badcmd_msg: db 'FAIL: CDAUDIO BADCMD', 13, 10, '$'
fail_badunit_msg: db 'FAIL: CDAUDIO BADUNIT', 13, 10, '$'
fail_discinfo_msg: db 'FAIL: CDAUDIO DISCINFO', 13, 10, '$'
fail_trackinfo_msg: db 'FAIL: CDAUDIO TRACKINFO', 13, 10, '$'
fail_play_msg: db 'FAIL: CDAUDIO PLAY', 13, 10, '$'
fail_stop_msg: db 'FAIL: CDAUDIO STOP', 13, 10, '$'
