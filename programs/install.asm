[bits 16]
[org 0x0100]

; LainDOS installer: update an existing LainDOS FAT16 hard disk in place, or
; format a target hard disk to FAT16 and copy the system files onto it.
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
    cld
    push cs
    pop ds
    mov si, m_banner
    call puts
    call require_floppy_boot
    jc fail_bootsource

    call detect_geometry
    jc fail_geom
    cmp word [cyls], 1024
    ja fail_geom_large
    xor eax, eax
    push cs
    pop es
    mov bx, boot_buf
    call read_lba
    jc fail_io
    call detect_existing_install
    jnc existing_install
    cmp byte [detect_io_error], 0
    jne fail_io
    jmp fresh_install

existing_install:
    mov si, m_update
    call puts
    call report_layout
    call confirm_update
    jc aborted

    call write_update_boot_sector
    jc fail_io
    call update_files
    jc fail_io

    mov si, m_update_done
    call puts
    mov ax, 0x4C00
    int 0x21

fresh_install:
    ; detect_existing_install may have loaded layout fields from a foreign BPB.
    call detect_geometry
    jc fail_geom
    call compute_layout
    jc fail_small
    call report_layout

    call confirm_format
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
fail_bootsource:
    mov si, m_failbootsource
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
; The installer writes the target hard disk through BIOS calls behind the DOS
; kernel's back. Refuse to run while booted from that same hard disk.
; ---------------------------------------------------------------------------
require_floppy_boot:
    ; boot.asm stores the raw BIOS boot drive at 0000:0500.
    push ax
    push ds
    xor ax, ax
    mov ds, ax
    mov al, [0x500]
    pop ds
    test al, al
    pop ax
    jnz .err
    clc
    ret
.err:
    stc
    ret

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
; Confirm: require a 'Y'.
; ---------------------------------------------------------------------------
confirm_format:
    mov word [confirm_prompt_ptr], m_confirm_format
    jmp confirm_common

confirm_update:
    mov word [confirm_prompt_ptr], m_confirm_update

confirm_common:
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
    mov si, [confirm_prompt_ptr]
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
; Existing install detection: accept the superfloppy FAT16 layout written by
; the installer only when all managed LainDOS files are present in the root.
; On success the normal layout variables are loaded from the existing BPB.
; ---------------------------------------------------------------------------
detect_existing_install:
    mov byte [detect_io_error], 0
    cmp word [boot_buf+0x1FE], 0xAA55
    jne .no
    cmp word [boot_buf+0x0B], 512
    jne .no
    movzx ax, byte [boot_buf+0x0D]
    test ax, ax
    jz .no
    mov bx, ax
    dec bx
    test ax, bx
    jnz .no
    mov [spc], ax
    cmp word [boot_buf+0x0E], RESERVED
    jne .no
    cmp byte [boot_buf+0x10], 2
    jne .no
    cmp word [boot_buf+0x11], 512
    jne .no
    cmp dword [boot_buf+0x1C], 0
    jne .no
    push ds
    pop es
    mov si, s_fat16
    mov di, boot_buf+0x36
    mov cx, 8
    repe cmpsb
    jne .no

    movzx eax, word [boot_buf+0x16]
    test eax, eax
    jz .no
    mov [fat_sz], eax
    movzx eax, word [boot_buf+0x13]
    test eax, eax
    jnz .got_total
    mov eax, [boot_buf+0x20]
.got_total:
    test eax, eax
    jz .no
    mov [total_sectors], eax
    mov dword [fat_start], RESERVED
    mov eax, [fat_sz]
    shl eax, 1
    add eax, RESERVED
    mov [root_start], eax
    add eax, ROOT_SECS
    mov [data_start], eax
    cmp eax, [total_sectors]
    jae .no
    mov eax, [total_sectors]
    sub eax, [data_start]
    movzx ebx, word [spc]
    xor edx, edx
    div ebx
    mov [clusters], eax
    cmp eax, FAT16_MIN_CLUS
    jb .no
    cmp eax, FAT16_MAX_CLUS
    ja .no
    add eax, 1
    mov [max_data_cluster], eax

    call all_managed_files_present
    jc .no
    clc
    ret
.no:
    stc
    ret

all_managed_files_present:
    push si
    mov si, file_table
