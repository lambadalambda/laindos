[bits 16]
[org 0x0010]

COM1_PORT equ 0x3F8
VGA_TEXT_SEG equ 0xB800
VGA_COLS equ 80
VGA_ROWS equ 25
%include "src/memory.inc"
%include "src/fat_bpb.inc"
%include "src/kernel/macros.inc"

BPB_SEG   equ 0x0000
BPB_OFF   equ 0x7C00
FAT_SEG   equ 0x0060
FAT_BUF_SECS equ ((CD_BUF - FAT_SEG) / 32)
ROOT_SEG  equ 0x0240

HANDLE_SIZE equ 34
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
H_DRIVE     equ 32
H_ALIAS_NONE equ 0xFFFF
MAX_HANDLES equ 20
COM_EXTRA_PAR equ 0x0110
KERNEL_STACK_TOP equ 0xFFF0
KERNEL_STACK_GUARD_BYTES equ 0x0800
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
ATTR_ARCHIVE equ 0x20
ATTR_MUTABLE equ ATTR_RDONLY | ATTR_HIDDEN | ATTR_SYSTEM | ATTR_ARCHIVE
ATTR_IMMUTABLE equ ATTR_VOLUME | ATTR_DIR
ROOT_ENT_CNT equ 224
ROOT_MAX_ENTRIES equ 512
ROOT_BUF_PARAS equ ((ROOT_MAX_ENTRIES * 32) + 15) / 16
MAX_DRIVES equ 4
DRIVE_TYPE_FAT equ 0
DRIVE_TYPE_CDROM equ 1
CD_READ_METHOD_BIOS equ 0
CD_READ_METHOD_ATAPI equ 1

CF equ 0x0001
ZF equ 0x0040
IFLAG equ 0x0200

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

%ifndef UTC_OFFSET_MINUTES
%define UTC_OFFSET_MINUTES 0
%endif
%assign LOCAL_TIME_OFFSET_MINUTES UTC_OFFSET_MINUTES
%rep 32
%if LOCAL_TIME_OFFSET_MINUTES < 0
%assign LOCAL_TIME_OFFSET_MINUTES LOCAL_TIME_OFFSET_MINUTES + 1440
%endif
%endrep
%rep 32
%if LOCAL_TIME_OFFSET_MINUTES >= 1440
%assign LOCAL_TIME_OFFSET_MINUTES LOCAL_TIME_OFFSET_MINUTES - 1440
%endif
%endrep
%if LOCAL_TIME_OFFSET_MINUTES < 0 || LOCAL_TIME_OFFSET_MINUTES >= 1440
%error "UTC_OFFSET_MINUTES is outside the supported normalization range"
%endif
%assign LOCAL_TIME_OFFSET_HOURS (LOCAL_TIME_OFFSET_MINUTES / 60)
%assign LOCAL_TIME_OFFSET_MINUTES_PART (LOCAL_TIME_OFFSET_MINUTES % 60)

%ifndef ENABLE_XMS
%define ENABLE_XMS 1
%endif

%ifndef ENABLE_EMS
%define ENABLE_EMS 0
%endif

kernel_entry:
    mov ax, cs
    cmp ax, HMA_SEG
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
    call enable_a20
    jnc .a20_ok
    mov si, msg_a20fail
    call serial_print
.a20_hang:
    hlt
    jmp .a20_hang
.a20_ok:
    mov ax, HMA_SEG
    mov es, ax
    mov si, kernel_entry
    mov di, kernel_entry
    mov cx, kernel_end - kernel_entry
    cld
    rep movsb
    jmp HMA_SEG:.relocated
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
    mov [kstack_seg], cs
    mov word [kstack_base], KERNEL_STACK_TOP
    call mouse_init_ps2

    mov word [cur_dir_cluster], ROOT_CLUSTER
    mov byte [cur_dir_path], 0

    mov ax, MCB_START
    mov es, ax
    mov byte [es:0], MCB_SIG_Z
    mov word [es:1], 0
    ; arena ends at the BIOS conventional-memory line, not at 640K: the
    ; EBDA above it belongs to the BIOS (PS/2 mouse state lives there)
    mov ax, [mem_kib]
    mov cl, 6
    shl ax, cl
    cmp ax, MEM_TOP
    jbe .arena_top_ok
    mov ax, MEM_TOP
.arena_top_ok:
    sub ax, MCB_START + 1
    mov word [es:3], ax
    mov word [mcb_first], MCB_START
    mov word [cur_psp], 0

%ifdef TEST_BAD_BPB_SEC_PER_CLUS
    mov byte [bpb_copy+0x0D], 0
%endif
%ifdef TEST_BAD_BPB_ROOT_ENTRIES
    mov word [bpb_copy+BPB_ROOT_ENT_COUNT], 1024
%endif
%ifdef TEST_BAD_BPB_FAT_SECS
    mov word [bpb_copy+BPB_SECS_PER_FAT], 32
%endif
    call init_bpb_geometry
    jnc .bpb_ok
    mov si, msg_badbpb
    call serial_print
    jmp .halt
.bpb_ok:

%ifdef TEST_FAT16_FAT_SECTOR_BOUNDS
    call test_fat16_sector_bounds
    jmp .halt
%endif

    mov si, fname_exe
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    cld
    rep movsb
    mov ax, ROOT_CLUSTER
    xor bx, bx
    xor dx, dx
    mov byte [cs:ff_attr_mask], 0
    call find_in_dir
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
    call init_environment
    jc .halt

    mov dx, SEC_BUF
    mov ds, dx
    cmp word [0x0000], 0x5A4D
    je .peek_mz

    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    mov cx, COM_EXTRA_PAR
    call image_paras_from_bytes
    jc .halt
    mov [cs:prog_par], ax
    jmp .alloc_com

.peek_mz:
    call exe_compute_sizing
    jc .halt
    call exe_apply_maxalloc_policy

.alloc:
    push cs
    pop ds
    mov bx, [cs:prog_par]
    call alloc_mem_direct
    jmp .alloc_done
.alloc_com:
    ; a .COM owns the largest free block, as on real DOS
    push cs
    pop ds
    call find_largest_free_block
    cmp bx, [cs:prog_par]
    jb .halt
    mov [cs:prog_par], bx
    call alloc_mem_direct
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
    inc byte [cs:indos_flag]
    call exec_com_dyn
    jmp .returned

.is_exe:
    push cs
    pop ds
    mov si, msg_exe_load
    call serial_print

    mov ax, [cs:prog_seg]
    inc byte [cs:indos_flag]
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

; A depth-1 INT 21h call runs on the kernel-owned stack with the
; caller's SS:SP parked as the two words below kstack_base, so the
; caller's stack must come back before the INT frame fixups. Nested
; calls and the boot launcher's direct exec path never switched and
; skip the restore: nested calls show indos > 1, and the boot path
; runs on the boot stack, not the kernel stack segment.
%macro INT21_RESTORE_CALLER_STACK 0
    cli
    cmp byte [cs:indos_flag], 1
    jne %%no_restore
    push ax
    mov ax, ss
    cmp ax, [cs:kstack_seg]
    pop ax
    jne %%no_restore
    pop word [cs:entry_caller_sp]
    pop word [cs:entry_caller_ss]
    mov ss, [cs:entry_caller_ss]
    mov sp, [cs:entry_caller_sp]
%%no_restore:
%endmacro

iret_nc:
    INT21_RESTORE_CALLER_STACK
    push bp
    mov bp, sp
    and word [bp+6], ~CF
    dec byte [cs:indos_flag]
    pop bp
    iret

iret_cy:
    INT21_RESTORE_CALLER_STACK
    push bp
    mov bp, sp
    or word [bp+6], CF
    dec byte [cs:indos_flag]
    pop bp
    iret

