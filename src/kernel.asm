[bits 16]
[org 0x0000]

COM1_PORT equ 0x3F8
VGA_TEXT_SEG equ 0xB800
VGA_COLS equ 80
VGA_ROWS equ 25

BPB_SEG   equ 0x0000
BPB_OFF   equ 0x7C00
FAT_SEG   equ 0x1000
ROOT_SEG  equ 0x2000
PSP_SEG   equ 0x3000
TEMP_SEG  equ 0x4000
SEC_BUF   equ 0x21C0
ENV_SEG   equ 0x21E0

HANDLE_SIZE equ 24
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
MAX_HANDLES equ 20
SMALL_ALLOC_HIGH_MAX equ 0x0020
COM_EXTRA_PAR equ 0x0110

ATTR_RDONLY equ 0x01
ATTR_VOLUME equ 0x08
ATTR_DIR equ 0x10
ROOT_ENT_CNT equ 224

MCB_SIG_M equ 'M'
MCB_SIG_Z equ 'Z'
MCB_START equ 0x2200
MEM_TOP   equ 0xA000

CF equ 0x0001
ZF equ 0x0040

ROOT_CLUSTER equ 0
FAT_TIME equ 0x6000
FAT_DATE equ 0x5CB6

%ifndef TRACE_DOS
%define TRACE_DOS 0
%endif

kernel_entry:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    cld

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
    mov word [cur_psp], PSP_SEG

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
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, [cs:kdsta]
    push es
    push bx
    mov bx, 0
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
    jmp .alloc

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

.alloc:
    push cs
    pop ds
    mov bx, [cs:prog_par]
    call alloc_mem_direct
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
    mov ax, BPB_SEG
    mov ds, ax
    mov bx, BPB_OFF

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

    mov ax, [BPB_OFF+19]
    test ax, ax
    jnz .have_total
    mov ax, [BPB_OFF+32]
.have_total:
    sub ax, [cs:kdsta]
    xor dx, dx
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
    xor ax, ax
    stosb
    stosb
    mov ax, 1
    stosw
    mov al, 'A'
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
    mov [es:0x33*4], word int33_handler
    mov [es:0x33*4+2], cs
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
    mov al, 0x01
    jmp exc_noerr
exc06_handler:
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
    cli
.exc_halt:
    hlt
    jmp .exc_halt

