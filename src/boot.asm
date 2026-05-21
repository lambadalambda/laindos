[bits 16]
[org 0x7C00]

LOAD_SEG equ 0x0800
FAT_SEG  equ 0x1000
ROOT_SEG equ 0x2000

bpb:
    jmp short boot
    nop
    times 8 db 0       ; +03 OEM name
    dw 512             ; +0B bytes/sector
    db 1               ; +0D sec/cluster
    dw 1               ; +0E reserved sectors
    db 2               ; +10 num FATs
    dw 224             ; +11 root entries
    dw 2880            ; +13 total sectors
    db 0xF0            ; +15 media
    dw 9               ; +16 sec/FAT
    dw 18              ; +18 sec/track
    dw 2               ; +1A heads
    dd 0               ; +1C hidden
    dd 0               ; +20 total sectors 32
    db 0               ; +24 drive
    db 0               ; +25 reserved
    db 0x29            ; +26 boot sig
    dd 0x12345678      ; +27 vol id
    times 11 db 0      ; +2B vol label
    times 8 db 0       ; +36 fs type

boot:
    cli
    xor ax,ax
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,0x7C00
    sti
    cld
    mov [drv],dl
    mov [0x500],dl

    mov dx,0x3F9
    xor al,al
    out dx,al
    mov dx,0x3FB
    mov al,0x80
    out dx,al
    mov dx,0x3F8
    mov al,1
    out dx,al
    mov dx,0x3F9
    xor al,al
    out dx,al
    mov dx,0x3FB
    mov al,3
    out dx,al
    mov dx,0x3FA
    mov al,0xC7
    out dx,al
    mov dx,0x3FC
    mov al,0x0B
    out dx,al

    mov ax,[bpb+22]
    movzx cx,byte[bpb+16]
    mul cx
    add ax,[bpb+14]
    mov [rsta],ax
    mov ax,[bpb+17]
    mov bx,32
    mul bx
    add ax,511
    mov bx,512
    div bx
    mov [rsc],ax
    add ax,[rsta]
    mov [dsta],ax

    mov ax,FAT_SEG
    mov es,ax
    xor bx,bx
    mov ax,[bpb+14]
    mov cx,[bpb+22]
    call rs

    mov ax,ROOT_SEG
    mov es,ax
    xor bx,bx
    mov ax,[rsta]
    mov cx,[rsc]
    call rs

    mov ax,ROOT_SEG
    mov es,ax
    xor di,di
    mov cx,[bpb+17]
sf: cmp byte[es:di],0
    je nf
    push cx
    push di
    mov si,kn
    mov cx,11
    repe cmpsb
    pop di
    pop cx
    je fk
    add di,32
    loop sf
nf: mov si,em
    call sprint
    cli
    hlt
fk: mov ax,[es:di+26]
    mov [kcl],ax

    mov ax,LOAD_SEG
    mov es,ax
    xor bx,bx
    mov si,[kcl]
ld: cmp si,0xFF8
    jae ldk
    cmp si,2
    jb nf
    push si
    mov ax,si
    sub ax,2
    movzx cx,byte[bpb+13]
    mul cx
    add ax,[dsta]
    mov cx,1
    call rs
    pop si
    jc nf
    call fat_next
    mov si,ax
    jmp ld
ldk:
    mov dl,[drv]
    jmp far LOAD_SEG:0

fat_next:
    push bx
    mov bx,si
    shr bx,1
    add bx,si
    push ds
    mov ax,FAT_SEG
    mov ds,ax
    mov ax,[bx]
    pop ds
    test si,1
    jz fe
    shr ax,4
    jmp fr
fe: and ax,0x0FFF
fr: pop bx
    ret

rs: mov [lb],ax
    mov [cnt],cx
r1: mov ax,[lb]
    xor dx,dx
    div word[bpb+24]
    inc dl
    mov [sc],dl
    xor dx,dx
    div word[bpb+26]
    mov [hd],dl
    mov [cy],al
    mov ah,2
    mov al,1
    mov ch,[cy]
    mov cl,[sc]
    mov dh,[hd]
    mov dl,[drv]
    int 0x13
    jc rerr
    add bx,512
    jnc rnb
    mov ax,es
    add ax,0x1000
    mov es,ax
rnb:inc word [lb]
    dec word [cnt]
    jnz r1
    clc
    ret
rerr:
    xor ax,ax
    mov dl,[drv]
    int 0x13
    dec byte[ret_]
    jnz r1
    stc
    ret

sprint:
    lodsb
    test al,al
    jz spr
    mov ah,al
    mov dx,0x3FD
s2: in al,dx
    test al,0x20
    jz s2
    mov al,ah
    mov dx,0x3F8
    out dx,al
    jmp sprint
spr:ret

kn:     db "KERNEL  SYS"
em:     db "NoK",0

drv: db 0
rsta:dw 0
rsc: dw 0
dsta:dw 0
kcl: dw 0
lb:  dw 0
cnt: dw 0
sc:  db 0
hd:  db 0
cy:  db 0
ret_:db 3

times 510-($-$$) db 0
dw 0xAA55
