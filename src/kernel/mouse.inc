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
    cmp ax, 0x0006
    je .get_button_release
    cmp ax, 0x0007
    je .set_x_range
    cmp ax, 0x0008
    je .set_y_range
    cmp ax, 0x000B
    je .get_motion
    cmp ax, 0x000C
    je .set_callback
    cmp ax, 0x000F
    je .set_ratio
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
    mov word [cs:mouse_release_count_l], 0
    mov word [cs:mouse_release_count_r], 0
    mov word [cs:mouse_visible_count], 0xFFFF
    mov word [cs:mouse_callback_mask], 0
    mov word [cs:mouse_callback_off], 0
    mov word [cs:mouse_callback_seg], 0
    mov byte [cs:mouse_in_callback], 0
    mov word [cs:mouse_ratio_x], 8
    mov word [cs:mouse_ratio_y], 8
    mov word [cs:mouse_scale_rem_x], 0
    mov word [cs:mouse_scale_rem_y], 0
    mov word [cs:mouse_event_dx], 0
    mov word [cs:mouse_event_dy], 0
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
    mov word [cs:mouse_scale_rem_x], 0
    mov word [cs:mouse_scale_rem_y], 0
    push ax
    call mouse_clamp_position
    pop ax
    iret
.set_x_range:
    cmp cx, dx
    jbe .set_x_ordered
    xchg cx, dx
.set_x_ordered:
    mov [cs:mouse_min_x], cx
    mov [cs:mouse_max_x], dx
    push ax
    call mouse_clamp_position
    pop ax
    iret
.set_y_range:
    cmp cx, dx
    jbe .set_y_ordered
    xchg cx, dx
.set_y_ordered:
    mov [cs:mouse_min_y], cx
    mov [cs:mouse_max_y], dx
    push ax
    call mouse_clamp_position
    pop ax
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
    call mouse_trace_return
    iret
.get_left_press:
    mov ax, [cs:mouse_buttons]
    mov bx, [cs:mouse_press_count_l]
    mov cx, [cs:mouse_press_x_l]
    mov dx, [cs:mouse_press_y_l]
    mov word [cs:mouse_press_count_l], 0
    call mouse_trace_return
    iret
.get_right_press:
    mov ax, [cs:mouse_buttons]
    mov bx, [cs:mouse_press_count_r]
    mov cx, [cs:mouse_press_x_r]
    mov dx, [cs:mouse_press_y_r]
    mov word [cs:mouse_press_count_r], 0
    call mouse_trace_return
    iret
.get_button_release:
    cmp bx, 0
    je .get_left_release
    cmp bx, 1
    je .get_right_release
    mov ax, [cs:mouse_buttons]
    xor bx, bx
    xor cx, cx
    xor dx, dx
    call mouse_trace_return
    iret
.get_left_release:
    mov ax, [cs:mouse_buttons]
    mov bx, [cs:mouse_release_count_l]
    mov cx, [cs:mouse_release_x_l]
    mov dx, [cs:mouse_release_y_l]
    mov word [cs:mouse_release_count_l], 0
    call mouse_trace_return
    iret
.get_right_release:
    mov ax, [cs:mouse_buttons]
    mov bx, [cs:mouse_release_count_r]
    mov cx, [cs:mouse_release_x_r]
    mov dx, [cs:mouse_release_y_r]
    mov word [cs:mouse_release_count_r], 0
    call mouse_trace_return
    iret
.get_motion:
    mov cx, [cs:mouse_motion_x]
    mov dx, [cs:mouse_motion_y]
    mov word [cs:mouse_motion_x], 0
    mov word [cs:mouse_motion_y], 0
    call mouse_trace_return
    iret
.set_callback:
    mov [cs:mouse_callback_mask], cx
    mov [cs:mouse_callback_off], dx
    mov [cs:mouse_callback_seg], es
    iret
.set_ratio:
    test cx, cx
    jnz .ratio_x_ok
    inc cx
.ratio_x_ok:
    cmp cx, 2048
    jbe .ratio_x_capped
    mov cx, 2048
.ratio_x_capped:
    test dx, dx
    jnz .ratio_y_ok
    inc dx
.ratio_y_ok:
    cmp dx, 2048
    jbe .ratio_y_capped
    mov dx, 2048
.ratio_y_capped:
    mov [cs:mouse_ratio_x], cx
    mov [cs:mouse_ratio_y], dx
    mov word [cs:mouse_scale_rem_x], 0
    mov word [cs:mouse_scale_rem_y], 0
    iret

mouse_trace_return:
    cmp word [cs:mouse_trace_left], 0
    je .done
    pusha
    push ds
    push cs
    pop ds
    mov si, msg_int33_ret
    call serial_print
    call serial_print_hex_word
    mov si, msg_reg_bx
    call serial_print
    mov ax, bx
    call serial_print_hex_word
    mov si, msg_reg_cx
    call serial_print
    mov ax, cx
    call serial_print_hex_word
    mov si, msg_reg_dx
    call serial_print
    mov ax, dx
    call serial_print_hex_word
    mov si, msg_crlf
    call serial_print
    pop ds
    popa
.done:
    ret

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

