[bits 16]
[org 0x0100]

%ifndef RET_CODE
%define RET_CODE 0
%endif

start:
    mov ax, 0x4C00 | RET_CODE
    int 0x21