int33_handler:
    mov [cs:mouse_log_ax], ax
    cmp word [cs:mouse_trace_left], 0
    je .poll
    dec word [cs:mouse_trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_int33
    call serial_print
    mov ax, [cs:mouse_log_ax]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.poll:
    pusha
    call mouse_poll_ps2
    popa
.dispatch:
    cmp ax, 0x0000
    je .reset
    cmp ax, 0x0001
    je .show
    cmp ax, 0x0002
    je .hide
    cmp ax, 0x0003
    je .get_pos
    cmp ax, 0x0004
    je .set_pos
    cmp ax, 0x0005
    je .get_button_press
    cmp ax, 0x0007
    je .set_x_range
    cmp ax, 0x0008
    je .set_y_range
    cmp ax, 0x000B
    je .get_motion
    cmp ax, 0x000C
    je .set_callback
    iret
.reset:
    mov word [cs:mouse_min_x], 0
    mov word [cs:mouse_max_x], 639
    mov word [cs:mouse_min_y], 0
    mov word [cs:mouse_max_y], 199
    mov word [cs:mouse_x], 320
    mov word [cs:mouse_y], 100
    mov word [cs:mouse_buttons], 0
    mov word [cs:mouse_motion_x], 0
    mov word [cs:mouse_motion_y], 0
    mov byte [cs:mouse_packet_index], 0
    mov word [cs:mouse_press_count_l], 0
    mov word [cs:mouse_press_count_r], 0
    mov word [cs:mouse_visible_count], 0xFFFF
    mov word [cs:mouse_callback_mask], 0
    mov word [cs:mouse_callback_off], 0
    mov word [cs:mouse_callback_seg], 0
    mov ax, 0xFFFF
    mov bx, 2
    iret
.show:
    inc word [cs:mouse_visible_count]
    iret
.hide:
    dec word [cs:mouse_visible_count]
    iret
.get_pos:
    mov bx, [cs:mouse_buttons]
    mov cx, [cs:mouse_x]
    mov dx, [cs:mouse_y]
    iret
.set_pos:
    mov [cs:mouse_x], cx
    mov [cs:mouse_y], dx
    call mouse_clamp_position
    iret
.set_x_range:
    cmp cx, dx
    jbe .set_x_ordered
    xchg cx, dx
.set_x_ordered:
    mov [cs:mouse_min_x], cx
    mov [cs:mouse_max_x], dx
    call mouse_clamp_position
    iret
.set_y_range:
    cmp cx, dx
    jbe .set_y_ordered
    xchg cx, dx
.set_y_ordered:
    mov [cs:mouse_min_y], cx
    mov [cs:mouse_max_y], dx
    call mouse_clamp_position
    iret
.get_button_press:
    cmp bx, 0
    je .get_left_press
    cmp bx, 1
    je .get_right_press
    mov ax, [cs:mouse_buttons]
    xor bx, bx
    xor cx, cx
    xor dx, dx
    iret
.get_left_press:
    mov ax, [cs:mouse_buttons]
    mov bx, [cs:mouse_press_count_l]
    mov cx, [cs:mouse_press_x_l]
    mov dx, [cs:mouse_press_y_l]
    mov word [cs:mouse_press_count_l], 0
    iret
.get_right_press:
    mov ax, [cs:mouse_buttons]
    mov bx, [cs:mouse_press_count_r]
    mov cx, [cs:mouse_press_x_r]
    mov dx, [cs:mouse_press_y_r]
    mov word [cs:mouse_press_count_r], 0
    iret
.get_motion:
    mov cx, [cs:mouse_motion_x]
    mov dx, [cs:mouse_motion_y]
    mov word [cs:mouse_motion_x], 0
    mov word [cs:mouse_motion_y], 0
    iret
.set_callback:
    mov [cs:mouse_callback_mask], cx
    mov [cs:mouse_callback_off], dx
    mov [cs:mouse_callback_seg], es
    iret

mouse_clamp_position:
    mov ax, [cs:mouse_x]
    cmp ax, [cs:mouse_min_x]
    jae .x_min_ok
    mov ax, [cs:mouse_min_x]
.x_min_ok:
    cmp ax, [cs:mouse_max_x]
    jbe .x_ok
    mov ax, [cs:mouse_max_x]
.x_ok:
    mov [cs:mouse_x], ax
    mov ax, [cs:mouse_y]
    cmp ax, [cs:mouse_min_y]
    jae .y_min_ok
    mov ax, [cs:mouse_min_y]
.y_min_ok:
    cmp ax, [cs:mouse_max_y]
    jbe .y_ok
    mov ax, [cs:mouse_max_y]
.y_ok:
    mov [cs:mouse_y], ax
    ret

mouse_init_ps2:
    mov byte [cs:mouse_ps2_stage], 1
    call ps2_flush_output
    mov byte [cs:mouse_ps2_stage], 2
    call ps2_wait_write
    jc .fail
    mov al, 0xA8
    out 0x64, al
    mov byte [cs:mouse_ps2_stage], 7
    mov al, 0xF6
    call ps2_mouse_cmd
    jc .fail
    mov byte [cs:mouse_ps2_stage], 8
    mov al, 0xF4
    call ps2_mouse_cmd
    jc .fail
    mov byte [cs:mouse_ps2_stage], 9
    call ps2_wait_write
    jc .fail
    mov al, 0x60
    out 0x64, al
    call ps2_wait_write
    jc .fail
    mov al, 0x47
    out 0x60, al
    in al, 0xA1
    and al, 0xEF
    out 0xA1, al
    in al, 0x21
    and al, 0xFB
    out 0x21, al
    mov byte [cs:mouse_ps2_enabled], 1
    push ds
    push cs
    pop ds
    mov si, msg_mouse_ps2_on
    call serial_print
    pop ds
    ret
.fail:
    mov byte [cs:mouse_ps2_enabled], 0
    push ds
    push cs
    pop ds
    mov si, msg_mouse_ps2_off
    call serial_print
    mov al, [cs:mouse_ps2_stage]
    call serial_print_hex
    mov si, msg_crlf
    call serial_print
    pop ds
    ret

ps2_flush_output:
    mov cx, 32
.loop:
    in al, 0x64
    test al, 0x01
    jz .done
    in al, 0x60
    loop .loop
.done:
    ret

ps2_wait_write:
    push cx
    mov cx, 0xFFFF
.loop:
    in al, 0x64
    test al, 0x02
    jz .ok
    loop .loop
    stc
    pop cx
    ret
.ok:
    clc
    pop cx
    ret

ps2_wait_read:
    push cx
    mov cx, 0xFFFF
.loop:
    in al, 0x64
    test al, 0x01
    jnz .ok
    loop .loop
    stc
    pop cx
    ret
.ok:
    clc
    pop cx
    ret

ps2_mouse_cmd:
    mov [cs:mouse_cmd], al
    mov dl, 2
.try:
    call ps2_wait_write
    jc .fail
    mov al, 0xD4
    out 0x64, al
    call ps2_wait_write
    jc .fail
    mov al, [cs:mouse_cmd]
    out 0x60, al
    call ps2_wait_read
    jc .fail
    in al, 0x60
    cmp al, 0xFA
    je .ok
    cmp al, 0xFE
    jne .fail
    dec dl
    jnz .try
.fail:
    stc
    ret
.ok:
    clc
    ret

mouse_poll_ps2:
    cmp byte [cs:mouse_ps2_enabled], 1
    jne .done
    mov cx, 32
.loop:
    in al, 0x64
    test al, 0x01
    jz .done
    test al, 0x20
    jz .done
    in al, 0x60
    call mouse_ps2_byte
    loop .loop
.done:
    ret

mouse_ps2_byte:
    cmp byte [cs:mouse_packet_index], 0
    je .byte0
    cmp byte [cs:mouse_packet_index], 1
    je .byte1
    mov [cs:mouse_packet2], al
    mov byte [cs:mouse_packet_index], 0
    jmp .packet
.byte0:
    test al, 0x08
    jz .done
    mov [cs:mouse_packet0], al
    mov byte [cs:mouse_packet_index], 1
    ret
.byte1:
    mov [cs:mouse_packet1], al
    mov byte [cs:mouse_packet_index], 2
    ret
.packet:
    mov al, [cs:mouse_packet0]
    and al, 0x07
    xor ah, ah
    mov [cs:mouse_new_buttons], ax
    test byte [cs:mouse_packet0], 0x40
    jnz .skip_x
    mov al, [cs:mouse_packet1]
    xor ah, ah
    test byte [cs:mouse_packet0], 0x10
    jz .x_pos
    mov ah, 0xFF
.x_pos:
    add [cs:mouse_motion_x], ax
    add [cs:mouse_x], ax
.skip_x:
    test byte [cs:mouse_packet0], 0x80
    jnz .skip_y
    mov al, [cs:mouse_packet2]
    xor ah, ah
    test byte [cs:mouse_packet0], 0x20
    jz .y_pos
    mov ah, 0xFF
.y_pos:
    neg ax
    add [cs:mouse_motion_y], ax
    add [cs:mouse_y], ax
.skip_y:
    call mouse_clamp_position
    mov bx, [cs:mouse_buttons]
    mov ax, [cs:mouse_new_buttons]
    test bx, 0x0001
    jnz .left_done
    test ax, 0x0001
    jz .left_done
    inc word [cs:mouse_press_count_l]
    mov cx, [cs:mouse_x]
    mov [cs:mouse_press_x_l], cx
    mov cx, [cs:mouse_y]
    mov [cs:mouse_press_y_l], cx
.left_done:
    test bx, 0x0002
    jnz .right_done
    test ax, 0x0002
    jz .right_done
    inc word [cs:mouse_press_count_r]
    mov cx, [cs:mouse_x]
    mov [cs:mouse_press_x_r], cx
    mov cx, [cs:mouse_y]
    mov [cs:mouse_press_y_r], cx
.right_done:
    mov [cs:mouse_buttons], ax
.done:
    ret

irq12_handler:
    pusha
    push ds
    push cs
    pop ds
    in al, 0x64
    test al, 0x01
    jz .eoi
    test al, 0x20
    jz .eoi
    in al, 0x60
    call mouse_ps2_byte
.eoi:
    mov al, 0x20
    out 0xA0, al
    out 0x20, al
    pop ds
    popa
    iret

int21_handler:
    cld
    cmp ah, 0x4C
    je .terminate
    cmp ah, 0x09
    je .print_string
    cmp ah, 0x01
    je .read_char_echo
    cmp ah, 0x02
    je .print_char
    cmp ah, 0x06
    je .direct_console_io
    cmp ah, 0x07
    je .read_char_direct
    cmp ah, 0x08
    je .read_char_no_echo
    cmp ah, 0x0A
    je .read_line_buffered
    cmp ah, 0x0B
    je .stdin_status
    cmp ah, 0x00
    je .terminate
    cmp ah, 0x3B
    je .chdir
    cmp ah, 0x3C
    je .create_file
    cmp ah, 0x3D
    je .open_file
    cmp ah, 0x3E
    je .close_file
    cmp ah, 0x3F
    je .read_file
    cmp ah, 0x40
    je .write_file
    cmp ah, 0x41
    je .delete_file
    cmp ah, 0x42
    je .seek_file
    cmp ah, 0x43
    je .file_attrs
    cmp ah, 0x44
    je .ioctl
    cmp ah, 0x47
    je .get_curdir
    cmp ah, 0x48
    je .alloc_mem
    cmp ah, 0x49
    je .free_mem
    cmp ah, 0x4A
    je .resize_mem
    cmp ah, 0x4B
    je .exec
    cmp ah, 0x4D
    je .get_return_code
    cmp ah, 0x19
    je .get_drive
    cmp ah, 0x1A
    je .set_dta
    cmp ah, 0x25
    je .set_vector
    cmp ah, 0x2A
    je .get_date
    cmp ah, 0x2C
    je .get_time
    cmp ah, 0x2F
    je .get_dta
    cmp ah, 0x30
    je .get_version
    cmp ah, 0x35
    je .get_vector
    cmp ah, 0x4E
    je .find_first
    cmp ah, 0x4F
    je .find_next
    cmp ah, 0x56
    je .rename_file
    cmp ah, 0x57
    je .file_time
    cmp ah, 0x58
    je .alloc_strategy
    cmp ah, 0x62
    je .get_psp
    mov [cs:log_ax], ax
    mov [cs:log_bx], bx
    mov [cs:log_cx], cx
    mov [cs:log_dx], dx
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_unhandled
    call serial_print
    mov al, ah
    call serial_print_hex
    mov si, msg_reg_ax
    call serial_print
    mov ax, [cs:log_ax]
    call serial_print_hex_word
    mov si, msg_reg_bx
    call serial_print
    mov ax, [cs:log_bx]
    call serial_print_hex_word
    mov si, msg_reg_cx
    call serial_print
    mov ax, [cs:log_cx]
    call serial_print_hex_word
    mov si, msg_reg_dx
    call serial_print
    mov ax, [cs:log_dx]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
    mov ax, 1
    jmp iret_cy
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
    call console_putchar
    jmp .lp
.dn:
    pop ax
    pop dx
    pop si
    pop ds
    jmp iret_nc
.print_char:
    push ax
    mov al, dl
    call console_putchar
    pop ax
    mov al, dl
    jmp iret_nc
.read_char_echo:
    push bx
    push cx
    push dx
    xor ah, ah
    int 0x16
    mov dl, al
    call console_putchar
    mov ah, 0x01
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.direct_console_io:
    cmp dl, 0xFF
    je .direct_console_input
    push ax
    mov al, dl
    call console_putchar
    pop ax
    mov al, dl
    jmp iret_nc
.direct_console_input:
    push bx
    push cx
    push dx
    mov ah, 0x01
    int 0x16
    jz .direct_console_empty
    xor ah, ah
    int 0x16
    mov ah, 0x06
    pop dx
    pop cx
    pop bx
    jmp iret_nc_nz
.direct_console_empty:
    mov ax, 0x0600
    pop dx
    pop cx
    pop bx
    jmp iret_nc_zf
.read_char_direct:
    push bx
    push cx
    push dx
    xor ah, ah
    int 0x16
    mov ah, 0x07
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.read_char_no_echo:
    push bx
    push cx
    push dx
    xor ah, ah
    int 0x16
    mov ah, 0x08
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.read_line_buffered:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov si, dx
    xor cx, cx
    mov cl, [si]
    mov byte [si+1], 0
    test cl, cl
    jz .rl_done
    dec cl
    xor bx, bx
    mov di, si
    add di, 2
.rl_loop:
    xor ah, ah
    int 0x16
    test al, al
    jz .rl_loop
    cmp al, 13
    je .rl_enter
    cmp al, 8
    je .rl_backspace
    cmp bl, cl
    jae .rl_loop
    mov [di], al
    inc di
    inc bl
    call console_putchar
    jmp .rl_loop
.rl_backspace:
    test bl, bl
    jz .rl_loop
    dec di
    dec bl
    mov al, 8
    call console_putchar
    mov al, ' '
    call console_putchar
    mov al, 8
    call console_putchar
    jmp .rl_loop
.rl_enter:
    mov byte [di], 13
    mov [si+1], bl
    mov al, 13
    call console_putchar
    mov al, 10
    call console_putchar
.rl_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    jmp iret_nc
.stdin_status:
    push bx
    push cx
    push dx
    mov ah, 0x01
    int 0x16
    jz .stdin_empty
    mov ax, 0x0BFF
    jmp .stdin_done
.stdin_empty:
    mov ax, 0x0B00
.stdin_done:
    pop dx
    pop cx
    pop bx
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
    cli
    mov ds, ax
    shl bx, 2
    mov [bx], dx
    pop ax
    mov [bx+2], ax
    sti
    pop ax
    pop bx
    pop ds
    jmp iret_nc
.get_version:
    mov ax, 0x1E03
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
    mov bx, [cs:cur_psp]
    jmp iret_nc
.alloc_strategy:
    mov [cs:log_ax], ax
    mov [cs:log_bx], bx
    cmp word [cs:trace_left], 0
    je .as_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_strategy_call
    call serial_print
    mov ax, [cs:log_ax]
    call serial_print_hex_word
    mov si, msg_reg_bx
    call serial_print
    mov ax, [cs:log_bx]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.as_no_trace:
    cmp al, 0
    je .as_get
    cmp al, 1
    je .as_set
    jmp iret_nc
.as_get:
    xor ax, ax
    mov al, [cs:alloc_strat]
    jmp iret_nc
.as_set:
    mov [cs:alloc_strat], bl
    jmp iret_nc
.alloc_mem:
    push ds
    push si
    mov [cs:am_req], bx
    mov al, [cs:alloc_strat]
    and al, 0x03
    cmp al, 2
    jne .am_not_last_strategy
    jmp near .am_find_last
.am_not_last_strategy:
    cmp al, 1
    jne .am_first_strategy
    jmp near .am_find_best
.am_first_strategy:
    cmp word [cs:am_req], SMALL_ALLOC_HIGH_MAX
    ja .am_first_walk
    jmp near .am_find_last
.am_first_walk:
    mov si, [cs:mcb_first]
.am_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .am_check
    cmp byte [ds:0], MCB_SIG_Z
    je .am_check
    mov ax, 7
    jmp .am_err
.am_check:
    cmp word [ds:1], 0
    jne .am_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .am_next
.am_use:
    mov ax, [ds:3]
    sub ax, [cs:am_req]
    cmp ax, 2
    jb .am_exact
    push si
    mov di, si
    add di, [cs:am_req]
    inc di
    push di
    mov es, di
    mov al, [ds:0]
    mov byte [es:0], al
    mov word [es:1], 0
    mov cx, [ds:3]
    sub cx, [cs:am_req]
    dec cx
    mov word [es:3], cx
    mov byte [ds:0], MCB_SIG_M
    mov ax, [cs:am_req]
    mov word [ds:3], ax
    pop di
    pop si
.am_exact:
    mov ax, [cs:cur_psp]
    mov word [ds:1], ax
    mov ax, si
    inc ax
    cmp word [cs:trace_left], 0
    je .am_no_trace
    dec word [cs:trace_left]
    push ax
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_alloc
    call serial_print
    mov ax, [cs:am_req]
    call serial_print_hex_word
    mov si, msg_trace_strategy
    call serial_print
    xor ax, ax
    mov al, [cs:alloc_strat]
    call serial_print_hex_word
    mov si, msg_trace_ret
    call serial_print
    pop ds
    popa
    pop ax
    call serial_print_hex_word
    push cs
    pop ds
    mov si, msg_crlf
    call serial_print
.am_no_trace:
    pop si
    pop ds
    jmp iret_nc
.am_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .am_nomem
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .am_walk
.am_find_last:
    mov word [cs:am_best_seg], 0
    mov si, [cs:mcb_first]
.am_last_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .am_last_check
    cmp byte [ds:0], MCB_SIG_Z
    je .am_last_check
    mov ax, 7
    jmp .am_err
.am_last_check:
    cmp word [ds:1], 0
    jne .am_last_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .am_last_next
    mov [cs:am_best_seg], si
.am_last_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .am_choose_last
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .am_last_walk
.am_find_best:
    mov word [cs:am_best_seg], 0
    mov word [cs:am_best_size], 0xFFFF
    mov si, [cs:mcb_first]
.am_best_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .am_best_check
    cmp byte [ds:0], MCB_SIG_Z
    je .am_best_check
    mov ax, 7
    jmp .am_err
.am_best_check:
    cmp word [ds:1], 0
    jne .am_best_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .am_best_next
    cmp ax, [cs:am_best_size]
    jae .am_best_next
    mov [cs:am_best_size], ax
    mov [cs:am_best_seg], si
.am_best_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .am_choose_best
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .am_best_walk
.am_choose_best:
    mov si, [cs:am_best_seg]
    test si, si
    jz .am_nomem
    mov ds, si
    jmp .am_use
.am_choose_last:
    mov si, [cs:am_best_seg]
    test si, si
    jz .am_nomem
    mov ds, si
.am_use_last:
    mov cx, [ds:3]
    sub cx, [cs:am_req]
    cmp cx, 2
    jb .am_exact
    mov di, si
    add di, cx
    mov al, [ds:0]
    mov byte [ds:0], MCB_SIG_M
    dec cx
    mov [ds:3], cx
    mov es, di
    mov byte [es:0], al
    mov ax, [cs:am_req]
    mov [es:3], ax
    mov si, di
    mov ds, di
    jmp .am_exact
.am_nomem:
    mov bx, 0
    mov si, [cs:mcb_first]
.am_scan_largest:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .am_sl_check
    cmp byte [ds:0], MCB_SIG_Z
    je .am_sl_check
    jmp .am_sl_done
.am_sl_check:
    cmp word [ds:1], 0
    jne .am_sl_next
    mov ax, [ds:3]
    cmp ax, bx
    jbe .am_sl_next
    mov bx, ax
.am_sl_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .am_sl_done
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .am_scan_largest
.am_sl_done:
    mov ax, 8
.am_err:
    cmp word [cs:trace_left], 0
    je .am_err_no_trace
    dec word [cs:trace_left]
    push ax
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_alloc
    call serial_print
    mov ax, [cs:am_req]
    call serial_print_hex_word
    mov si, msg_trace_fail
    call serial_print
    pop ds
    popa
    pop ax
.am_err_no_trace:
    pop si
    pop ds
    jmp iret_cy
.free_mem:
    push ds
    push si
    mov si, es
    dec si
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .fm_ok
    cmp byte [ds:0], MCB_SIG_Z
    je .fm_ok
    mov ax, 9
    jmp .fm_err
.fm_ok:
    mov word [ds:1], 0
.fm_fwd_merge:
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov di, ax
    mov es, ax
    cmp byte [es:0], MCB_SIG_M
    je .fm_next_valid
    cmp byte [es:0], MCB_SIG_Z
    jne .fm_done
.fm_next_valid:
    cmp word [es:1], 0
    jne .fm_done
    mov cx, [es:3]
    inc cx
    add word [ds:3], cx
    mov al, [es:0]
    mov byte [ds:0], al
    jmp .fm_fwd_merge
.fm_done:
    pop si
    pop ds
    jmp iret_nc
.fm_err:
    pop si
    pop ds
    jmp iret_cy
.resize_mem:
    push ds
    push si
    push es
    push di
    mov [cs:rm_req], bx
    mov si, es
    dec si
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .rm_ok
    cmp byte [ds:0], MCB_SIG_Z
    je .rm_ok
    mov ax, 9
    jmp .rm_err
.rm_ok:
    mov ax, [ds:3]
    cmp ax, bx
    jae .rm_shrink
    mov di, si
    inc di
    add di, ax
    mov es, di
    cmp byte [es:0], MCB_SIG_M
    je .rm_next_ok
    cmp byte [es:0], MCB_SIG_Z
    jne .rm_cant_grow
.rm_next_ok:
    cmp word [es:1], 0
    jne .rm_cant_grow
    mov cx, [es:3]
    inc cx
    add ax, cx
    cmp ax, bx
    jb .rm_cant_grow
    mov dl, [es:0]
    mov byte [ds:0], dl
    add word [ds:3], cx
    mov ax, [ds:3]
    sub ax, bx
    cmp ax, 2
    jb .rm_shrink
    push es
    mov di, si
    add di, bx
    inc di
    mov es, di
    mov byte [es:0], dl
    mov byte [ds:0], MCB_SIG_M
    mov word [es:1], 0
    mov cx, [ds:3]
    sub cx, bx
    dec cx
    mov word [es:3], cx
    mov word [ds:3], bx
    pop es
    jmp .rm_done
.rm_shrink:
    mov ax, [ds:3]
    sub ax, bx
    cmp ax, 2
    jb .rm_done
    push es
    mov di, si
    add di, bx
    inc di
    mov es, di
    mov dl, [ds:0]
    mov byte [es:0], dl
    mov word [es:1], 0
    dec ax
    mov word [es:3], ax
    mov byte [ds:0], MCB_SIG_M
    mov word [ds:3], bx
    pop es
.rm_done:
    cmp word [cs:trace_left], 0
    je .rm_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    xor ax, ax
    mov al, [ds:0]
    push ax
    mov ax, [ds:3]
    push ax
    mov ax, si
    inc ax
    push ax
    push cs
    pop ds
    mov si, msg_trace_resize
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_size
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_sig
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_req
    call serial_print
    mov ax, [cs:rm_req]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.rm_no_trace:
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.rm_cant_grow:
    mov bx, ax
    mov ax, 8
.rm_err:
    cmp word [cs:trace_left], 0
    je .rm_err_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    xor ax, ax
    mov al, [ds:0]
    push ax
    mov ax, [ds:3]
    push ax
    mov ax, si
    inc ax
    push ax
    push cs
    pop ds
    mov si, msg_trace_resize
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_size
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_sig
    call serial_print
    pop ax
    call serial_print_hex_word
    mov si, msg_trace_req
    call serial_print
    mov ax, [cs:rm_req]
    call serial_print_hex_word
    mov si, msg_trace_fail
    call serial_print
    pop ds
    popa
.rm_err_no_trace:
    pop di
    pop es
    pop si
    pop ds
    jmp iret_cy
.get_date:
    mov al, 0
    mov cx, 2026
    mov dh, 5
    mov dl, 21
    jmp iret_nc
.get_time:
    mov ch, 12
    mov cl, 0
    mov dh, 0
    mov dl, 0
    jmp iret_nc
.exec:
    cmp al, 0
    je .exec_program
    cmp al, 3
    je .exec_overlay
    mov ax, 1
    jmp iret_cy
.get_return_code:
    xor ah, ah
    mov al, [cs:ret_code]
    mov byte [cs:ret_code], 0
    jmp iret_nc
.exec_program:
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    push word [cs:cur_psp]
    push word [cs:dta_seg]
    push word [cs:dta_off]
    push word [cs:saved_ss]
    push word [cs:saved_sp]
    mov [cs:exec_param_off], bx
    mov [cs:exec_param_seg], es
    mov [cs:exec_path_off], dx
    mov [cs:exec_path_seg], ds
    call load_exec_program
    jc .exec_program_err
    call update_exec_environment_path
    cmp byte [cs:exec_is_exe], 0
    jne .exec_run_exe
    call exec_com_dyn
    jmp .exec_program_returned
.exec_run_exe:
    call setup_exe_dyn
.exec_program_returned:
    pop ax
    mov [cs:saved_sp], ax
    pop ax
    mov [cs:saved_ss], ax
    pop ax
    mov [cs:dta_off], ax
    pop ax
    mov [cs:dta_seg], ax
    pop ax
    mov [cs:cur_psp], ax
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    xor ax, ax
    jmp iret_nc
.exec_program_err:
    mov [cs:exec_status], ax
    pop ax
    mov [cs:saved_sp], ax
    pop ax
    mov [cs:saved_ss], ax
    pop ax
    mov [cs:dta_off], ax
    pop ax
    mov [cs:dta_seg], ax
    pop ax
    mov [cs:cur_psp], ax
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    mov ax, [cs:exec_status]
    jmp iret_cy
.exec_overlay:
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov [cs:ov_param_off], bx
    mov [cs:ov_param_seg], es
    mov [cs:ov_path_off], dx
    mov [cs:ov_path_seg], ds
    mov bx, [cs:ov_param_off]
    mov ax, [es:bx]
    mov [cs:ov_load_seg], ax
    mov ax, [es:bx+2]
    mov [cs:ov_reloc_seg], ax
    mov ds, [cs:ov_path_seg]
    mov si, [cs:ov_path_off]
    call resolve_path
    jc .exec_overlay_nf
    mov ax, [es:di+26]
    mov [cs:ov_cluster], ax
    mov ax, [es:di+28]
    mov [cs:ov_size_lo], ax
    call load_overlay_direct
    jc .exec_overlay_err
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    xor ax, ax
    jmp iret_nc
.exec_overlay_nf:
    mov word [cs:ov_status], 2
    jmp .exec_overlay_pop_err
.exec_overlay_err:
    mov word [cs:ov_status], 1
.exec_overlay_pop_err:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    mov ax, [cs:ov_status]
    jmp iret_cy
.chdir:
    push ds
    push si
    push es
    push di
    push bx
    mov [cs:cd_path_off], dx
    mov [cs:cd_path_seg], ds
    mov si, dx
    cmp byte [ds:si], 'A'
    jb .cd_check_root
    cmp byte [ds:si], 'Z'
    ja .cd_check_root
    cmp byte [ds:si+1], ':'
    jne .cd_check_root
    add si, 2
.cd_check_root:
    cmp byte [ds:si], '\'
    je .cd_root_sep
    cmp byte [ds:si], '/'
    je .cd_root_sep
    jmp .cd_resolve
.cd_root_sep:
    inc si
.cd_root_skip:
    cmp byte [ds:si], '\'
    je .cd_root_advance
    cmp byte [ds:si], '/'
    je .cd_root_advance
    cmp byte [ds:si], 0
    je .cd_root
    jmp .cd_resolve
.cd_root_advance:
    inc si
    jmp .cd_root_skip
.cd_root:
    mov word [cs:cur_dir_cluster], ROOT_CLUSTER
    mov byte [cs:cur_dir_path], 0
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.cd_resolve:
    mov si, dx
    call resolve_path
    jc .cd_err
    test byte [es:di+11], ATTR_DIR
    jz .cd_err
    mov ax, [es:di+26]
    mov [cs:cur_dir_cluster], ax
    push cs
    pop es
    mov di, cur_dir_path
    mov cx, 62
    mov ds, [cs:cd_path_seg]
    mov si, [cs:cd_path_off]
    cmp byte [ds:si], 'A'
    jb .cd_skip_sep
    cmp byte [ds:si], 'Z'
    ja .cd_skip_sep
    cmp byte [ds:si+1], ':'
    jne .cd_skip_sep
    add si, 2
.cd_skip_sep:
    cmp byte [ds:si], '\'
    je .cd_ss
    cmp byte [ds:si], '/'
    je .cd_ss
    jmp .cd_copy
.cd_ss:
    inc si
    jmp .cd_skip_sep
.cd_copy:
    lodsb
    stosb
    dec cx
    jz .cd_trunc
    test al, al
    jnz .cd_copy
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.cd_trunc:
    mov byte [es:di-1], 0
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.cd_err:
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, 3
    jmp iret_cy
.create_file:
    push ds
    push si
    push es
    push di
    push bx
    push cx
    mov [cs:cf_attr], cl
    mov si, dx
    call parse_root_path
    jc .cr_path_err
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:pr_dir_cluster]
    call find_in_dir
    jnc .cr_existing
    mov ax, [cs:pr_dir_cluster]
    call find_dir_free
    jc .cr_no_slot
    mov [cs:cf_entry_idx], cx
    mov [cs:cf_entry_off], di
    mov byte [cs:cf_found], 0
    jmp .cr_alloc_handle
