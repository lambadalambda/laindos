[bits 16]
[org 0x0100]

; LainDOS installer: format a target hard disk to FAT16 (sized to fill the
; detected disk) and copy the system files onto it, making it bootable.
; Runs under LainDOS booted from the installer floppy; talks to the target
; with INT 13h directly (the kernel exposes no absolute-disk API and will
; not auto-mount a freshly formatted disk until the next boot). The system
; files and a FAT16 boot template are read from drive A: with normal DOS
; calls. Requires a 386 (32-bit math); LainDOS already targets DOS/4GW
; games, so that is a given.

TARGET_DRIVE  equ 0x80
ROOT_SECS     equ 32            ; 512 root entries * 32 bytes / 512
RESERVED      equ 1
FAT16_MAX_CLUS equ 65524
FAT16_MIN_CLUS equ 4085

start:
    push cs
    pop ds
    mov si, m_banner
    call puts

    call detect_geometry
    jc fail_geom
    cmp word [cyls], 1024
    ja fail_geom_large
    call compute_layout
    jc fail_small
    call report_layout

    call confirm
    jc aborted

    call write_boot_sector
    jc fail_io
    call copy_files
    jc fail_io
    call write_fats
    jc fail_io
    call write_root
    jc fail_io

    mov si, m_done
    call puts
    mov ax, 0x4C00
    int 0x21

fail_geom:
    mov si, m_failgeom
    jmp die
fail_geom_large:
    mov si, m_failgeomlarge
    jmp die
fail_small:
    mov si, m_failsmall
    jmp die
fail_io:
    mov si, m_failio
    jmp die
aborted:
    mov si, m_aborted
die:
    call puts
    mov ax, 0x4C01
    int 0x21

; ---------------------------------------------------------------------------
; Geometry: INT 13h AH=08h on the target drive.
; ---------------------------------------------------------------------------
detect_geometry:
    mov dl, TARGET_DRIVE
    mov ah, 0x08
    int 0x13
    jc .err
    test ah, ah
    jnz .err
    movzx ax, cl
    and ax, 0x3F
    mov [spt], ax
    movzx ax, dh
    inc ax
    mov [heads], ax
    movzx ax, ch
    movzx bx, cl
    and bx, 0xC0
    shl bx, 2
    or ax, bx
    inc ax
    mov [cyls], ax
    movzx eax, word [cyls]
    movzx ebx, word [heads]
    mul ebx
    movzx ebx, word [spt]
    mul ebx
    mov [total_sectors], eax
    clc
    ret
.err:
    stc
    ret

; ---------------------------------------------------------------------------
; Layout: choose the smallest cluster size that keeps the cluster count in
; FAT16 range, using the FAT-spec fat-size formula. Sets spc, fat_sz,
; fat_start, root_start, data_start, max_data_cluster.
; ---------------------------------------------------------------------------
compute_layout:
    mov word [spc], 1
.try_spc:
    ; fat_sz = (total - RESERVED - ROOT_SECS + tmp2 - 1) / tmp2
    ;   tmp2 = 256 * spc + 2
    movzx ebx, word [spc]
    shl ebx, 8
    add ebx, 2                  ; ebx = tmp2
    mov eax, [total_sectors]
    sub eax, RESERVED + ROOT_SECS
    add eax, ebx
    dec eax
    xor edx, edx
    div ebx                     ; eax = fat_sz
    mov [fat_sz], eax
    ; data = total - RESERVED - ROOT_SECS - 2*fat_sz
    mov eax, [total_sectors]
    sub eax, RESERVED + ROOT_SECS
    mov ebx, [fat_sz]
    shl ebx, 1
    sub eax, ebx                ; eax = data sectors
    ; clusters = data / spc
    movzx ebx, word [spc]
    xor edx, edx
    div ebx                     ; eax = cluster count
    mov [clusters], eax
    cmp eax, FAT16_MAX_CLUS
    jbe .got
    shl word [spc], 1           ; double cluster size, retry
    cmp word [spc], 256
    jb .try_spc
    stc                         ; never fit (disk absurdly large for FAT16)
    ret
