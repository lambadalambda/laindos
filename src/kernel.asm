[bits 16]
[org 0x0000]

COM1_PORT equ 0x3F8
VGA_TEXT_SEG equ 0xB800
VGA_COLS equ 80
VGA_ROWS equ 25
%include "src/memory.inc"

BPB_SEG   equ 0x0000
BPB_OFF   equ 0x7C00
FAT_SEG   equ 0x0060
ROOT_SEG  equ 0x0A00
PSP_SEG   equ 0x3000
TEMP_SEG  equ 0x4000

HANDLE_SIZE equ 32
H_USED      equ 0
H_MODE      equ 1
H_CLUSTER   equ 2
H_POS_LO    equ 4
H_POS_HI    equ 6
H_SIZE_LO   equ 8
H_SIZE_HI   equ 10
H_LAST_CLUSTER equ 12
H_LAST_INDEX   equ 14
H_DIR_LBA   equ 16
H_DIR_OFF   equ 18
H_TIME      equ 20
H_DATE      equ 22
H_OWNER     equ 24
H_DIR_LBA_HI equ 26
H_REFCOUNT  equ 28
H_ALIAS     equ 30
H_ALIAS_NONE equ 0xFFFF
MAX_HANDLES equ 20
SMALL_ALLOC_HIGH_MAX equ 0x0020
COM_EXTRA_PAR equ 0x0110
KERNEL_STACK_TOP equ 0xBC00
%ifndef XMS_MAX_KB
%define XMS_MAX_KB 15360
%endif
EMS_TOTAL_PAGES equ 64
%ifndef EMS_FRAME_SEG
%define EMS_FRAME_SEG 0x9000
%endif
EMS_FRAME_PARAS equ 0x1000
EMS_FRAME_PHYS_LO equ ((EMS_FRAME_SEG << 4) & 0xFFFF)
EMS_FRAME_PHYS_HI equ ((EMS_FRAME_SEG << 4) >> 16)
EMS_BACKING_HI equ 0x0020

ATTR_RDONLY equ 0x01
ATTR_HIDDEN equ 0x02
ATTR_SYSTEM equ 0x04
ATTR_VOLUME equ 0x08
ATTR_DIR equ 0x10
ROOT_ENT_CNT equ 224
ROOT_MAX_ENTRIES equ 512
ROOT_BUF_PARAS equ ((ROOT_MAX_ENTRIES * 32) + 15) / 16

CF equ 0x0001
ZF equ 0x0040

ROOT_CLUSTER equ 0
FAT_TIME equ 0x6000
FAT_DATE equ 0x5CB6
DEV_CON equ 1
DEV_NUL equ 2
DEV_AUX equ 3
DEV_PRN equ 4
DEV_EMM equ 5

%ifndef TRACE_DOS
%define TRACE_DOS 0
%endif

%ifndef TRACE_EXEC_STATE
%define TRACE_EXEC_STATE 0
%endif

%ifndef ENABLE_XMS
%define ENABLE_XMS 1
%endif

%ifndef ENABLE_EMS
%define ENABLE_EMS 0
%endif

kernel_entry:
    mov ax, cs
    cmp ax, RELOC_SEG
    je .relocated
    cli
    push ax
    xor ax, ax
    mov ds, ax
    pop ax
    mov es, ax
    mov si, BPB_OFF
    mov di, bpb_copy
    mov cx, 64
    cld
    rep movsb
    mov ds, ax
    mov ax, RELOC_SEG
    mov es, ax
    xor si, si
    xor di, di
    mov cx, kernel_end
    cld
    rep movsb
    jmp RELOC_SEG:.relocated
.relocated:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, KERNEL_STACK_TOP
    sti
    cld
    fninit

    call serial_init
    call vga_clear

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

%if ENABLE_XMS
    call init_xms_size
%endif

    call init_interrupts

    mov si, msg_ints
    call serial_print

    mov word [trace_left], TRACE_DOS
    call mouse_init_ps2

    mov word [cur_dir_cluster], ROOT_CLUSTER
    mov byte [cur_dir_path], 0

    call init_environment

    mov ax, MCB_START
    mov es, ax
    mov byte [es:0], MCB_SIG_Z
    mov word [es:1], 0
    mov ax, MEM_TOP - MCB_START - 1
    mov word [es:3], ax
    mov word [mcb_first], MCB_START
    mov word [cur_psp], 0

    call init_bpb_geometry

    mov si, fname_exe
    call resolve_path
    jnc .rp_ok
    push cs
    pop ds
    mov si, msg_nofile
    call serial_print
    jmp .halt
.rp_ok:
    mov ax, [es:di+26]
    mov [cs:kclus], ax
    mov ax, [es:di+28]
    mov [cs:kfsize], ax
    mov dx, [es:di+30]
    mov [cs:kfsize_hi], dx

    mov si, [cs:kclus]
    mov ax, si
    xor bx, bx
    call cluster_lba
    push es
    push bx
    mov bx, 0
    mov [cs:kio_lba_hi], dx
    mov dx, SEC_BUF
    mov es, dx
    mov cx, 1
    call read_sector
    pop bx
    pop es
    jc .halt

    mov dx, SEC_BUF
    mov ds, dx
    cmp word [0x0000], 0x5A4D
    je .peek_mz

    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 511
    adc dx, 0
    mov cx, 9
.shr9c:
    shr dx, 1
    rcr ax, 1
    loop .shr9c
    mov cx, 5
.shl5c:
    shl ax, 1
    rcl dx, 1
    loop .shl5c
    add ax, COM_EXTRA_PAR
    adc dx, 0
    test dx, dx
    jnz .halt
    mov [cs:prog_par], ax
    jmp .alloc_com

.peek_mz:
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 15
    adc dx, 0
    mov cx, 4
.shr4p:
    shr dx, 1
    rcr ax, 1
    loop .shr4p
    sub ax, [0x08]
    add ax, [0x0A]
    add ax, 0x10
    mov [cs:exe_min_par], ax
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 511
    adc dx, 0
    mov cx, 9
.shr9m:
    shr dx, 1
    rcr ax, 1
    loop .shr9m
    mov cx, 5
.shl5m:
    shl ax, 1
    rcl dx, 1
    loop .shl5m
    add ax, 0x12
    cmp ax, [cs:exe_min_par]
    jae .use_file
    mov ax, [cs:exe_min_par]
.use_file:
    mov [cs:prog_par], ax

    mov cx, [0x0C]
    test cx, cx
    jz .alloc
    cmp cx, 0xFFFF
    je .max_all
    mov ax, [cs:exe_min_par]
    sub ax, [0x0A]
    add ax, cx
    jc .max_all
    cmp ax, [cs:prog_par]
    jae .max_desired_ready
    mov ax, [cs:prog_par]
.max_desired_ready:
    call find_largest_free_block
    cmp bx, [cs:prog_par]
    jb .alloc
    cmp ax, bx
    jbe .max_use_desired
    mov ax, bx