.cr_existing:
    test byte [es:di+11], ATTR_DIR
    jnz .cr_access_denied
    mov ax, [cs:ff_entry_idx]
    mov [cs:cf_entry_idx], ax
    mov [cs:cf_entry_off], di
    mov byte [cs:cf_found], 1
.cr_alloc_handle:
    mov ax, es
    mov [cs:cf_entry_seg], ax
    mov [cs:cf_entry_off], di
    call alloc_handle
    jc .cr_no_handles
    mov [cs:cf_handle], ax
    mov ax, [cs:cf_entry_seg]
    mov es, ax
    mov di, [cs:cf_entry_off]
    cmp byte [cs:cf_found], 0
    je .cr_clear_entry
    mov si, [es:di+26]
    call fat_free_chain
    call flush_fat
    jc .cr_io_err
.cr_clear_entry:
    push di
    xor ax, ax
    mov cx, 16
    cld
    rep stosw
    pop di
    push ds
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    pop ds
    mov di, [cs:cf_entry_off]
    mov al, [cs:cf_attr]
    mov [es:di+11], al
    mov word [es:di+22], FAT_TIME
    mov word [es:di+24], FAT_DATE
    mov word [es:di+26], 0
    mov word [es:di+28], 0
    mov word [es:di+30], 0
    mov ax, [cs:ff_entry_lba]
    call flush_dir_sector
    jc .cr_io_err
    mov ax, [cs:cf_handle]
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    mov byte [cs:bx+handles+H_USED], 1
    mov byte [cs:bx+handles+H_MODE], 2
    mov word [cs:bx+handles+H_CLUSTER], 0
    mov word [cs:bx+handles+H_POS_LO], 0
    mov word [cs:bx+handles+H_POS_HI], 0
    mov word [cs:bx+handles+H_SIZE_LO], 0
    mov word [cs:bx+handles+H_SIZE_HI], 0
    mov word [cs:bx+handles+H_LAST_CLUSTER], 0
    mov word [cs:bx+handles+H_LAST_INDEX], 0
    mov ax, [cs:ff_entry_lba]
    mov [cs:bx+handles+H_DIR_LBA], ax
    mov ax, [cs:ff_entry_off]
    mov [cs:bx+handles+H_DIR_OFF], ax
    mov word [cs:bx+handles+H_TIME], FAT_TIME
    mov word [cs:bx+handles+H_DATE], FAT_DATE
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, [cs:cf_handle]
    jmp iret_nc
.cr_path_err:
    mov ax, 3
    jmp .cr_err
.cr_no_slot:
    mov ax, 4
    jmp .cr_err
.cr_no_handles:
    mov ax, 4
    jmp .cr_err
.cr_access_denied:
    mov ax, 5
    jmp .cr_err
.cr_io_err:
    mov ax, 5
.cr_err:
    mov [cs:cf_status], ax
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, [cs:cf_status]
    jmp iret_cy
.open_file:
    cmp word [cs:trace_left], 0
    je .of_no_path_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push si
    push cs
    pop ds
    mov si, msg_trace_open
    call serial_print
    pop si
    pop ds
    push ds
    push si
    mov si, dx
    call serial_print
    push cs
    pop ds
    mov si, msg_crlf
    call serial_print
    pop si
    pop ds
    popa
.of_no_path_trace:
    push ds
    push si
    push cx
    push di
    mov [cs:of_mode], al
    mov si, dx
    call resolve_path
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
    mov al, [cs:of_mode]
    mov byte [cs:di+handles+H_MODE], al
    pop si
    mov ax, [es:si+26]
    mov [cs:di+handles+H_CLUSTER], ax
    mov [cs:di+handles+H_LAST_CLUSTER], ax
    mov word [cs:di+handles+H_LAST_INDEX], 0
    mov ax, [es:si+28]
    mov [cs:di+handles+H_SIZE_LO], ax
    mov ax, [es:si+30]
    mov [cs:di+handles+H_SIZE_HI], ax
    mov word [cs:di+handles+H_POS_LO], 0
    mov word [cs:di+handles+H_POS_HI], 0
    mov ax, [cs:ff_entry_lba]
    mov [cs:di+handles+H_DIR_LBA], ax
    mov ax, [cs:ff_entry_off]
    mov [cs:di+handles+H_DIR_OFF], ax
    mov ax, [es:si+22]
    mov [cs:di+handles+H_TIME], ax
    mov ax, [es:si+24]
    mov [cs:di+handles+H_DATE], ax
    pop ax
    cmp word [cs:trace_left], 0
    je .of_no_handle_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_handle
    call serial_print
    call serial_print_hex_word
    mov si, msg_trace_size
    call serial_print
    mov ax, [cs:di+handles+H_SIZE_HI]
    call serial_print_hex_word
    mov ax, [cs:di+handles+H_SIZE_LO]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.of_no_handle_trace:
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
    cmp word [cs:trace_left], 0
    je .cf_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_close
    call serial_print
    mov ax, bx
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.cf_no_trace:
    cmp bx, 5
    jb .cf_std_handle
    push bx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    cmp byte [cs:bx+handles+H_USED], 0
    je .cf_invalid_pop
    cmp byte [cs:bx+handles+H_MODE], 0
    je .cf_mark_free
    mov si, bx
    call flush_handle_dir_entry
    jc .cf_flush_err_pop
    call flush_fat
    jc .cf_flush_err_pop
.cf_mark_free:
    mov byte [cs:bx+handles+H_USED], 0
    mov byte [cs:bx+handles+H_MODE], 0
    pop bx
    jmp iret_nc
.cf_flush_err_pop:
    pop bx
    mov ax, 5
    jmp iret_cy
.cf_invalid_pop:
    pop bx
    jmp .cf_err
.cf_std_handle:
    jmp iret_nc
.cf_err:
    mov ax, 6
    jmp iret_cy
.read_file:
    cmp bx, MAX_HANDLES
    jae .rf_err
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov [cs:rf_handle], bx
    mov [cs:rf_req], cx
    mov [cs:rf_count], cx
    mov [cs:rf_buf_off], dx
    mov [cs:rf_buf_seg], ds
    mov [cs:rf_start_buf_off], dx
    mov [cs:rf_start_buf_seg], ds
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov [cs:rf_hoff], ax
    mov si, ax
    mov ax, [cs:si+handles+H_POS_LO]
    mov [cs:rf_start_lo], ax
    mov ax, [cs:si+handles+H_POS_HI]
    mov [cs:rf_start_hi], ax
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
    mov si, [cs:bx+handles+H_CLUSTER]
    mov ax, [cs:bx+handles+H_POS_LO]
    mov dx, [cs:bx+handles+H_POS_HI]
    mov cx, 9
.rf_sector_shift:
    shr dx, 1
    rcr ax, 1
    loop .rf_sector_shift
    xor ch, ch
    mov cl, [cs:kspc]
    div cx
    mov [cs:rf_sec_in_cluster], dx
    mov [cs:rf_cluster_index], ax
    mov cx, ax
    mov si, [cs:bx+handles+H_LAST_CLUSTER]
    mov ax, [cs:bx+handles+H_LAST_INDEX]
    cmp ax, cx
    je .rf_have_cluster
    inc ax
    cmp ax, cx
    jne .rf_walk_from_start
    call fat_next
    cmp ax, 0xFF8
    jae .rf_done
    cmp ax, 2
    jb .rf_err_pop
    mov si, ax
    jmp .rf_cache_cluster
.rf_walk_from_start:
    mov si, [cs:bx+handles+H_CLUSTER]
    mov cx, [cs:rf_cluster_index]
.rf_cluster_walk:
    test cx, cx
    jz .rf_cache_cluster
    call fat_next
    cmp ax, 0xFF8
    jae .rf_done
    cmp ax, 2
    jb .rf_err_pop
    mov si, ax
    loop .rf_cluster_walk
