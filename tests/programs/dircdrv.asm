%include "tests/programs/common.inc"

COM_START
    cld
    PRINT_DOLLAR msg_bench

    mov ax, 0xF000
    int 0x21
    jc fail_perf

    mov dx, a_path
    call open_close
    mov dx, a_path
    call open_close
    mov dx, c_path
    call open_close
    mov dx, c_path
    call open_close
    mov dx, a_path
    call open_close
    mov dx, a_path
    call open_close

    mov ax, 0xF001
    int 0x21
    jc fail_perf

    PASS_WITH msg_pass

open_close:
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

fail_perf:
    FAIL_WITH msg_fail_perf
fail_open:
    FAIL_WITH msg_fail_open
fail_close:
    FAIL_WITH msg_fail_close

msg_bench: db "BENCH: DIRCDRV", 13, 10, "$"
msg_pass: db "PASS: DIRCDRV", 13, 10, "$"
msg_fail_perf: db "FAIL: DIRCDRV PERF", 13, 10, "$"
msg_fail_open: db "FAIL: DIRCDRV OPEN", 13, 10, "$"
msg_fail_close: db "FAIL: DIRCDRV CLOSE", 13, 10, "$"

a_path: db "A:\CACHE\AONLY.DAT", 0
c_path: db "C:\CACHE\CONLY.DAT", 0