.max_use_desired:
    mov [cs:prog_par], ax
    jmp .alloc
.max_all:
    call find_largest_free_block
    cmp bx, [cs:prog_par]
    jb .alloc
    mov [cs:prog_par], bx

.alloc:
    push cs
    pop ds
    mov bx, [cs:prog_par]
    call alloc_mem_direct
    jmp .alloc_done
.alloc_com:
    push cs
    pop ds
    mov bx, [cs:prog_par]
    call alloc_mem_direct_high
.alloc_done:
    jc .halt
    mov [cs:prog_seg], ax
    push ax
    dec ax
    mov es, ax
    pop ax
    mov [es:1], ax

    mov ax, [cs:prog_seg]
    add ax, 0x10
    mov es, ax
    xor bx, bx
    mov si, [cs:kclus]
    call load_file_direct
    cmp ax, 0
    jne .halt

    mov ax, [cs:prog_seg]
    add ax, 0x10
    mov ds, ax
    cmp word [0x0000], 0x5A4D
    je .is_exe

    push cs
    pop ds
    mov si, msg_com_load
    call serial_print

    mov ax, [cs:prog_seg]
    call build_psp

    push cs
    pop ds

    mov ax, [cs:prog_seg]
    call exec_com_dyn
    jmp .returned

.is_exe:
    push cs
    pop ds
    mov si, msg_exe_load
    call serial_print

    mov ax, [cs:prog_seg]
    call setup_exe_dyn
    jc .halt

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

iret_nc_zf:
    push bp
    mov bp, sp
    and word [bp+6], ~CF
    or word [bp+6], ZF
    pop bp
    iret

iret_nc_nz:
    push bp
    mov bp, sp
    and word [bp+6], ~(CF | ZF)
    pop bp
    iret

init_bpb_geometry:
    push ds
    push bx
    push cs
    pop ds
    mov bx, bpb_copy

    mov ax, [bx+0x1C]
    mov [cs:kpart_lba], ax
    mov ax, [bx+0x1E]
    mov [cs:kpart_lba_hi], ax

    mov byte [cs:kfat_bits], 12
    mov word [cs:kfat_eoc], 0x0FF8
    mov word [cs:kfat_eoc_value], 0x0FFF
    mov word [cs:kfat_reserved], 0x0FF0
    cmp byte [bx+0x3A], '6'
    jne .fat_type_done
    mov byte [cs:kfat_bits], 16
    mov word [cs:kfat_eoc], 0xFFF8
    mov word [cs:kfat_eoc_value], 0xFFFF
    mov word [cs:kfat_reserved], 0xFFF0
.fat_type_done:
    mov ax, [bx+22]
    mov [cs:kfat_secs], ax
    mov ax, [bx+14]
    mov [cs:kfat_start], ax
    mov al, [bx+16]
    mov [cs:knum_fats], al
    mov ax, [bx+22]
    movzx cx, byte [bx+16]
    mul cx
    add ax, [bx+14]
    mov [cs:krsta], ax
    mov ax, [bx+17]
    mov [cs:kroot_entries], ax
    push ax
    mov al, [bx+13]
    mov [cs:kspc], al
    mov ax, [bx+24]
    mov [cs:kbio_spt], ax
    mov ax, [bx+26]
    mov [cs:kbio_heads], ax
    pop ax
    mov bx, 32
    mul bx
    mov [cs:kroot_bytes], ax
    add ax, 511
    mov bx, 512
    div bx
    mov [cs:krsc], ax
    add ax, [cs:krsta]
    mov [cs:kdsta], ax

    mov bx, bpb_copy
    mov ax, [bx+19]
    xor dx, dx
    test ax, ax
    jnz .have_total
    mov ax, [bx+32]
    mov dx, [bx+34]
.have_total:
    sub ax, [cs:kdsta]
    sbb dx, 0
    xor ch, ch
    mov cl, [cs:kspc]
    div cx
    add ax, 2
    mov [cs:kmax_cluster], ax

    pop bx
    pop ds
    push ds
    xor ax, ax
    mov ds, ax
    mov al, [0x500]
    pop ds
    mov [cs:kdrv], al
    mov byte [cs:dos_drive_num], 0
    mov byte [cs:dos_drive_letter], 'A'
    mov byte [cs:dos_drive_count], 1
    cmp al, 0x80
    jb .drive_done
    call query_bios_disk_geometry
    mov byte [cs:dos_drive_num], 2
    mov byte [cs:dos_drive_letter], 'C'
    mov byte [cs:dos_drive_count], 3
.drive_done:
    ret

query_bios_disk_geometry:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    push cs
    pop es
    mov di, int13_scratch
    mov dl, [cs:kdrv]
    mov ah, 0x08
    int 0x13
    jc .done
    test ah, ah
    jnz .done
    mov al, cl
    and al, 0x3F
    jz .done
    cmp al, 63
    ja .done
    xor ah, ah
    mov [cs:kbio_spt], ax
    mov al, dh
    xor ah, ah
    inc ax
    mov [cs:kbio_heads], ax
.done:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

init_environment:
    push ax
    push cx
    push ds
    push es
    push si
    push di
    push cs
    pop ds
    mov ax, ENV_SEG
    mov es, ax
    xor di, di
    call write_environment_vars
    mov ax, 1
    stosw
    mov al, [cs:dos_drive_letter]
    stosb
    mov al, ':'
    stosb
    mov al, '\'
    stosb
    mov si, fname_exe
    mov cx, 8
.name_loop:
    lodsb
    cmp al, ' '
    je .name_next
    stosb
.name_next:
    loop .name_loop
    mov al, '.'
    stosb
    mov cx, 3
.ext_loop:
    lodsb
    cmp al, ' '
    je .ext_next
    stosb
.ext_next:
    loop .ext_loop
    xor ax, ax
    stosb
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop ax
    ret

write_environment_vars:
    push ax
    push ds
    push si
    push cs
    pop ds
    mov si, env_comspec_name
    call env_copy_part
    call env_copy_drive_root
    mov si, env_shell_name
    call env_copy_string
    mov si, env_path_name
    call env_copy_part
    call env_copy_drive_root
    mov al, ';'
    stosb
    call env_copy_drive_root
    mov si, env_bin_dir
    call env_copy_string
    mov si, env_prompt
    call env_copy_string
    xor al, al
    stosb
    pop si
    pop ds
    pop ax
    ret

env_copy_part:
    lodsb
    test al, al
    jz .done
    stosb
    jmp env_copy_part
.done:
    ret

env_copy_string:
    lodsb
    stosb
    test al, al
    jnz env_copy_string
    ret

env_copy_drive_root:
    mov al, [cs:dos_drive_letter]
    stosb
    mov al, ':'
    stosb
    mov al, '\'
    stosb
    ret

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
%if ENABLE_XMS
    mov [es:0x2F*4], word int2f_handler
    mov [es:0x2F*4+2], cs
