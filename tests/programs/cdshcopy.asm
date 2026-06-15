%include "tests/programs/common.inc"

COM_START
    cld
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    jc fail_resize

    mov bx, 0x4A00
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [alloc_seg], ax

    mov dx, install_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, install_dir
    mov ah, 0x3B
    int 0x21
    jc fail_chdir

    mov dx, keep1_name
    call create_keep
    mov [keep1_handle], ax
    mov dx, keep2_name
    call create_keep
    mov [keep2_handle], ax
    mov dx, keep3_name
    call create_keep
    mov [keep3_handle], ax
    mov dx, keep4_name
    call create_keep
    mov [keep4_handle], ax

    mov si, tail_english
    call run_shell
    mov si, tail_drv
    call run_shell
    mov si, tail_readme
    call run_shell
    mov si, tail_install
    call run_shell
    mov si, tail_norm
    call run_shell
    mov si, tail_filler
    call run_shell

    mov dx, gfx_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov si, tail_gfx
    call run_shell

    PASS_WITH pass_msg

run_shell:
    push cs
    pop ds
    push cs
    pop es
    mov [exec_params+2], si
    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, shell_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec
    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_child
    ret

create_keep:
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    ret

fail_resize:
    mov dx, fail_resize_msg
    jmp fail
fail_alloc:
    mov dx, fail_alloc_msg
    jmp fail
fail_mkdir:
    mov dx, fail_mkdir_msg
    jmp fail
fail_chdir:
    mov dx, fail_chdir_msg
    jmp fail
fail_exec:
    mov dx, fail_exec_msg
    jmp fail
fail_child:
    mov dx, fail_child_msg
    jmp fail
fail_create:
    mov dx, fail_create_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    EXIT_CODE 1

install_dir: db "NORMINC", 0
gfx_dir: db "GFX", 0
keep1_name: db "KEEP1.TMP", 0
keep2_name: db "KEEP2.TMP", 0
keep3_name: db "KEEP3.TMP", 0
keep4_name: db "KEEP4.TMP", 0
shell_path: db "C:\SHELL.COM", 0

tail_english: db tail_english_end - tail_english_cmd
tail_english_cmd: db " /c copy D:\DEMOS\NORMALIT\ENGLISH.DAT >NUL"
tail_english_end: db 13
tail_drv: db tail_drv_end - tail_drv_cmd
tail_drv_cmd: db " /c copy D:\DEMOS\NORMALIT\*.DRV >NUL"
tail_drv_end: db 13
tail_readme: db tail_readme_end - tail_readme_cmd
tail_readme_cmd: db " /c copy D:\DEMOS\NORMALIT\READ.ME >NUL"
tail_readme_end: db 13
tail_install: db tail_install_end - tail_install_cmd
tail_install_cmd: db " /c copy D:\DEMOS\NORMALIT\INSTALL.* >NUL"
tail_install_end: db 13
tail_norm: db tail_norm_end - tail_norm_cmd
tail_norm_cmd: db " /c copy D:\DEMOS\NORMALIT\NORM.EXE >NUL"
tail_norm_end: db 13
tail_filler: db tail_filler_end - tail_filler_cmd
tail_filler_cmd: db " /c copy D:\DEMOS\NORMALIT\FILLER.BIN >NUL"
tail_filler_end: db 13
tail_gfx: db tail_gfx_end - tail_gfx_cmd
tail_gfx_cmd: db " /c copy D:\DEMOS\NORMALIT\GFX\*.* GFX >NUL"
tail_gfx_end: db 13

exec_params:
    dw 0
    dw tail_english, 0
    dw fcb1, 0
    dw fcb2, 0
fcb1: times 16 db 0
fcb2: times 16 db 0
alloc_seg: dw 0
keep1_handle: dw 0
keep2_handle: dw 0
keep3_handle: dw 0
keep4_handle: dw 0

pass_msg: db "PASS: CDSHCOPY", 13, 10, "$"
fail_resize_msg: db "FAIL: CDSHCOPY RESIZE", 13, 10, "$"
fail_alloc_msg: db "FAIL: CDSHCOPY ALLOC", 13, 10, "$"
fail_mkdir_msg: db "FAIL: CDSHCOPY MKDIR", 13, 10, "$"
fail_chdir_msg: db "FAIL: CDSHCOPY CHDIR", 13, 10, "$"
fail_exec_msg: db "FAIL: CDSHCOPY EXEC", 13, 10, "$"
fail_child_msg: db "FAIL: CDSHCOPY CHILD", 13, 10, "$"
fail_create_msg: db "FAIL: CDSHCOPY CREATE", 13, 10, "$"