.got:
    cmp dword [clusters], FAT16_MIN_CLUS
    jb .too_small
    mov dword [fat_start], RESERVED
    mov eax, [fat_sz]
    shl eax, 1
    add eax, RESERVED
    mov [root_start], eax
    add eax, ROOT_SECS
    mov [data_start], eax
    mov eax, [clusters]
    add eax, 1                  ; highest cluster number = clusters + 1
    mov [max_data_cluster], eax
    clc
    ret
.too_small:
    stc
    ret

report_layout:
    mov si, m_total
    call puts
    mov eax, [total_sectors]
    call ph32
    mov si, m_spc
    call puts
    mov ax, [spc]
    call ph16
    mov si, m_fatsz
    call puts
    mov eax, [fat_sz]
    call ph32
    mov si, m_clus
    call puts
    mov eax, [clusters]
    call ph32
    call crlf
    ret

; ---------------------------------------------------------------------------
; Confirm: destructive, so require a 'Y'.
; ---------------------------------------------------------------------------
confirm:
    ; a command-tail argument containing Y/y is a scripted "yes" -- skips
    ; the interactive prompt (e.g. INSTALL /Y)
    movzx cx, byte [0x80]
    test cx, cx
    jz .prompt
    mov si, 0x81
.scan:
    lodsb
    cmp al, 'Y'
    je .yes
    cmp al, 'y'
    je .yes
    loop .scan
.prompt:
    mov si, m_confirm
    call puts
    mov ah, 0x01
    int 0x21
    call crlf
    cmp al, 'Y'
    je .yes
    cmp al, 'y'
    je .yes
    stc
    ret
.yes:
    clc
    ret

; ---------------------------------------------------------------------------
; Boot sector: read BOOT16.BIN from A:, patch its BPB, write to LBA 0.
; ---------------------------------------------------------------------------
write_boot_sector:
    mov dx, p_boot16
    mov ax, 0x3D00
    int 0x21
    jc .err
    mov [fhandle], ax
    mov bx, ax
    mov cx, 512
    mov dx, boot_buf
    mov ah, 0x3F
    int 0x21
    jc .err
    mov bx, [fhandle]
    mov ah, 0x3E
    int 0x21
    ; patch BPB
    mov word [boot_buf+0x0B], 512
    mov al, [spc]
    mov [boot_buf+0x0D], al
    mov word [boot_buf+0x0E], RESERVED
    mov byte [boot_buf+0x10], 2
    mov word [boot_buf+0x11], 512
    mov eax, [total_sectors]
    cmp eax, 0x10000
    jae .big
    mov [boot_buf+0x13], ax
    mov dword [boot_buf+0x20], 0
    jmp .tot_done
.big:
    mov word [boot_buf+0x13], 0
    mov [boot_buf+0x20], eax
.tot_done:
    mov byte [boot_buf+0x15], 0xF8
    mov ax, [fat_sz]
    mov [boot_buf+0x16], ax
    mov ax, [spt]
    mov [boot_buf+0x18], ax
    mov ax, [heads]
    mov [boot_buf+0x1A], ax
    mov dword [boot_buf+0x1C], 0
    mov byte [boot_buf+0x24], 0x80
    mov word [boot_buf+0x1FE], 0xAA55
    mov si, s_fat16
    mov di, boot_buf+0x36
    mov cx, 8
    push ds
    push cs
    pop es
    rep movsb
    pop ds
    ; write to LBA 0
    xor eax, eax
    mov bx, boot_buf
    call write_lba
    ret
.err:
    stc
    ret

; ---------------------------------------------------------------------------
; Copy each system file: assign contiguous clusters, stream the data to the
; target's data area, record [first,last] cluster and a root entry.
; ---------------------------------------------------------------------------
copy_files:
    mov word [next_free], 2
    mov word [file_index], 0
    mov si, file_table
