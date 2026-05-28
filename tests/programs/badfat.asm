[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, bad_path
    mov ax, 0x3D00
    int 0x21
    jc fail_open_bad
    mov [handle], ax
    mov word [read_count], 0

.read_loop:
    cmp word [read_count], 8
    jae .read_bad_tail
    mov bx, [handle]
    mov dx, buf
    mov cx, 512
    mov ah, 0x3F
    int 0x21
    jc fail_read_bad
    cmp ax, 512
    jne fail_read_bad
    cmp byte [buf], 'B'
    jne fail_read_bad
    inc word [read_count]
    jmp .read_loop

.read_bad_tail:
    mov bx, [handle]
    mov dx, buf
    mov cx, 512
    mov ah, 0x3F
    int 0x21
    jc fail_read_bad
    cmp ax, 0
    jne fail_read_bad

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, bad_path
    mov ah, 0x41
    int 0x21
    jc fail_delete

    mov dx, firstbad_path
    mov ah, 0x41
    int 0x21

    mov dx, good_path
    mov ax, 0x3D00
    int 0x21
    jc fail_open_good
    mov [handle], ax

    mov bx, ax
    mov dx, buf
    mov cx, good_size
    mov ah, 0x3F
    int 0x21
    jc fail_read_good
    cmp ax, good_size
    jne fail_read_good
    mov si, buf
    mov di, good_data
    mov cx, good_size
    repe cmpsb
    jne fail_read_good

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open_bad:
    mov dx, fail_open_bad_msg
    jmp print_fail
fail_read_bad:
    mov dx, fail_read_bad_msg
    jmp print_fail
fail_close:
    mov dx, fail_close_msg
    jmp print_fail
fail_delete:
    mov dx, fail_delete_msg
    jmp print_fail
fail_open_good:
    mov dx, fail_open_good_msg
    jmp print_fail
fail_read_good:
    mov dx, fail_read_good_msg

print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

bad_path db 'BADCHAIN.DAT', 0
firstbad_path db 'FIRSTBAD.DAT', 0
good_path db 'GOOD.DAT', 0
good_data db 'root-ok-after-bad-fat'
good_size equ $ - good_data
pass_msg db 'PASS: BADFAT', 13, 10, '$'
fail_open_bad_msg db 'FAIL: OPEN BAD', 13, 10, '$'
fail_read_bad_msg db 'FAIL: READ BAD', 13, 10, '$'
fail_close_msg db 'FAIL: CLOSE', 13, 10, '$'
fail_delete_msg db 'FAIL: DELETE', 13, 10, '$'
fail_open_good_msg db 'FAIL: OPEN GOOD', 13, 10, '$'
fail_read_good_msg db 'FAIL: READ GOOD', 13, 10, '$'
handle dw 0
read_count dw 0
buf times 512 db 0