mouse_scale_x:
    shl ax, 1
    shl ax, 1
    shl ax, 1
    add ax, [cs:mouse_scale_rem_x]
    cwd
    idiv word [cs:mouse_ratio_x]
    mov [cs:mouse_scale_rem_x], dx
    ret

mouse_scale_y:
    shl ax, 1
    shl ax, 1
    shl ax, 1
    add ax, [cs:mouse_scale_rem_y]
    cwd
    idiv word [cs:mouse_ratio_y]
    mov [cs:mouse_scale_rem_y], dx
    ret

mouse_apply_delta_x:
    mov bx, [cs:mouse_x]
    test ax, ax
    js .neg
    add bx, ax
    jc .max
    cmp bx, [cs:mouse_max_x]
    jbe .store
.max:
    mov bx, [cs:mouse_max_x]
    jmp .store
.neg:
    neg ax
    cmp bx, ax
    jb .min
    sub bx, ax
    cmp bx, [cs:mouse_min_x]
    jae .store
.min:
    mov bx, [cs:mouse_min_x]
.store:
    mov [cs:mouse_x], bx
    ret

mouse_apply_delta_y:
    mov bx, [cs:mouse_y]
    test ax, ax
    js .neg
    add bx, ax
    jc .max
    cmp bx, [cs:mouse_max_y]
    jbe .store
.max:
    mov bx, [cs:mouse_max_y]
    jmp .store
.neg:
    neg ax
    cmp bx, ax
    jb .min
    sub bx, ax
    cmp bx, [cs:mouse_min_y]
    jae .store
.min:
    mov bx, [cs:mouse_min_y]
.store:
    mov [cs:mouse_y], bx
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
    mov word [cs:mouse_event_mask], 0
    mov word [cs:mouse_event_dx], 0
    mov word [cs:mouse_event_dy], 0
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
    test ax, ax
    jz .x_no_event
    or word [cs:mouse_event_mask], 0x0001
.x_no_event:
    mov [cs:mouse_event_dx], ax
    add [cs:mouse_motion_x], ax
    call mouse_scale_x
    call mouse_apply_delta_x
.skip_x:
    test byte [cs:mouse_packet0], 0x80
    jnz .skip_y
    mov al, [cs:mouse_packet2]
    xor ah, ah
    test byte [cs:mouse_packet0], 0x20
    jz .y_pos
    mov ah, 0xFF
.y_pos:
    test ax, ax
    jz .y_no_event
    or word [cs:mouse_event_mask], 0x0001
.y_no_event:
    neg ax
    mov [cs:mouse_event_dy], ax
    add [cs:mouse_motion_y], ax
    call mouse_scale_y
    call mouse_apply_delta_y
.skip_y:
    call mouse_clamp_position
    mov bx, [cs:mouse_buttons]
    mov ax, [cs:mouse_new_buttons]
    test bx, 0x0001
    jz .left_was_up
    test ax, 0x0001
    jnz .left_done
    or word [cs:mouse_event_mask], 0x0004
    inc word [cs:mouse_release_count_l]
    mov cx, [cs:mouse_x]
    mov [cs:mouse_release_x_l], cx
    mov cx, [cs:mouse_y]
    mov [cs:mouse_release_y_l], cx
    jmp .left_done
.left_was_up:
    test ax, 0x0001
    jz .left_done
    or word [cs:mouse_event_mask], 0x0002
    inc word [cs:mouse_press_count_l]
    mov cx, [cs:mouse_x]
    mov [cs:mouse_press_x_l], cx
    mov cx, [cs:mouse_y]
    mov [cs:mouse_press_y_l], cx
.left_done:
    test bx, 0x0002
    jz .right_was_up
    test ax, 0x0002
    jnz .right_done
    or word [cs:mouse_event_mask], 0x0010
    inc word [cs:mouse_release_count_r]
    mov cx, [cs:mouse_x]
    mov [cs:mouse_release_x_r], cx
    mov cx, [cs:mouse_y]
    mov [cs:mouse_release_y_r], cx
    jmp .right_done
.right_was_up:
    test ax, 0x0002
    jz .right_done
    or word [cs:mouse_event_mask], 0x0008
    inc word [cs:mouse_press_count_r]
    mov cx, [cs:mouse_x]
    mov [cs:mouse_press_x_r], cx
    mov cx, [cs:mouse_y]
    mov [cs:mouse_press_y_r], cx
.right_done:
    mov [cs:mouse_buttons], ax
    call mouse_invoke_callback
.done:
    ret

mouse_invoke_callback:
    mov ax, [cs:mouse_event_mask]
    test ax, [cs:mouse_callback_mask]
    jz .done
    cmp word [cs:mouse_callback_seg], 0
    je .done
    cmp byte [cs:mouse_in_callback], 0
    jne .done
    cmp byte [cs:indos_flag], 0
    jne .done
    mov byte [cs:mouse_in_callback], 1
    pusha
    push ds
    push es
    and ax, [cs:mouse_callback_mask]
    mov bx, [cs:mouse_buttons]
    mov cx, [cs:mouse_x]
    mov dx, [cs:mouse_y]
    mov si, [cs:mouse_event_dx]
    mov di, [cs:mouse_event_dy]
    call far [cs:mouse_callback_off]
    pop es
    pop ds
    popa
    mov byte [cs:mouse_in_callback], 0
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