%endif
    mov ax, kernel_entry
    mov [es:0x22*4], ax
    mov [es:0x22*4+2], cs
    mov [es:0x23*4], word int23_handler
    mov [es:0x23*4+2], cs
    mov [es:0x24*4], word int24_handler
    mov [es:0x24*4+2], cs
    mov [es:0x33*4], word int33_handler
    mov [es:0x33*4+2], cs
%if ENABLE_EMS
    mov [es:0x67*4], word int67_handler
    mov [es:0x67*4+2], cs
%else
    mov [es:0x67*4], word int67_absent_handler
    mov [es:0x67*4+2], cs
%endif
    mov [es:0x74*4], word irq12_handler
    mov [es:0x74*4+2], cs
    mov [es:0x01*4], word exc01_handler
    mov [es:0x01*4+2], cs
    mov [es:0x06*4], word exc06_handler
    mov [es:0x06*4+2], cs
    mov [es:0x0D*4], word exc0d_handler
    mov [es:0x0D*4+2], cs
    pop es
    pop ds
    popa
    ret

int20_handler:
    mov byte [cs:ret_code], 0
    jmp do_terminate

exc01_handler:
    push bp
    mov bp, sp
    and word [bp+6], ~0x0100
    pop bp
    iret
exc06_handler:
    push bp
    mov bp, sp
    push ax
    push ds
    push si
    mov ax, [bp+4]
    mov ds, ax
    mov si, [bp+2]
    cmp si, 2
    jb .real_invalid
    cmp byte [si], 0x0F
    je .real_invalid
    sub si, 2
    cmp word [si], 0x06CD
    jne .real_invalid
    pop si
    pop ds
    pop ax
    pop bp
    iret
.real_invalid:
    pop si
    pop ds
    pop ax
    pop bp
    mov al, 0x06
    jmp exc_noerr
exc0d_handler:
    add sp, 2
    mov al, 0x0D
exc_noerr:
    mov [cs:exc_vec], al
    push bp
    mov bp, sp
    pusha
    push ds
    push cs
    pop ds
    mov [log_ax], ax
    mov si, msg_exc
    call serial_print
    mov al, [cs:exc_vec]
    call serial_print_hex
    mov si, msg_at
    call serial_print
    mov ax, [bp+4]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [bp+2]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    mov si, msg_exc_bytes
    call serial_print
    mov ax, [bp+4]
    mov ds, ax
    mov si, [bp+2]
    mov cx, 16
.dump_bytes:
    lodsb
    call serial_print_hex
    mov al, ' '
    call serial_putchar
    loop .dump_bytes
    push cs
    pop ds
    mov si, msg_crlf
    call serial_print
    cli
.exc_halt:
    hlt
    jmp .exc_halt

%include "src/kernel/mouse.inc"

%include "src/kernel/int21.inc"

int23_handler:
    iret

int24_handler:
    mov al, 3
    iret

%if ENABLE_XMS
init_xms_size:
    push ax
    mov word [cs:xms_total_kb], 0
    mov ah, 0x88
    int 0x15
    jc .done
    test ax, ax
    jz .done
    cmp ax, XMS_MAX_KB
    jbe .store
    mov ax, XMS_MAX_KB
.store:
    mov [cs:xms_total_kb], ax
.done:
    pop ax
    ret
%endif

int2f_handler:
%if ENABLE_XMS
    cmp ax, 0x4300
    je .xms_installed
    cmp ax, 0x4310
    je .xms_entry
    xor al, al
    iret
.xms_installed:
    mov al, 0x80
    jmp iret_nc
.xms_entry:
    mov bx, xms_entry
    push cs
    pop es
    jmp iret_nc
%else
    xor al, al
    iret
%endif

%if ENABLE_XMS
xms_entry:
    cmp ah, 0x00
    je .version
    cmp ah, 0x08
    je .query
    cmp ah, 0x09
    je .alloc
    cmp ah, 0x0A
    je .free
    cmp ah, 0x0B
    je .move
    cmp ah, 0x0C
    je .lock
    cmp ah, 0x0D
    je .unlock
    cmp ah, 0x0E
    je .info
    xor ax, ax
    mov bl, 0x80
    retf
.version:
    mov ax, 0x0200
    xor bx, bx
    xor dx, dx
    retf
.query:
    mov ax, [cs:xms_total_kb]
    sub ax, [cs:xms_alloc_kb]
    mov dx, ax
    xor bl, bl
    retf
.alloc:
    cmp word [cs:xms_alloc_kb], 0
    jne .no_mem
    test dx, dx
    jz .no_mem
    cmp dx, [cs:xms_total_kb]
    ja .no_mem
    mov [cs:xms_alloc_kb], dx
    mov ax, 1
    mov dx, 1
    xor bl, bl
    retf
.no_mem:
    xor ax, ax
    mov bl, 0xA0
    retf
.free:
    cmp dx, 1
    jne .bad_handle
    cmp word [cs:xms_alloc_kb], 0
    je .bad_handle
    mov word [cs:xms_alloc_kb], 0
    mov ax, 1
    xor bl, bl
    retf
.move:
    push cx
    push dx
    push si
    push di
    push ds
    push es
    mov ax, [ds:si]
    mov [cs:xms_move_len], ax
    mov dx, [ds:si+2]
    test dx, dx
    jnz .move_bad_len
    test ax, 1
    jnz .move_bad_len
    test ax, ax
    jz .move_ok
    shr ax, 1
    mov [cs:xms_move_words], ax
    mov bx, [ds:si+4]
    mov ax, [ds:si+6]
    mov dx, [ds:si+8]
    call xms_endpoint_phys
    jc .move_bad_handle
    mov [cs:xms_src_phys], ax
    mov [cs:xms_src_phys+2], dx
    mov bx, [ds:si+10]
    mov ax, [ds:si+12]
    mov dx, [ds:si+14]
    call xms_endpoint_phys
    jc .move_bad_handle
    mov [cs:xms_dst_phys], ax
    mov [cs:xms_dst_phys+2], dx
    push cs
    pop ds
    mov ax, [cs:xms_move_len]
    dec ax
    mov di, xms_gdt + 0x10
    mov bx, [cs:xms_src_phys]
    mov dx, [cs:xms_src_phys+2]
    call xms_set_desc
    mov ax, [cs:xms_move_len]
    dec ax
    mov di, xms_gdt + 0x18
    mov bx, [cs:xms_dst_phys]
    mov dx, [cs:xms_dst_phys+2]
    call xms_set_desc
    mov ax, 0x8700
    mov cx, [cs:xms_move_words]
    mov si, xms_gdt
    push cs
    pop es
    int 0x15
    jc .move_failed
    test ah, ah
    jnz .move_failed
.move_ok:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    mov ax, 1
    xor bl, bl
    retf
.move_bad_len:
    mov bl, 0xA7
    jmp .move_err
.move_bad_handle:
    mov bl, 0xA3
    jmp .move_err