.rf_cache_cluster:
    mov bx, [cs:rf_hoff]
    mov [cs:bx+handles+H_LAST_CLUSTER], si
    mov ax, [cs:rf_cluster_index]
    mov [cs:bx+handles+H_LAST_INDEX], ax
.rf_have_cluster:
    mov ax, si
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, [cs:rf_sec_in_cluster]
    add ax, [cs:kdsta]
    cmp byte [cs:rf_cache_valid], 1
    jne .rf_read_sector
    cmp ax, [cs:rf_cache_lba]
    je .rf_have_sector
.rf_read_sector:
    mov [cs:rf_cache_lba], ax
    push es
    push bx
    xor bx, bx
    mov dx, SEC_BUF
    mov es, dx
    call read_sector
    pop bx
    pop es
    jc .rf_err_pop
    mov byte [cs:rf_cache_valid], 1
.rf_have_sector:
    mov si, [cs:rf_hoff]
    mov ax, [cs:si+handles+H_POS_LO]
    and ax, 511
    mov cx, 512
    sub cx, ax
    mov ax, [cs:rf_count]
    cmp cx, ax
    jbe .rf_got2
    mov cx, ax
.rf_got2:
    mov ax, [cs:si+handles+H_POS_HI]
    cmp ax, [cs:si+handles+H_SIZE_HI]
    jne .rf_copy_limit_done
    mov ax, [cs:si+handles+H_SIZE_LO]
    sub ax, [cs:si+handles+H_POS_LO]
    cmp cx, ax
    jbe .rf_copy_limit_done
    mov cx, ax
.rf_copy_limit_done:
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
    cmp word [cs:rf_req], 1
    je .rf_no_trace
    cmp word [cs:trace_left], 0
    je .rf_no_trace
    dec word [cs:trace_left]
    push ax
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_read
    call serial_print
    mov ax, [cs:rf_handle]
    call serial_print_hex_word
    mov si, msg_trace_req
    call serial_print
    mov ax, [cs:rf_req]
    call serial_print_hex_word
    mov si, msg_trace_pos
    call serial_print
    mov ax, [cs:rf_start_hi]
    call serial_print_hex_word
    mov ax, [cs:rf_start_lo]
    call serial_print_hex_word
    mov si, msg_trace_buf
    call serial_print
    mov ax, [cs:rf_start_buf_seg]
    call serial_print_hex_word
    mov si, msg_colon
    call serial_print
    mov ax, [cs:rf_start_buf_off]
    call serial_print_hex_word
    mov si, msg_trace_ret
    call serial_print
    mov ax, [cs:rf_read]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
    pop ax
.rf_no_trace:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.rf_err_pop:
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
.rf_err:
    mov ax, 6
    jmp iret_cy

.write_file:
    cmp bx, MAX_HANDLES
    jae .wf_invalid
    cmp bx, 5
    jb .wf_stdio
    push bx
    push cx
    push dx
    push ds
    push es
    push si
    push di
    mov [cs:wf_req], cx
    mov [cs:wf_count], cx
    mov word [cs:wf_written], 0
    mov [cs:wf_buf_off], dx
    mov [cs:wf_buf_seg], ds
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov [cs:wf_hoff], ax
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .wf_file_invalid_pop
    cmp byte [cs:si+handles+H_MODE], 0
    je .wf_file_access_pop
.wf_file_loop:
    cmp word [cs:wf_count], 0
    je .wf_file_done
    mov si, [cs:wf_hoff]
    cmp word [cs:si+handles+H_CLUSTER], 0
    jne .wf_have_start
    call fat_alloc_cluster
    jc .wf_file_done
    mov si, [cs:wf_hoff]
    mov [cs:si+handles+H_CLUSTER], ax
    mov [cs:si+handles+H_LAST_CLUSTER], ax
    mov word [cs:si+handles+H_LAST_INDEX], 0
.wf_have_start:
    mov ax, [cs:si+handles+H_POS_LO]
    mov dx, [cs:si+handles+H_POS_HI]
    mov cx, 9
.wf_sector_shift:
    shr dx, 1
    rcr ax, 1
    loop .wf_sector_shift
    xor ch, ch
    mov cl, [cs:kspc]
    div cx
    mov [cs:wf_cluster_index], ax
    mov [cs:wf_sec_in_cluster], dx
    mov cx, ax
    call wf_get_cluster
    jc .wf_file_done
    mov [cs:wf_cluster], si
    mov ax, si
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, [cs:wf_sec_in_cluster]
    add ax, [cs:kdsta]
    mov [cs:wf_sector_lba], ax
    push es
    push bx
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    pop bx
    pop es
    jc .wf_file_io_pop
    mov si, [cs:wf_hoff]
    mov di, [cs:si+handles+H_POS_LO]
    and di, 511
    mov cx, 512
    sub cx, di
    mov ax, [cs:wf_count]
    cmp cx, ax
    jbe .wf_chunk_ok
    mov cx, ax
.wf_chunk_ok:
    push cx
    push ds
    push es
    mov ax, SEC_BUF
    mov es, ax
    mov ax, [cs:wf_buf_seg]
    mov ds, ax
    mov si, [cs:wf_buf_off]
    rep movsb
    pop es
    pop ds
    pop cx
    push cx
    push es
    push bx
    mov ax, [cs:wf_sector_lba]
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call write_sector
    pop bx
    pop es
    pop cx
    jc .wf_file_io_pop
    mov byte [cs:rf_cache_valid], 0
    mov si, [cs:wf_hoff]
    add [cs:si+handles+H_POS_LO], cx
    adc word [cs:si+handles+H_POS_HI], 0
    mov ax, [cs:si+handles+H_POS_HI]
    cmp ax, [cs:si+handles+H_SIZE_HI]
    jb .wf_size_ok
    ja .wf_update_size
    mov ax, [cs:si+handles+H_POS_LO]
    cmp ax, [cs:si+handles+H_SIZE_LO]
    jbe .wf_size_ok
.wf_update_size:
    mov ax, [cs:si+handles+H_POS_LO]
    mov [cs:si+handles+H_SIZE_LO], ax
    mov ax, [cs:si+handles+H_POS_HI]
    mov [cs:si+handles+H_SIZE_HI], ax
.wf_size_ok:
    add [cs:wf_buf_off], cx
    sub [cs:wf_count], cx
    add [cs:wf_written], cx
    jmp .wf_file_loop
.wf_file_done:
    mov ax, [cs:wf_written]
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    jmp iret_nc
.wf_file_invalid_pop:
    mov ax, 6
    jmp .wf_file_err_pop
.wf_file_access_pop:
    mov ax, 5
    jmp .wf_file_err_pop
.wf_file_io_pop:
    mov ax, 5
.wf_file_err_pop:
    mov [cs:wf_status], ax
    pop di
    pop si
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    mov ax, [cs:wf_status]
    jmp iret_cy
.wf_invalid:
    mov ax, 6
    jmp iret_cy
.wf_stdio:
    push ds
    push si
    push cx
    mov si, dx
    mov [cs:wf_count], cx
.wf_loop:
    jcxz .wf_done
    lodsb
    call console_putchar
    loop .wf_loop
.wf_done:
    mov ax, [cs:wf_count]
    pop cx
    pop si
    pop ds
    jmp iret_nc

.delete_file:
    push ds
    push si
    push es
    push di
    push bx
    push cx
    mov si, dx
    call parse_root_path
    jc .df_path_err
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:pr_dir_cluster]
    call find_in_dir
    jc .df_not_found
    test byte [es:di+11], ATTR_DIR
    jnz .df_access
    test byte [es:di+11], ATTR_RDONLY
    jnz .df_access
    call entry_has_open_handle
    jc .df_access
    mov si, [es:di+26]
    mov [cs:df_first_cluster], si
    mov byte [es:di], 0xE5
    mov ax, [cs:ff_entry_lba]
    call flush_dir_sector
    jc .df_io_err
    mov si, [cs:df_first_cluster]
    call fat_free_chain
    call flush_fat
    jc .df_io_err
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.df_not_found:
    mov ax, 2
    jmp .df_err
.df_path_err:
    mov ax, 3
    jmp .df_err
.df_access:
    mov ax, 5
    jmp .df_err
.df_io_err:
    mov ax, 5
.df_err:
    mov [cs:df_status], ax
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, [cs:df_status]
    jmp iret_cy

.seek_file:
    cmp bx, MAX_HANDLES
    jae .sf_err
    push si
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
    je .sf_err_saved
    cmp byte [cs:sf_origin], 0
    je .sf_start
    cmp byte [cs:sf_origin], 1
    je .sf_cur
    cmp byte [cs:sf_origin], 2
    je .sf_end
    jmp .sf_err_saved
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
    add ax, dx
    mov [cs:si+handles+H_POS_LO], ax
    mov ax, [cs:si+handles+H_SIZE_HI]
    adc ax, cx
    mov [cs:si+handles+H_POS_HI], ax
.sf_ok:
    mov ax, [cs:si+handles+H_POS_LO]
    mov dx, [cs:si+handles+H_POS_HI]
    mov [cs:sf_ret_lo], ax
    mov [cs:sf_ret_hi], dx
    cmp word [cs:trace_left], 0
    je .sf_no_trace
    dec word [cs:trace_left]
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_trace_seek
    call serial_print
    mov ax, bx
    call serial_print_hex_word
    mov si, msg_trace_pos
    call serial_print
    mov ax, [cs:sf_ret_hi]
    call serial_print_hex_word
    mov ax, [cs:sf_ret_lo]
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.sf_no_trace:
    pop si
    jmp iret_nc
.sf_err_saved:
    pop si
.sf_err:
    mov ax, 1
    jmp iret_cy

.file_attrs:
    cmp al, 0
    je .fa_get
    cmp al, 1
    je .fa_set
    mov ax, 1
    jmp iret_cy
.fa_get:
    push ds
    push si
    push di
    mov si, dx
    call resolve_path
    jc .fa_nf
    xor ch, ch
    mov cl, [es:di+11]
    pop di
    pop si
    pop ds
    jmp iret_nc
.fa_set:
    push ds
    push si
    push di
    mov si, dx
    call resolve_path
    jc .fa_nf
    pop di
    pop si
    pop ds
    jmp iret_nc
.fa_nf:
    pop di
    pop si
    pop ds
    mov ax, 2
    jmp iret_cy

.ioctl:
    cmp al, 0
    je .ioctl_get
    mov ax, 1
    jmp iret_cy
.ioctl_get:
    cmp bx, 5
    jb .ioctl_stdio
    cmp bx, MAX_HANDLES
    jae .ioctl_bad_handle
    push bx
    push ax
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov bx, ax
    pop ax
    cmp byte [cs:bx+handles+H_USED], 0
    pop bx
    je .ioctl_bad_handle
    xor dx, dx
    jmp iret_nc
.ioctl_stdio:
    mov dx, 0x80D3
    jmp iret_nc
.ioctl_bad_handle:
    mov ax, 6
    jmp iret_cy

.get_curdir:
    push ds
    push si
    push es
    push di
    mov ax, ds
    mov es, ax
    mov di, si
    push cs
    pop ds
    mov si, cur_dir_path
.cdl:
    lodsb
    stosb
    test al, al
    jnz .cdl
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc

.find_first:
    push ds
    push si
    push cx
    push bx
    push es
    push di
    mov [cs:ff_path_off], dx
    mov [cs:ff_path_seg], ds
    mov ax, ds
    mov es, ax
    mov di, dx
    mov word [cs:ff_sep_off], 0
.ff_scan:
    mov al, [es:di]
    test al, al
    jz .ff_scan_done
    cmp al, '\'
    je .ff_sep
    cmp al, '/'
    je .ff_sep
    inc di
    jmp .ff_scan
.ff_sep:
    mov [cs:ff_sep_off], di
    inc di
    jmp .ff_scan
.ff_scan_done:
    cmp word [cs:ff_sep_off], 0
    je .ff_bare_name
.ff_has_path:
    mov ds, [cs:ff_path_seg]
    mov di, [cs:ff_sep_off]
    mov ax, [cs:ff_path_off]
    cmp ax, di
    je .ff_root_path
    mov bl, [ds:di]
    push bx
    push di
    mov byte [ds:di], 0
    mov si, [cs:ff_path_off]
    call resolve_path
    mov [cs:ff_res_es], es
    mov [cs:ff_res_di], di
    pop di
    pop bx
    mov ds, [cs:ff_path_seg]
    mov [ds:di], bl
    jc .ff_err
    mov es, [cs:ff_res_es]
    mov di, [cs:ff_res_di]
    test byte [es:di+11], ATTR_DIR
    jnz .ff_got_dir_entry
    stc
    jmp .ff_err
.ff_root_path:
    mov ds, [cs:ff_path_seg]
    mov di, [cs:ff_sep_off]
    mov bl, [ds:di]
    push bx
    push di
    mov byte [ds:di], 0
    mov si, [cs:ff_path_off]
    call resolve_path
    mov [cs:ff_res_es], es
    mov [cs:ff_res_di], di
    pop di
    pop bx
    mov ds, [cs:ff_path_seg]
    mov [ds:di], bl
    jc .ff_root_fallback
    mov es, [cs:ff_res_es]
    mov di, [cs:ff_res_di]
    test byte [es:di+11], ATTR_DIR
    jnz .ff_got_dir_entry
.ff_root_fallback:
    mov ax, ROOT_CLUSTER
    mov [cs:ff_dir_cluster], ax
    jmp .ff_after_dir
.ff_got_dir_entry:
    mov ax, [es:di+26]
    mov [cs:ff_dir_cluster], ax
.ff_after_dir:
    mov ds, [cs:ff_path_seg]
    mov si, [cs:ff_sep_off]
    inc si
    jmp .ff_parse_name