.loop:
    mov dx, [si]
    test dx, dx
    jz .done
    mov ax, 0x3D00
    int 0x21
    jc .err
    mov [fhandle], ax
    ; size via seek-end, then rewind
    mov bx, ax
    xor cx, cx
    xor dx, dx
    mov ax, 0x4202
    int 0x21
    jc .err
    mov [fsize], ax
    mov [fsize+2], dx
    mov bx, [fhandle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    ; n_clusters = ceil(size / (spc*512))
    movzx ecx, word [spc]
    shl ecx, 9
    mov eax, [fsize]
    add eax, ecx
    dec eax
    xor edx, edx
    div ecx
    mov [n_clusters], ax
    ; first cluster + record it
    mov ax, [next_free]
    mov [cur_first], ax
    mov bx, [file_index]
    shl bx, 1
    mov [first_clusters+bx], ax
    ; data LBA = data_start + (first-2)*spc
    movzx eax, word [cur_first]
    sub eax, 2
    movzx ecx, word [spc]
    mul ecx
    add eax, [data_start]
    mov [w_lba], eax
    ; data sectors = ceil(size / 512)
    mov eax, [fsize]
    add eax, 511
    shr eax, 9
    mov [n_data_sectors], eax
.data:
    cmp dword [n_data_sectors], 0
    je .data_done
    call zero_sec_buf
    mov bx, [fhandle]
    mov cx, 512
    mov dx, sec_buf
    mov ah, 0x3F
    int 0x21
    jc .err
    push cs
    pop es
    mov bx, sec_buf
    mov eax, [w_lba]
    call write_lba
    jc .err
    inc dword [w_lba]
    dec dword [n_data_sectors]
    jmp .data
.data_done:
    ; last cluster, record it
    mov ax, [cur_first]
    add ax, [n_clusters]
    dec ax
    mov bx, [file_index]
    shl bx, 1
    mov [last_clusters+bx], ax
    ; next_free += n_clusters
    mov ax, [next_free]
    add ax, [n_clusters]
    mov [next_free], ax
    ; root entry
    call add_root_entry
    ; close, advance
    mov bx, [fhandle]
    mov ah, 0x3E
    int 0x21
    add si, 4
    inc word [file_index]
    jmp .loop
.done:
    clc
    ret
.err:
    stc
    ret

; build a 32-byte dir entry in root_buf for the current file. SI -> the
; file_table entry (word path, word name83 ptr).
add_root_entry:
    push si
    push di
    mov di, [file_index]
    shl di, 5                   ; *32
    add di, root_buf
    mov bx, [si+2]              ; name83 ptr
    mov cx, 11
.name:
    mov al, [bx]
    mov [di], al
    inc bx
    inc di
    loop .name
    mov byte [di], 0x20         ; attr = archive
    inc di
    mov cx, 14                  ; reserved + time/date through cluster-hi
    xor al, al
.zero:
    mov [di], al
    inc di
    loop .zero
    mov ax, [cur_first]
    mov [di], ax               ; +26 first cluster
    add di, 2
    mov ax, [fsize]
    mov [di], ax               ; +28 size low
    mov ax, [fsize+2]
    mov [di+2], ax             ; +30 size high
    pop di
    pop si
    ret

; ---------------------------------------------------------------------------
; FAT: stream each FAT sector for both copies. The chains are contiguous
; (sequential allocation), so each entry is c+1 except the last cluster of
; each file (EOC) and free clusters beyond next_free (0).
; ---------------------------------------------------------------------------
write_fats:
    xor eax, eax
    mov [fat_s], eax
.loop:
    mov eax, [fat_s]
    cmp eax, [fat_sz]
    jae .done
    call build_fat_sector
    mov eax, [fat_start]
    add eax, [fat_s]
    push cs
    pop es
    mov bx, sec_buf
    call write_lba
    jc .err
    mov eax, [fat_start]
    add eax, [fat_sz]
    add eax, [fat_s]
    push cs
    pop es
    mov bx, sec_buf
    call write_lba
    jc .err
    inc dword [fat_s]
    jmp .loop
.done:
    clc
    ret
.err:
    stc
    ret

; fill sec_buf with the 256 FAT16 entries for FAT sector [fat_s].
build_fat_sector:
    push si
    push di
    mov eax, [fat_s]
    shl eax, 8                  ; base cluster = fat_s * 256
    mov [bf_cluster], eax
    xor di, di
.entry:
    cmp di, 512
    jae .filled
    mov eax, [bf_cluster]
    ; default entry value -> dx
    test eax, eax
    jnz .not0
    mov dx, 0xFFF8
    jmp .store
.not0:
    cmp eax, 1
    jne .not1
    mov dx, 0xFFFF
    jmp .store
.not1:
    cmp eax, [max_data_cluster]
    ja .free
    movzx ebx, word [next_free]
    cmp eax, ebx
    jae .free
    ; in-use: EOC if it is some file's last cluster, else c+1
    call is_last_cluster
    jc .eoc
    mov dx, ax
    inc dx
    jmp .store
.eoc:
    mov dx, 0xFFFF
    jmp .store
.free:
    xor dx, dx
.store:
    mov [sec_buf+di], dx
    add di, 2
    inc dword [bf_cluster]
    jmp .entry
.filled:
    pop di
    pop si
    ret

; CF set if AX (a cluster number, low 16 bits of bf_cluster) equals any
; recorded last_cluster. AX returned = the cluster (caller uses low word).
is_last_cluster:
    push cx
    push bx
    mov ax, [bf_cluster]       ; low word is enough (clusters < 65525)
    mov cx, [file_index]
    xor bx, bx
.scan:
    test cx, cx
    jz .no
    cmp ax, [last_clusters+bx]
    je .yes
    add bx, 2
    dec cx
    jmp .scan
.yes:
    pop bx
    pop cx
    stc
    ret
.no:
    pop bx
    pop cx
    clc
    ret

; ---------------------------------------------------------------------------
; Root directory: sector 0 holds the file entries (built in root_buf); the
; rest is zeroed.
; ---------------------------------------------------------------------------
write_root:
    mov eax, [root_start]
    push cs
    pop es
    mov bx, root_buf
    call write_lba
    jc .err
    call zero_sec_buf
    mov ecx, ROOT_SECS - 1
    mov eax, [root_start]
    inc eax
.loop:
    test ecx, ecx
    jz .done
    push ecx
    push cs
    pop es
    mov bx, sec_buf
    call write_lba
    pop ecx
    jc .err
    inc eax
    dec ecx
    jmp .loop
.done:
    clc
    ret
.err:
    stc
    ret

; ---------------------------------------------------------------------------
; write_lba: write the 512-byte buffer ES:BX to target LBA EAX (1 sector),
; converting to CHS. CF set on error. Preserves caller registers.
; ---------------------------------------------------------------------------
write_lba:
    pushad
    push es
    ; cyl = lba / (heads*spt); rem = lba % (heads*spt)
    movzx ecx, word [heads]
    movzx esi, word [spt]
    imul ecx, esi              ; ecx = heads*spt
    xor edx, edx
    div ecx                    ; eax = cyl, edx = rem
    mov [w_cyl], ax
    mov eax, edx
    xor edx, edx
    movzx ecx, word [spt]
    div ecx                    ; eax = head, edx = sector-1
    mov [w_head], al
    mov ax, dx
    inc ax
    mov [w_sec], al
    ; CHS for INT 13h
    mov ax, [w_cyl]
    mov ch, al
    mov cl, [w_sec]
    and cl, 0x3F
    mov ax, [w_cyl]
    shr ax, 8
    and al, 0x03
    shl al, 6
    or cl, al
    mov dh, [w_head]
    mov dl, TARGET_DRIVE
    mov ax, 0x0301             ; write 1 sector
    pop es                     ; restore ES (buffer segment) just before call
    push es
    int 0x13
    mov byte [w_err], 0
    jnc .ok
    mov byte [w_err], 1
.ok:
    pop es
    popad
    cmp byte [w_err], 0
    je .clc
    stc
    ret
.clc:
    clc
    ret

zero_sec_buf:
    push di
    push cx
    push es
    push cs
    pop es
    mov di, sec_buf
    mov cx, 256
    xor ax, ax
    rep stosw
    pop es
    pop cx
    pop di
    ret

; ---------------------------------------------------------------------------
; output: screen (INT 21h AH=02h)
; ---------------------------------------------------------------------------
putc:
    push ax
    push dx
    mov dl, bl
    mov ah, 0x02
    int 0x21
    pop dx
    pop ax
    ret

puts:
    push ax
.l:
    lodsb
    test al, al
    jz .d
    mov bl, al
    call putc
    jmp .l
.d:
    pop ax
    ret

crlf:
    mov bl, 13
    call putc
    mov bl, 10
    call putc
    ret

ph16:
    push cx
    push ax
    mov cx, 4
.l:
    rol ax, 4
    push ax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .ok
    add al, 7
.ok:
    mov bl, al
    call putc
    pop ax
    loop .l
    pop ax
    pop cx
    ret

ph32:
    push eax
    shr eax, 16
    call ph16
    pop eax
    call ph16
    ret

; ---- strings / tables ----
m_banner:   db "LainDOS Installer", 13, 10, 0
m_total:    db "  total sectors: ", 0
m_spc:      db "  sec/cluster: ", 0
m_fatsz:    db "  fat sectors: ", 0
m_clus:     db "  clusters: ", 0
m_confirm:  db "Format C: and install? This ERASES the disk. [Y/N] ", 0
m_done:     db "INSTALL DONE. Remove the floppy and reboot.", 13, 10, 0
m_aborted:  db "Aborted.", 13, 10, 0
m_failgeom: db "FAIL: no hard disk (INT 13h AH=08h)", 13, 10, 0
m_failgeomlarge: db "FAIL: disk exceeds CHS limit", 13, 10, 0
m_failsmall: db "FAIL: disk too small for FAT16", 13, 10, 0
m_failio:   db "FAIL: disk I/O error during install", 13, 10, 0
s_fat16:    db "FAT16   "

p_boot16:   db "A:\BOOT16.BIN", 0
p_kernel:   db "A:\KERNEL.SYS", 0
n_kernel:   db "KERNEL  SYS"
p_shell:    db "A:\SHELL.COM", 0
n_shell:    db "SHELL   COM"
p_free:     db "A:\FREE.COM", 0
n_free:     db "FREE    COM"
p_time:     db "A:\TIME.COM", 0
n_time:     db "TIME    COM"

file_table:
    dw p_kernel, n_kernel
    dw p_shell, n_shell
    dw p_free, n_free
    dw p_time, n_time
    dw 0

; ---- variables ----
spt:            dw 0
heads:          dw 0
cyls:           dw 0
total_sectors:  dd 0
spc:            dw 0
fat_sz:         dd 0
clusters:       dd 0
fat_start:      dd 0
root_start:     dd 0
data_start:     dd 0
max_data_cluster: dd 0
next_free:      dw 0
file_index:     dw 0
fhandle:        dw 0
fsize:          dd 0
cur_first:      dw 0
n_clusters:     dw 0
n_data_sectors: dd 0
w_lba:          dd 0
fat_s:          dd 0
bf_cluster:     dd 0
w_cyl:          dw 0
w_head:         db 0
w_sec:          db 0
w_err:          db 0
first_clusters: times 8 dw 0
last_clusters:  times 8 dw 0
boot_buf:       times 512 db 0
root_buf:       times 512 db 0
sec_buf:        times 512 db 0