.move_failed:
    mov bl, 0xAB
.move_err:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    xor ax, ax
    retf
.info:
    cmp dx, 1
    jne .bad_handle
    cmp word [cs:xms_alloc_kb], 0
    je .bad_handle
    mov ax, 1
    xor bh, bh
    xor bl, bl
    mov dx, [cs:xms_alloc_kb]
    retf
.lock:
    cmp dx, 1
    jne .bad_handle
    cmp word [cs:xms_alloc_kb], 0
    je .bad_handle
    mov ax, 1
    xor bx, bx
    mov dx, 0x0010
    retf
.unlock:
    cmp dx, 1
    jne .bad_handle
    cmp word [cs:xms_alloc_kb], 0
    je .bad_handle
    mov ax, 1
    xor bl, bl
    retf
.bad_handle:
    xor ax, ax
    mov bl, 0xA2
    retf
%endif

%if ENABLE_XMS
xms_endpoint_phys:
    test bx, bx
    jz xms_real_ptr_to_phys
    cmp bx, 1
    jne .bad
    cmp word [cs:xms_alloc_kb], 0
    je .bad
    push ax
    push dx
    push cx
    push di
    mov cx, ax
    mov di, dx
    add cx, [cs:xms_move_len]
    adc di, 0
    mov ax, [cs:xms_alloc_kb]
    mov dx, 1024
    mul dx
    cmp di, dx
    ja .bad_pop
    jb .in_bounds
    cmp cx, ax
    ja .bad_pop
.in_bounds:
    pop di
    pop cx
    pop dx
    pop ax
    add dx, 0x0010
    clc
    ret
.bad_pop:
    pop di
    pop cx
    pop dx
    pop ax
.bad:
    stc
    ret

xms_real_ptr_to_phys:
    push bx
    push cx
    mov bx, dx
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shr dx, 12
    add ax, bx
    adc dx, 0
    pop cx
    pop bx
    clc
    ret
%endif

xms_set_desc:
    mov [di], ax
    mov [di+2], bx
    mov [di+4], dl
    mov byte [di+5], 0x93
    mov word [di+6], 0
    ret

%if !ENABLE_EMS
int67_absent_handler:
    mov ah, 0x80
    iret
%endif

%if ENABLE_EMS
int67_handler:
    cmp ah, 0x40
    je .ok
    cmp ah, 0x41
    je .frame
    cmp ah, 0x42
    je .pages
    cmp ah, 0x43
    je .alloc
    cmp ah, 0x44
    je .map
    cmp ah, 0x45
    je .free
    cmp ah, 0x46
    je .version
    cmp ah, 0x4B
    je .handles
    cmp ah, 0x4C
    je .info
    mov ah, 0x80
    iret
.ok:
    xor ah, ah
    iret
.frame:
    xor ah, ah
    mov bx, EMS_FRAME_SEG
    iret
.pages:
    mov bx, EMS_TOTAL_PAGES
    sub bx, [cs:ems_alloc_pages]
    mov dx, EMS_TOTAL_PAGES
    xor ah, ah
    iret
.alloc:
    cmp word [cs:ems_alloc_pages], 0
    jne .no_pages
    test bx, bx
    jz .no_pages
    cmp bx, EMS_TOTAL_PAGES
    ja .no_pages
    mov [cs:ems_alloc_pages], bx
    call ems_clear_map
    mov dx, 1
    xor ah, ah
    iret
.no_pages:
    mov ah, 0x88
    iret
.map:
    cmp dx, 1
    jne .bad_handle
    cmp word [cs:ems_alloc_pages], 0
    je .bad_handle
    cmp al, 3
    ja .bad_page
    cmp bx, [cs:ems_alloc_pages]
    jae .bad_page
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    mov [cs:ems_req_phys], al
    mov [cs:ems_req_logical], bx
    xor bh, bh
    mov bl, al
    shl bx, 1
    mov si, bx
    mov bx, [cs:si+ems_map_pages]
    cmp bx, 0xFFFF
    je .map_load_new
    call ems_logical_phys
    mov [cs:xms_dst_phys], ax
    mov [cs:xms_dst_phys+2], dx
    mov al, [cs:ems_req_phys]
    call ems_frame_phys
    mov [cs:xms_src_phys], ax
    mov [cs:xms_src_phys+2], dx
    call ems_copy_16k
    jc .map_io_error
.map_load_new:
    mov bx, [cs:ems_req_logical]
    call ems_logical_phys
    mov [cs:xms_src_phys], ax
    mov [cs:xms_src_phys+2], dx
    mov al, [cs:ems_req_phys]
    call ems_frame_phys
    mov [cs:xms_dst_phys], ax
    mov [cs:xms_dst_phys+2], dx
    call ems_copy_16k
    jc .map_io_error
    xor bh, bh
    mov bl, [cs:ems_req_phys]
    shl bx, 1
    mov si, bx
    mov bx, [cs:ems_req_logical]
    mov [cs:si+ems_map_pages], bx
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    xor ah, ah
    iret
.map_io_error:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    mov ah, 0x80
    iret
.bad_page:
    mov ah, 0x8A
    iret
.free:
    cmp dx, 1
    jne .bad_handle
    cmp word [cs:ems_alloc_pages], 0
    je .bad_handle
    mov word [cs:ems_alloc_pages], 0
    call ems_clear_map
    xor ah, ah
    iret
.version:
    xor ah, ah
    mov al, 0x40
    iret
.handles:
    xor ah, ah
    mov bx, 1
    iret
.info:
    cmp dx, 1
    jne .bad_handle
    cmp word [cs:ems_alloc_pages], 0
    je .bad_handle
    mov bx, [cs:ems_alloc_pages]
    xor ah, ah
    iret
.bad_handle:
    mov ah, 0x83
    iret

ems_clear_map:
    mov word [cs:ems_map_pages], 0xFFFF
    mov word [cs:ems_map_pages+2], 0xFFFF
    mov word [cs:ems_map_pages+4], 0xFFFF
    mov word [cs:ems_map_pages+6], 0xFFFF
    ret

ems_logical_phys:
    push cx
    mov ax, bx
    xor dx, dx
    mov cx, 14
.shift:
    shl ax, 1
    rcl dx, 1
    loop .shift
    add dx, EMS_BACKING_HI
    pop cx
    ret

ems_frame_phys:
    push cx
    xor ah, ah
    xor dx, dx
    mov cx, 14
.shift:
    shl ax, 1
    rcl dx, 1
    loop .shift
    add ax, EMS_FRAME_PHYS_LO
    adc dx, EMS_FRAME_PHYS_HI
    pop cx
    ret

