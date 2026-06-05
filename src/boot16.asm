[bits 16]
[org 0x7C00]

%include "src/memory.inc"
%include "src/fat_bpb.inc"
FAT_SEG  equ 0x0060
ROOT_SEG equ 0x0A20

bpb:
    jmp short boot
    nop
    db "MSDOS5.0"
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
    db "NO NAME    "
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

    mov ax,[bpb+BPB_SECS_PER_FAT]
    movzx cx,byte[bpb+BPB_NUM_FATS]
    mul cx
    add ax,[bpb+BPB_RSV_SEC_COUNT]
    mov [rsta],ax
    mov ax,[bpb+BPB_ROOT_ENT_COUNT]
    shr ax,4
    mov [rsc],ax
    add ax,[rsta]
    mov [dsta],ax
    mov ax,[bpb+BPB_TOT_SECS_16]
    xor dx,dx
    test ax,ax
    jnz mtc
    mov ax,[bpb+BPB_TOT_SECS_32]
    mov dx,[bpb+BPB_TOT_SECS_32+2]
mtc:sub ax,[dsta]
    sbb dx,0
    movzx bx,byte[bpb+BPB_SECS_PER_CLUS]
    div bx
    add ax,2
    mov [mcl],ax

    mov ax,ROOT_SEG
    mov es,ax
    xor bx,bx
    mov ax,[rsta]
    mov cx,[rsc]
    call rs

    mov ax,ROOT_SEG
    mov es,ax
    xor di,di
    mov cx,[bpb+BPB_ROOT_ENT_COUNT]
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
fk: mov si,[es:di+26]

    mov ax,LOAD_SEG
    mov es,ax
    xor bx,bx
ld: cmp si,FAT16_EOC
    jae ldk
    cmp si,2
    jb nf
    cmp si,FAT16_RESERVED
    jae nf
    cmp si,[mcl]
    jae nf
    push si
    mov ax,si
    sub ax,2
    movzx cx,byte[bpb+BPB_SECS_PER_CLUS]
    mul cx
    add ax,[dsta]
    movzx cx,byte[bpb+BPB_SECS_PER_CLUS]
    call rs
    pop si
    jc nf
    call fat_next
    mov si,ax
    jmp ld
ldk:
    mov dl,[drv]
    db 0xEA
    dw 0
    dw LOAD_SEG

fat_next:
    push bx
    push es
    mov ax,si
    mov bx,ax
    mov cl,8
    shr ax,cl
    add ax,[bpb+BPB_RSV_SEC_COUNT]
    xor bh,bh
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
    mov ax,FAT16_EOC_VALUE
f16r:
    pop es
    pop bx
    ret

rs: mov [lb],ax
    mov [cnt],cx
r1: mov ax,[lb]
    xor dx,dx
    add ax,[bpb+BPB_HIDDEN_SECS]
    adc dx,[bpb+BPB_HIDDEN_SECS+2]
    div word[bpb+BPB_SECS_PER_TRK]
    inc dl
    mov [sc],dl
    xor dx,dx
    div word[bpb+BPB_NUM_HEADS]
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
mcl: dw 0
lb:  dw 0
cnt: dw 0
sc:  db 0
hd:  db 0
cy:  dw 0
ret_:db 3

times 510-($-$$) db 0
dw 0xAA55