iret_nc_zf:
    INT21_RESTORE_CALLER_STACK
    push bp
    mov bp, sp
    and word [bp+6], ~CF
    or word [bp+6], ZF
    dec byte [cs:indos_flag]
    pop bp
    iret

iret_nc_nz:
    INT21_RESTORE_CALLER_STACK
    push bp
    mov bp, sp
    and word [bp+6], ~(CF | ZF)
    dec byte [cs:indos_flag]
    pop bp
    iret

iret_cy_no_indos:
    push bp
    mov bp, sp
    or word [bp+6], CF
    pop bp
    iret

enable_a20:
    call a20_test
    jnz .enabled
    mov ax, 0x2401
    int 0x15
    call a20_test
    jnz .enabled
    call kbc_enable_a20
    call a20_test
    jnz .enabled
    in al, 0x92
    or al, 0x02
    and al, 0xFE
    out 0x92, al
    call a20_test
    jnz .enabled
    stc
    ret
.enabled:
    clc
    ret

a20_test:
    push ds
    push es
    push si
    push di
    push cx
    xor ax, ax
    mov ds, ax
    mov ax, HMA_SEG
    mov es, ax
    xor si, si
    mov di, HMA_OFF
    mov cx, 16
    cld
    repe cmpsb
    pop cx
    pop di
    pop si
    pop es
    pop ds
    ret

kbc_enable_a20:
    call .wait_input
    jc .done
    mov al, 0xD1
    out 0x64, al
    call .wait_input
    jc .done
    mov al, 0xDF
    out 0x60, al
    call .wait_input
.done:
    ret
.wait_input:
    push cx
    xor cx, cx
.wait_loop:
    in al, 0x64
    test al, 0x02
    jz .wait_ok
    loop .wait_loop
    pop cx
    stc
    ret
.wait_ok:
    pop cx
    clc
    ret

init_bpb_geometry:
    call parse_bpb_geometry
    jc .done
    call init_drive_table
.done:
    ret

parse_bpb_geometry:
    push ds
    push bx
    push cs
    pop ds
    mov bx, bpb_copy

    cmp word [bx+BPB_BYTES_PER_SEC], 512
    jne .bad
    mov al, [bx+BPB_SECS_PER_CLUS]
    test al, al
    jz .bad
    mov ah, al
    dec ah
    test al, ah
    jnz .bad
    cmp word [bx+BPB_RSV_SEC_COUNT], 0
    je .bad
    cmp byte [bx+BPB_NUM_FATS], 0
    je .bad
    cmp byte [bx+BPB_NUM_FATS], 2
    ja .bad
    mov ax, [bx+BPB_ROOT_ENT_COUNT]
    test ax, ax
    jz .bad
    test ax, 0x000F
    jnz .bad
    cmp ax, ROOT_MAX_ENTRIES
    ja .bad
    cmp word [bx+BPB_SECS_PER_FAT], 0
    je .bad
    cmp word [bx+BPB_SECS_PER_TRK], 0
    je .bad
    cmp word [bx+BPB_NUM_HEADS], 0
    je .bad
    mov ax, [bx+BPB_TOT_SECS_16]
    test ax, ax
    jnz .total_ok
    mov ax, [bx+BPB_TOT_SECS_32]
    or ax, [bx+BPB_TOT_SECS_32+2]
    jz .bad
.total_ok:

    mov ax, [bx+BPB_HIDDEN_SECS]
    mov [cs:kpart_lba], ax
    mov ax, [bx+BPB_HIDDEN_SECS+2]
    mov [cs:kpart_lba_hi], ax

    mov ax, [bx+BPB_SECS_PER_FAT]
    mov [cs:kfat_secs], ax
    mov ax, [bx+BPB_RSV_SEC_COUNT]
    mov [cs:kfat_start], ax
    mov al, [bx+BPB_NUM_FATS]
    mov [cs:knum_fats], al
    mov ax, [bx+BPB_SECS_PER_FAT]
    movzx cx, byte [bx+BPB_NUM_FATS]
    mul cx
    test dx, dx
    jnz .bad
    add ax, [bx+BPB_RSV_SEC_COUNT]
    jc .bad
    mov [cs:krsta], ax
    mov ax, [bx+BPB_ROOT_ENT_COUNT]
    mov [cs:kroot_entries], ax
    push ax
    mov al, [bx+BPB_SECS_PER_CLUS]
    mov [cs:kspc], al
    mov ax, [bx+BPB_SECS_PER_TRK]
    mov [cs:kbio_spt], ax
    mov ax, [bx+BPB_NUM_HEADS]
    mov [cs:kbio_heads], ax
    pop ax
    mov bx, 32
    mul bx
    test dx, dx
    jnz .bad
    mov [cs:kroot_bytes], ax
    add ax, 511
    jc .bad
    mov bx, 512
    div bx
    mov [cs:krsc], ax
    add ax, [cs:krsta]
    jc .bad
    mov [cs:kdsta], ax

    mov bx, bpb_copy
    mov ax, [bx+BPB_TOT_SECS_16]
    xor dx, dx
    test ax, ax
    jnz .have_total
    mov ax, [bx+BPB_TOT_SECS_32]
    mov dx, [bx+BPB_TOT_SECS_32+2]
.have_total:
    test dx, dx
    jnz .total_over_root
    cmp ax, [cs:kdsta]
    jbe .bad
.total_over_root:
    sub ax, [cs:kdsta]
    sbb dx, 0
    xor ch, ch
    mov cl, [cs:kspc]
    cmp dx, cx
    jae .bad
    div cx
    cmp ax, 0xFFF4
    ja .bad
    add ax, 2
    mov [cs:kmax_cluster], ax

    mov byte [cs:kfat_bits], 12
    mov word [cs:kfat_eoc], FAT12_EOC
    mov word [cs:kfat_eoc_value], FAT12_EOC_VALUE
    mov word [cs:kfat_reserved], FAT12_RESERVED
    cmp ax, 4087
    jb .fat_type_done
    mov byte [cs:kfat_bits], 16
    mov word [cs:kfat_eoc], FAT16_EOC
    mov word [cs:kfat_eoc_value], FAT16_EOC_VALUE
    mov word [cs:kfat_reserved], FAT16_RESERVED
    jmp .fat_fit_ok
.fat_type_done:
    cmp word [cs:kfat_secs], FAT_BUF_SECS
    ja .bad
.fat_fit_ok:

    pop bx
    pop ds
    clc
    ret
.bad:
    pop bx
    pop ds
    stc
    ret

init_drive_table:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    push cs
    pop ds
    mov cx, MAX_DRIVES
    xor bx, bx
    xor di, di
.clear_loop:
    mov byte [cs:drive_present+bx], 0
    mov byte [cs:drive_type+bx], DRIVE_TYPE_FAT
    mov byte [cs:drive_cur_paths+di], 0
    inc bx
    add di, 64
    loop .clear_loop
    push ds
    xor ax, ax
    mov ds, ax
    mov al, [0x500]
    pop ds
    mov [cs:kdrv], al
    cmp al, 0x80
    jb .floppy_boot
    call query_bios_disk_geometry
    mov byte [cs:dos_drive_num], 2
    mov byte [cs:boot_drive_num], 2
    mov byte [cs:dos_drive_letter], 'C'
    mov byte [cs:dos_drive_count], 3
    mov byte [cs:active_drive_num], 2
    mov word [cs:cur_dir_cluster], ROOT_CLUSTER
    mov byte [cs:cur_dir_path], 0
    mov al, 0
    call save_active_drive_slot
    mov al, 1
    call save_active_drive_slot
    mov al, 2
    call save_active_drive_slot
    call load_active_volume_buffers
    jc .done
    call mount_bios_floppy_a
    jnc .hd_have_floppy
    mov al, 2
    call load_drive_slot_geometry
    mov byte [cs:rf_cache_valid], 0
    mov byte [cs:fat16_cache_valid], 0
    call load_active_volume_buffers
    jmp .hd_floppy_done