ems_copy_16k:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    push cs
    pop ds
    mov ax, 0x3FFF
    mov di, xms_gdt + 0x10
    mov bx, [cs:xms_src_phys]
    mov dx, [cs:xms_src_phys+2]
    call xms_set_desc
    mov ax, 0x3FFF
    mov di, xms_gdt + 0x18
    mov bx, [cs:xms_dst_phys]
    mov dx, [cs:xms_dst_phys+2]
    call xms_set_desc
    mov ax, 0x8700
    mov cx, 0x2000
    mov si, xms_gdt
    push cs
    pop es
    int 0x15
    jc .fail
    test ah, ah
    jnz .fail
    clc
    jmp .done
.fail:
    stc
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
%endif

do_terminate:
    push ds
    push si
    push ax
    mov word [cs:mouse_callback_mask], 0
    mov word [cs:mouse_callback_off], 0
    mov word [cs:mouse_callback_seg], 0
    mov byte [cs:mouse_in_callback], 0
%if ENABLE_EMS
    mov word [cs:ems_alloc_pages], 0
    call ems_clear_map
%endif
    mov word [cs:xms_alloc_kb], 0
    call close_owned_handles
    mov byte [cs:console_ext_pending], 0
    mov si, [cs:mcb_first]
.dt_mcb_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .dt_mcb_check
    cmp byte [ds:0], MCB_SIG_Z
    je .dt_mcb_check
    jmp .dt_mcb_done
.dt_mcb_check:
    mov ax, [cs:cur_psp]
    cmp word [ds:1], ax
    jne .dt_mcb_next
    mov word [ds:1], 0
.dt_mcb_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .dt_mcb_done
    call mcb_walk_next
    jc .dt_mcb_done
    jmp .dt_mcb_walk
.dt_mcb_done:
    mov ax, [cs:cur_psp]
    test ax, ax
    jz .dt_parent_done
    mov ds, ax
    mov ax, [0x16]
    mov [cs:cur_psp], ax
.dt_parent_done:
    pop ax
    pop si
    pop ds
    mov word [cs:running], 0
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, [cs:saved_ss]
    cli
    mov ss, ax
    mov sp, [cs:saved_sp]
    sti
    jmp exec_com.back

close_owned_handles:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov ax, [cs:cur_psp]
    test ax, ax
    jz .done
    mov word [cs:coh_index], 0
.loop:
    mov ax, [cs:coh_index]
    cmp ax, MAX_HANDLES
    jae .done
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    cmp byte [cs:bx+handles+H_USED], 1
    jne .next
    mov ax, [cs:cur_psp]
    cmp [cs:bx+handles+H_OWNER], ax
    jne .next
    mov bx, [cs:coh_index]
    call close_table_handle
.next:
    inc word [cs:coh_index]
    jmp .loop
.done:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

%include "src/kernel/memory_mcb.inc"

%include "src/kernel/path_dir.inc"


%include "src/kernel/fat.inc"

%include "src/kernel/disk.inc"

%include "src/kernel/fs.inc"

%include "src/kernel/exec.inc"

%if TRACE_EXEC_STATE
trace_exec_state:
    pusha
    push ds
    push es
    mov ax, [cs:prog_seg]
    mov ds, ax
    mov ax, [0x02]
    mov [cs:trace_psp_top], ax
    mov ax, [0x16]
    mov [cs:trace_parent_psp], ax
    mov ax, [0x2C]
    mov [cs:trace_env_seg], ax
    mov ax, [0x80]
    mov [cs:trace_cmd_tail], ax
    mov ax, [cs:exe_load_seg]
    add ax, [cs:exe_cs]
    mov [cs:trace_entry_cs], ax
    mov ax, [cs:exe_load_seg]
    add ax, [cs:exe_ss]
    mov [cs:trace_entry_ss], ax
    push cs
    pop ds
    mov si, msg_xstate
    call serial_print
    mov si, msg_x_psp
    call serial_print
    mov ax, [cs:prog_seg]
    call serial_print_hex_word
    mov si, msg_x_top
    call serial_print
    mov ax, [cs:trace_psp_top]
    call serial_print_hex_word
    mov si, msg_x_parent
    call serial_print
    mov ax, [cs:trace_parent_psp]
    call serial_print_hex_word
    mov si, msg_x_env
    call serial_print
    mov ax, [cs:trace_env_seg]
    call serial_print_hex_word
    mov si, msg_x_cmd
    call serial_print
    mov ax, [cs:trace_cmd_tail]
    call serial_print_hex_word
    mov si, msg_x_entry
    call serial_print
    mov ax, [cs:trace_entry_cs]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:exe_ip]
    call serial_print_hex_word
    mov si, msg_x_sssp
    call serial_print
    mov ax, [cs:trace_entry_ss]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:exe_sp]
    call serial_print_hex_word
    mov si, msg_x_dta
    call serial_print
    mov ax, [cs:dta_seg]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:dta_off]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    call trace_exec_env
    call trace_exec_bda
    call trace_exec_ivt
    call trace_exec_mcb
    pop es
    pop ds
    popa
    ret

trace_exec_env:
    push ax
    push cx
    push ds
    push si
    mov ax, ENV_SEG
    dec ax
    mov ds, ax
    mov al, [0]
    mov [cs:trace_sig], al
    mov ax, [1]
    mov [cs:trace_owner], ax
    mov ax, [3]
    mov [cs:trace_size], ax
    push cs
    pop ds
    mov si, msg_xenv
    call serial_print
    mov ax, ENV_SEG - 1
    call serial_print_hex_word
    mov si, msg_x_sig
    call serial_print
    mov al, [cs:trace_sig]
    call serial_print_hex
    mov si, msg_x_owner
    call serial_print
    mov ax, [cs:trace_owner]
    call serial_print_hex_word
    mov si, msg_x_size
    call serial_print
    mov ax, [cs:trace_size]
    call serial_print_hex_word
    mov si, msg_x_bytes
    call serial_print
    mov ax, ENV_SEG
    mov ds, ax
    xor si, si
    mov cx, 8
.bytes:
    lodsb
    call serial_print_hex
    mov al, ' '
    call serial_putchar
    loop .bytes
    push cs
    pop ds
    mov si, msg_crlf
    call serial_print
    pop si
    pop ds
    pop cx
    pop ax
    ret

trace_exec_bda:
    push ax
    push bx
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov ax, [0x0010]
    mov [cs:trace_bda_equip], ax
    xor ax, ax
    mov al, [0x0049]
    mov [cs:trace_bda_mode], ax
    xor ax, ax
    mov al, [0x0017]
    mov [cs:trace_bda_keyflags], ax
    mov ax, [0x001A]
    mov [cs:trace_bda_keyhead], ax
    mov ax, [0x001C]
    mov [cs:trace_bda_keytail], ax
    mov ax, [0x006C]
    mov [cs:trace_bda_tick_lo], ax
    mov ax, [0x006E]
    mov [cs:trace_bda_tick_hi], ax
    in al, 0x21
    xor ah, ah
    mov [cs:trace_pic1], ax
    in al, 0xA1
    xor ah, ah
    mov [cs:trace_pic2], ax
    push cs
    pop ds
    mov si, msg_xbda
    call serial_print
    mov si, msg_x_eq
    call serial_print
    mov ax, [cs:trace_bda_equip]
    call serial_print_hex_word
    mov si, msg_x_mode
    call serial_print
    mov ax, [cs:trace_bda_mode]
    call serial_print_hex_word
    mov si, msg_x_key
    call serial_print
    mov ax, [cs:trace_bda_keyflags]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:trace_bda_keyhead]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:trace_bda_keytail]
    call serial_print_hex_word
    mov si, msg_x_tick
    call serial_print
    mov ax, [cs:trace_bda_tick_hi]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:trace_bda_tick_lo]
    call serial_print_hex_word
    mov si, msg_x_pic
    call serial_print
    mov ax, [cs:trace_pic1]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:trace_pic2]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    pop bx
    pop ax
    ret

