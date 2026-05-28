[bits 16]
[org 0x0100]

    mov dx, ready_msg
    mov ah, 0x09
    int 0x21

    mov ah, 0x0B
    int 0x21
    cmp al, 0x00
    jne fail_initial

.wait_key:
    mov ah, 0x0B
    int 0x21
    cmp al, 0xFF
    jne .wait_key

    mov ah, 0x08
    int 0x21
    cmp al, 0x00
    jne fail_prefix

    mov ah, 0x0B
    int 0x21
    cmp al, 0xFF
    jne fail_pending

    mov ah, 0x08
    int 0x21
    cmp al, 0x3F
    jne fail_scan

    mov ah, 0x0B
    int 0x21
    cmp al, 0x00
    jne fail_final

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_initial:
    mov dx, fail_initial_msg
    jmp fail
fail_prefix:
    mov dx, fail_prefix_msg
    jmp fail
fail_pending:
    mov dx, fail_pending_msg
    jmp fail
fail_scan:
    mov dx, fail_scan_msg
    jmp fail
fail_final:
    mov dx, fail_final_msg

fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

ready_msg: db "READY: EXTKEY", 13, 10, "$"
pass_msg: db "PASS: EXTKEY", 13, 10, "$"
fail_initial_msg: db "FAIL: EXTKEY INITIAL", 13, 10, "$"
fail_prefix_msg: db "FAIL: EXTKEY PREFIX", 13, 10, "$"
fail_pending_msg: db "FAIL: EXTKEY PENDING", 13, 10, "$"
fail_scan_msg: db "FAIL: EXTKEY SCAN", 13, 10, "$"
fail_final_msg: db "FAIL: EXTKEY FINAL", 13, 10, "$"