.hd_have_floppy:
    mov al, 2
    call activate_drive
.hd_floppy_done:
    call mount_bios_cdrom_d
    jc .hard_boot_cd_done
    mov byte [cs:dos_drive_count], 4
.hard_boot_cd_done:
    clc
    jmp .done
.floppy_boot:
    mov byte [cs:dos_drive_num], 0
    mov byte [cs:boot_drive_num], 0
    mov byte [cs:dos_drive_letter], 'A'
    mov byte [cs:dos_drive_count], 1
    mov byte [cs:active_drive_num], 0
    mov word [cs:cur_dir_cluster], ROOT_CLUSTER
    mov byte [cs:cur_dir_path], 0
    mov al, 0
    call save_active_drive_slot
    call mount_bios_hard_disk_c
    jc .restore_floppy
    mov byte [cs:dos_drive_num], 2
    mov byte [cs:dos_drive_count], 3
    mov byte [cs:active_drive_num], 0xFF
    xor al, al
    call activate_drive
    mov al, 1
    call save_active_drive_slot
    mov byte [cs:dos_drive_num], 0
    mov byte [cs:dos_drive_letter], 'A'
    call mount_bios_cdrom_d
    jc .floppy_cd_done
    mov byte [cs:dos_drive_count], 4
.floppy_cd_done:
    clc
    jmp .done
.restore_floppy:
    mov byte [cs:active_drive_num], 0xFF
    xor al, al
    call activate_drive
    mov byte [cs:dos_drive_num], 0
    mov byte [cs:dos_drive_letter], 'A'
    mov byte [cs:dos_drive_count], 1
    call mount_bios_cdrom_d
    jc .restore_cd_done
    mov byte [cs:dos_drive_count], 4
.restore_cd_done:
    clc
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

save_active_drive_slot:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    xor bh, bh
    mov bl, al
    cmp bl, MAX_DRIVES
    jae .done
    mov byte [cs:drive_present+bx], 1
    mov byte [cs:drive_type+bx], DRIVE_TYPE_FAT
    mov al, [cs:kdrv]
    mov [cs:drive_bios+bx], al
    mov al, [cs:kspc]
    mov [cs:drive_kspc+bx], al
    mov al, [cs:knum_fats]
    mov [cs:drive_knum_fats+bx], al
    mov al, [cs:kfat_bits]
    mov [cs:drive_kfat_bits+bx], al
    mov si, bx
    shl si, 1
    mov ax, [cs:krsta]
    mov [cs:drive_krsta+si], ax
    mov ax, [cs:krsc]
    mov [cs:drive_krsc+si], ax
    mov ax, [cs:kdsta]
    mov [cs:drive_kdsta+si], ax
    mov ax, [cs:kbio_spt]
    mov [cs:drive_kbio_spt+si], ax
    mov ax, [cs:kbio_heads]
    mov [cs:drive_kbio_heads+si], ax
    mov ax, [cs:kfat_start]
    mov [cs:drive_kfat_start+si], ax
    mov ax, [cs:kfat_secs]
    mov [cs:drive_kfat_secs+si], ax
    mov ax, [cs:kfat_eoc]
    mov [cs:drive_kfat_eoc+si], ax
    mov ax, [cs:kfat_eoc_value]
    mov [cs:drive_kfat_eoc_value+si], ax
    mov ax, [cs:kfat_reserved]
    mov [cs:drive_kfat_reserved+si], ax
    mov ax, [cs:kroot_entries]
    mov [cs:drive_kroot_entries+si], ax
    mov ax, [cs:kroot_bytes]
    mov [cs:drive_kroot_bytes+si], ax
    mov ax, [cs:kmax_cluster]
    mov [cs:drive_kmax_cluster+si], ax
    mov ax, [cs:kpart_lba]
    mov [cs:drive_kpart_lba+si], ax
    mov ax, [cs:kpart_lba_hi]
    mov [cs:drive_kpart_lba_hi+si], ax
    mov si, bx
    shl si, 6
    push ds
    push es
    push cs
    pop ds
    push cs
    pop es
    mov di, drive_bpbs
    add di, si
    mov si, bpb_copy
    mov cx, 64
    cld
    rep movsb
    pop es
    pop ds
    mov si, bx
    shl si, 1
    mov ax, [cs:cur_dir_cluster]
    mov [cs:drive_cur_clusters+si], ax
    mov si, bx
    shl si, 6
    push ds
    push es
    push cs
    pop ds
    push cs
    pop es
    mov di, drive_cur_paths
    add di, si
    mov si, cur_dir_path
    mov cx, 64
    cld
    rep movsb
    pop es
    pop ds
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

save_active_drive_cwd:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    xor bh, bh
    mov bl, [cs:active_drive_num]
    cmp bl, MAX_DRIVES
    jae .done
    mov si, bx
    shl si, 1
    mov ax, [cs:cur_dir_cluster]
    mov [cs:drive_cur_clusters+si], ax
    mov si, bx
    shl si, 6
    push cs
    pop ds
    push cs
    pop es
    mov di, drive_cur_paths
    add di, si
    mov si, cur_dir_path
    mov cx, 64
    cld
    rep movsb
.done:
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    ret

load_active_drive_cwd:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    xor bh, bh
    mov bl, [cs:active_drive_num]
    cmp bl, MAX_DRIVES
    jae .done
    mov si, bx
    shl si, 1
    mov ax, [cs:drive_cur_clusters+si]
    mov [cs:cur_dir_cluster], ax
    mov si, bx
    shl si, 6
    push cs
    pop ds
    push cs
    pop es
    mov di, cur_dir_path
    add si, drive_cur_paths
    mov cx, 64
    cld
    rep movsb
.done:
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    ret

load_drive_slot_geometry:
    push ax
    push bx
    push si
    xor bh, bh
    mov bl, al
    mov al, [cs:drive_bios+bx]
    mov [cs:kdrv], al
    mov al, [cs:drive_type+bx]
    mov [cs:kdrive_type], al
    mov al, [cs:drive_kspc+bx]
    mov [cs:kspc], al
    mov al, [cs:drive_knum_fats+bx]
    mov [cs:knum_fats], al
    mov al, [cs:drive_kfat_bits+bx]
    mov [cs:kfat_bits], al
    mov si, bx
    shl si, 1
    mov ax, [cs:drive_krsta+si]
    mov [cs:krsta], ax
    mov ax, [cs:drive_krsc+si]
    mov [cs:krsc], ax
    mov ax, [cs:drive_kdsta+si]
    mov [cs:kdsta], ax
    mov ax, [cs:drive_kbio_spt+si]
    mov [cs:kbio_spt], ax
    mov ax, [cs:drive_kbio_heads+si]
    mov [cs:kbio_heads], ax
    mov ax, [cs:drive_kfat_start+si]
    mov [cs:kfat_start], ax
    mov ax, [cs:drive_kfat_secs+si]
    mov [cs:kfat_secs], ax
    mov ax, [cs:drive_kfat_eoc+si]
    mov [cs:kfat_eoc], ax
    mov ax, [cs:drive_kfat_eoc_value+si]
    mov [cs:kfat_eoc_value], ax
    mov ax, [cs:drive_kfat_reserved+si]
    mov [cs:kfat_reserved], ax
    mov ax, [cs:drive_kroot_entries+si]
    mov [cs:kroot_entries], ax
    mov ax, [cs:drive_kroot_bytes+si]
    mov [cs:kroot_bytes], ax
    mov ax, [cs:drive_kmax_cluster+si]
    mov [cs:kmax_cluster], ax
    mov ax, [cs:drive_kpart_lba+si]
    mov [cs:kpart_lba], ax
    mov ax, [cs:drive_kpart_lba_hi+si]
    mov [cs:kpart_lba_hi], ax
    mov si, bx
    shl si, 6
    push cx
    push ds
    push es
    push cs
    pop ds
    push cs
    pop es
    mov di, bpb_copy
    add si, drive_bpbs
    mov cx, 64
    cld
    rep movsb
    pop es
    pop ds
    pop cx
    pop si
    pop bx
    pop ax
    ret