trace_exec_ivt:
    push ax
    push bx
    push ds
    push si
    push cs
    pop ds
    mov si, msg_xivt
    call serial_print
    mov al, 0x06
    call trace_print_vector
    mov al, 0x08
    call trace_print_vector
    mov al, 0x09
    call trace_print_vector
    mov al, 0x10
    call trace_print_vector
    mov al, 0x16
    call trace_print_vector
    mov al, 0x1A
    call trace_print_vector
    mov al, 0x1C
    call trace_print_vector
    mov al, 0x22
    call trace_print_vector
    mov al, 0x23
    call trace_print_vector
    mov al, 0x24
    call trace_print_vector
    mov si, msg_crlf
    call serial_print
    pop si
    pop ds
    pop bx
    pop ax
    ret

trace_print_vector:
    push ax
    push bx
    push ds
    mov [cs:trace_vec_num], al
    mov bl, al
    xor bh, bh
    shl bx, 1
    shl bx, 1
    xor ax, ax
    mov ds, ax
    mov ax, [bx]
    mov [cs:trace_vec_off], ax
    mov ax, [bx+2]
    mov [cs:trace_vec_seg], ax
    push cs
    pop ds
    mov al, ' '
    call serial_putchar
    mov al, [cs:trace_vec_num]
    call serial_print_hex
    mov al, '='
    call serial_putchar
    mov ax, [cs:trace_vec_seg]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:trace_vec_off]
    call serial_print_hex_word
    pop ds
    pop bx
    pop ax
    ret

trace_exec_mcb:
    push ax
    push cx
    push ds
    push si
    mov word [cs:trace_mcb_seg], MCB_START
    mov cx, 6
.loop:
    mov ax, [cs:trace_mcb_seg]
    mov ds, ax
    mov al, [0]
    mov [cs:trace_sig], al
    mov ax, [1]
    mov [cs:trace_owner], ax
    mov ax, [3]
    mov [cs:trace_size], ax
    push cs
    pop ds
    mov si, msg_xmcb
    call serial_print
    mov ax, [cs:trace_mcb_seg]
    call serial_print_hex_word
    mov si, msg_x_sig
    call serial_print
    mov al, [cs:trace_sig]
    call serial_print_hex
    mov si, msg_x_owner
    call serial_print
    mov ax, [cs:trace_owner]
    call serial_print_hex_word
    mov si, msg_x_size
    call serial_print
    mov ax, [cs:trace_size]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    mov al, [cs:trace_sig]
    cmp al, MCB_SIG_Z
    je .done
    cmp al, MCB_SIG_M
    jne .done
    mov ax, [cs:trace_mcb_seg]
    inc ax
    add ax, [cs:trace_size]
    mov [cs:trace_mcb_seg], ax
    loop .loop
.done:
    pop si
    pop ds
    pop cx
    pop ax
    ret
%endif

%include "src/kernel/console.inc"

msg_booted:   db "MiniDOS booted", 13, 10, 0
msg_mem:      db "Conventional memory: ", 0
msg_kib:      db " KB", 13, 10, 0
msg_ints:     db "INT 20h/21h installed", 13, 10, 0
msg_nofile:   db "File not found", 13, 10, 0
msg_com_load: db "COM loaded", 13, 10, 0
msg_exe_load: db "EXE loaded", 13, 10, 0
msg_returned: db "Program exited, code=", 0
msg_crlf:     db 13, 10, 0
msg_halt:     db "HALT", 13, 10, 0
env_comspec_name: db "COMSPEC=", 0
env_path_name: db "PATH=", 0
env_shell_name: db "SHELL.COM", 0
env_bin_dir: db "BIN", 0
env_prompt: db "PROMPT=$P$G", 0
msg_unhandled: db "INT 21h AH=", 0
msg_int33:     db "INT 33h AX=", 0
msg_mouse_ps2_on: db "PS2 mouse enabled", 13, 10, 0
msg_mouse_ps2_off: db "PS2 mouse unavailable", 13, 10, 0
msg_colon:     db ":", 0
msg_exc:       db "EXC ", 0
msg_at:        db " at ", 0
msg_exc_bytes: db "BYTES ", 0
msg_trace_open: db "OPEN ", 0
msg_trace_handle: db " -> H=", 0
msg_trace_ioctl: db "IOCTL AL=", 0
msg_trace_size: db " SIZE=", 0
msg_trace_sig: db " SIG=", 0
msg_trace_read: db "READ H=", 0
msg_trace_close: db "CLOSE H=", 0
msg_trace_seek: db "SEEK H=", 0
msg_trace_org: db " ORG=", 0
msg_trace_off: db " OFF=", 0
msg_trace_req: db " REQ=", 0
msg_trace_pos: db " POS=", 0
msg_trace_buf: db " BUF=", 0
msg_trace_ret: db " -> ", 0
msg_trace_fail: db " FAIL", 13, 10, 0
msg_trace_alloc: db "ALLOC ", 0
msg_trace_strategy: db " STRAT=", 0
msg_trace_strategy_call: db "STRATEGY AX=", 0
msg_trace_resize: db "RESIZE ", 0
msg_trace_stdin: db "STDIN ", 0
msg_trace_setvec: db "SETVEC ", 0
msg_trace_getvec: db "GETVEC ", 0
msg_trace_eq: db " = ", 0
msg_int33_ret: db "INT33 RET AX=", 0
msg_reg_ax:    db " AX=", 0
msg_reg_bx:    db " BX=", 0
msg_reg_cx:    db " CX=", 0
msg_reg_dx:    db " DX=", 0
country_data:
    dw 0
    db '$', 0, 0, 0, 0
    db ',', 0
    db '.', 0
    db '/', 0
    db ':', 0
    db 0
    db 2
    db 0
    dd 0
    db ',', 0
    times 10 db 0
