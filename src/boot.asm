[bits 16]
[org 0x7C00]

%include "src/memory.inc"
%include "src/fat_bpb.inc"
FAT_SEG  equ 0x0060
ROOT_SEG equ 0x0A20

%ifndef FAT12
%define FAT12 0
%endif
%ifndef FAT16
%define FAT16 0
%endif
%if FAT12 + FAT16 != 1
%error "Build must pass -DFAT12=1 or -DFAT16=1"
%endif

%if FAT12
%define FAT_EOC         FAT12_EOC
%define FAT_RESERVED    FAT12_RESERVED
%define FS_TYPE_STR     "FAT12   "
%define DRIVE_NUM       0
%define MEDIA_BYTE      0xF0
%define NUM_HEADS_VAL   2
%define ROOT_ENTRIES_V  224
%define SECS_PER_CLUS_V 1
%define SECS_PER_FAT_V  9
%define SECS_PER_TRK_V  18
%define TOT_SECS_16_V   2880
%else
%define FAT_EOC         FAT16_EOC
%define FAT_RESERVED    FAT16_RESERVED
%define FS_TYPE_STR     "FAT16   "
%define DRIVE_NUM       0x80
%define MEDIA_BYTE      0xF8
%define NUM_HEADS_VAL   16
%define ROOT_ENTRIES_V  512
%define SECS_PER_CLUS_V 8
%define SECS_PER_FAT_V  32
%define SECS_PER_TRK_V  63
%define TOT_SECS_16_V   65520
%endif

bpb:
    jmp short boot
    nop
    db "MSDOS5.0"
    dw 512
    db SECS_PER_CLUS_V
    dw 1
    db 2
    dw ROOT_ENTRIES_V
    dw TOT_SECS_16_V
    db MEDIA_BYTE
    dw SECS_PER_FAT_V
    dw SECS_PER_TRK_V
    dw NUM_HEADS_VAL
    dd 0
    dd 0
    db DRIVE_NUM
    db 0
    db 0x29
    dd 0x12345678
    db "NO NAME    "
    db FS_TYPE_STR

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
%if FAT12
    mov bx,[bpb+BPB_TOT_SECS_16]
    sub bx,ax
    mov ax,bx
%else
    mov ax,[bpb+BPB_TOT_SECS_16]
    xor dx,dx
    test ax,ax
    jnz mtc
    mov ax,[bpb+BPB_TOT_SECS_32]
    mov dx,[bpb+BPB_TOT_SECS_32+2]
mtc:sub ax,[dsta]
    sbb dx,0
%endif
    movzx bx,byte[bpb+BPB_SECS_PER_CLUS]
    div bx
    add ax,2
    mov [mcl],ax

%if FAT12
    mov ax,FAT_SEG
    mov es,ax
    xor bx,bx
    mov ax,[bpb+BPB_RSV_SEC_COUNT]
    mov cx,[bpb+BPB_SECS_PER_FAT]
    call rs
    jc nf
%endif

    mov ax,ROOT_SEG
    mov es,ax
    xor bx,bx
    mov ax,[rsta]
    mov cx,[rsc]
    call rs
    jc nf

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
ld: cmp si,FAT_EOC
    jae ldk
    cmp si,2
    jb nf
    cmp si,FAT_RESERVED
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
    dw HMA_OFF
    dw ENTRY_SEG

%if FAT12
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
fe: and ax,FAT12_MASK
fr: pop bx
    ret
%else
fat_next:
    push bx
    push es
    mov ax,si
    mov bx,ax
    shr ax,8
    add ax,[bpb+BPB_RSV_SEC_COUNT]
    xor bh,bh
    shl bx,1
    push bx
    xor bx,bx
    mov cx,1
    push word FAT_SEG
    pop es
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
%endif

rs: mov [lb],ax
    mov [cnt],cx
r1: mov ax,[lb]
    xor dx,dx
%if !FAT12
    add ax,[bpb+BPB_HIDDEN_SECS]
    adc dx,[bpb+BPB_HIDDEN_SECS+2]
%endif
    div word[bpb+BPB_SECS_PER_TRK]
    inc dl
    mov [sc],dl
    xor dx,dx
    div word[bpb+BPB_NUM_HEADS]
    mov [hd],dl
%if !FAT12
    mov [cy],ax
    mov ch,al
    mov cl,ah
    shl cl,6
    or cl,[sc]
%else
    mov [cy],al
    mov ch,[cy]
    mov cl,[sc]
%endif
    mov ax,0x0201
    mov dh,[hd]
    mov dl,[drv]
    int 0x13
    jc rerr
    mov byte[ret_],3
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
%if FAT12
cy:  db 0
%else
cy:  dw 0
%endif
ret_:db 3

times 510-($-$$) db 0
dw 0xAA55