mount_bios_hard_disk_c:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov byte [cs:drive_present+2], 0
    mov byte [cs:kdrv], 0x80
    mov word [cs:kpart_lba], 0
    mov word [cs:kpart_lba_hi], 0
    mov word [cs:kbio_spt], 63
    mov word [cs:kbio_heads], 16
    call query_bios_disk_geometry
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    xor ax, ax
    mov word [cs:kio_lba_hi], 0
    call read_sector
    jc .err
    call copy_secbuf_to_bpb
    call parse_bpb_geometry
    jnc .mounted_bpb
    call mount_mbr_partition
    jc .err
.mounted_bpb:
    mov byte [cs:kdrv], 0x80
    call query_bios_disk_geometry
    mov word [cs:cur_dir_cluster], ROOT_CLUSTER
    mov byte [cs:cur_dir_path], 0
    mov byte [cs:active_drive_num], 2
    mov al, 2
    call save_active_drive_slot
    clc
    jmp .done
.err:
    mov byte [cs:drive_present+2], 0
    stc
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

; Mount the BIOS floppy (drive 00h) as A: when booting from hard disk,
; like real DOS. The caller restores C: as the active drive afterwards.
mount_bios_floppy_a:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov byte [cs:kdrv], 0x00
    mov word [cs:kpart_lba], 0
    mov word [cs:kpart_lba_hi], 0
    mov word [cs:kbio_spt], 18
    mov word [cs:kbio_heads], 2
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    xor ax, ax
    mov word [cs:kio_lba_hi], 0
    call read_sector
    jc .err
    call copy_secbuf_to_bpb
    call parse_bpb_geometry
    jc .err
    mov word [cs:kpart_lba], 0
    mov word [cs:kpart_lba_hi], 0
    mov word [cs:cur_dir_cluster], ROOT_CLUSTER
    mov byte [cs:cur_dir_path], 0
    mov byte [cs:active_drive_num], 0
    mov al, 0
    call save_active_drive_slot
    clc
    jmp .done
.err:
    stc
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

; A floppy INT 13h read failed with the change-line error (AH=06h): the
; disk was swapped under an in-flight operation. Reset the drive, re-read
; the BPB, reload the active volume, and reset A:'s working directory so
; the retried I/O sees the new disk. The in-flight kio state survives the
; nested sector reads.
floppy_media_remount:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov ax, [cs:klba]
    push ax
    mov ax, [cs:klba_hi]
    push ax
    mov al, [cs:kio_op]
    push ax
    xor ax, ax
    mov dl, [cs:kdrv]
    int 0x13
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    xor ax, ax
    mov word [cs:kio_lba_hi], 0
    call read_sector
    jc .err
    call copy_secbuf_to_bpb
    call parse_bpb_geometry
    jc .err
    mov word [cs:kpart_lba], 0
    mov word [cs:kpart_lba_hi], 0
    mov word [cs:cur_dir_cluster], ROOT_CLUSTER
    mov byte [cs:cur_dir_path], 0
    mov byte [cs:rf_cache_valid], 0
    mov byte [cs:fat16_cache_valid], 0
    mov byte [cs:fat_dirty], 0
    call load_active_volume_buffers
    jc .err
    cmp byte [cs:kdrv], 0
    jne .saved
    mov word [cs:drive_cur_clusters], ROOT_CLUSTER
    mov byte [cs:drive_cur_paths], 0
    mov al, 0
    call save_active_drive_slot
.saved:
    clc
    jmp .out
.err:
    stc
.out:
    pop ax
    mov [cs:kio_op], al
    pop ax
    mov [cs:klba_hi], ax
    pop ax
    mov [cs:klba], ax
    mov byte [cs:kcnt], 1
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Real DOS issues a MEDIA CHECK before trusting its buffers on a removable
; drive. Without it a swap is invisible while the drive stays current: the
; cached FAT/root keep serving the old disk because no physical read ever
; happens to surface the change-line error. Like DOS, a drive verified
; within the last 2 seconds (36 ticks) is assumed unchanged, and a
; "changed" answer from INT 13h AH=16h is confirmed by content before any
; state is discarded — QEMU's change line latches "changed" forever, and
; real DOS too re-read the volume before invalidating buffers it could
; not rebuild.
floppy_media_check:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cmp byte [cs:kdrive_type], DRIVE_TYPE_CDROM
    je .ok
    cmp byte [cs:kdrv], 0x80
    jae .ok
    mov ax, 0x40
    mov ds, ax
    mov ax, [ds:0x6C]
    sub ax, [cs:floppy_check_tick]
    cmp ax, 36
    jb .ok
    mov ah, 0x16
    mov dl, [cs:kdrv]
    int 0x13
    cmp ah, 0x06
    jne .stamp
    ; Change line active (or unreliable): re-read the first root
    ; directory sector and compare with the cached copy. A mismatch is a
    ; different disk; a swapped identical disk is indistinguishable, as
    ; on real DOS. A read failing mid-probe with error 06h takes the
    ; in-flight remount path inside sector_io_loop.
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov word [cs:kio_lba_hi], 0
    mov ax, [cs:krsta]
    call read_sector
    jc .err
    mov ax, SEC_BUF
    mov ds, ax
    mov ax, ROOT_SEG
    mov es, ax
    xor si, si
    xor di, di
    mov cx, 256
    repe cmpsw
    je .stamp
    call floppy_media_remount
    jc .err
.stamp:
    mov ax, 0x40
    mov ds, ax
    mov ax, [ds:0x6C]
    mov [cs:floppy_check_tick], ax
.ok:
    clc
    jmp .done
.err:
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

copy_secbuf_to_bpb:
    push ax
    push cx
    push ds
    push es
    push si
    push di
    mov ax, SEC_BUF
    mov ds, ax
    push cs
    pop es
    xor si, si
    mov di, bpb_copy
    mov cx, 64
    cld
    rep movsb
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop ax
    ret

mount_mbr_partition:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    mov ax, SEC_BUF
    mov ds, ax
    cmp word [0x1FE], 0xAA55
    jne .err
    mov si, 0x1BE
    mov cx, 4
.active_loop:
    cmp byte [si], 0x80
    jne .active_next
    call mbr_entry_is_fat
    jnc .found
.active_next:
    add si, 16
    loop .active_loop
    mov si, 0x1BE
    mov cx, 4
.any_loop:
    call mbr_entry_is_fat
    jnc .found
    add si, 16
    loop .any_loop
    jmp .err
.found:
    mov ax, [si+8]
    mov [cs:mbr_part_lba], ax
    mov dx, [si+10]
    mov [cs:mbr_part_lba_hi], dx
    or ax, dx
    jz .err
    mov word [cs:kpart_lba], 0
    mov word [cs:kpart_lba_hi], 0
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:mbr_part_lba]
    mov dx, [cs:mbr_part_lba_hi]
    mov [cs:kio_lba_hi], dx
    call read_sector
    jc .err
    call copy_secbuf_to_bpb
    mov bx, bpb_copy
    mov ax, [cs:bx+0x1C]
    or ax, [cs:bx+0x1E]
    jnz .parse
    mov ax, [cs:mbr_part_lba]
    mov [cs:bx+0x1C], ax
    mov ax, [cs:mbr_part_lba_hi]
    mov [cs:bx+0x1E], ax
.parse:
    call parse_bpb_geometry
    jc .err
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err:
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

mbr_entry_is_fat:
    mov al, [si+4]
    cmp al, 0x01
    je .type_ok
    cmp al, 0x04
    je .type_ok
    cmp al, 0x06
    je .type_ok
    cmp al, 0x0E
    je .type_ok
    stc
    ret
