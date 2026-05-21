[bits 16]
[org 0x0000]

COM1_PORT equ 0x3F8

BPB_SEG   equ 0x0000
BPB_OFF   equ 0x7C00
FAT_SEG   equ 0x1000
ROOT_SEG  equ 0x2000
PSP_SEG   equ 0x3000
TEMP_SEG  equ 0x4000
SEC_BUF   equ 0x5000

HANDLE_SIZE equ 12
H_USED      equ 0
H_MODE      equ 1
H_CLUSTER   equ 2
H_POS_LO    equ 4
H_POS_HI    equ 6
H_SIZE_LO   equ 8
H_SIZE_HI   equ 10
MAX_HANDLES equ 20

CF equ 0x0001

kernel_entry:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    cld

    call serial_init

    mov si, msg_booted
    call serial_print

    int 0x12
    mov [mem_kib], ax
    mov si, msg_mem
    call serial_print
    mov ax, [mem_kib]
    call serial_print_int
    mov si, msg_kib
    call serial_print

    call init_interrupts

    mov si, msg_ints
    call serial_print

    mov si, fname_exe
    mov ax, TEMP_SEG
    xor bx, bx
    call load_file
    cmp ax, 0
    jne .halt

    mov ax, TEMP_SEG
    mov ds, ax
    cmp word [0x0000], 0x5A4D
    je .is_exe

    push cs
    pop ds
    mov si, msg_com_load
    call serial_print

    mov ax, PSP_SEG
    call build_psp

    mov ax, TEMP_SEG
    mov ds, ax
    xor si, si
    mov ax, PSP_SEG
    mov es, ax
    mov di, 0x0100
    mov cx, [cs:kfsize]
    rep movsb
    push cs
    pop ds

    mov ax, PSP_SEG
    call exec_com
    jmp .returned

.is_exe:
    push cs
    pop ds
    mov si, msg_exe_load
    call serial_print

    call setup_exe

.returned:

    mov si, msg_returned
    call serial_print
    mov al, [ret_code]
    call serial_print_hex
    mov si, msg_crlf
    call serial_print

.halt:
    mov si, msg_halt
    call serial_print
    cli
.hloop:
    hlt
    jmp .hloop

iret_nc:
    push bp
    mov bp, sp
    and word [bp+6], ~CF
    pop bp
    iret

iret_cy:
    push bp
    mov bp, sp
    or word [bp+6], CF
    pop bp
    iret

init_interrupts:
    pusha
    push ds
    push es
    xor ax, ax
    mov es, ax
    mov [es:0x20*4], word int20_handler
    mov [es:0x20*4+2], cs
    mov [es:0x21*4], word int21_handler
    mov [es:0x21*4+2], cs
    mov ax, kernel_entry
    mov [es:0x22*4], ax
    mov [es:0x22*4+2], cs
    mov [es:0x23*4], word int23_handler
    mov [es:0x23*4+2], cs
    mov [es:0x24*4], word int24_handler
    mov [es:0x24*4+2], cs
    pop es
    pop ds
    popa
    ret

int20_handler:
    mov byte [cs:ret_code], 0
    jmp do_terminate

int21_handler:
    cmp ah, 0x4C
    je .terminate
    cmp ah, 0x09
    je .print_string
    cmp ah, 0x00
    je .terminate
    cmp ah, 0x3D
    je .open_file
    cmp ah, 0x3E
    je .close_file
    cmp ah, 0x3F
    je .read_file
    cmp ah, 0x42
    je .seek_file
    cmp ah, 0x19
    je .get_drive
    cmp ah, 0x1A
    je .set_dta
    cmp ah, 0x25
    je .set_vector
    cmp ah, 0x2F
    je .get_dta
    cmp ah, 0x30
    je .get_version
    cmp ah, 0x35
    je .get_vector
    cmp ah, 0x4E
    je .find_first
    cmp ah, 0x62
    je .get_psp
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_unhandled
    call serial_print
    mov al, ah
    call serial_print_hex
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
    jmp iret_nc
.terminate:
    mov [cs:ret_code], al
    jmp do_terminate