.ff_bare_name:
    mov ax, [cs:cur_dir_cluster]
    mov [cs:ff_dir_cluster], ax
    mov ds, [cs:ff_path_seg]
    mov si, [cs:ff_path_off]
.ff_parse_name:
    call parse_83name
    mov ax, [cs:dta_seg]
    mov es, ax
    mov di, [cs:dta_off]
    mov byte [es:di], 0
    mov [es:di+12], cl
    mov word [es:di+13], 0
    mov ax, [cs:ff_dir_cluster]
    mov [es:di+15], ax
    mov [cs:ff_attr_mask], cl
    inc di
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    mov ax, [cs:ff_dir_cluster]
    xor dx, dx
    call find_in_dir
    jnc .ff_found
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
    mov ax, 2
    jmp iret_cy
.ff_err:
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
    mov ax, 3
    jmp iret_cy
.ff_found:
    call store_find_dta
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
    jmp iret_nc

.find_next:
    push ds
    push si
    push cx
    push bx
    push es
    push di
    mov ax, [cs:ff_dir_cluster]
    mov bx, [cs:ff_entry_idx]
    inc bx
    call find_in_dir_from
    jnc .fn_found
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
    mov ax, 2
    jmp iret_cy
.fn_found:
    call store_find_dta
    pop di
    pop es
    pop bx
    pop cx
    pop si
    pop ds
    jmp iret_nc

.rename_file:
    push ds
    push si
    push es
    push di
    push bx
    push cx
    mov [cs:rn_new_off], di
    mov ax, es
    mov [cs:rn_new_seg], ax
    mov si, dx
    call parse_root_path
    jc .rn_path_err
    mov ax, [cs:pr_dir_cluster]
    mov [cs:rn_dir_cluster], ax
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:rn_dir_cluster]
    call find_in_dir
    jc .rn_not_found
    test byte [es:di+11], ATTR_DIR
    jnz .rn_access
    mov ax, [cs:ff_entry_idx]
    mov [cs:rn_src_idx], ax
    mov [cs:rn_src_off], di
    mov ax, [cs:ff_entry_lba]
    mov [cs:rn_src_lba], ax
    mov ax, [cs:ff_entry_off]
    mov [cs:rn_src_dir_off], ax
    mov ax, [cs:rn_new_seg]
    mov ds, ax
    mov si, [cs:rn_new_off]
    call parse_root_path
    jc .rn_path_err
    mov ax, [cs:pr_dir_cluster]
    cmp ax, [cs:rn_dir_cluster]
    jne .rn_access
    mov byte [cs:ff_attr_mask], 0
    mov ax, [cs:rn_dir_cluster]
    call find_in_dir
    jnc .rn_access
    mov ax, [cs:rn_src_lba]
    cmp ax, [cs:krsta]
    jb .rn_load_subdir
    cmp ax, [cs:kdsta]
    jae .rn_load_subdir
    mov ax, ROOT_SEG
    mov es, ax
    mov di, [cs:rn_src_off]
    jmp .rn_write_name
.rn_load_subdir:
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:rn_src_lba]
    call read_sector
    jc .rn_access
    mov di, [cs:rn_src_dir_off]
.rn_write_name:
    push cs
    pop ds
    mov si, name_buf
    mov cx, 11
    rep movsb
    mov ax, [cs:rn_src_lba]
    call flush_dir_sector
    jc .rn_access
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    jmp iret_nc
.rn_not_found:
    mov ax, 2
    jmp .rn_err
.rn_path_err:
    mov ax, 3
    jmp .rn_err
.rn_access:
    mov ax, 5
.rn_err:
    mov [cs:rn_status], ax
    pop cx
    pop bx
    pop di
    pop es
    pop si
    pop ds
    mov ax, [cs:rn_status]
    jmp iret_cy

.file_time:
    cmp bx, MAX_HANDLES
    jae .ft_bad_handle
    push si
    mov [cs:ft_mode], al
    mov [cs:ft_time], cx
    mov [cs:ft_date], dx
    mov ax, bx
    mov cx, HANDLE_SIZE
    mul cx
    mov si, ax
    cmp byte [cs:si+handles+H_USED], 0
    je .ft_bad_handle_saved
    cmp byte [cs:ft_mode], 0
    je .ft_get
    cmp byte [cs:ft_mode], 1
    je .ft_set
    pop si
    mov ax, 1
    jmp iret_cy
.ft_get:
    mov cx, [cs:si+handles+H_TIME]
    mov dx, [cs:si+handles+H_DATE]
    pop si
    jmp iret_nc
.ft_set:
    mov ax, [cs:ft_time]
    mov [cs:si+handles+H_TIME], ax
    mov ax, [cs:ft_date]
    mov [cs:si+handles+H_DATE], ax
    call flush_handle_dir_entry
    jc .ft_io_err_saved
    pop si
    jmp iret_nc
.ft_io_err_saved:
    pop si
    mov ax, 5
    jmp iret_cy
.ft_bad_handle_saved:
    pop si
.ft_bad_handle:
    mov ax, 6
    jmp iret_cy

int23_handler:
    iret

int24_handler:
    mov al, 3
    iret

do_terminate:
    push ds
    push si
    push ax
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
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .dt_mcb_walk
.dt_mcb_done:
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

alloc_mem_direct:
    push ds
    push si
    mov [cs:am_req], bx
    mov si, [cs:mcb_first]
.amd_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .amd_check
    cmp byte [ds:0], MCB_SIG_Z
    je .amd_check
    stc
    pop si
    pop ds
    ret
.amd_check:
    cmp word [ds:1], 0
    jne .amd_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .amd_next
    mov ax, [ds:3]
    sub ax, [cs:am_req]
    cmp ax, 2
    jb .amd_exact
    push si
    mov di, si
    add di, [cs:am_req]
    inc di
    push di
    mov es, di
    mov al, [ds:0]
    mov byte [es:0], al
    mov word [es:1], 0
    mov cx, [ds:3]
    sub cx, [cs:am_req]
    dec cx
    mov word [es:3], cx
    mov byte [ds:0], MCB_SIG_M
    mov ax, [cs:am_req]
    mov word [ds:3], ax
    pop di
    pop si
.amd_exact:
    mov ax, [cs:cur_psp]
    mov word [ds:1], ax
    mov ax, si
    inc ax
    pop si
    pop ds
    clc
    ret
.amd_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .amd_nomem
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .amd_walk
.amd_nomem:
    stc
    pop si
    pop ds
    ret

alloc_all_mem_direct:
    push ds
    push si
    mov [cs:am_req], bx
    mov si, [cs:mcb_first]
.aad_walk:
    mov ds, si
    cmp byte [ds:0], MCB_SIG_M
    je .aad_check
    cmp byte [ds:0], MCB_SIG_Z
    je .aad_check
    stc
    pop si
    pop ds
    ret
.aad_check:
    cmp word [ds:1], 0
    jne .aad_next
    mov ax, [ds:3]
    cmp ax, [cs:am_req]
    jb .aad_next
    mov ax, [cs:cur_psp]
    mov word [ds:1], ax
    mov ax, si
    inc ax
    pop si
    pop ds
    clc
    ret
.aad_next:
    cmp byte [ds:0], MCB_SIG_Z
    je .aad_nomem
    mov ax, si
    inc ax
    add ax, [ds:3]
    mov si, ax
    jmp .aad_walk
.aad_nomem:
    stc
    pop si
    pop ds
    ret

alloc_handle:
    push bx
    push si
    mov bx, 5
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

resolve_path:
    push bx
    mov [cs:rp_path], si
    mov [cs:rp_path_seg], ds
    cmp byte [ds:si], '\'
    je .rp_abs
    cmp byte [ds:si], '/'
    je .rp_abs
    cmp byte [ds:si], 'A'
    jb .rp_rel
    cmp byte [ds:si], 'Z'
    ja .rp_rel
    cmp byte [ds:si+1], ':'
    jne .rp_rel
.rp_abs:
    add si, 2
    cmp byte [ds:si-1], ':'
    je .rp_abs_skip
    sub si, 2
.rp_abs_skip:
    mov [cs:rp_path], si
    mov ax, ROOT_CLUSTER
    jmp .rp_walk
.rp_rel:
    mov ax, [cs:cur_dir_cluster]
.rp_walk:
    mov [cs:rp_cluster], ax
.rp_next:
    mov ds, [cs:rp_path_seg]
    mov si, [cs:rp_path]
.rp_skip_sep:
    cmp byte [ds:si], '\'
    je .rp_sep
    cmp byte [ds:si], '/'
    je .rp_sep
    jmp .rp_have_name
.rp_sep:
    inc si
    mov [cs:rp_path], si
    jmp .rp_skip_sep
.rp_have_name:
    cmp byte [ds:si], 0
    je .rp_empty
    cmp byte [ds:si], ':'
    jne .rp_parse_name
    inc si
    inc si
    mov [cs:rp_path], si
    jmp .rp_skip_sep
.rp_empty:
    cmp word [cs:rp_cluster], ROOT_CLUSTER
    je .rp_empty_root
    stc
    pop bx
    ret
.rp_empty_root:
    stc
    pop bx
    ret
.rp_parse_name:
    push ds
    push es
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    mov al, ' '
    rep stosb
    mov di, name_buf
    cld
.rp_copy:
    mov ds, [cs:rp_path_seg]
    mov si, [cs:rp_path]
    lodsb
    cmp al, 0
    je .rp_copy_end
    cmp al, '\'
    je .rp_copy_sep
    cmp al, '/'
    je .rp_copy_sep
    cmp al, 'a'
    jb .rp_no_lower
    cmp al, 'z'
    ja .rp_no_lower
    sub al, 32
.rp_no_lower:
    cmp al, '.'
    je .rp_dot
    stosb
    jmp .rp_adv
.rp_dot:
    mov di, name_buf + 8
    jmp .rp_adv
.rp_adv:
    mov [cs:rp_path], si
    jmp .rp_copy
.rp_copy_sep:
    mov [cs:rp_path], si
    pop es
    pop ds
    mov ax, [cs:rp_cluster]
    xor bx, bx
    xor dx, dx
    mov byte [cs:ff_attr_mask], 0
    call find_in_dir
    jc .rp_notfound
    test byte [es:di+11], ATTR_DIR
    jz .rp_notadir
    mov ax, [es:di+26]
    mov [cs:rp_cluster], ax
    jmp .rp_next
.rp_notadir:
    stc
    pop bx
    ret
.rp_copy_end:
    pop es
    pop ds
    mov ax, [cs:rp_cluster]
    xor bx, bx
    xor dx, dx
    mov byte [cs:ff_attr_mask], 0
    call find_in_dir
    jc .rp_notfound
    pop bx
    ret
.rp_notfound:
    stc
    pop bx
    ret

find_in_dir:
    xor bx, bx
find_in_dir_from:
    push ax
    push cx
    push ds
    push si
    mov [cs:fid_cluster], ax
    mov [cs:fid_idx], bx
.rid_loop:
    mov ax, [cs:fid_cluster]
    cmp ax, ROOT_CLUSTER
    jne .rid_subdir
    mov ax, ROOT_SEG
    mov es, ax
    mov cx, [cs:fid_idx]
    mov ax, cx
    mov dx, 32
    mul dx
    mov di, ax
    mov ax, cx
    push cx
    mov cl, 4
    shr ax, cl
    pop cx
    add ax, [cs:krsta]
    mov [cs:ff_entry_lba], ax
    mov ax, di
    and ax, 511
    mov [cs:ff_entry_off], ax
    cmp di, ROOT_ENT_CNT * 32
    jae .rid_notfound
    cmp byte [es:di], 0
    je .rid_notfound
    cmp byte [es:di], 0xE5
    je .rid_root_next
    test byte [es:di+11], ATTR_VOLUME
    jz .rid_root_matchable
    test byte [cs:ff_attr_mask], ATTR_VOLUME
    jz .rid_root_next
.rid_root_matchable:
    call name_matches
    jnc .rid_found
.rid_root_next:
    inc cx
    mov [cs:fid_idx], cx
    jmp .rid_loop
.rid_subdir:
    push bx
    push dx
    mov [cs:rid_clus], ax
    xor cx, cx
.rid_cluster_loop:
    mov si, [cs:rid_clus]
    cmp si, 0xFF8
    jae .rid_notfound_pop
    mov ax, si
    sub ax, 2
    push cx
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    pop cx
    add ax, [cs:kdsta]
    mov [cs:rid_lba], ax
    mov byte [cs:rid_sec_idx], 0
.rid_sec_loop:
    xor bx, bx
    mov dx, SEC_BUF
    mov es, dx
    mov ax, [cs:rid_lba]
    push cx
    call read_sector
    pop cx
    jc .rid_notfound_pop
    mov ax, SEC_BUF
    mov es, ax
    xor di, di
    mov bx, 16
.rid_entry:
    cmp byte [es:di], 0
    je .rid_notfound_pop
    cmp cx, [cs:fid_idx]
    jb .rid_subdir_next
    cmp byte [es:di], 0xE5
    je .rid_subdir_next
    test byte [es:di+11], ATTR_VOLUME
    jz .rid_subdir_matchable
    test byte [cs:ff_attr_mask], ATTR_VOLUME
    jz .rid_subdir_next
.rid_subdir_matchable:
    mov ax, SEC_BUF
    mov es, ax
    call name_matches
    jnc .rid_found_subdir
.rid_subdir_next:
    inc cx
    add di, 32
    dec bx
    jnz .rid_entry
.rid_next_sec:
    inc word [cs:rid_lba]
    inc byte [cs:rid_sec_idx]
    mov al, [cs:rid_sec_idx]
    cmp al, [cs:kspc]
    jb .rid_sec_loop
    mov si, [cs:rid_clus]
    call fat_next
    mov [cs:rid_clus], ax
    jmp .rid_cluster_loop