.type_ok:
    mov ax, [si+8]
    or ax, [si+10]
    jz .bad
    clc
    ret
.bad:
    stc
    ret

activate_drive:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov [cs:drive_req], al
    mov al, [cs:active_drive_num]
    mov [cs:drive_prev], al
    mov al, [cs:drive_req]
    cmp al, MAX_DRIVES
    jae .err
    xor bh, bh
    mov bl, al
    cmp byte [cs:drive_present+bx], 0
    je .err
    cmp al, [cs:active_drive_num]
    jne .switch
    call floppy_media_check
    jc .err
    jmp .ok
.switch:
    call flush_fat
    jc .err
    call save_active_drive_cwd
    mov al, [cs:drive_req]
    call load_drive_slot_geometry
    mov byte [cs:rf_cache_valid], 0
    mov byte [cs:fat16_cache_valid], 0
    mov byte [cs:fat_dirty], 0
    call load_active_volume_buffers
    jc .restore_old
    mov al, [cs:drive_req]
    mov [cs:active_drive_num], al
    call load_active_drive_cwd
.ok:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.restore_old:
    mov al, [cs:drive_prev]
    cmp al, MAX_DRIVES
    jae .err
    call load_drive_slot_geometry
    mov byte [cs:rf_cache_valid], 0
    mov byte [cs:fat16_cache_valid], 0
    mov byte [cs:fat_dirty], 0
    call load_active_volume_buffers
.err:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

load_active_volume_buffers:
    push ax
    push bx
    push cx
    push dx
    push es
    cmp byte [cs:kdrive_type], DRIVE_TYPE_CDROM
    je .ok
    cmp byte [cs:kfat_bits], 16
    je .root
    mov ax, FAT_SEG
    mov es, ax
    xor bx, bx
    mov ax, [cs:kfat_start]
    mov cx, [cs:kfat_secs]
    call read_sector_loop
    jc .err
.root:
    mov ax, ROOT_SEG
    mov es, ax
    xor bx, bx
    mov ax, [cs:krsta]
    mov cx, [cs:krsc]
    call read_sector_loop
    jc .err
.ok:
    clc
    jmp .done
.err:
    stc
.done:
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

read_sector_loop:
    push dx
    mov [cs:drive_load_lba], ax
.loop:
    test cx, cx
    jz .ok
    mov word [cs:kio_lba_hi], 0
    mov ax, [cs:drive_load_lba]
    push cx
    call read_sector
    pop cx
    jc .err
    inc word [cs:drive_load_lba]
    dec cx
    jmp .loop
.ok:
    pop dx
    clc
    ret
.err:
    pop dx
    stc
    ret

activate_drive_for_path:
    push ax
    push bx
    push si
    mov al, [ds:si]
    call ascii_upper
    cmp al, 'A'
    jb .default
    cmp al, 'Z'
    ja .default
    cmp byte [ds:si+1], ':'
    jne .default
    sub al, 'A'
    cmp al, 3
    jne .activate
    cmp byte [cs:drive_present+3], 0
    jne .activate
    call mount_bios_cdrom_d
    jc .activate
    mov byte [cs:dos_drive_count], 4
    jmp .activate
.default:
    mov al, [cs:dos_drive_num]
.activate:
    mov [cs:drive_req], al
    call activate_drive
    jc .err
    pop si
    pop bx
    pop ax
    clc
    ret
.err:
    pop si
    pop bx
    pop ax
    stc
    ret

activate_drive_for_dl:
    push ax
    test dl, dl
    jz .default
    mov al, dl
    dec al
    jmp .activate
.default:
    mov al, [cs:dos_drive_num]
.activate:
    call activate_drive
    pop ax
    ret

activate_drive_for_handle:
    push ax
    mov al, [cs:si+handles+H_DRIVE]
    call activate_drive
    pop ax
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

%ifdef TEST_FAT16_FAT_SECTOR_BOUNDS
test_fat16_sector_bounds:
    cmp byte [cs:kfat_bits], 16
    jne .fail
    mov word [cs:kfat_secs], 1
    mov byte [cs:knum_fats], 1
    mov byte [cs:fat16_cache_valid], 0
    mov byte [cs:fat_io_error], 0
    mov si, 0x0100
    mov ax, [cs:kfat_eoc_value]
    call fat_set
    cmp byte [cs:fat_io_error], 1
    jne .fail
    mov byte [cs:fat_io_error], 0
    mov si, 0x0100
    call fat_next
    cmp ax, [cs:kfat_eoc_value]
    jne .fail
    cmp byte [cs:fat_io_error], 0
    jne .fail
    mov si, msg_fat16_bounds_pass
    call serial_print
    ret
.fail:
    mov si, msg_fat16_bounds_fail
    call serial_print
    ret
%endif

init_environment:
    push ax
    push cx
    push ds
    push es
    push si
    push di
    push bx
    mov bx, ENV_PARAS
    call alloc_exec_environment
    pop bx
    jc .fail
    mov ax, [cs:exec_env_seg]
    mov es, ax
    xor di, di
    push cs
    pop ds
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
    clc
    jmp .done
.fail:
    stc
.done:
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
    mov si, env_blaster
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
    mov [es:0x2F*4], word int2f_handler
    mov [es:0x2F*4+2], cs
%if ENABLE_XMS
    mov ax, [es:0x15*4]
    mov [cs:old_int15], ax
    mov ax, [es:0x15*4+2]
    mov [cs:old_int15+2], ax
    mov [es:0x15*4], word int15_handler
    mov [es:0x15*4+2], cs
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

restore_irq1_null_mask:
    cmp byte [cs:irq1_null_mask_active], 0
    je .done
    push ax
    in al, 0x21
    and al, 0xFD
    test byte [cs:irq1_null_saved_mask], 0x02
    jz .write
    or al, 0x02
.write:
    out 0x21, al
    mov byte [cs:irq1_null_mask_active], 0
    pop ax
.done:
    ret

int20_handler:
    mov byte [cs:ret_code], 0
    mov byte [cs:ret_type], 0
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
    mov si, msg_exc_stack
    call serial_print
    mov ax, ss
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    lea ax, [bp+8]
    call serial_print_hex_word
    mov al, ' '
    call serial_putchar
    mov si, bp
    add si, 8
    mov cx, 24
.dump_stack:
    push ds
    push ss
    pop ds
    lodsw
    pop ds
    call serial_print_hex_word
    mov al, ' '
    call serial_putchar
    loop .dump_stack
    mov si, msg_crlf
    call serial_print
    mov si, msg_exc_regs
    call serial_print
    mov ax, [log_ax]
    call serial_print_hex_word
    mov ax, [bp-8]
    call serial_print_hex_word
    mov ax, [bp-4]
    call serial_print_hex_word
    mov ax, [bp-6]
    call serial_print_hex_word
    mov ax, [bp-14]
    call serial_print_hex_word
    mov ax, [bp-16]
    call serial_print_hex_word
    mov ax, [bp]
    call serial_print_hex_word
    mov ax, [bp-18]
    call serial_print_hex_word
    mov ax, es
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    cli
.exc_halt:
    hlt
    jmp .exc_halt

%include "src/kernel/mouse.inc"

%include "src/kernel/int21.inc"

int23_handler:
    mov byte [cs:ret_code], 0
    mov byte [cs:ret_type], 0
    dec byte [cs:indos_flag]
    jmp do_terminate

dos_invoke_int23:
    push ax
    push dx
    mov al, '^'
    call console_putchar
    mov al, 'C'
    call console_putchar
    mov al, 13
    call console_putchar
    mov al, 10
    call console_putchar
    int 0x23
    pop dx
    pop ax
    ret

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
    cmp ax, 64
    jbe .done
    sub ax, 64
    cmp ax, XMS_MAX_KB - 64
    jbe .store
    mov ax, XMS_MAX_KB - 64
.store:
    mov [cs:xms_total_kb], ax