.print_string:
    push ds
    push si
    push dx
    push ax
    mov si, dx
.lp:
    lodsb
    cmp al, '$'
    je .dn
    mov ah, al
    mov dx, COM1_PORT + 5
.w: in al, dx
    test al, 0x20
    jz .w
    mov al, ah
    mov dx, COM1_PORT
    out dx, al
    jmp .lp
.dn:
    pop ax
    pop dx
    pop si
    pop ds
    jmp iret_nc
.get_drive:
    mov al, 0
    jmp iret_nc
.set_dta:
    mov [cs:dta_off], dx
    mov [cs:dta_seg], ds
    jmp iret_nc
.get_dta:
    mov bx, [cs:dta_off]
    mov es, [cs:dta_seg]
    jmp iret_nc
.set_vector:
    push ds
    push bx
    push ax
    push ds
    mov bl, al
    xor bh, bh
    xor ax, ax
    mov ds, ax
    shl bx, 2
    mov [bx], dx
    pop ax
    mov [bx+2], ax
    pop ax
    pop bx
    pop ds
    jmp iret_nc
.get_version:
    mov ax, 0x0003
    mov bx, 0x0000
    mov cx, 0x0000
    jmp iret_nc
.get_vector:
    push ax
    mov bl, al
    xor bh, bh
    xor ax, ax
    mov es, ax
    shl bx, 2
    mov si, [es:bx]
    mov bx, [es:bx+2]
    mov es, bx
    mov bx, si
    pop ax
    jmp iret_nc
.get_psp:
    mov bx, PSP_SEG
    jmp iret_nc
.open_file:
    push ds
    push si
    push cx
    push di
    mov si, dx
    call parse_83name
    call find_in_root
    jnc .of_found
    pop di
    pop cx
    pop si
    pop ds
    mov ax, 2
    jmp iret_cy
.of_found:
    call alloc_handle
    jc .of_no_handles
    push ax
    push di
    mov di, ax
    mov cx, HANDLE_SIZE
    mul cx
    mov di, ax
    mov byte [cs:di+handles+H_USED], 1
    mov byte [cs:di+handles+H_MODE], 0
    pop si
    mov ax, [es:si+26]
    mov [cs:di+handles+H_CLUSTER], ax
    mov ax, [es:si+28]
    mov [cs:di+handles+H_SIZE_LO], ax
    mov word [cs:di+handles+H_SIZE_HI], 0
    mov word [cs:di+handles+H_POS_LO], 0
    mov word [cs:di+handles+H_POS_HI], 0
    pop ax
    pop di
    pop cx
    pop si
    pop ds
    jmp iret_nc
.of_no_handles:
    pop di
    pop cx
    pop si
    pop ds
    mov ax, 4
    jmp iret_cy
.close_file:
    cmp bx, MAX_HANDLES
    jae .cf_err
    push bx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    mov byte [cs:bx+handles+H_USED], 0
    pop bx
    jmp iret_nc
.cf_err:
    mov ax, 6
    jmp iret_cy
.read_file:
    cmp bx, MAX_HANDLES
    jae .rf_err
    push bx
    push cx
    push ds
    push es
    push si
    push di
    mov [cs:rf_count], cx
    mov [cs:rf_buf_off], dx
    mov [cs:rf_buf_seg], ds
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov [cs:rf_hoff], ax
    mov word [cs:rf_read], 0
.rf_loop:
    mov cx, [cs:rf_count]
    test cx, cx
    jz .rf_done
    mov bx, [cs:rf_hoff]
    mov ax, [cs:bx+handles+H_POS_HI]
    cmp ax, [cs:bx+handles+H_SIZE_HI]
    ja .rf_done
    jb .rf_do_read
    mov ax, [cs:bx+handles+H_POS_LO]
    cmp ax, [cs:bx+handles+H_SIZE_LO]
    jae .rf_done
