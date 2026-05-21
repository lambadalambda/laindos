[bits 16]
[org 0x0000]

COM1_PORT equ 0x3F8

BPB_SEG   equ 0x0000
BPB_OFF   equ 0x7C00
FAT_SEG   equ 0x1000
ROOT_SEG  equ 0x2000
PSP_SEG   equ 0x3000
TEMP_SEG  equ 0x4000

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
    iret
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
    iret

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
fname_exe:   db "HELLO   EXE"

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
