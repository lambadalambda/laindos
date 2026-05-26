[bits 16]
[org 0x7C00]

%include "src/memory.inc"
FAT_SEG  equ 0x0060
ROOT_SEG equ 0x0920

bpb:
    jmp short boot
    nop
    times 8 db 0
    dw 512
    db 8
    dw 1
    db 2
    dw 512
    dw 65520
    db 0xF8
    dw 32
    dw 63
    dw 16
    dd 0
    dd 0
    db 0x80
    db 0
    db 0x29
    dd 0x12345678
    times 11 db 0
    db "FAT16   "

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
ld: cmp si,0xFFF8
    jae ldk
    cmp si,2
    jb nf
    push si
    mov ax,si
    sub ax,2
    movzx cx,byte[bpb+13]
    mul cx
    add ax,[dsta]
    movzx cx,byte[bpb+13]
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
    push cx
    push dx
    push es
    mov ax,si
    mov bx,ax
    mov cl,8
    shr ax,cl
    add ax,[bpb+14]
    and bx,0x00FF
    shl bx,1
    push bx
    mov bx,0
    mov cx,1
    push ax
    mov ax,FAT_SEG
    mov es,ax
    pop ax
    call rs
    pop bx
    jc f16e
    push ds
    mov ax,FAT_SEG
    mov ds,ax
    mov ax,[bx]
    pop ds
    jmp f16r
f16e:
    mov ax,0xFFFF
f16r:
    pop es
    pop dx
    pop cx
    pop bx
    ret

rs: mov [lb],ax
    mov [cnt],cx
r1: mov ax,[lb]
    xor dx,dx
    add ax,[bpb+28]
    adc dx,[bpb+30]
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
cy:  dw 0
ret_:db 3

times 510-($-$$) db 0
dw 0xAA55