.rf_do_read:
    mov ax, [cs:bx+handles+H_CLUSTER]
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, [cs:kdsta]
    push es
    push bx
    xor bx, bx
    mov dx, SEC_BUF
    mov es, dx
    call read_sector
    pop bx
    pop es
    jc .rf_err
    mov si, [cs:rf_hoff]
    mov cx, [cs:si+handles+H_SIZE_LO]
    mov ax, [cs:si+handles+H_POS_LO]
    sub cx, ax
    cmp cx, 512
    jbe .rf_got1
    mov cx, 512
.rf_got1:
    mov ax, [cs:rf_count]
    cmp cx, ax
    jbe .rf_got2
    mov cx, ax
.rf_got2:
    push ds
    push si
    mov dx, [cs:rf_buf_seg]
    mov es, dx
    mov di, [cs:rf_buf_off]
    mov dx, SEC_BUF
    mov ds, dx
    xor si, si
    mov bx, [cs:rf_hoff]
    add si, [cs:bx+handles+H_POS_LO]
    and si, 511
    mov ax, 512
    sub ax, si
    cmp cx, ax
    jbe .rf_copy
    mov cx, ax
.rf_copy:
    push cx
    rep movsb
    pop cx
    pop si
    pop ds
    mov bx, [cs:rf_hoff]
    add [cs:bx+handles+H_POS_LO], cx
    adc word [cs:bx+handles+H_POS_HI], 0
    mov ax, [cs:rf_buf_off]
    add ax, cx
    mov [cs:rf_buf_off], ax
    mov ax, [cs:rf_count]
    sub ax, cx
    mov [cs:rf_count], ax
    add [cs:rf_read], cx
    jmp .rf_loop
.rf_done:
    mov ax, [cs:rf_read]
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    jmp iret_nc
.rf_err:
    mov ax, 6
    jmp iret_cy

.seek_file:
    cmp bx, MAX_HANDLES
    jae .sf_err
    mov [cs:sf_origin], al
    push cx
    push dx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    pop dx
    pop cx
    cmp byte [cs:si+handles+H_USED], 0
    je .sf_err
    cmp byte [cs:sf_origin], 0
    je .sf_start
    cmp byte [cs:sf_origin], 1
    je .sf_cur
    cmp byte [cs:sf_origin], 2
    je .sf_end
    jmp .sf_err
.sf_start:
    mov [cs:si+handles+H_POS_LO], dx
    mov [cs:si+handles+H_POS_HI], cx
    jmp .sf_ok
.sf_cur:
    add [cs:si+handles+H_POS_LO], dx
    adc [cs:si+handles+H_POS_HI], cx
    jmp .sf_ok
.sf_end:
    mov ax, [cs:si+handles+H_SIZE_LO]
    sub ax, dx
    mov [cs:si+handles+H_POS_LO], ax
    mov ax, [cs:si+handles+H_SIZE_HI]
    sbb ax, cx
    mov [cs:si+handles+H_POS_HI], ax
.sf_ok:
    mov ax, [cs:si+handles+H_POS_LO]
    mov dx, [cs:si+handles+H_POS_HI]
    jmp iret_nc
.sf_err:
    mov ax, 1
    jmp iret_cy

.find_first:
    push ds
    push si
    push cx
    push bx
    mov si, dx
    call parse_83name
    mov ax, [cs:dta_seg]
    mov es, ax
    mov di, [cs:dta_off]
    add di, 21
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    mov ax, ROOT_SEG
    mov ds, ax
    xor si, si
    mov cx, 224
.ff_search:
    cmp byte [ds:si], 0
    je .ff_notfound
    push cx
    push si
    push es
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    repe cmpsb
    pop es
    pop si
    pop cx
    jne .ff_next
    mov ax, [cs:dta_seg]
    mov es, ax
    mov di, [cs:dta_off]
    mov al, [ds:si]
    mov [es:di], al
    mov ax, [ds:si+28]
    mov [es:di+26], ax
    mov ax, [ds:si+26]
    mov [es:di+24], ax
    mov byte [es:di+20], 0
    mov byte [es:di+19], 0
    pop bx
    pop cx
    pop si
    pop ds
    jmp iret_nc
.ff_next:
    add si, 32
    loop .ff_search
.ff_notfound:
    pop bx
    pop cx
    pop si
    pop ds
    mov ax, 2
    jmp iret_cy