.done:
    pop ax
    ret
%endif

%if ENABLE_XMS
int15_handler:
    cmp ah, 0x88
    je .ext_size
    jmp far [cs:old_int15]
.ext_size:
    push bp
    mov bp, sp
    and word [bp+6], ~CF
    pop bp
    xor ax, ax
    iret

old_int15: dw 0, 0
%endif

int2f_handler:
    cmp ax, 0x1500
    je int2f_cd_install_check
    cmp ax, 0x150B
    je int2f_cd_drive_check
    cmp ax, 0x150C
    je int2f_cd_version
    cmp ax, 0x150D
    je int2f_cd_drive_letters
    cmp ax, 0x1510
    je int2f_cd_dev_req
%if ENABLE_XMS
    cmp ax, 0x4300
    je .xms_installed
    cmp ax, 0x4310
    je .xms_entry
    cmp ax, 0x43E0
    je .xms_pool_size
    iret
.xms_installed:
    mov al, 0x80
    jmp int2f_iret_nc
.xms_entry:
    mov bx, xms_entry
    push cs
    pop es
    jmp int2f_iret_nc
.xms_pool_size:
    mov dx, [cs:xms_total_kb]
    mov al, 0x80
    jmp int2f_iret_nc
%else
    iret
%endif

%if ENABLE_XMS
xms_entry:
    cmp ah, 0x00
    je .version
    cmp ah, 0x01
    je .hma_request
    cmp ah, 0x02
    je .hma_release
    cmp ah, 0x03
    je .a20_on
    cmp ah, 0x04
    je .a20_off
    cmp ah, 0x05
    je .a20_on
    cmp ah, 0x06
    je .a20_off
    cmp ah, 0x07
    je .a20_query
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
    mov dx, 1
    retf
.hma_request:
    xor ax, ax
    mov bl, 0x91
    retf
.hma_release:
    xor ax, ax
    mov bl, 0x93
    retf
.a20_on:
    mov ax, 1
    xor bl, bl
    retf
.a20_off:
    mov ax, 1
    mov bl, 0x94
    retf
.a20_query:
    mov ax, 1
    xor bl, bl
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
    mov dx, [ds:si+2]
    test ax, 1
    jnz .move_bad_len
    mov [cs:xms_move_rem], ax
    mov [cs:xms_move_rem+2], dx
    mov bx, [ds:si+4]
    mov [cs:xms_src_handle], bx
    mov ax, [ds:si+6]
    mov dx, [ds:si+8]
    call xms_prepare_endpoint
    jc .move_bad_handle
    mov [cs:xms_src_off], ax
    mov [cs:xms_src_off+2], dx
    mov bx, [ds:si+10]
    mov [cs:xms_dst_handle], bx
    mov ax, [ds:si+12]
    mov dx, [ds:si+14]
    call xms_prepare_endpoint
    jc .move_bad_handle
    mov [cs:xms_dst_off], ax
    mov [cs:xms_dst_off+2], dx
.move_loop:
    mov ax, [cs:xms_move_rem]
    or ax, [cs:xms_move_rem+2]
    jz .move_ok
    mov ax, 0xFFFE
    cmp word [cs:xms_move_rem+2], 0
    jne .move_have_chunk
    cmp word [cs:xms_move_rem], ax
    ja .move_have_chunk
    mov ax, [cs:xms_move_rem]
.move_have_chunk:
    mov [cs:xms_move_len], ax
    shr ax, 1
    mov [cs:xms_move_words], ax
    mov bx, [cs:xms_src_handle]
    mov ax, [cs:xms_src_off]
    mov dx, [cs:xms_src_off+2]
    call xms_current_endpoint_phys
    jc .move_bad_handle
    mov [cs:xms_src_phys], ax
    mov [cs:xms_src_phys+2], dx
    mov bx, [cs:xms_dst_handle]
    mov ax, [cs:xms_dst_off]
    mov dx, [cs:xms_dst_off+2]
    call xms_current_endpoint_phys
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
; @anchor: xms_move_bios_call
    int 0x15
    jc .move_failed
    test ah, ah
    jnz .move_failed
    mov ax, [cs:xms_move_len]
    sub [cs:xms_move_rem], ax
    sbb word [cs:xms_move_rem+2], 0
    add [cs:xms_src_off], ax
    adc word [cs:xms_src_off+2], 0
    add [cs:xms_dst_off], ax
    adc word [cs:xms_dst_off+2], 0
    jmp .move_loop
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
    mov dx, 0x0011
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
xms_prepare_endpoint:
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
    add cx, [cs:xms_move_rem]
    adc di, [cs:xms_move_rem+2]
    jc .bad_pop
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

xms_current_endpoint_phys:
    test bx, bx
    jz .ok
    cmp bx, 1
    jne .bad
    add dx, 0x0011
.ok:
    clc
    ret
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
; @anchor: ems_clear_map_fill
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

restore_psp_vectors:
    push ax
    push ds
    push es
    mov ax, [cs:cur_psp]
    test ax, ax
    jz .done
    mov ds, ax
    xor ax, ax
    mov es, ax
    mov ax, [ds:0x0A]
    mov [es:0x22*4], ax
    mov ax, [ds:0x0C]
    mov [es:0x22*4+2], ax
    mov ax, [ds:0x0E]
    mov [es:0x23*4], ax
    mov ax, [ds:0x10]
    mov [es:0x23*4+2], ax
    mov ax, [ds:0x12]
    mov [es:0x24*4], ax
    mov ax, [ds:0x14]
    mov [es:0x24*4+2], ax
.done:
    pop es
    pop ds
    pop ax
    ret

do_terminate:
    push ds
    push si
    push ax
    call restore_psp_vectors
    call restore_irq1_null_mask
    mov word [cs:mouse_callback_mask], 0
    mov word [cs:mouse_callback_off], 0
    mov word [cs:mouse_callback_seg], 0
    mov byte [cs:mouse_in_callback], 0
%if ENABLE_EMS
    mov word [cs:ems_alloc_pages], 0
    call ems_clear_map
%endif
    mov word [cs:xms_alloc_kb], 0
    call release_inherited_handles
    call close_owned_handles
    mov byte [cs:console_ext_pending], 0
    mov si, [cs:mcb_first]
    MCB_WALK_EACH .dt_mcb_walk, .dt_mcb_check, .dt_mcb_next, .dt_mcb_done, .dt_mcb_done, .dt_mcb_done
.dt_mcb_check:
    mov ax, [cs:cur_psp]
    cmp word [ds:1], ax
    jne .dt_mcb_next
    mov word [ds:1], 0
    jmp .dt_mcb_next
.dt_mcb_done:
    call mcb_coalesce_all_free
    mov ax, [cs:cur_psp]
    test ax, ax
    jz .dt_parent_done
    mov ds, ax
    mov ax, [0x16]
; @anchor: do_terminate_restore_parent_psp
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
    mov ax, [cs:saved_kbase]
    mov [cs:kstack_base], ax
    sti
; @anchor: do_terminate_return_to_parent
    jmp exec_resume_parent

do_terminate_tsr:
    call restore_psp_vectors
    call restore_irq1_null_mask
    call release_inherited_handles
    call close_owned_handles
    mov byte [cs:console_ext_pending], 0
    mov word [cs:tsr_parent], 0
    mov word [cs:tsr_psp_mcb], 0
    mov word [cs:tsr_env_mcb], 0
    mov ax, [cs:cur_psp]
    test ax, ax
    jz .return_to_parent
    mov ds, ax
    mov bx, [0x16]
    mov [cs:tsr_parent], bx
    mov bx, [0x2C]
    test bx, bx
    jz .no_env_mcb
    dec bx
    mov [cs:tsr_env_mcb], bx