.rid_found_subdir:
    mov ax, [cs:rid_lba]
    mov [cs:ff_entry_lba], ax
    mov ax, di
    mov [cs:ff_entry_off], ax
    pop dx
    pop bx
.rid_found:
    mov al, [es:di+11]
    mov [cs:ff_entry_attr], al
    mov ax, [es:di+26]
    mov [cs:ff_entry_cluster], ax
    mov ax, [es:di+28]
    mov [cs:ff_entry_size], ax
    mov ax, [es:di+30]
    mov [cs:ff_entry_size_hi], ax
    mov [cs:ff_entry_idx], cx
    push cx
    push ds
    push si
    push di
    push es
    push es
    pop ds
    mov si, di
    push cs
    pop es
    mov di, ff_entry_name
    mov cx, 11
    rep movsb
    pop es
    pop di
    pop si
    pop ds
    pop cx
    pop si
    pop ds
    pop cx
    pop ax
    clc
    ret
.rid_notfound_pop:
    pop dx
    pop bx
.rid_notfound:
    pop si
    pop ds
    pop cx
    pop ax
    stc
    ret

find_root_free:
    push ax
    mov ax, ROOT_SEG
    mov es, ax
    xor di, di
    xor cx, cx
.loop:
    cmp cx, ROOT_ENT_CNT
    jae .full
    cmp byte [es:di], 0
    je .found
    cmp byte [es:di], 0xE5
    je .found
    add di, 32
    inc cx
    jmp .loop
.found:
    pop ax
    clc
    ret
.full:
    pop ax
    stc
    ret

root_entry_loc_from_cx:
    push ax
    push cx
    push dx
    mov ax, cx
    mov dx, ax
    shr ax, 1
    shr ax, 1
    shr ax, 1
    shr ax, 1
    add ax, [cs:krsta]
    mov [cs:ff_entry_lba], ax
    mov ax, dx
    and ax, 0x000F
    mov dx, 32
    mul dx
    mov [cs:ff_entry_off], ax
    pop dx
    pop cx
    pop ax
    ret

find_dir_free:
    cmp ax, ROOT_CLUSTER
    jne .subdir
    call find_root_free
    jc .err
    call root_entry_loc_from_cx
    clc
    ret
.subdir:
    push bx
    push dx
    push si
    mov [cs:rid_clus], ax
    mov word [cs:ff_entry_idx], 0
.sd_cluster_loop:
    mov si, [cs:rid_clus]
    cmp si, 0x0FF8
    jae .sd_full
    cmp si, 2
    jb .sd_full
    mov ax, si
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, [cs:kdsta]
    mov [cs:rid_lba], ax
    mov byte [cs:rid_sec_idx], 0
.sd_sector:
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    mov ax, [cs:rid_lba]
    call read_sector
    jc .sd_full
    mov ax, SEC_BUF
    mov es, ax
    xor di, di
    mov cx, 16
.sd_entry:
    cmp byte [es:di], 0
    je .sd_found
    cmp byte [es:di], 0xE5
    je .sd_found
    add di, 32
    inc word [cs:ff_entry_idx]
    loop .sd_entry
    inc word [cs:rid_lba]
    inc byte [cs:rid_sec_idx]
    mov al, [cs:rid_sec_idx]
    cmp al, [cs:kspc]
    jb .sd_sector
    mov si, [cs:rid_clus]
    call fat_next
    mov [cs:rid_clus], ax
    jmp .sd_cluster_loop
.sd_found:
    mov ax, [cs:rid_lba]
    mov [cs:ff_entry_lba], ax
    mov [cs:ff_entry_off], di
    mov cx, [cs:ff_entry_idx]
    pop si
    pop dx
    pop bx
    clc
    ret
.sd_full:
    pop si
    pop dx
    pop bx
.err:
    stc
    ret

parse_83name:
    push ax
    push bx
    push cx
    push di
    push ds
    push es
    push cs
    pop es
    mov di, name_buf
    mov cx, 11
    mov al, ' '
    rep stosb
    mov di, name_buf
    xor bx, bx
.pl:
    lodsb
    test al, al
    jz .pl_done
    cmp al, '.'
    je .pl_dot
    cmp al, '*'
    je .pl_star
    cmp al, 'a'
    jb .pl_noupper
    cmp al, 'z'
    ja .pl_noupper
    sub al, 32
.pl_noupper:
    test bx, bx
    jnz .pl_ext_char
    cmp di, name_buf + 8
    jae .pl
    stosb
    jmp .pl
.pl_ext_char:
    cmp di, name_buf + 11
    jae .pl
    stosb
    jmp .pl
.pl_dot:
    mov bx, 1
    mov di, name_buf + 8
    jmp .pl
.pl_star:
    test bx, bx
    jnz .pl_ext_star
.pl_name_star_fill:
    cmp di, name_buf + 8
    jae .pl_skip_to_dot
    mov byte [es:di], '?'
    inc di
    jmp .pl_name_star_fill
.pl_skip_to_dot:
    lodsb
    test al, al
    jz .pl_done
    cmp al, '.'
    jne .pl_skip_to_dot
    jmp .pl_dot
.pl_ext_star:
    cmp di, name_buf + 11
    jae .pl_skip_ext
    mov byte [es:di], '?'
    inc di
    jmp .pl_ext_star
.pl_skip_ext:
    lodsb
    test al, al
    jnz .pl_skip_ext
.pl_done:
    pop es
    pop ds
    pop di
    pop cx
    pop bx
    pop ax
    ret

parse_root_path:
    push ax
    push bx
    push dx
    mov byte [cs:pr_abs], 0
    mov ax, [cs:cur_dir_cluster]
    mov [cs:pr_dir_cluster], ax
    cmp byte [ds:si], 'A'
    jb .check_sep
    cmp byte [ds:si], 'Z'
    ja .check_sep
    cmp byte [ds:si+1], ':'
    jne .check_sep
    add si, 2
.check_sep:
    cmp byte [ds:si], '\'
    je .sep
    cmp byte [ds:si], '/'
    jne .after_sep
.sep:
    mov byte [cs:pr_abs], 1
    mov word [cs:pr_dir_cluster], ROOT_CLUSTER
    inc si
    jmp .check_sep
.after_sep:
    cmp byte [ds:si], 0
    je .err
    mov [cs:pr_name_off], si
    mov bx, si
.scan:
    mov al, [ds:bx]
    test al, al
    jz .parse
    cmp al, '\'
    je .err
    cmp al, '/'
    je .err
    inc bx
    jmp .scan
.parse:
    mov si, [cs:pr_name_off]
    call parse_83name
    pop dx
    pop bx
    pop ax
    clc
    ret
.err:
    pop dx
    pop bx
    pop ax
    stc
    ret

name_matches:
    push ax
    push bx
    push cx
    push ds
    push si
    push cs
    pop ds
    mov si, name_buf
    mov bx, di
    mov cx, 11
.nm_loop:
    lodsb
    cmp al, '?'
    je .nm_ok
    cmp al, [es:bx]
    jne .nm_no
.nm_ok:
    inc bx
    loop .nm_loop
    clc
    jmp .nm_done
.nm_no:
    stc
.nm_done:
    pop si
    pop ds
    pop cx
    pop bx
    pop ax
    ret

store_find_dta:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    mov ax, [cs:dta_seg]
    mov es, ax
    mov di, [cs:dta_off]
    mov ax, [cs:ff_entry_idx]
    mov [es:di+13], ax
    mov ax, [cs:ff_dir_cluster]
    mov [es:di+15], ax
    mov al, [cs:ff_entry_attr]
    mov [es:di+21], al
    mov word [es:di+22], 0
    mov word [es:di+24], 0
    mov ax, [cs:ff_entry_size]
    mov [es:di+26], ax
    mov ax, [cs:ff_entry_size_hi]
    mov [es:di+28], ax
    add di, 30
    push cs
    pop ds
    mov si, ff_entry_name
    mov cx, 8
.sfd_name:
    lodsb
    cmp al, ' '
    je .sfd_name_done
    stosb
    loop .sfd_name
.sfd_name_done:
    mov si, ff_entry_name + 8
    mov bx, si
    mov cx, 3
.sfd_ext_check:
    cmp byte [bx], ' '
    jne .sfd_ext_yes
    inc bx
    loop .sfd_ext_check
    jmp .sfd_term
.sfd_ext_yes:
    mov al, '.'
    stosb
    mov si, ff_entry_name + 8
    mov cx, 3
.sfd_ext:
    lodsb
    cmp al, ' '
    je .sfd_term
    stosb
    loop .sfd_ext
.sfd_term:
    xor al, al
    stosb
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    ret

load_file_direct:
.load:
    cmp si, 0xFF8
    jae .done
    cmp si, 2
    jb .err
    push si
    mov ax, si
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, [cs:kdsta]
    mov [cs:.sec_num], ax
    pop si
    xor ch, ch
    mov cl, [cs:kspc]
.sec_loop:
    push cx
    push si
    mov ax, [cs:.sec_num]
    push es
    push bx
    mov bx, 0
    mov dx, SEC_BUF
    mov es, dx
    mov cx, 1
    call read_sector
    pop bx
    pop es
    jc .err_pop2
    push ds
    push si
    push di
    mov dx, SEC_BUF
    mov ds, dx
    xor si, si
    mov di, bx
    mov cx, 512
    rep movsb
    pop di
    pop si
    pop ds
    add bx, 512
    jnc .adv_ok
    mov ax, es
    add ax, 0x1000
    mov es, ax
.adv_ok:
    inc word [cs:.sec_num]
    pop si
    pop cx
    loop .sec_loop
    call fat_next
    mov si, ax
    jmp .load
.done:
    push cs
    pop ds
    xor ax, ax
    ret
.err_pop2:
    pop si
.err:
    push cs
    pop ds
    mov ax, 1
    ret

.sec_num: dw 0

load_file:
    mov [cs:load_name], si
    mov [cs:load_seg], ax
    mov [cs:load_off], bx

    push cs
    pop ds
    mov si, [cs:load_name]
    call resolve_path
    jc .notfound
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
.notfound:
    push cs
    pop ds
    mov si, msg_nofile
    call serial_print
    mov ax, 1
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

fat_set:
    push bx
    push dx
    push ds
    mov dx, ax
    mov bx, si
    shr bx, 1
    add bx, si
    mov ax, FAT_SEG
    mov ds, ax
    mov ax, dx
    and ax, 0x0FFF
    test si, 1
    jnz .odd
    mov [bx], al
    mov dl, ah
    and dl, 0x0F
    and byte [bx+1], 0xF0
    or [bx+1], dl
    jmp .done
.odd:
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    and byte [bx], 0x0F
    or [bx], al
    mov [bx+1], ah
.done:
    mov byte [cs:fat_dirty], 1
    pop ds
    pop dx
    pop bx
    ret

fat_alloc_cluster:
    push cx
    push si
    mov cx, 2
.loop:
    cmp cx, [cs:kmax_cluster]
    jae .none
    mov si, cx
    call fat_next
    test ax, ax
    jz .found
    inc cx
    jmp .loop
.found:
    mov si, cx
    mov ax, 0x0FFF
    call fat_set
    mov ax, cx
    pop si
    pop cx
    clc
    ret
.none:
    pop si
    pop cx
    stc
    ret

fat_free_chain:
    push ax
    push bx
    push si
    cmp si, 2
    jb .done
.loop:
    mov bx, si
    call fat_next
    push ax
    mov si, bx
    xor ax, ax
    call fat_set
    pop ax
    cmp ax, 0x0FF8
    jae .done
    cmp ax, 2
    jb .done
    mov si, ax
    jmp .loop
.done:
    pop si
    pop bx
    pop ax
    ret

flush_fat:
    cmp byte [cs:fat_dirty], 0
    je .clean
    push ax
    push bx
    push cx
    push dx
    push es
    mov byte [cs:fat_copy_idx], 0
    mov ax, [cs:kfat_start]
    mov [cs:fat_flush_lba], ax
.copy_loop:
    xor ax, ax
    mov al, [cs:knum_fats]
    cmp [cs:fat_copy_idx], al
    jae .done
    mov word [cs:fat_flush_off], 0
    mov cx, [cs:kfat_secs]
.sector_loop:
    test cx, cx
    jz .next_copy
    mov ax, FAT_SEG
    mov es, ax
    mov bx, [cs:fat_flush_off]
    mov ax, [cs:fat_flush_lba]
    push cx
    call write_sector
    pop cx
    jc .err
    inc word [cs:fat_flush_lba]
    add word [cs:fat_flush_off], 512
    dec cx
    jmp .sector_loop
.next_copy:
    inc byte [cs:fat_copy_idx]
    jmp .copy_loop
.done:
    mov byte [cs:fat_dirty], 0
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
.clean:
    clc
    ret
.err:
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    stc
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

write_sector:
    mov [cs:klba], ax
    mov byte [cs:kcnt], 1
    mov byte [cs:kret], 3
.w1:
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
    mov ah, 3
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
    jnz .w1
    stc
    ret
.ok:
    add bx, 512
    jnc .wnb
    mov ax, es
    add ax, 0x1000
    mov es, ax
.wnb:
    inc word [cs:klba]
    dec byte [cs:kcnt]
    jnz .w1
    clc
    ret

flush_root_sector:
    push ax
    push bx
    push es
    mov [cs:dir_flush_lba], ax
    sub ax, [cs:krsta]
    mov bx, ax
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    mov ax, ROOT_SEG
    mov es, ax
    mov ax, [cs:dir_flush_lba]
    call write_sector
    pop es
    pop bx
    pop ax
    ret