int23_handler:
    iret

int24_handler:
    mov al, 3
    iret

do_terminate:
    mov word [cs:running], 0
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, [cs:saved_sp]
    jmp exec_com.back

alloc_handle:
    push bx
    push si
    xor bx, bx
.ah_loop:
    cmp bx, MAX_HANDLES
    jae .ah_full
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .ah_found
    inc bx
    jmp .ah_loop
.ah_found:
    mov ax, bx
    pop si
    pop bx
    clc
    ret
.ah_full:
    pop si
    pop bx
    stc
    ret

parse_83name:
    push ax
    push cx
    push ds
    push es
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    mov al, ' '
    rep stosb
    mov di, name_buf
.pl:
    lodsb
    test al, al
    jz .pl_done
    cmp al, '.'
    je .pl_dot
    cmp al, 'a'
    jb .pl_noupper
    cmp al, 'z'
    ja .pl_noupper
    sub al, 32
.pl_noupper:
    stosb
    jmp .pl
.pl_dot:
    mov di, name_buf + 8
    jmp .pl
.pl_done:
    pop es
    pop ds
    pop cx
    pop ax
    ret

find_in_root:
    push cs
    pop ds
    mov si, name_buf
    mov ax, ROOT_SEG
    mov es, ax
    xor di, di
    mov cx, 224
.fr_search:
    cmp byte [es:di], 0
    je .fr_notfound
    push cx
    push di
    push ds
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    repe cmpsb
    pop ds
    pop di
    pop cx
    je .fr_found
    add di, 32
    loop .fr_search
.fr_notfound:
    stc
    ret
.fr_found:
    mov [cs:find_di], di
    clc
    ret

load_file:
    mov [cs:load_name], si
    mov [cs:load_seg], ax
    mov [cs:load_off], bx

    push ds
    push bx
    mov ax, BPB_SEG
    mov ds, ax
    mov bx, BPB_OFF

    mov ax, [bx+22]
    movzx cx, byte [bx+16]
    mul cx
    add ax, [bx+14]
    mov [cs:krsta], ax
    mov ax, [bx+17]
    push ax
    mov al, [bx+13]
    mov [cs:kspc], al
    pop ax
    mov bx, 32
    mul bx
    add ax, 511
    mov bx, 512
    div bx
    mov [cs:krsc], ax
    add ax, [cs:krsta]
    mov [cs:kdsta], ax

    pop bx
    pop ds
    push ds
    xor ax, ax
    mov ds, ax
    mov al, [0x500]
    pop ds
    mov [cs:kdrv], al

    mov ax, ROOT_SEG
    mov es, ax
    xor di, di
    mov cx, 224
.search:
    cmp byte [es:di], 0
    je .notfound
    push cx
    push di
    push ds
    push cs
    pop ds
    mov si, [cs:load_name]
    mov cx, 11
    repe cmpsb
    pop ds
    pop di
    pop cx
    je .found
    add di, 32
    loop .search
.notfound:
    push cs
    pop ds
    mov si, msg_nofile
    call serial_print
    mov ax, 1
    ret
.found:
    mov ax, [es:di+26]
    mov [cs:kclus], ax
    mov ax, [es:di+28]
    mov [cs:kfsize], ax

    mov ax, [cs:load_seg]
    mov es, ax
    mov bx, [cs:load_off]
    mov si, [cs:kclus]
.load:
    cmp si, 0xFF8
    jae .done
    cmp si, 2
    jb .notfound
    push si
    mov ax, si
    sub ax, 2
    xor ch, ch
    mov cl, [kspc]
    mul cx
    add ax, [kdsta]
    mov cx, 1
    call read_sector
    pop si
    jc .notfound
    call fat_next
    mov si, ax
    jmp .load
.done:
    push cs
    pop ds
    xor ax, ax
    ret

fat_next:
    push bx
    mov bx, si
    shr bx, 1
    add bx, si
    push ds
    mov ax, FAT_SEG
    mov ds, ax
    mov ax, [bx]
    pop ds
    test si, 1
    jz .even
    shr ax, 4
    jmp .ret
