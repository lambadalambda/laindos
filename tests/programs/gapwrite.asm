[bits 16]
[org 0x0100]

; Writing far past EOF must extend the file by allocating clusters only --
; not by read-modify-writing every gap sector with zeros. This pins both
; halves of the Red Alert swap-file fix: the gap extend allocates the
; chain through the write position, and the FAT16 write-back window
; collapses thousands of per-entry FAT writes into a few. The gap on a
; freshly formatted volume still reads back as zero.

GAP_HI equ 0x0040            ; write position = 0x00400000 (4 MiB)
GAP_LO equ 0x0000
MID_HI equ 0x0020            ; mid-gap probe at 0x00200000 (2 MiB)

start:
    push cs
    pop ds
    cld
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    ; create the file
    mov dx, fname
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    ; seek to 4 MiB and write a marker there (forces the gap extend)
    mov bx, [handle]
    mov cx, GAP_HI
    mov dx, GAP_LO
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    mov bx, [handle]
    mov cx, 16
    mov dx, marker
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 16
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    ; reopen and verify the size is exactly the write position + 16
    mov dx, fname
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax
    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4202
    int 0x21
    jc fail_seek
    cmp dx, GAP_HI
    jne fail_size
    cmp ax, 16
    jne fail_size

    ; the marker reads back intact
    mov bx, [handle]
    mov cx, GAP_HI
    mov dx, GAP_LO
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    mov bx, [handle]
    mov cx, 16
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    cmp ax, 16
    jne fail_read
    mov si, marker
    mov di, buf
    mov cx, 16
    call cmp_bytes
    jc fail_marker

    ; the gap reads back as zero at the start...
    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    call read64
    jc fail_read
    call check_zero64
    jc fail_gap

    ; ...and in the middle (a different FAT-window sector)
    mov bx, [handle]
    mov cx, MID_HI
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    call read64
    jc fail_read
    call check_zero64
    jc fail_gap

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

read64:                      ; read 64 bytes into buf; CF=read error/short
    mov bx, [handle]
    mov cx, 64
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    jc .err
    cmp ax, 64
    jne .err
    clc
    ret
.err:
    stc
    ret

cmp_bytes:                   ; ds:si vs ds:di, cx bytes; CF set if differ
    mov al, [si]
    cmp al, [di]
    jne .diff
    inc si
    inc di
    loop cmp_bytes
    clc
    ret
.diff:
    stc
    ret

check_zero64:                ; CF set if any of buf[0..63] is nonzero
    mov di, buf
    mov cx, 64
.loop:
    cmp byte [di], 0
    jne .nz
    inc di
    loop .loop
    clc
    ret
.nz:
    stc
    ret

fail_create:
    mov dx, m_create
    jmp fail
fail_seek:
    mov dx, m_seek
    jmp fail
fail_write:
    mov dx, m_write
    jmp fail
fail_close:
    mov dx, m_close
    jmp fail
fail_open:
    mov dx, m_open
    jmp fail
fail_size:
    mov dx, m_size
    jmp fail
fail_read:
    mov dx, m_read
    jmp fail
fail_marker:
    mov dx, m_marker
    jmp fail
fail_gap:
    mov dx, m_gap
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fname:   db 'C:\GAP.DAT', 0
marker:  db 'GAPDAT-WRITEBACK'
pass_msg:  db 'PASS: GAPWRITE', 13, 10, '$'
m_create:  db 'FAIL: GAPWRITE CREATE', 13, 10, '$'
m_seek:    db 'FAIL: GAPWRITE SEEK', 13, 10, '$'
m_write:   db 'FAIL: GAPWRITE WRITE', 13, 10, '$'
m_close:   db 'FAIL: GAPWRITE CLOSE', 13, 10, '$'
m_open:    db 'FAIL: GAPWRITE OPEN', 13, 10, '$'
m_size:    db 'FAIL: GAPWRITE SIZE', 13, 10, '$'
m_read:    db 'FAIL: GAPWRITE READ', 13, 10, '$'
m_marker:  db 'FAIL: GAPWRITE MARKER', 13, 10, '$'
m_gap:     db 'FAIL: GAPWRITE GAP', 13, 10, '$'
handle: dw 0
buf: times 64 db 0