flush_dir_sector:
    mov [cs:dir_flush_lba], ax
    cmp ax, [cs:krsta]
    jb .subdir
    cmp ax, [cs:kdsta]
    jae .subdir
    call flush_root_sector
    ret
.subdir:
    push ax
    push bx
    push es
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:dir_flush_lba]
    call write_sector
    pop es
    pop bx
    pop ax
    ret

flush_handle_dir_entry:
    push ax
    push bx
    push dx
    push es
    push di
    mov [cs:dir_update_hoff], si
    mov ax, [cs:si+handles+H_DIR_LBA]
    test ax, ax
    jz .ok
    mov [cs:dir_flush_lba], ax
    cmp ax, [cs:krsta]
    jb .subdir
    cmp ax, [cs:kdsta]
    jae .subdir
    sub ax, [cs:krsta]
    mov bx, ax
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    mov ax, ROOT_SEG
    mov es, ax
    mov di, bx
    mov si, [cs:dir_update_hoff]
    add di, [cs:si+handles+H_DIR_OFF]
    call store_handle_dir_fields
    mov ax, [cs:dir_flush_lba]
    call flush_root_sector
    jmp .done
.subdir:
    mov ax, SEC_BUF
    mov es, ax
    xor bx, bx
    mov ax, [cs:dir_flush_lba]
    call read_sector
    jc .done
    mov si, [cs:dir_update_hoff]
    mov di, [cs:si+handles+H_DIR_OFF]
    call store_handle_dir_fields
    mov ax, [cs:dir_flush_lba]
    mov bx, 0
    call write_sector
.done:
    pop di
    pop es
    pop dx
    pop bx
    pop ax
    ret
.ok:
    pop di
    pop es
    pop dx
    pop bx
    pop ax
    clc
    ret

store_handle_dir_fields:
    push ax
    mov ax, [cs:si+handles+H_TIME]
    mov [es:di+22], ax
    mov ax, [cs:si+handles+H_DATE]
    mov [es:di+24], ax
    mov ax, [cs:si+handles+H_CLUSTER]
    mov [es:di+26], ax
    mov ax, [cs:si+handles+H_SIZE_LO]
    mov [es:di+28], ax
    mov ax, [cs:si+handles+H_SIZE_HI]
    mov [es:di+30], ax
    pop ax
    ret

entry_has_open_handle:
    push ax
    push bx
    push cx
    xor bx, bx
    mov cx, MAX_HANDLES
.loop:
    cmp byte [cs:bx+handles+H_USED], 0
    je .next
    mov ax, [cs:ff_entry_lba]
    cmp [cs:bx+handles+H_DIR_LBA], ax
    jne .next
    mov ax, [cs:ff_entry_off]
    cmp [cs:bx+handles+H_DIR_OFF], ax
    je .found
.next:
    add bx, HANDLE_SIZE
    loop .loop
    pop cx
    pop bx
    pop ax
    clc
    ret
.found:
    pop cx
    pop bx
    pop ax
    stc
    ret

wf_get_cluster:
    push ax
    push bx
    push cx
    push dx
    mov bx, [cs:wf_hoff]
    mov si, [cs:bx+handles+H_LAST_CLUSTER]
    mov cx, [cs:bx+handles+H_LAST_INDEX]
    cmp si, 0
    je .from_start
    cmp cx, [cs:wf_cluster_index]
    jbe .walk
.from_start:
    mov bx, [cs:wf_hoff]
    mov si, [cs:bx+handles+H_CLUSTER]
    xor cx, cx
.walk:
    cmp cx, [cs:wf_cluster_index]
    je .found
    mov bx, si
    call fat_next
    cmp ax, 0x0FF8
    jae .extend
    cmp ax, 0x0FF0
    jae .err
    cmp ax, 2
    jb .err
    cmp ax, [cs:kmax_cluster]
    jae .err
    jmp .have_next
.extend:
    call fat_alloc_cluster
    jc .err
    push ax
    mov si, bx
    call fat_set
    pop ax
.have_next:
    mov si, ax
    inc cx
    jmp .walk
.found:
    mov bx, [cs:wf_hoff]
    mov [cs:bx+handles+H_LAST_CLUSTER], si
    mov [cs:bx+handles+H_LAST_INDEX], cx
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err:
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

load_exec_program:
    mov ds, [cs:exec_path_seg]
    mov si, [cs:exec_path_off]
    call resolve_path
    jnc .found
    mov ax, 2
    stc
    ret
.found:
    mov byte [cs:exec_is_exe], 0
    mov ax, [es:di+26]
    mov [cs:exec_cluster], ax
    mov ax, [es:di+28]
    mov [cs:kfsize], ax
    mov ax, [es:di+30]
    mov [cs:kfsize_hi], ax
    call exec_read_first_sector
    jc .io_err
    mov ax, SEC_BUF
    mov ds, ax
    cmp word [0], 0x5A4D
    jne .com_size
    mov byte [cs:exec_is_exe], 1
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 15
    adc dx, 0
    mov cx, 4
.exe_min_shift:
    shr dx, 1
    rcr ax, 1
    loop .exe_min_shift
    sub ax, [0x08]
    add ax, [0x0A]
    add ax, 0x10
    mov [cs:exe_min_par], ax
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 511
    adc dx, 0
    mov cx, 9
.exe_file_shr:
    shr dx, 1
    rcr ax, 1
    loop .exe_file_shr
    mov cx, 5
.exe_file_shl:
    shl ax, 1
    rcl dx, 1
    loop .exe_file_shl
    add ax, 0x12
    adc dx, 0
    test dx, dx
    jz .exe_size_ok
    mov ax, 8
    stc
    ret
.exe_size_ok:
    cmp ax, [cs:exe_min_par]
    jae .exe_use_file
    mov ax, [cs:exe_min_par]
.exe_use_file:
    mov [cs:prog_par], ax
    jmp .alloc
.com_size:
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 511
    adc dx, 0
    mov cx, 9
.shr9:
    shr dx, 1
    rcr ax, 1
    loop .shr9
    mov cx, 5
.shl5:
    shl ax, 1
    rcl dx, 1
    loop .shl5
    add ax, COM_EXTRA_PAR
    adc dx, 0
    test dx, dx
    jz .com_size_ok
    mov ax, 8
    stc
    ret
.com_size_ok:
    mov [cs:prog_par], ax
.alloc:
    push cs
    pop ds
    mov bx, [cs:prog_par]
    cmp byte [cs:exec_is_exe], 0
    je .alloc_fixed
    call alloc_all_mem_direct
    jnc .alloc_ok
    mov ax, 8
    stc
    ret
.alloc_fixed:
    call alloc_mem_direct
    jnc .alloc_ok
    mov ax, 8
    stc
    ret
.alloc_ok:
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
    mov si, [cs:exec_cluster]
    call load_file_direct
    cmp ax, 0
    je .loaded
    call free_prog_mcb
.io_err:
    mov ax, 1
    stc
    ret
.loaded:
    cmp byte [cs:exec_is_exe], 0
    jne .loaded_done
    mov ax, [cs:prog_seg]
    call build_psp
    call exec_copy_command_tail
.loaded_done:
    xor ax, ax
    clc
    ret

exec_read_first_sector:
    push bx
    push cx
    push dx
    push es
    mov ax, [cs:exec_cluster]
    cmp ax, 2
    jb .err
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, [cs:kdsta]
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    jc .err
    pop es
    pop dx
    pop cx
    pop bx
    clc
    ret
.err:
    pop es
    pop dx
    pop cx
    pop bx
    stc
    ret

exec_copy_command_tail:
    push ax
    push bx
    push cx
    push ds
    push es
    push si
    push di
    mov ax, [cs:prog_seg]
    mov es, ax
    mov word [es:0x80], 0x0D00
    mov ax, [cs:exec_param_seg]
    test ax, ax
    jz .done
    mov ds, ax
    mov bx, [cs:exec_param_off]
    mov si, [bx+2]
    mov ax, [bx+4]
    test ax, ax
    jz .done
    mov ds, ax
    mov ax, [cs:prog_seg]
    mov es, ax
    mov di, 0x80
    mov cx, 128
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

update_exec_environment_path:
    push ax
    push cx
    push ds
    push es
    push si
    push di
    mov ax, ENV_SEG
    mov es, ax
    xor di, di
    xor ax, ax
    stosb
    stosb
    mov ax, 1
    stosw
    mov al, 'A'
    stosb
    mov al, ':'
    stosb
    mov al, '\'
    stosb
    mov ds, [cs:exec_path_seg]
    mov si, [cs:exec_path_off]
    cmp byte [ds:si+1], ':'
    jne .skip_sep
    add si, 2
.skip_sep:
    cmp byte [ds:si], '\'
    je .skip_one_sep
    cmp byte [ds:si], '/'
    jne .copy
.skip_one_sep:
    inc si
    jmp .skip_sep
.copy:
    mov cx, 80
.copy_loop:
    lodsb
    test al, al
    jz .done
    cmp al, '/'
    je .slash
    cmp al, '\'
    je .slash
    cmp al, 'a'
    jb .store
    cmp al, 'z'
    ja .store
    sub al, 32
    jmp .store
.slash:
    mov al, '\'
.store:
    stosb
    loop .copy_loop
.done:
    xor al, al
    stosb
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop ax
    ret

free_prog_mcb:
    push ax
    push ds
    mov ax, [cs:prog_seg]
    test ax, ax
    jz .done
    dec ax
    mov ds, ax
    cmp byte [ds:0], MCB_SIG_M
    je .free
    cmp byte [ds:0], MCB_SIG_Z
    jne .done
.free:
    mov word [ds:1], 0
.done:
    pop ds
    pop ax
    ret

load_overlay_direct:
    call overlay_read_first_sector
    jc .err
    push ds
    mov ax, SEC_BUF
    mov ds, ax
    cmp word [0], 0x5A4D
    je .mz
    pop ds
    mov word [cs:ov_skip], 0
    mov ax, [cs:ov_size_lo]
    mov [cs:ov_left], ax
    mov ax, [cs:ov_load_seg]
    mov [cs:ov_dst_seg], ax
    mov word [cs:ov_dst_off], 0
    call overlay_copy_range
    ret
.mz:
    mov ax, [0x08]
    mov cx, 4
.hdr_shift:
    shl ax, 1
    loop .hdr_shift
    mov [cs:ov_skip], ax
    mov ax, [cs:ov_size_lo]
    sub ax, [cs:ov_skip]
    jc .mz_bad_pop
    mov [cs:ov_left], ax
    mov ax, [0x06]
    mov [cs:ov_reloc_count], ax
    mov ax, [0x18]
    mov [cs:ov_reloc_off], ax
    pop ds
    mov ax, [cs:ov_load_seg]
    mov [cs:ov_dst_seg], ax
    mov word [cs:ov_dst_off], 0
    call overlay_copy_range
    jc .err
    call overlay_apply_relocs
    ret
.mz_bad_pop:
    pop ds
.err:
    stc
    ret

overlay_apply_relocs:
    push ax
    push bx
    push cx
    push ds
    push es
    push di
    mov cx, [cs:ov_reloc_count]
    test cx, cx
    jz .done
.loop:
    call overlay_read_reloc_sector
    jc .err
    push ds
    mov ax, SEC_BUF
    mov ds, ax
    mov bx, [cs:ov_reloc_off]
    and bx, 511
    cmp bx, 508
    ja .entry_crosses_sector
    mov di, [bx]
    mov ax, [bx+2]
    pop ds
    add ax, [cs:ov_load_seg]
    mov es, ax
    mov ax, [es:di]
    add ax, [cs:ov_reloc_seg]
    mov [es:di], ax
    add word [cs:ov_reloc_off], 4
    loop .loop
.done:
    pop di
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    clc
    ret
.entry_crosses_sector:
    pop ds
.err:
    pop di
    pop es
    pop ds
    pop cx
    pop bx
    pop ax
    stc
    ret

overlay_read_reloc_sector:
    push ax
    push bx
    push cx
    push dx
    push si
    push es
    mov si, [cs:ov_cluster]
    mov ax, [cs:ov_reloc_off]
    mov cx, 9
.sector_shift:
    shr ax, 1
    loop .sector_shift
    mov bx, ax
.cluster_walk:
    xor ch, ch
    mov cl, [cs:kspc]
    cmp bx, cx
    jb .read_sector
    sub bx, cx
    call fat_next
    cmp ax, 0xFF8
    jae .err
    cmp ax, 2
    jb .err
    mov si, ax
    jmp .cluster_walk
.read_sector:
    mov ax, si
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, bx
    add ax, [cs:kdsta]
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    jc .err
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err:
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

overlay_read_first_sector:
    push bx
    push cx
    push dx
    push es
    mov ax, [cs:ov_cluster]
    cmp ax, 2
    jb .err
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, [cs:kdsta]
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    jc .err
    pop es
    pop dx
    pop cx
    pop bx
    clc
    ret
.err:
    pop es
    pop dx
    pop cx
    pop bx
    stc
    ret

overlay_copy_range:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    mov si, [cs:ov_cluster]
    mov ax, [cs:ov_skip]
    mov dx, ax
    and dx, 511
    mov [cs:ov_sector_offset], dx
    mov cx, 9
.sector_shift:
    shr ax, 1
    loop .sector_shift
    mov bx, ax
.skip_cluster_loop:
    xor ch, ch
    mov cl, [cs:kspc]
    cmp bx, cx
    jb .have_sector
    sub bx, cx
    call fat_next
    cmp ax, 0xFF8
    jae .err_pop
    cmp ax, 2
    jb .err_pop
    mov si, ax
    jmp .skip_cluster_loop
.have_sector:
    mov [cs:ov_sec_in_cluster], bx