.even:
    and ax, 0x0FFF
.ret:
    pop bx
    ret

read_sector:
    mov [cs:klba], ax
    mov byte [cs:kcnt], 1
    mov byte [cs:kret], 3
.r1:
    push ds
    mov ax, BPB_SEG
    mov ds, ax
    mov ax, [cs:klba]
    xor dx, dx
    div word [BPB_OFF+24]
    inc dl
    mov [cs:ksc], dl
    xor dx, dx
    div word [BPB_OFF+26]
    mov [cs:khd], dl
    mov [cs:kcy], al
    pop ds
    mov ah, 2
    mov al, 1
    mov ch, [cs:kcy]
    mov cl, [cs:ksc]
    mov dh, [cs:khd]
    mov dl, [cs:kdrv]
    int 0x13
    jnc .ok
    xor ax, ax
    mov dl, [cs:kdrv]
    int 0x13
    dec byte [cs:kret]
    jnz .r1
    stc
    ret
.ok:
    add bx, 512
    jnc .rnb
    mov ax, es
    add ax, 0x1000
    mov es, ax
.rnb:
    inc word [cs:klba]
    dec byte [cs:kcnt]
    jnz .r1
    clc
    ret

exec_com:
    mov byte [cs:ret_code], 0xFF
    mov word [cs:running], 1
    mov [cs:saved_sp], sp

    mov ax, PSP_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    push word 0x0000
    jmp far PSP_SEG:0x0100

.back:
    ret

build_psp:
    mov es, ax
    push ax
    xor di, di
    mov cx, 128
    xor ax, ax
    rep stosw

    mov byte [es:0x00], 0xCD
    mov byte [es:0x01], 0x20
    mov ax, 0xA000
    mov [es:0x02], ax

    push ds
    xor ax, ax
    mov ds, ax
    mov ax, [0x22*4]
    mov [es:0x0A], ax
    mov ax, [0x22*4+2]
    mov [es:0x0C], ax
    mov ax, [0x23*4]
    mov [es:0x0E], ax
    mov ax, [0x23*4+2]
    mov [es:0x10], ax
    mov ax, [0x24*4]
    mov [es:0x12], ax
    mov ax, [0x24*4+2]
    mov [es:0x14], ax
    pop ds

    mov word [es:0x2C], 0
    pop ax
    ret

setup_exe:
    mov ax, TEMP_SEG
    mov ds, ax

    mov ax, [0x08]
    mov [cs:exe_hdr_par], ax
    mov ax, [0x0E]
    mov [cs:exe_ss], ax
    mov ax, [0x10]
    mov [cs:exe_sp], ax
    mov ax, [0x14]
    mov [cs:exe_ip], ax
    mov ax, [0x16]
    mov [cs:exe_cs], ax
    mov ax, [0x06]
    mov [cs:exe_reloc_count], ax
    mov ax, [0x18]
    mov [cs:exe_reloc_off], ax

    mov ax, PSP_SEG
    call build_psp

    mov ax, PSP_SEG
    add ax, 0x10
    mov [cs:exe_load_seg], ax

    mov ax, [cs:exe_hdr_par]
    mov cx, 16
    mul cx
    mov si, ax

    mov ax, TEMP_SEG
    mov ds, ax
    mov ax, [cs:exe_load_seg]
    mov es, ax
    xor di, di
    mov cx, [cs:kfsize]
    sub cx, si
    rep movsb

    mov cx, [cs:exe_reloc_count]
    test cx, cx
    jz .no_reloc
.reloc_loop:
    push cx
    mov bx, [cs:exe_reloc_off]
    mov ax, TEMP_SEG
    mov ds, ax
    mov di, [bx]
    mov ax, [bx+2]
    pop cx

    push ax
    add ax, [cs:exe_load_seg]
    mov es, ax
    pop ax
    mov ax, [es:di]
    add ax, [cs:exe_load_seg]
    mov [es:di], ax

    add word [cs:exe_reloc_off], 4
    loop .reloc_loop
.no_reloc:
    push cs
    pop ds
    call exec_exe
    ret

