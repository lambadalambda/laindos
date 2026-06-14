; Shared boilerplate for DOS test programs.
;
; A minimal marker test reduces to:
;     %include "tests/programs/common.inc"
;     COM_START
;         cmp ax, ax
;         jne .bad
;         PASS_WITH pass_msg
;     .bad:
;         FAIL_WITH fail_msg
;     pass_msg: db "PASS: X", 13, 10, "$"
;     fail_msg: db "FAIL: X", 13, 10, "$"
;
; EXE tests start with MZ_HEADER instead of COM_START and provide their own
; entry code (the header's CS:IP/SS:SP fields match the long-hand block the
; existing EXE tests duplicated).

; COM program prologue: origin, entry label, DS=CS.
%macro COM_START 0
[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
%endmacro

; Print a '$'-terminated message via AH=09h (DS must address it).
%macro PRINT_DOLLAR 1
    mov dx, %1
    mov ah, 0x09
    int 0x21
%endmacro

; Exit via AH=4Ch with the given code.
%macro EXIT_CODE 1
    mov ax, 0x4C00 | (%1)
    int 0x21
%endmacro

; Print a message and exit 0.
%macro PASS_WITH 1
    PRINT_DOLLAR %1
    EXIT_CODE 0
%endmacro

; Print a message and exit 1.
%macro FAIL_WITH 1
    PRINT_DOLLAR %1
    EXIT_CODE 1
%endmacro

; Standard small-EXE MZ header (4-paragraph header, SS/SP at the image top,
; entry at image_start). Optional arguments override min/max allocation.
; The program defines image_start and file_end.
%macro MZ_HEADER 0-2 0x0010, 0xFFFF
[bits 16]

hdr_size equ 4

mz_header:
    dw 0x5A4D
    dw (file_end - mz_header) % 512
    dw ((file_end - mz_header) + 511) / 512
    dw 0
    dw hdr_size
    dw %1
    dw %2
    dw 0x0000
    dw 0xFFFE
    dw 0x0000
    dw 0x0000
    dw 0x0000
    dw 0x001C
    dw 0x0000

    times (hdr_size * 16) - ($ - mz_header) db 0
%endmacro