%if TRACE_EXEC_STATE
msg_xstate: db "XSTATE", 0
msg_x_psp: db " PSP=", 0
msg_x_top: db " TOP=", 0
msg_x_parent: db " PARENT=", 0
msg_x_env: db " ENV=", 0
msg_x_cmd: db " CMD=", 0
msg_x_entry: db " ENTRY=", 0
msg_x_sssp: db " SSSP=", 0
msg_x_dta: db " DTA=", 0
msg_xenv: db "XENV ", 0
msg_xbda: db "XBDA", 0
msg_xivt: db "XIVT", 0
msg_xmcb: db "XMCB ", 0
msg_x_sig: db " SIG=", 0
msg_x_owner: db " OWNER=", 0
msg_x_size: db " SIZE=", 0
msg_x_bytes: db " BYTES=", 0
msg_x_eq: db " EQ=", 0
msg_x_mode: db " MODE=", 0
msg_x_key: db " KEY=", 0
msg_x_tick: db " TICK=", 0
msg_x_pic: db " PIC=", 0
%endif

fname_hello:  db "HELLO   COM", 0
%ifndef BOOT_FILE
%define BOOT_FILE "MEMTEST EXE"
%endif
fname_exe:   db BOOT_FILE, 0

mem_kib:   dw 0
ret_code:  db 0
running:   dw 0
saved_ss:  dw 0
saved_sp:  dw 0
com_stack_top: dw 0
vga_row:   dw 0
vga_col:   dw 0
console_ext_pending: db 0

load_name: dw 0
load_seg:  dw 0
load_off:  dw 0

krsta: dw 0
krsc:  dw 0
kdsta: dw 0
kspc:  db 0
kbio_spt: dw 0
kbio_heads: dw 0
kfat_start: dw 0
kfat_secs: dw 0
knum_fats: db 0
kfat_bits: db 12
kfat_eoc: dw 0x0FF8
kfat_eoc_value: dw 0x0FFF
kfat_reserved: dw 0x0FF0
kroot_entries: dw 224
kroot_bytes: dw 224 * 32
kmax_cluster: dw 0
kclus: dw 0
kfsize: dw 0
kpart_lba: dw 0
kpart_lba_hi: dw 0
klba:  dw 0
klba_hi: dw 0
kio_lba_hi: dw 0
kcnt:  db 0
ksc:   db 0
khd:   db 0
kcy:   dw 0
kdrv:  db 0
int13_scratch: times 32 db 0
dos_drive_num: db 0
dos_drive_letter: db 'A'
dos_drive_count: db 1
break_flag: db 0
verify_flag: db 0
kret:  db 3
dos_first_mcb: dw MCB_START
dos_list_of_lists: times 32 db 0

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
date_year: dw 2026
date_month: db 5
date_day: db 21
date_weekday: db 0
time_set: db 0
time_hour: db 0
time_min: db 0
time_sec: db 0
time_hund: db 0

rf_count:      dw 0
rf_read:       dw 0
rf_hoff:       dw 0
rf_handle:     dw 0
rf_req:        dw 0
rf_start_lo:   dw 0
rf_start_hi:   dw 0
rf_start_buf_off: dw 0
rf_start_buf_seg: dw 0
rf_sec_in_cluster: dw 0
rf_cluster_index: dw 0
rf_cache_lba:  dw 0
rf_cache_lba_hi: dw 0
rf_cache_valid: db 0
rf_buf_off:    dw 0
rf_buf_seg:    dw 0
wf_count:      dw 0
wf_req:        dw 0
wf_written:    dw 0
wf_buf_off:    dw 0
wf_buf_seg:    dw 0
wf_hoff:       dw 0
wf_cluster_index: dw 0
wf_sec_in_cluster: dw 0
wf_sector_lba: dw 0
wf_sector_lba_hi: dw 0
wf_cluster:    dw 0
wf_status:     dw 0
wf_target_lo:  dw 0
wf_target_hi:  dw 0

sf_origin: db 0
sf_req_lo: dw 0
sf_req_hi: dw 0
sf_ret_lo: dw 0
sf_ret_hi: dw 0
ioctl_func: db 0
dup_root: dw 0
dup_dest: dw 0
dup_new_root: dw 0
dup_status: dw 0
dup_is_device: db 0

cur_dir_cluster: dw 0
cur_dir_path: times 64 db 0
cd_path_off: dw 0
cd_path_seg: dw 0
of_mode: db 0
of_status: dw 0
dev_type: db 0
fa_attr: db 0
fa_ret_attr: dw 0

cf_attr: db 0
cf_handle: dw 0
cf_entry_idx: dw 0
cf_entry_seg: dw 0
cf_entry_lba: dw 0
cf_entry_lba_hi: dw 0
cf_entry_off: dw 0
cf_found: db 0
cf_new_only: db 0
cf_status: dw 0
tm_end_off: dw 0
tm_tries: dw 0
temp_counter: dw 0

rn_new_off: dw 0
rn_new_seg: dw 0
rn_src_idx: dw 0
rn_src_off: dw 0
rn_src_dir_off: dw 0
rn_src_lba: dw 0
rn_src_lba_hi: dw 0
rn_dir_cluster: dw 0
rn_status: dw 0

ft_mode: db 0
ft_time: dw 0
ft_date: dw 0
df_status: dw 0
df_first_cluster: dw 0
md_status: dw 0
md_cluster: dw 0
md_parent_cluster: dw 0
md_entry_lba: dw 0
md_entry_lba_hi: dw 0
md_entry_off: dw 0
md_dir_lba: dw 0
md_dir_lba_hi: dw 0
md_sec_idx: db 0
rd_status: dw 0
rd_cluster: dw 0
rd_entry_lba: dw 0
rd_entry_lba_hi: dw 0
rd_entry_off: dw 0
rd_scan_cluster: dw 0
rd_scan_lba: dw 0
rd_scan_lba_hi: dw 0
rd_scan_sec_idx: db 0

pr_abs: db 0
pr_name_off: dw 0
pr_dir_cluster: dw 0
pr_path_off: dw 0
pr_last_sep: dw 0
pr_sep_char: db 0

dir_flush_lba: dw 0
dir_flush_lba_hi: dw 0
dir_update_hoff: dw 0
dir_ext_old_next: dw 0
dir_ext_fail_once: db 0

fat_dirty: db 0
fat_io_error: db 0
fat_copy_idx: db 0
fat_alloc_hint: dw 2
fat_flush_lba: dw 0
fat_flush_off: dw 0
fat16_lba: dw 0
fat16_sector: dw 0
fat16_off: dw 0
fat16_value: dw 0
fat16_cache_lba: dw 0
fat16_cache_valid: db 0

rp_path: dw 0
rp_path_seg: dw 0
rp_cluster: dw 0
rp_component_idx: db 0
lf_left_lo: dw 0
lf_left_hi: dw 0
lf_chunk: dw 0

ff_dir_cluster: dw 0
ff_entry_idx: dw 0
ff_entry_cluster: dw 0
ff_entry_size: dw 0
ff_entry_size_hi: dw 0
ff_entry_attr: db 0
ff_entry_time: dw 0
ff_entry_date: dw 0
ff_entry_name: times 11 db 0
ff_entry_lba: dw 0
ff_entry_lba_hi: dw 0
ff_entry_off: dw 0
ff_attr_mask: db 0
ff_filter_attrs: db 0
ff_path_off: dw 0
ff_path_seg: dw 0
ff_sep_off: dw 0
ff_res_es: dw 0
ff_res_di: dw 0