.no_env_mcb:
    mov si, ax
    dec si
    mov [cs:tsr_psp_mcb], si
    mov ds, si
    MCB_IS_VALID
    jne .free_extra
    cmp [ds:1], ax
    jne .free_extra
    mov bx, [cs:tsr_keep_par]
    cmp bx, 0x10
    jae .keep_size_ok
    mov bx, 0x10
.keep_size_ok:
    mov ax, [ds:3]
    cmp bx, ax
    jae .free_extra
    sub ax, bx
    cmp ax, 2
    jb .free_extra
    call mcb_split_low
    add si, bx
    inc si
    mov ds, si
    call mcb_merge_free_forward
    mov ax, [cs:cur_psp]
    mov es, ax
    add ax, bx
    mov [es:0x02], ax
.free_extra:
    call tsr_free_owned_extra
.return_to_parent:
    mov ax, [cs:tsr_parent]
    mov [cs:cur_psp], ax
    mov word [cs:running], 0
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, [cs:saved_ss]
    cli
    mov ss, ax
    mov sp, [cs:saved_sp]
    mov ax, [cs:saved_kbase]
    mov [cs:kstack_base], ax
    sti
    jmp exec_resume_parent

tsr_free_owned_extra:
    mov si, [cs:mcb_first]
    MCB_WALK_EACH .walk, .check, .next, .done, .done, .done
.check:
    mov ax, [cs:cur_psp]
    cmp [ds:1], ax
    jne .merge_if_free
    cmp si, [cs:tsr_psp_mcb]
    je .next
    cmp si, [cs:tsr_env_mcb]
    je .next
    mov word [ds:1], 0
.merge_if_free:
    cmp word [ds:1], 0
    jne .next
    call mcb_merge_free_forward
    jmp .next
.done:
    ret

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

release_inherited_handles:
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
    mov es, ax
    xor bx, bx
.loop:
    cmp bx, MAX_HANDLES
    jae .done
    mov al, [es:bx+0x18]
    cmp al, 0xFF
    je .next
    cmp al, MAX_HANDLES
    jae .next
    xor ah, ah
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 1
    jne .next
    mov ax, [cs:cur_psp]
    cmp [cs:si+handles+H_OWNER], ax
    je .next
    mov ax, [cs:si+handles+H_ALIAS]
    cmp ax, H_ALIAS_NONE
    je .dec
    cmp ax, MAX_HANDLES
    jae .next
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .next
.dec:
    cmp word [cs:si+handles+H_REFCOUNT], 0
    je .next
    dec word [cs:si+handles+H_REFCOUNT]
.next:
    inc bx
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

%include "src/kernel/cdrom.inc"

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
    mov ax, [cs:exec_env_seg]
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
    mov ax, [cs:exec_env_seg]
    dec ax
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
    mov ax, [cs:exec_env_seg]
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

msg_booted:   db "LainDOS booted", 13, 10, 0
msg_mem:      db "Conventional memory: ", 0
msg_kib:      db " KB", 13, 10, 0
msg_ints:     db "INT 20h/21h installed", 13, 10, 0
msg_badbpb:   db "Invalid BPB", 13, 10, 0
msg_a20fail:  db "A20 enable failed", 13, 10, 0
msg_nofile:   db "File not found", 13, 10, 0
msg_com_load: db "COM loaded", 13, 10, 0
msg_exe_load: db "EXE loaded", 13, 10, 0
msg_returned: db "Program exited, code=", 0
%ifdef TEST_FAT16_FAT_SECTOR_BOUNDS
msg_fat16_bounds_pass: db "PASS: FAT16BOUND", 13, 10, 0
msg_fat16_bounds_fail: db "FAIL: FAT16BOUND", 13, 10, 0
%endif
msg_crlf:     db 13, 10, 0
msg_halt:     db "HALT", 13, 10, 0
env_comspec_name: db "COMSPEC=", 0
env_path_name: db "PATH=", 0
env_shell_name: db "SHELL.COM", 0
env_bin_dir: db "BIN", 0
env_blaster: db "BLASTER=A220 I5 D1 H5 P330 T6", 0
env_prompt: db "PROMPT=$P$G", 0
dbcs_empty_table: db 0, 0
dos_sda: times 0x18 db 0
msg_unhandled: db "INT 21h AH=", 0
msg_int33:     db "INT 33h AX=", 0
msg_mouse_ps2_on: db "PS2 mouse enabled", 13, 10, 0
msg_mouse_ps2_off: db "PS2 mouse unavailable", 13, 10, 0
msg_colon:     db ":", 0
msg_exc:       db "EXC ", 0
msg_at:        db " at ", 0
msg_exc_bytes: db "BYTES ", 0
msg_exc_stack: db "STACK ", 0
msg_exc_regs:  db "REGS AX/BX/CX/DX/SI/DI/BP/DS/ES ", 0
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
msg_trace_exec: db "EXEC ", 0
msg_trace_tail: db " TAIL=", 0
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

%ifndef BOOT_FILE
%define BOOT_FILE "MEMTEST EXE"
%endif
fname_exe:   db BOOT_FILE, 0

mem_kib:   dw 0
ret_code:  db 0
ret_type:  db 0
running:   dw 0
tsr_keep_par: dw 0
tsr_parent: dw 0
tsr_psp_mcb: dw 0
tsr_env_mcb: dw 0
saved_ss:  dw 0
saved_sp:  dw 0
com_stack_top: dw 0
exec_env_seg: dw 0
exec_env_owned: db 0
exec_env_src_seg: dw 0
tn_src_seg: dw 0
tn_src_off: dw 0
tn_dst_seg: dw 0
tn_dst_off: dw 0
tn_root_off: dw 0
tn_limit_off: dw 0
tn_status: dw 0
fcb_dir_cluster: dw 0
fcb_last_idx: dw 0
fcb_attr_mask: db 0
fcb_drive_num: db 0
fcb_name: times 11 db 0
vga_row:   dw 0
vga_col:   dw 0
console_ext_pending: db 0


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
kfat_eoc: dw FAT12_EOC
kfat_eoc_value: dw FAT12_EOC_VALUE
kfat_reserved: dw FAT12_RESERVED
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
kio_op: db 0
ksc:   db 0
khd:   db 0
kcy:   dw 0
kdrv:  db 0
kdrive_type: db DRIVE_TYPE_FAT
int13_scratch: times 32 db 0
dos_drive_num: db 0
dos_drive_letter: db 'A'
dos_drive_count: db 1
active_drive_num: db 0
drive_req: db 0
drive_prev: db 0
drive_load_lba: dw 0
mbr_part_lba: dw 0
mbr_part_lba_hi: dw 0
cd_present: db 0
cd_probe_drive: db 0
cd_io_drive: db 0
cd_bios_drive: db 0
cd_read_method: db CD_READ_METHOD_BIOS
cd_seen_name: db 0
cd_lba_lo: dw 0
cd_lba_hi: dw 0
cd_root_lba_lo: dw 0
cd_root_lba_hi: dw 0
cd_root_size_lo: dw 0
cd_root_size_hi: dw 0
cd_volume_id: times 11 db ' '
cd_scan_lba_lo: dw 0
cd_scan_lba_hi: dw 0
cd_scan_sectors: dw 0
cd_sector_left: dw 0
cd_record_len: dw 0
cd_record_flags: db 0
cd_path_last: db 0
cd_dir_lba_lo: dw 0
cd_dir_lba_hi: dw 0
cd_dir_size_lo: dw 0
cd_dir_size_hi: dw 0
cd_file_lba_lo: dw 0
cd_file_lba_hi: dw 0
cd_file_size_lo: dw 0
cd_file_size_hi: dw 0
cd_find_start: dw 0
cd_empty_path: db 0
cd_dap: db 0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
atapi_base: dw 0
atapi_ctrl: dw 0
atapi_devsel: db 0
atapi_scan_base: dw 0
atapi_scan_ctrl: dw 0
atapi_scan_devsel: db 0
cd_scan_handler: dw 0
atapi_count: dw 0
atapi_cdb: times 12 db 0
atapi_limit: dw 0
cd_toc_track: db 0
cd_play_lo: dw 0
cd_play_hi: dw 0
cd_play_msf: times 6 db 0
cd_cmp_name: times 11 db 0
drive_present: times MAX_DRIVES db 0
drive_type: times MAX_DRIVES db 0
drive_bios: times MAX_DRIVES db 0
drive_kspc: times MAX_DRIVES db 0
drive_knum_fats: times MAX_DRIVES db 0
drive_kfat_bits: times MAX_DRIVES db 0
drive_krsta: times MAX_DRIVES dw 0
drive_krsc: times MAX_DRIVES dw 0
drive_kdsta: times MAX_DRIVES dw 0
drive_kbio_spt: times MAX_DRIVES dw 0
drive_kbio_heads: times MAX_DRIVES dw 0
drive_kfat_start: times MAX_DRIVES dw 0
drive_kfat_secs: times MAX_DRIVES dw 0
drive_kfat_eoc: times MAX_DRIVES dw 0
drive_kfat_eoc_value: times MAX_DRIVES dw 0
drive_kfat_reserved: times MAX_DRIVES dw 0
drive_kroot_entries: times MAX_DRIVES dw 0
drive_kroot_bytes: times MAX_DRIVES dw 0
drive_kmax_cluster: times MAX_DRIVES dw 0
drive_kpart_lba: times MAX_DRIVES dw 0
drive_kpart_lba_hi: times MAX_DRIVES dw 0
drive_bpbs: times MAX_DRIVES * 64 db 0
drive_cur_clusters: times MAX_DRIVES dw 0
drive_cur_paths: times MAX_DRIVES * 64 db 0
break_flag: db 0
verify_flag: db 0
irq1_null_mask_active: db 0
irq1_null_saved_mask: db 0
kret:  db 3
dos_first_mcb: dw MCB_START
dos_list_of_lists:
    dd 0
    dd 0
    dd 0
    dd 0
    dw 512
    dd 0
    dd 0
    dd 0
    dw 0
    db 3
    db 3
