[bits 16]
[org 0x0100]

; The CD read path keeps a one-sector cache in CD_BUF. CD_BUF is also the
; scratch buffer for directory scans, the PVD, and audio, so a raw sector
; read must invalidate the cache. This checks coherence: read a file
; sector, run a FindFirst (which reads the directory into CD_BUF), then
; re-read the same file sector -- the bytes must still be the file's, not
; the directory's. Also exercises plain cache hits (re-reading without an
; intervening directory op). Pattern: byte[o] = (o ^ (o>>8)) & 0xFF.

start:
    push cs
    pop ds
    cld
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    mov dx, fname
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax

    ; read sector 0 region and verify
    xor dx, dx
    xor cx, cx
    call seek_read256
    jc fail_read
    xor bx, bx
    call verify256
    jc fail_v1

    ; re-read the same region (plain cache hit) and verify
    xor dx, dx
    xor cx, cx
    call seek_read256
    jc fail_read
    xor bx, bx
    call verify256
    jc fail_v2

    ; FindFirst reads the directory into CD_BUF, invalidating the cache
    mov dx, wild
    mov cx, 0x0010
    mov ah, 0x4E
    int 0x21
    jc fail_find

    ; re-read sector 0 region: must be the file's bytes, not directory
    xor dx, dx
    xor cx, cx
    call seek_read256
    jc fail_read
    xor bx, bx
    call verify256
    jc fail_coh

    ; a region that crosses a sector boundary (offset 1960, 256 bytes)
    mov dx, 1960
    xor cx, cx
    call seek_read256
    jc fail_read
    mov bx, 1960
    call verify256
    jc fail_v3

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

; seek to CX:DX, read 256 bytes into buf. CF on read error.
seek_read256:
    mov bx, [handle]
    mov ax, 0x4200
    int 0x21
    jc .err
    mov bx, [handle]
    mov cx, 256
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    jc .err
    cmp ax, 256
    jne .err
    clc
    ret
.err:
    stc
    ret

; verify buf[0..255] against the pattern for file offset BX. CF if wrong.
verify256:
    push si
    push di
    mov si, buf
    mov di, bx                  ; di = current file offset
    mov cx, 256
.loop:
    mov ax, di
    mov bl, al
    xor bl, ah                  ; (o ^ (o>>8)) & 0xFF
    cmp [si], bl
    jne .bad
    inc si
    inc di
    loop .loop
    pop di
    pop si
    clc
    ret
.bad:
    pop di
    pop si
    stc
    ret

fail_open:
    mov dx, m_open
    jmp fail
fail_read:
    mov dx, m_read
    jmp fail
fail_find:
    mov dx, m_find
    jmp fail
fail_v1:
    mov dx, m_v1
    jmp fail
fail_v2:
    mov dx, m_v2
    jmp fail
fail_coh:
    mov dx, m_coh
    jmp fail
fail_v3:
    mov dx, m_v3
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fname:   db 'D:\PATTERN.BIN', 0
wild:    db 'D:\*.*', 0
pass_msg: db 'PASS: CDCACHE', 13, 10, '$'
m_open: db 'FAIL: CDCACHE OPEN', 13, 10, '$'
m_read: db 'FAIL: CDCACHE READ', 13, 10, '$'
m_find: db 'FAIL: CDCACHE FIND', 13, 10, '$'
m_v1:   db 'FAIL: CDCACHE V1', 13, 10, '$'
m_v2:   db 'FAIL: CDCACHE V2 (hit)', 13, 10, '$'
m_coh:  db 'FAIL: CDCACHE COHERENCE', 13, 10, '$'
m_v3:   db 'FAIL: CDCACHE V3 (span)', 13, 10, '$'
handle: dw 0
buf: times 256 db 0