.loop:
    mov ax, [si]
    test ax, ax
    jz .done
    mov ax, [si+2]
    mov [cur_name_ptr], ax
    call find_root_entry
    jc .missing
    add si, 4
    jmp .loop
.done:
    pop si
    clc
    ret
.missing:
    pop si
    stc
    ret

find_root_entry:
    pushad
    mov word [root_s], 0
.sector:
    mov ax, [root_s]
    cmp ax, ROOT_SECS
    jae .not_found
    movzx eax, ax
    add eax, [root_start]
    push cs
    pop es
    mov bx, root_buf
    call read_lba
    jc .io_error
    push cs
    pop es
    mov di, root_buf
    mov cx, 16
.entry:
    cmp byte [di], 0
    je .not_found
    cmp byte [di], 0xE5
    je .next
    cmp byte [di+11], 0x0F
    je .next
    push cx
    push di
    mov si, [cur_name_ptr]
    mov cx, 11
    repe cmpsb
    pop di
    pop cx
    je .found
.next:
    add di, 32
    loop .entry
    inc word [root_s]
    jmp .sector
.found:
    mov ax, [root_s]
    movzx eax, ax
    add eax, [root_start]
    mov [root_entry_lba], eax
    mov ax, di
    sub ax, root_buf
    mov [root_entry_off], ax
    mov ax, [di+26]
    mov [old_first], ax
    clc
    jmp .out
.io_error:
    mov byte [detect_io_error], 1
.not_found:
    stc
.out:
    popad
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

; Refresh boot code while preserving the existing BPB and volume fields.
write_update_boot_sector:
    mov dx, p_boot16
    mov ax, 0x3D00
    int 0x21
    jc .err
    mov [fhandle], ax
    mov bx, ax
    mov cx, 512
    mov dx, sec_buf
    mov ah, 0x3F
    int 0x21
    jc .err
    mov bx, [fhandle]
    mov ah, 0x3E
    int 0x21
    push ds
    pop es
    mov si, boot_buf+0x0B
    mov di, sec_buf+0x0B
    mov cx, 0x33
    rep movsb
    mov word [sec_buf+0x1FE], 0xAA55
    xor eax, eax
    push cs
    pop es
    mov bx, sec_buf
    call write_lba
    ret
.err:
    stc
    ret

; ---------------------------------------------------------------------------
; Update each managed file on an existing FAT16 target. New clusters are
; allocated from currently-free FAT entries; the root entry is flipped only
; after the new chain is complete, then the old chain is released.
; ---------------------------------------------------------------------------
update_files:
    mov word [alloc_scan], 2
    mov word [file_index], 0
    mov si, file_table
.loop:
    mov dx, [si]
    test dx, dx
    jz .done
    mov ax, [si+2]
    mov [cur_name_ptr], ax
    mov ax, 0x3D00
    int 0x21
    jc .err
    mov [fhandle], ax
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
    jc .err
    call find_root_entry
    jc .err
    movzx ecx, word [spc]
    shl ecx, 9
    mov eax, [fsize]
    add eax, ecx
    dec eax
    xor edx, edx
    div ecx
    mov [n_clusters], ax
    mov eax, [fsize]
    add eax, 511
    shr eax, 9
    mov [n_data_sectors], eax
    cmp word [n_clusters], 0
    jne .non_empty
    mov word [cur_first], 0
    call update_root_entry
    jc .err
    mov ax, [old_first]
    call free_chain
    jc .err
    jmp .close_next
.non_empty:
    call ensure_free_clusters
    jc .err
    mov word [cur_first], 0
    mov word [prev_cluster], 0
    mov ax, [n_clusters]
    mov [clusters_left], ax
.alloc_loop:
    cmp word [clusters_left], 0
    je .chain_done
    call find_free_cluster
    jc .err
    mov [cur_cluster], ax
    call write_current_cluster
    jc .err
    cmp word [prev_cluster], 0
    je .first_cluster
    mov ax, [prev_cluster]
    mov dx, [cur_cluster]
    call set_fat_entry_both
    jc .err
    jmp .linked
.first_cluster:
    mov ax, [cur_cluster]
    mov [cur_first], ax