fid_cluster: dw 0
fid_idx: dw 0
rid_clus: dw 0
rid_lba: dw 0
rid_lba_hi: dw 0
rid_sec_idx: db 0
dir_ext_cluster: dw 0

find_di: dw 0

mcb_first: dw 0
cur_psp: dw 0
alloc_strat: db 0
am_req: dw 0
am_best_seg: dw 0
am_best_size: dw 0
am_ret_ax: dw 0
am_ret_bx: dw 0
am_ret_seg: dw 0
rm_req: dw 0
coh_index: dw 0

ov_param_off: dw 0
ov_param_seg: dw 0
ov_path_off: dw 0
ov_path_seg: dw 0
ov_load_seg: dw 0
ov_reloc_seg: dw 0
ov_cluster: dw 0
ov_size_lo: dw 0
ov_size_hi: dw 0
ov_skip: dw 0
ov_left: dw 0
ov_dst_seg: dw 0
ov_dst_off: dw 0
ov_sector_offset: dw 0
ov_sec_in_cluster: dw 0
ov_chunk: dw 0
ov_reloc_count: dw 0
ov_reloc_off: dw 0
ov_image_par: dw 0
ov_status: dw 0

exec_param_off: dw 0
exec_param_seg: dw 0
exec_path_off: dw 0
exec_path_seg: dw 0
exec_cluster: dw 0
exec_status: dw 0
exec_is_exe: db 0

prog_seg: dw 0
prog_par: dw 0
kfsize_hi: dw 0
exe_min_par: dw 0
exe_image_par: dw 0
copy_src_seg: dw 0
copy_dst_seg: dw 0

name_buf: times 11 db 0

handles: times MAX_HANDLES * HANDLE_SIZE db 0

log_ax: dw 0
log_bx: dw 0
log_cx: dw 0
log_dx: dw 0
trace_left: dw 0
exc_vec: db 0
bpb_copy: times 64 db 0
%if TRACE_EXEC_STATE
trace_psp_top: dw 0
trace_parent_psp: dw 0
trace_env_seg: dw 0
trace_cmd_tail: dw 0
trace_entry_cs: dw 0
trace_entry_ss: dw 0
trace_sig: db 0
trace_owner: dw 0
trace_size: dw 0
trace_bda_equip: dw 0
trace_bda_mode: dw 0
trace_bda_keyflags: dw 0
trace_bda_keyhead: dw 0
trace_bda_keytail: dw 0
trace_bda_tick_lo: dw 0
trace_bda_tick_hi: dw 0
trace_pic1: dw 0
trace_pic2: dw 0
trace_vec_num: db 0
trace_vec_off: dw 0
trace_vec_seg: dw 0
trace_mcb_seg: dw 0
%endif

mouse_x: dw 320
mouse_y: dw 100
mouse_min_x: dw 0
mouse_max_x: dw 639
mouse_min_y: dw 0
mouse_max_y: dw 199
mouse_buttons: dw 0
mouse_motion_x: dw 0
mouse_motion_y: dw 0
mouse_visible_count: dw 0xFFFF
mouse_trace_left: dw 0
mouse_log_ax: dw 0
mouse_callback_mask: dw 0
mouse_callback_off: dw 0
mouse_callback_seg: dw 0
mouse_event_mask: dw 0
mouse_ratio_x: dw 8
mouse_ratio_y: dw 8
mouse_scale_rem_x: dw 0
mouse_scale_rem_y: dw 0
mouse_event_dx: dw 0
mouse_event_dy: dw 0
mouse_in_callback: db 0
mouse_ps2_enabled: db 0
mouse_cmd: db 0
mouse_ps2_stage: db 0
mouse_packet_index: db 0
mouse_packet0: db 0
mouse_packet1: db 0
mouse_packet2: db 0
mouse_new_buttons: dw 0
mouse_press_count_l: dw 0
mouse_press_count_r: dw 0
mouse_press_x_l: dw 320
mouse_press_y_l: dw 100
mouse_press_x_r: dw 320
mouse_press_y_r: dw 100
xms_alloc_kb: dw 0
xms_move_len: dw 0
xms_move_words: dw 0
xms_src_phys: dd 0
xms_dst_phys: dd 0
xms_gdt: times 48 db 0
xms_total_kb: dw 0
%if ENABLE_EMS
ems_alloc_pages: dw 0
ems_map_pages: times 4 dw 0xFFFF
ems_req_logical: dw 0
ems_req_phys: db 0
%endif
kernel_end:

%if mouse_callback_seg != (mouse_callback_off + 2)
%error "mouse callback far pointer layout changed"
%endif

%if LOAD_SEG <= RELOC_SEG
%error "LOAD_SEG must be above RELOC_SEG"
%endif
%if (kernel_end - kernel_entry) > ((LOAD_SEG - RELOC_SEG) * 16)
%error "kernel exceeds boot relocation gap"
%endif
%if (kernel_end - kernel_entry) > ((SEC_BUF - RELOC_SEG) * 16)
%error "kernel overlaps SEC_BUF"
%endif
%if SEC_BUF >= ENV_SEG
%error "SEC_BUF must remain below ENV_SEG"
%endif
%if (kernel_end - kernel_entry) > ((ENV_SEG - RELOC_SEG) * 16)
%error "kernel overlaps ENV_SEG"
%endif
%if ENV_SEG >= ROOT_SEG
%error "ENV_SEG must remain below ROOT_SEG"
%endif
%if (ROOT_SEG + ROOT_BUF_PARAS) > (RELOC_SEG + (KERNEL_STACK_TOP / 16))
%error "ROOT buffer overlaps kernel stack"
%endif
%if (RELOC_SEG + (KERNEL_STACK_TOP / 16)) > MCB_START
%error "kernel stack overlaps MCB arena"
%endif
%if (ROOT_SEG + ROOT_BUF_PARAS) > MCB_START
%error "ROOT_SEG overlaps MCB arena"
%endif
%if ENABLE_EMS && EMS_FRAME_SEG <= MCB_START
%error "EMS frame must be inside conventional arena"
%endif
%if ENABLE_EMS && EMS_FRAME_SEG == MEM_TOP
%error "EMS frame must not overlap VGA graphics memory"
%endif
%if ENABLE_EMS && (EMS_FRAME_SEG + EMS_FRAME_PARAS) > 0xF000
%error "EMS frame must remain below system ROM"
%endif
%if ENABLE_EMS && (EMS_FRAME_SEG & 0x03FF) != 0
%error "EMS frame must be 16K-aligned"
%endif
%if ENABLE_XMS && XMS_MAX_KB > 15360
%error "XMS BIOS move backing must remain below 16 MiB"
%endif