dos_nul_device:
    dw 0xFFFF, 0xFFFF
    dw 0x8004
    dw 0, 0
    db 'NUL     '
dos_joined_drives: db 0

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
date_weekday: db 4
date_month_offsets: dw 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334
time_set: db 0
time_hour: db 0
time_min: db 0
time_sec: db 0
time_hund: db 0
time_offset_lo: dw 0
time_offset_hi: dw 0
ct_hm: dw 0
ct_sh: dw 0
ct_t_lo: dw 0
ct_t_hi: dw 0
month_lengths: db 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

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
floppy_check_tick: dw 0
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
cd_full_path: times 128 db 0
cd_walk_cluster: dw 0
of_mode: db 0
of_status: dw 0
dev_type: db 0
fa_attr: db 0
fa_ret_attr: dw 0

cf_attr: db 0
cf_handle: dw 0
cf_first_cluster: dw 0
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
dir_slot_off: dw 0
dir_update_hoff: dw 0
dir_ext_old_next: dw 0
dir_ext_fail_once: db 0
%ifdef TEST_FLUSH_DIR_SLOT_FAIL
flush_dir_slot_fail_once: db 0
%endif

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
rm_trace_tail: dw 0
coh_index: dw 0

ov_param_off: dw 0
ov_param_seg: dw 0
ov_path_off: dw 0
ov_path_seg: dw 0
ov_load_seg: dw 0
ov_reloc_seg: dw 0
ov_cluster: dw 0
ov_cd_lba_hi: dw 0
ov_size_lo: dw 0
ov_size_hi: dw 0
ov_skip: dw 0
ov_left: dw 0
ov_left_hi: dw 0
fat_walk_left: dw 0
exec_env_bytes: dw 0
boot_drive_num: db 0
exec_no_run: db 0
switch_char: db '/'
ov_rel_sec_idx: dw 0
ov_rel_clus: dw 0
ov_rel_clus_base: dw 0
ov_rel_stage: db 0, 0, 0, 0
ov_rel_stage_n: dw 0
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
exec_cd_lba_hi: dw 0
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
indos_flag: db 0
kstack_seg: dw 0
kstack_base: dw 0
saved_kbase: dw 0
entry_caller_ss: dw 0
entry_caller_sp: dw 0
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

mouse_state_vars:
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
mouse_ratio_y: dw 16
mouse_scale_rem_x: dw 0
mouse_scale_rem_y: dw 0
mouse_event_dx: dw 0
mouse_event_dy: dw 0
mouse_state_vars_end:
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
mouse_release_count_l: dw 0
mouse_release_count_r: dw 0
mouse_release_x_l: dw 320
mouse_release_y_l: dw 100
mouse_release_x_r: dw 320
mouse_release_y_r: dw 100
xms_alloc_kb: dw 0
xms_move_len: dw 0
xms_move_words: dw 0
xms_move_rem: dd 0
xms_src_handle: dw 0
xms_dst_handle: dw 0
xms_src_off: dd 0
xms_dst_off: dd 0
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

int2f_cd_install_check:
    call int2f_cd_ensure
    jc .none
    mov bx, 1
    mov cx, 3
    jmp int2f_iret_nc
.none:
    xor bx, bx
    xor cx, cx
    jmp int2f_iret_nc

int2f_cd_drive_check:
    call int2f_cd_ensure
    jc .none
    mov bx, 0xADAD
    xor ax, ax
    cmp cx, 3
    jne .done
    mov ax, 1
.done:
    jmp int2f_iret_nc
.none:
    xor ax, ax
    xor bx, bx
    jmp int2f_iret_nc

int2f_cd_version:
    call int2f_cd_ensure
    jc .none
    mov bx, 0x0200
    jmp int2f_iret_nc
.none:
    xor bx, bx
    jmp int2f_iret_nc

int2f_cd_drive_letters:
    call int2f_cd_ensure
    jc .done
    mov byte [es:bx], 3
.done:
    jmp int2f_iret_nc

int2f_cd_ensure:
    cmp byte [cs:drive_present+3], 0
    jne .ok
    call mount_bios_cdrom_d
    jc .err
    mov byte [cs:dos_drive_count], 4
.ok:
    clc
    ret
.err:
    stc
    ret

int2f_iret_nc:
    push bp
    mov bp, sp
    and word [bp+6], ~CF
    pop bp
    iret

kernel_end:

%if mouse_callback_seg != (mouse_callback_off + 2)
%error "mouse callback far pointer layout changed"
%endif

%if (HMA_OFF + (kernel_end - kernel_entry)) > (KERNEL_STACK_TOP - KERNEL_STACK_GUARD_BYTES)
%error "kernel leaves too little HMA stack guard"
%endif
%if (kernel_end - kernel_entry) > ((MEM_TOP - LOAD_SEG) * 16)
%error "kernel exceeds boot load area"
%endif
%if (FAT_SEG + 0x120) > CD_BUF
%error "FAT buffer overlaps CD_BUF"
%endif
%if (CD_BUF + CD_BUF_PARAS) > SEC_BUF
%error "CD_BUF overlaps SEC_BUF"
%endif
%if (SEC_BUF + SECTOR_BUF_PARAS) > READ_CACHE_BUF
%error "SEC_BUF overlaps READ_CACHE_BUF"
%endif
%if (READ_CACHE_BUF + SECTOR_BUF_PARAS) > ROOT_SEG
%error "READ_CACHE_BUF overlaps ROOT_SEG"
%endif
%if (ROOT_SEG + ROOT_BUF_PARAS) > MCB_START
%error "ROOT_SEG overlaps MCB arena"
%endif
%if MCB_START >= MEM_TOP
%error "MCB arena is empty"
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
; @anchor: xms_backing_limit_error
%error "XMS BIOS move backing must remain below 16 MiB"
%endif