.linked:
    mov ax, [cur_cluster]
    mov [prev_cluster], ax
    dec word [clusters_left]
    jmp .alloc_loop
.chain_done:
    mov ax, [prev_cluster]
    mov dx, 0xFFFF
    call set_fat_entry_both
    jc .err
    call update_root_entry
    jc .err
    mov ax, [old_first]
    call free_chain
    jc .err
.close_next:
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

ensure_free_clusters:
    pushad
    mov ax, [n_clusters]
    mov [free_needed], ax
    mov word [scan_cluster], 2
.loop:
    cmp word [free_needed], 0
    je .ok
    mov ax, [scan_cluster]
    cmp ax, [max_data_cluster]
    ja .no
    call read_fat_entry
    jc .err
    test ax, ax
    jnz .next
    dec word [free_needed]
.next:
    inc word [scan_cluster]
    jmp .loop
.ok:
    clc
    jmp .out
.no:
.err:
    stc
.out:
    popad
    ret

find_free_cluster:
    push bx
    mov ax, [alloc_scan]
    cmp ax, 2
    jae .start_low_ok
    mov ax, 2
    mov [alloc_scan], ax
.start_low_ok:
    cmp ax, [max_data_cluster]
    jbe .start_ok
    mov ax, 2
    mov [alloc_scan], ax
.start_ok:
    mov [alloc_start], ax
    mov byte [alloc_wrapped], 0
.loop:
    mov ax, [alloc_scan]
    cmp ax, [max_data_cluster]
    jbe .check_wrap
    mov word [alloc_scan], 2
    mov ax, 2
    mov byte [alloc_wrapped], 1
.check_wrap:
    cmp byte [alloc_wrapped], 0
    je .scan
    cmp ax, [alloc_start]
    jae .no
.scan:
    mov bx, ax
    call read_fat_entry
    jc .err
    test ax, ax
    jz .found
    inc word [alloc_scan]
    jmp .loop
.found:
    mov ax, bx
    inc word [alloc_scan]
    clc
    pop bx
    ret
.no:
.err:
    stc
    pop bx
    ret

write_current_cluster:
    pushad
    movzx eax, word [cur_cluster]
    sub eax, 2
    movzx ecx, word [spc]
    mul ecx
    add eax, [data_start]
    mov [w_lba], eax
    mov cx, [spc]
.sector:
    push cx
    call zero_sec_buf
    cmp dword [n_data_sectors], 0
    je .write
    mov bx, [fhandle]
    mov cx, 512
    mov dx, sec_buf
    mov ah, 0x3F
    int 0x21
    jc .err_pop
    dec dword [n_data_sectors]
.write:
    push cs
    pop es
    mov bx, sec_buf
    mov eax, [w_lba]
    call write_lba
    jc .err_pop
    inc dword [w_lba]
    pop cx
    loop .sector
    clc
    jmp .out
.err_pop:
    pop cx
    stc
.out:
    popad
    ret

update_root_entry:
    pushad
    mov eax, [root_entry_lba]
    push cs
    pop es
    mov bx, root_buf
    call read_lba
    jc .err
    mov bx, [root_entry_off]
    mov ax, [cur_first]
    mov [root_buf+bx+26], ax
    mov ax, [fsize]
    mov [root_buf+bx+28], ax
    mov ax, [fsize+2]
    mov [root_buf+bx+30], ax
    mov eax, [root_entry_lba]
    push cs
    pop es
    mov bx, root_buf
    call write_lba
    jc .err
    clc
    jmp .out
.err:
    stc
.out:
    popad
    ret

free_chain:
    pushad
    mov [chain_cluster], ax
    mov eax, [clusters]
    cmp eax, 0xFFFF
    jbe .guard_word
    mov eax, 0xFFFF
.guard_word:
    mov [chain_guard], ax
.loop:
    mov ax, [chain_cluster]
    cmp ax, 2
    jb .done
    cmp ax, [max_data_cluster]
    ja .done
    cmp word [chain_guard], 0
    je .done
    call read_fat_entry
    jc .err
    mov [next_cluster_value], ax
    mov ax, [chain_cluster]
    xor dx, dx
    call set_fat_entry_both
    jc .err
    dec word [chain_guard]
    mov ax, [next_cluster_value]
    cmp ax, 0xFFF8
    jae .done
    cmp ax, 2
    jb .done
    cmp ax, [max_data_cluster]
    ja .done
    mov [chain_cluster], ax
    jmp .loop