.copy_loop:
    mov ax, [cs:ov_left]
    test ax, ax
    jz .done
    cmp si, 0xFF8
    jae .err_pop
    cmp si, 2
    jb .err_pop
    push si
    mov ax, si
    sub ax, 2
    xor ch, ch
    mov cl, [cs:kspc]
    mul cx
    add ax, [cs:ov_sec_in_cluster]
    add ax, [cs:kdsta]
    mov dx, SEC_BUF
    mov es, dx
    xor bx, bx
    call read_sector
    pop si
    jc .err_pop
    mov cx, 512
    sub cx, [cs:ov_sector_offset]
    mov ax, [cs:ov_left]
    cmp cx, ax
    jbe .chunk_ok
    mov cx, ax
.chunk_ok:
    mov [cs:ov_chunk], cx
    push si
    mov ax, SEC_BUF
    mov ds, ax
    mov si, [cs:ov_sector_offset]
    mov ax, [cs:ov_dst_seg]
    mov es, ax
    mov di, [cs:ov_dst_off]
    rep movsb
    pop si
    mov ax, [cs:ov_dst_off]
    add ax, [cs:ov_chunk]
    mov [cs:ov_dst_off], ax
    jnc .dst_no_wrap
    add word [cs:ov_dst_seg], 0x1000
.dst_no_wrap:
    mov ax, [cs:ov_chunk]
    sub [cs:ov_left], ax
    mov word [cs:ov_sector_offset], 0
    inc word [cs:ov_sec_in_cluster]
    xor ch, ch
    mov cl, [cs:kspc]
    cmp [cs:ov_sec_in_cluster], cx
    jb .copy_loop
    call fat_next
    cmp ax, 0xFF8
    jae .done
    cmp ax, 2
    jb .err_pop
    mov si, ax
    mov word [cs:ov_sec_in_cluster], 0
    jmp .copy_loop
.done:
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.err_pop:
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

exec_com:
    mov byte [cs:ret_code], 0xFF
    mov word [cs:running], 1
    push ss
    pop ax
    mov [cs:saved_ss], ax
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
    push ds
    mov ax, es
    dec ax
    mov ds, ax
    mov ax, es
    add ax, [ds:3]
    mov [es:0x02], ax
    pop ds

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

    pop ax
    mov word [es:0x2C], ENV_SEG
    mov [cs:dta_seg], ax
    mov word [cs:dta_off], 0x0080
    mov [cs:cur_psp], ax
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

setup_exe_dyn:
    mov ax, [cs:prog_seg]
    add ax, 0x10
    mov ds, ax

    mov ax, [0x08]
    mov [cs:exe_hdr_par], ax
    mov ax, [cs:kfsize]
    mov dx, [cs:kfsize_hi]
    add ax, 15
    adc dx, 0
    mov cx, 4
.img_par_shift:
    shr dx, 1
    rcr ax, 1
    loop .img_par_shift
    sub ax, [cs:exe_hdr_par]
    mov [cs:exe_image_par], ax
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

    mov ax, [cs:prog_seg]
    call build_psp
    call exec_copy_command_tail

    mov ax, [cs:prog_seg]
    add ax, 0x10
    mov [cs:exe_load_seg], ax

    mov cx, [cs:exe_reloc_count]
    test cx, cx
    jz .copy_image
    mov bx, [cs:exe_reloc_off]
    mov ax, [cs:prog_seg]
    add ax, 0x10
    mov ds, ax
.reloc_source:
    push cx
    mov di, [bx]
    mov ax, [bx+2]
    add ax, [cs:exe_hdr_par]
    add ax, [cs:exe_load_seg]
    mov es, ax
    mov ax, [es:di]
    add ax, [cs:exe_load_seg]
    mov [es:di], ax
    add bx, 4
    pop cx
    loop .reloc_source

.copy_image:
    mov ax, [cs:prog_seg]
    add ax, 0x10
    add ax, [cs:exe_hdr_par]
    mov [cs:copy_src_seg], ax
    mov ax, [cs:exe_load_seg]
    mov [cs:copy_dst_seg], ax
    mov cx, [cs:exe_image_par]
.copy_par:
    test cx, cx
    jz .copy_done
    push cx
    mov ax, [cs:copy_src_seg]
    mov ds, ax
    mov ax, [cs:copy_dst_seg]
    mov es, ax
    xor si, si
    xor di, di
    mov cx, 8
    rep movsw
    inc word [cs:copy_src_seg]
    inc word [cs:copy_dst_seg]
    pop cx
    loop .copy_par
.copy_done:
    push cs
    pop ds
    call exec_exe_dyn
    ret

exec_exe_dyn:
    mov byte [cs:ret_code], 0xFF
    mov word [cs:running], 1
    push ss
    pop ax
    mov [cs:saved_ss], ax
    mov [cs:saved_sp], sp

    mov ax, [cs:prog_seg]
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

exec_com_dyn:
    mov byte [cs:ret_code], 0xFF
    mov word [cs:running], 1
    push ss
    pop ax
    mov [cs:saved_ss], ax
    mov [cs:saved_sp], sp

    mov ax, [cs:prog_seg]
    dec ax
    mov ds, ax
    mov ax, [ds:3]
    cmp ax, 0x1000
    jb .small_stack
    mov ax, 0xFFFE
    jmp .stack_ready
.small_stack:
    mov cx, 4
.stack_shift:
    shl ax, 1
    loop .stack_shift
    sub ax, 2
.stack_ready:
    mov [cs:com_stack_top], ax

    mov ax, [cs:prog_seg]
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, [cs:com_stack_top]
    push word 0x0000
    push ax
    push word 0x0100
    retf

exec_exe:
    mov byte [cs:ret_code], 0xFF
    mov word [cs:running], 1
    push ss
    pop ax
    mov [cs:saved_ss], ax
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

console_putchar:
    push ax
    cmp al, 12
    je .clear
    call serial_putchar
    call vga_putchar
    pop ax
    ret
.clear:
    call serial_putchar
    call vga_clear
    pop ax
    ret

vga_putchar:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    cmp al, 13
    je .cr
    cmp al, 10
    je .lf
    cmp al, 8
    je .bs
    push ax
    mov ax, [cs:vga_row]
    mov bx, VGA_COLS
    mul bx
    add ax, [cs:vga_col]
    shl ax, 1
    mov di, ax
    mov ax, VGA_TEXT_SEG
    mov es, ax
    pop ax
    mov ah, 0x07
    stosw
    inc word [cs:vga_col]
    cmp word [cs:vga_col], VGA_COLS
    jb .update
    mov word [cs:vga_col], 0
    jmp .advance_row
.cr:
    mov word [cs:vga_col], 0
    jmp .update
.lf:
    jmp .advance_row
.bs:
    cmp word [cs:vga_col], 0
    je .update
    dec word [cs:vga_col]
    jmp .update
.advance_row:
    inc word [cs:vga_row]
    cmp word [cs:vga_row], VGA_ROWS
    jb .update
    call vga_scroll
    mov word [cs:vga_row], VGA_ROWS - 1
.update:
    call vga_update_cursor
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

vga_clear:
    push ax
    push cx
    push es
    push di
    mov ax, VGA_TEXT_SEG
    mov es, ax
    xor di, di
    mov ax, 0x0720
    mov cx, VGA_COLS * VGA_ROWS
    cld
    rep stosw
    mov word [cs:vga_row], 0
    mov word [cs:vga_col], 0
    call vga_update_cursor
    pop di
    pop es
    pop cx
    pop ax
    ret

vga_scroll:
    push ax
    push cx
    push ds
    push es
    push si
    push di
    mov ax, VGA_TEXT_SEG
    mov ds, ax
    mov es, ax
    mov si, VGA_COLS * 2
    xor di, di
    mov cx, VGA_COLS * (VGA_ROWS - 1)
    cld
    rep movsw
    mov ax, 0x0720
    mov cx, VGA_COLS
    mov di, VGA_COLS * (VGA_ROWS - 1) * 2
    rep stosw
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop ax
    ret

vga_update_cursor:
    push ax
    push bx
    push dx
    mov ax, [cs:vga_row]
    mov bx, VGA_COLS
    mul bx
    add ax, [cs:vga_col]
    mov bx, ax
    mov dx, 0x03D4
    mov al, 0x0F
    out dx, al
    inc dx
    mov al, bl
    out dx, al
    dec dx
    mov al, 0x0E
    out dx, al
    inc dx
    mov al, bh
    out dx, al
    pop dx
    pop bx
    pop ax
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

serial_print_hex_word:
    push cx
    push ax
    mov cx, 4
.whloop:
    rol ax, 4
    push ax
    and al, 0x0F
    cmp al, 10
    jae .walpha
    add al, '0'
    jmp .wout
.walpha:
    add al, 'A' - 10
.wout:
    call serial_putchar
    pop ax
    loop .whloop
    pop ax
    pop cx
    ret

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
msg_unhandled: db "INT 21h AH=", 0
msg_int33:     db "INT 33h AX=", 0
msg_mouse_ps2_on: db "PS2 mouse enabled", 13, 10, 0
msg_mouse_ps2_off: db "PS2 mouse unavailable", 13, 10, 0
msg_colon:     db ":", 0
msg_exc:       db "EXC ", 0
msg_at:        db " at ", 0
msg_trace_open: db "OPEN ", 0
msg_trace_handle: db " -> H=", 0
msg_trace_size: db " SIZE=", 0
msg_trace_sig: db " SIG=", 0
msg_trace_read: db "READ H=", 0
msg_trace_close: db "CLOSE H=", 0
msg_trace_seek: db "SEEK H=", 0
msg_trace_req: db " REQ=", 0
msg_trace_pos: db " POS=", 0
msg_trace_buf: db " BUF=", 0
msg_trace_ret: db " -> ", 0
msg_trace_fail: db " FAIL", 13, 10, 0
msg_trace_alloc: db "ALLOC ", 0
msg_trace_strategy: db " STRAT=", 0
msg_trace_strategy_call: db "STRATEGY AX=", 0
msg_trace_resize: db "RESIZE ", 0
msg_reg_ax:    db " AX=", 0
msg_reg_bx:    db " BX=", 0
msg_reg_cx:    db " CX=", 0
msg_reg_dx:    db " DX=", 0

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

load_name: dw 0
load_seg:  dw 0
load_off:  dw 0

krsta: dw 0
krsc:  dw 0
kdsta: dw 0
kspc:  db 0
kfat_start: dw 0
kfat_secs: dw 0
knum_fats: db 0
kmax_cluster: dw 0
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
rf_handle:     dw 0
rf_req:        dw 0
rf_start_lo:   dw 0
rf_start_hi:   dw 0
rf_start_buf_off: dw 0
rf_start_buf_seg: dw 0
rf_sec_in_cluster: dw 0
rf_cluster_index: dw 0
rf_cache_lba:  dw 0
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
wf_cluster:    dw 0
wf_status:     dw 0

sf_origin: db 0
sf_ret_lo: dw 0
sf_ret_hi: dw 0

cur_dir_cluster: dw 0
cur_dir_path: times 64 db 0
cd_path_off: dw 0
cd_path_seg: dw 0
of_mode: db 0

cf_attr: db 0
cf_handle: dw 0
cf_entry_idx: dw 0
cf_entry_seg: dw 0
cf_entry_off: dw 0
cf_found: db 0
cf_status: dw 0

rn_new_off: dw 0
rn_new_seg: dw 0
rn_src_idx: dw 0
rn_src_off: dw 0
rn_src_dir_off: dw 0
rn_src_lba: dw 0
rn_dir_cluster: dw 0
rn_status: dw 0

ft_mode: db 0
ft_time: dw 0
ft_date: dw 0
df_status: dw 0
df_first_cluster: dw 0

pr_abs: db 0
pr_name_off: dw 0
pr_dir_cluster: dw 0

dir_flush_lba: dw 0
dir_update_hoff: dw 0

fat_dirty: db 0
fat_copy_idx: db 0
fat_flush_lba: dw 0
fat_flush_off: dw 0

rp_path: dw 0
rp_path_seg: dw 0
rp_cluster: dw 0
rp_component_idx: db 0

ff_dir_cluster: dw 0
ff_entry_idx: dw 0
ff_entry_cluster: dw 0
ff_entry_size: dw 0
ff_entry_size_hi: dw 0
ff_entry_attr: db 0
ff_entry_name: times 11 db 0
ff_entry_lba: dw 0
ff_entry_off: dw 0
ff_attr_mask: db 0
ff_path_off: dw 0
ff_path_seg: dw 0
ff_sep_off: dw 0
ff_res_es: dw 0
ff_res_di: dw 0

fid_cluster: dw 0
fid_idx: dw 0
rid_clus: dw 0
rid_lba: dw 0
rid_sec_idx: db 0

find_di: dw 0

mcb_first: dw 0
cur_psp: dw 0
alloc_strat: db 0
am_req: dw 0
am_best_seg: dw 0
am_best_size: dw 0
rm_req: dw 0

ov_param_off: dw 0
ov_param_seg: dw 0
ov_path_off: dw 0
ov_path_seg: dw 0
ov_load_seg: dw 0
ov_reloc_seg: dw 0
ov_cluster: dw 0
ov_size_lo: dw 0
ov_skip: dw 0
ov_left: dw 0
ov_dst_seg: dw 0
ov_dst_off: dw 0
ov_sector_offset: dw 0
ov_sec_in_cluster: dw 0
ov_chunk: dw 0
ov_reloc_count: dw 0
ov_reloc_off: dw 0
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
mouse_trace_left: dw 80
mouse_log_ax: dw 0
mouse_callback_mask: dw 0
mouse_callback_off: dw 0
mouse_callback_seg: dw 0
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