exec_exe:
    mov byte [cs:ret_code], 0xFF
    mov word [cs:running], 1
    mov [cs:saved_sp], sp

    mov ax, PSP_SEG
    mov ds, ax
    mov es, ax

    mov ax, [cs:exe_load_seg]
    add ax, [cs:exe_ss]
    mov ss, ax
    mov sp, [cs:exe_sp]

    mov ax, [cs:exe_load_seg]
    add ax, [cs:exe_cs]
    push ax
    push word [cs:exe_ip]
    retf

serial_init:
    mov dx, COM1_PORT + 1
    xor al, al
    out dx, al
    mov dx, COM1_PORT + 3
    mov al, 0x80
    out dx, al
    mov dx, COM1_PORT
    mov al, 0x01
    out dx, al
    mov dx, COM1_PORT + 1
    xor al, al
    out dx, al
    mov dx, COM1_PORT + 3
    mov al, 0x03
    out dx, al
    mov dx, COM1_PORT + 2
    mov al, 0xC7
    out dx, al
    mov dx, COM1_PORT + 4
    mov al, 0x0B
    out dx, al
    ret

serial_putchar:
    push dx
    push ax
    mov dx, COM1_PORT + 5
.wait:
    in al, dx
    test al, 0x20
    jz .wait
    pop ax
    mov dx, COM1_PORT
    out dx, al
    pop dx
    ret

serial_print:
    push si
    push ax
.loop:
    lodsb
    test al, al
    jz .done
    call serial_putchar
    jmp .loop
.done:
    pop ax
    pop si
    ret

serial_print_int:
    push ax
    push bx
    push cx
    push dx
    mov cx, 0
    mov bx, 10
.div_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div_loop
.print_loop:
    pop ax
    add al, '0'
    call serial_putchar
    loop .print_loop
    pop dx
    pop cx
    pop bx
    pop ax
    ret

serial_print_hex:
    push cx
    push ax
    mov cx, 2
.hloop:
    rol al, 4
    push ax
    and al, 0x0F
    cmp al, 10
    jae .alpha
    add al, '0'
    jmp .out
.alpha:
    add al, 'A' - 10
.out:
    call serial_putchar
    pop ax
    loop .hloop
    pop ax
    pop cx
    ret

msg_booted:   db "MiniDOS booted", 13, 10, 0
msg_mem:      db "Conventional memory: ", 0
msg_kib:      db " KB", 13, 10, 0
msg_ints:     db "INT 20h/21h installed", 13, 10, 0
msg_nofile:   db "File not found", 13, 10, 0
msg_com_load: db "HELLO.COM loaded", 13, 10, 0
msg_exe_load: db "HELLO.EXE loaded", 13, 10, 0
msg_returned: db "Program exited, code=", 0
msg_crlf:     db 13, 10, 0
msg_halt:     db "HALT", 13, 10, 0
msg_unhandled: db "INT 21h AH=", 0

fname_hello:  db "HELLO   COM"
fname_exe:   db "FILETESTEXE"

mem_kib:   dw 0
ret_code:  db 0
running:   dw 0
saved_sp:  dw 0

load_name: dw 0
load_seg:  dw 0
load_off:  dw 0

krsta: dw 0
krsc:  dw 0
kdsta: dw 0
kspc:  db 0
kclus: dw 0
kfsize: dw 0
klba:  dw 0
kcnt:  db 0
ksc:   db 0
khd:   db 0
kcy:   db 0
kdrv:  db 0
kret:  db 3

exe_hdr_par:    dw 0
exe_ss:         dw 0
exe_sp:         dw 0
exe_ip:         dw 0
exe_cs:         dw 0
exe_reloc_count: dw 0
exe_reloc_off:  dw 0
exe_load_seg:   dw 0

dta_seg: dw 0
dta_off: dw 0

rf_count:      dw 0
rf_read:       dw 0
rf_hoff:       dw 0
rf_buf_off:    dw 0
rf_buf_seg:    dw 0

sf_origin: db 0

find_di: dw 0

name_buf: times 11 db 0

handles: times MAX_HANDLES * HANDLE_SIZE db 0