.done:
    clc
    jmp .out
.err:
    stc
.out:
    popad
    ret

read_fat_entry:
    push bx
    push cx
    push edx
    push es
    mov [fat_cluster], ax
    mov bx, ax
    and bx, 0x00FF
    shl bx, 1
    mov [fat_entry_off], bx
    movzx eax, word [fat_cluster]
    shr eax, 8
    add eax, [fat_start]
    push cs
    pop es
    mov bx, sec_buf
    call read_lba
    jc .err
    mov bx, [fat_entry_off]
    mov ax, [sec_buf+bx]
    clc
    jmp .out
.err:
    stc
.out:
    pop es
    pop edx
    pop cx
    pop bx
    ret

set_fat_entry_both:
    push eax
    push dx
    mov [fat_cluster], ax
    mov [fat_value], dx
    mov eax, [fat_start]
    add eax, [fat_sz]
    call set_fat_entry_at
    jc .err
    mov eax, [fat_start]
    call set_fat_entry_at
    jc .err
    clc
    jmp .out
.err:
    stc
.out:
    pop dx
    pop eax
    ret

set_fat_entry_at:
    pushad
    push es
    mov bx, [fat_cluster]
    and bx, 0x00FF
    shl bx, 1
    mov [fat_entry_off], bx
    movzx edx, word [fat_cluster]
    shr edx, 8
    add eax, edx
    mov [fat_entry_lba], eax
    push cs
    pop es
    mov bx, sec_buf
    call read_lba
    jc .err
    mov bx, [fat_entry_off]
    mov dx, [fat_value]
    mov [sec_buf+bx], dx
    mov eax, [fat_entry_lba]
    push cs
    pop es
    mov bx, sec_buf
    call write_lba
    jc .err
    clc
    jmp .out
.err:
    stc
.out:
    pop es
    popad
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
; read_lba/write_lba: transfer the 512-byte buffer ES:BX to/from target LBA
; EAX (1 sector), converting to CHS. CF set on error. Preserves registers.
; ---------------------------------------------------------------------------
read_lba:
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
    mov ax, 0x0201             ; read 1 sector
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
m_update:   db "Existing LainDOS install found; updater mode.", 13, 10, 0
m_confirm_format: db "Format C: and install? This ERASES the disk. [Y/N] ", 0
m_confirm_update: db "Update existing LainDOS files on C:? [Y/N] ", 0
m_done:     db "INSTALL DONE. Remove the floppy and reboot.", 13, 10, 0
m_update_done: db "UPDATE DONE. Remove the floppy and reboot.", 13, 10, 0
m_aborted:  db "Aborted.", 13, 10, 0
m_failgeom: db "FAIL: no hard disk (INT 13h AH=08h)", 13, 10, 0
m_failgeomlarge: db "FAIL: disk exceeds CHS limit", 13, 10, 0
m_failbootsource: db "FAIL: boot the installer floppy before running INSTALL", 13, 10, 0
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
old_first:      dw 0
cur_cluster:    dw 0
prev_cluster:   dw 0
n_clusters:     dw 0
clusters_left:  dw 0
n_data_sectors: dd 0
w_lba:          dd 0
fat_s:          dd 0
bf_cluster:     dd 0
root_s:         dw 0
root_entry_lba: dd 0
root_entry_off: dw 0
cur_name_ptr:   dw 0
confirm_prompt_ptr: dw 0
detect_io_error: db 0
alloc_scan:     dw 0
alloc_start:    dw 0
alloc_wrapped:  db 0
scan_cluster:   dw 0
free_needed:    dw 0
chain_cluster:  dw 0
next_cluster_value: dw 0
chain_guard:    dw 0
fat_cluster:    dw 0
fat_value:      dw 0
fat_entry_off:  dw 0
fat_entry_lba:  dd 0
w_cyl:          dw 0
w_head:         db 0
w_sec:          db 0
w_err:          db 0
first_clusters: times 8 dw 0
last_clusters:  times 8 dw 0
boot_buf:       times 512 db 0
root_buf:       times 512 db 0
sec_buf:        times 512 db 0
