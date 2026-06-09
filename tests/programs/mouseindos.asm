[bits 16]
[org 0x0100]

%ifndef KERNEL_SEG
%error "KERNEL_SEG must be defined"
%endif

%ifndef MOUSE_X
%error "MOUSE_X must be defined"
%endif
%ifndef MOUSE_Y
%error "MOUSE_Y must be defined"
%endif
%ifndef MOUSE_BUTTONS
%error "MOUSE_BUTTONS must be defined"
%endif
%ifndef MOUSE_CALLBACK_MASK
%error "MOUSE_CALLBACK_MASK must be defined"
%endif
%ifndef MOUSE_CALLBACK_OFF
%error "MOUSE_CALLBACK_OFF must be defined"
%endif
%ifndef MOUSE_CALLBACK_SEG
%error "MOUSE_CALLBACK_SEG must be defined"
%endif
%ifndef MOUSE_EVENT_MASK
%error "MOUSE_EVENT_MASK must be defined"
%endif
%ifndef MOUSE_IN_CALLBACK
%error "MOUSE_IN_CALLBACK must be defined"
%endif
%ifndef INDOS_FLAG
%error "INDOS_FLAG must be defined"
%endif
%ifndef MOUSE_INVOKE_CALLBACK_FAR
%error "MOUSE_INVOKE_CALLBACK_FAR must be defined"
%endif

start:
    push cs
    pop ds

    mov ax, KERNEL_SEG
    mov es, ax
    mov word [es:MOUSE_CALLBACK_OFF], callback
    mov word [es:MOUSE_CALLBACK_SEG], cs
    mov word [es:MOUSE_CALLBACK_MASK], 0x0007
    mov byte [es:MOUSE_IN_CALLBACK], 0

    mov word [es:MOUSE_X], 100
    mov word [es:MOUSE_Y], 200
    mov word [es:MOUSE_BUTTONS], 0
    mov word [es:MOUSE_EVENT_MASK], 0x0007

    mov word [callback_seen], 0
    mov word [nested_ax], 0
    mov word [nested_flags], 0
    mov byte [es:INDOS_FLAG], 1

    call KERNEL_SEG:MOUSE_INVOKE_CALLBACK_FAR

    mov ax, KERNEL_SEG
    mov es, ax
    cmp word [callback_seen], 1
    jne fail_not_called_during_dos
    cmp byte [es:INDOS_FLAG], 1
    jne fail_indos_changed
    cmp byte [es:MOUSE_IN_CALLBACK], 0
    jne fail_still_in_callback
    cmp word [nested_ax], 0x0005
    jne fail_nested_ax
    test word [nested_flags], 0x0001
    jz fail_nested_cf

    mov byte [es:INDOS_FLAG], 0
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_not_called_during_dos:
    mov dx, fail_not_called_msg
    jmp fail
fail_indos_changed:
    mov dx, fail_indos_changed_msg
    jmp fail
fail_still_in_callback:
    mov dx, fail_still_in_callback_msg
    jmp fail
fail_nested_ax:
    mov dx, fail_nested_ax_msg
    jmp fail
fail_nested_cf:
    mov dx, fail_nested_cf_msg
    jmp fail

fail:
    mov byte [es:INDOS_FLAG], 0
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

callback:
    push ds
    push cs
    pop ds
    inc word [callback_seen]
    mov dx, nested_msg
    mov ah, 0x09
    int 0x21
    mov [nested_ax], ax
    pushf
    pop ax
    mov [nested_flags], ax
    pop ds
    retf

callback_seen: dw 0
nested_ax: dw 0
nested_flags: dw 0
pass_msg: db "PASS: MOUSEINDOS", 13, 10, "$"
nested_msg: db "NESTED", 13, 10, "$"
fail_not_called_msg: db "FAIL: MOUSEINDOS NOT CALLED", 13, 10, "$"
fail_indos_changed_msg: db "FAIL: MOUSEINDOS INDOS", 13, 10, "$"
fail_still_in_callback_msg: db "FAIL: MOUSEINDOS CALLBACK", 13, 10, "$"
fail_nested_ax_msg: db "FAIL: MOUSEINDOS NESTED AX", 13, 10, "$"
fail_nested_cf_msg: db "FAIL: MOUSEINDOS NESTED CF", 13, 10, "$"
