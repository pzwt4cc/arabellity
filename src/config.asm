default rel
%include "syscalls.inc"

%define SYS_MKDIR       83
%define O_RDONLY        0
%define O_WRONLY_CREAT  0x241

global config_load
global cfg_pad_x
global cfg_pad_y
global cfg_win_w
global cfg_win_h
global cfg_bg
global cfg_fg
global cfg_cursor
global cfg_sel_bg
global cfg_sel_fg
global cfg_opacity
global cfg_blur
global cfg_bg_pixel
global cfg_scroll_lines
global ansi_colors
global parse_hex_color

extern getenv
extern streq
extern strcpy
extern write_all
extern repeat_delay
extern repeat_rate
extern win_w
extern win_h

section .rodata
s_home:                 db "HOME", 0
s_dot_config:           db "/.config", 0
s_app_dir:              db "/.config/arabellity", 0
s_app_conf:             db "/.config/arabellity/arabellity.conf", 0
s_local_conf:           db "arabellity.conf", 0

k_win_pad:              db "window_padding_width", 0
k_pad_x:                db "padding_x", 0
k_pad_y:                db "padding_y", 0
k_win_w:                db "initial_window_width", 0
k_win_h:                db "initial_window_height", 0
k_opacity:              db "background_opacity", 0
k_blur:                 db "background_blur", 0
k_scroll:               db "scroll_lines", 0
k_rep_delay:            db "repeat_delay", 0
k_rep_rate:             db "repeat_rate", 0
k_bg:                   db "background", 0
k_fg:                   db "foreground", 0
k_cursor:               db "cursor", 0
k_sel_bg:               db "selection_background", 0
k_sel_fg:               db "selection_foreground", 0
k_include:              db "include", 0
s_kitty_conf:           db "/.config/kitty/kitty.conf", 0
s_slash_kitty:          db "/.config/kitty/", 0

default_conf_start:
    incbin "arabellity.conf"
default_conf_end:
default_conf_len equ default_conf_end - default_conf_start

section .data
cfg_pad_x:          dd 8
cfg_pad_y:          dd 8
cfg_win_w:          dd 800
cfg_win_h:          dd 500
cfg_bg:             dd 0x000000
cfg_fg:             dd 0xc9d1d9
cfg_cursor:         dd 0x39ff14
cfg_sel_bg:         dd 0x264f78
cfg_sel_fg:         dd 0xffffff
cfg_opacity:        dd 255
cfg_blur:           dd 1
cfg_bg_pixel:       dd 0xff000000
cfg_scroll_lines:   dd 3

ansi_colors:
    dd 0x000000, 0xcd0000, 0x00cd00, 0xcdcd00
    dd 0x0000ee, 0xcd00cd, 0x00cdcd, 0xe5e5e5
    dd 0x7f7f7f, 0xff0000, 0x00ff00, 0xffff00
    dd 0x5c5cff, 0xff00ff, 0x00ffff, 0xffffff

section .bss
conf_path:          resb 1024
conf_buf:           resb 16384
key_buf:            resb 128
val_buf:            resb 128
inc_path:           resb 1024
inc_buf:            resb 16384

section .text

config_load:
    push    rbx
    push    r12
    push    r13

    lea     rsi, [s_home]
    call    getenv
    test    rax, rax
    jz      .try_local
    cmp     byte [rax], 0
    je      .try_local
    mov     r12, rax

    lea     rdi, [conf_path]
    mov     rsi, r12
    call    strcpy
    mov     rdi, rax
    lea     rsi, [s_kitty_conf]
    call    strcpy

    mov     eax, SYS_OPEN
    lea     rdi, [conf_path]
    mov     esi, O_RDONLY
    xor     edx, edx
    syscall
    test    rax, rax
    js      .load_arabellity
    mov     rdi, rax
    call    read_and_parse_fd

.load_arabellity:
    lea     rdi, [conf_path]
    mov     rsi, r12
    call    strcpy
    mov     rdi, rax
    lea     rsi, [s_dot_config]
    call    strcpy
    mov     eax, SYS_MKDIR
    lea     rdi, [conf_path]
    mov     esi, 493
    syscall

    lea     rdi, [conf_path]
    mov     rsi, r12
    call    strcpy
    mov     rdi, rax
    lea     rsi, [s_app_dir]
    call    strcpy
    mov     eax, SYS_MKDIR
    lea     rdi, [conf_path]
    mov     esi, 493
    syscall

    lea     rdi, [conf_path]
    mov     rsi, r12
    call    strcpy
    mov     rdi, rax
    lea     rsi, [s_app_conf]
    call    strcpy

    mov     eax, SYS_OPEN
    lea     rdi, [conf_path]
    mov     esi, O_RDONLY
    xor     edx, edx
    syscall
    test    rax, rax
    js      .create_default
    mov     rdi, rax
    call    read_and_parse_fd
    jmp     .try_local

.create_default:
    mov     eax, SYS_OPEN
    lea     rdi, [conf_path]
    mov     esi, O_WRONLY_CREAT
    mov     edx, 420
    syscall
    test    rax, rax
    js      .try_local
    mov     rbx, rax
    mov     rdi, rbx
    lea     rsi, [default_conf_start]
    mov     edx, default_conf_len
    call    write_all
    mov     eax, SYS_CLOSE
    mov     rdi, rbx
    syscall

.try_local:
    mov     eax, SYS_OPEN
    lea     rdi, [s_local_conf]
    mov     esi, O_RDONLY
    xor     edx, edx
    syscall
    test    rax, rax
    js      .finalize
    mov     rdi, rax
    call    read_and_parse_fd

.finalize:
    mov     eax, [cfg_win_w]
    mov     [win_w], eax
    mov     eax, [cfg_win_h]
    mov     [win_h], eax

    mov     ecx, [cfg_opacity]
    cmp     dword [cfg_blur], 0
    jne     .op_ok
    mov     ecx, 255
.op_ok:
    cmp     ecx, 255
    jbe     .op_clamped
    mov     ecx, 255
.op_clamped:
    mov     r8d, [cfg_bg]

    mov     eax, r8d
    shr     eax, 16
    and     eax, 0xff
    imul    eax, ecx
    xor     edx, edx
    mov     esi, 255
    div     esi
    mov     r9d, eax

    mov     eax, r8d
    shr     eax, 8
    and     eax, 0xff
    imul    eax, ecx
    xor     edx, edx
    div     esi
    mov     r10d, eax

    mov     eax, r8d
    and     eax, 0xff
    imul    eax, ecx
    xor     edx, edx
    div     esi
    mov     r11d, eax

    shl     ecx, 24
    shl     r9d, 16
    shl     r10d, 8
    or      ecx, r9d
    or      ecx, r10d
    or      ecx, r11d
    mov     [cfg_bg_pixel], ecx

    pop     r13
    pop     r12
    pop     rbx
    ret

read_and_parse_fd:
    push    rbx
    push    r13
    mov     rbx, rdi
    mov     eax, SYS_READ
    mov     rdi, rbx
    lea     rsi, [conf_buf]
    mov     edx, 16383
    syscall
    mov     r13, rax
    mov     eax, SYS_CLOSE
    mov     rdi, rbx
    syscall
    test    r13, r13
    jle     .rp_done
    lea     rax, [conf_buf]
    mov     byte [rax + r13], 0
    call    parse_config_buf
.rp_done:
    pop     r13
    pop     rbx
    ret

parse_config_buf:
    push    rbx
    push    r12
    lea     rbx, [conf_buf]

.line_loop:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .done

.skip_ws1:
    movzx   eax, byte [rbx]
    cmp     al, ' '
    je      .next_ws1
    cmp     al, 9
    je      .next_ws1
    cmp     al, 13
    je      .next_ws1
    jmp     .check_line
.next_ws1:
    inc     rbx
    jmp     .skip_ws1

.check_line:
    test    al, al
    jz      .done
    cmp     al, 10
    je      .next_line
    cmp     al, '#'
    je      .skip_to_eol

    lea     rdi, [key_buf]
    xor     ecx, ecx
.read_key:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .end_key
    cmp     al, 10
    je      .end_key
    cmp     al, 13
    je      .end_key
    cmp     al, ' '
    je      .end_key
    cmp     al, 9
    je      .end_key
    cmp     al, '='
    je      .end_key
    cmp     ecx, 126
    jae     .skip_key_ch
    mov     [rdi + rcx], al
    inc     ecx
.skip_key_ch:
    inc     rbx
    jmp     .read_key
.end_key:
    mov     byte [rdi + rcx], 0

.skip_sep:
    movzx   eax, byte [rbx]
    cmp     al, ' '
    je      .next_sep
    cmp     al, 9
    je      .next_sep
    cmp     al, '='
    je      .next_sep
    jmp     .read_val_start
.next_sep:
    inc     rbx
    jmp     .skip_sep

.read_val_start:
    lea     rdi, [val_buf]
    xor     ecx, ecx
.read_val:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .end_val
    cmp     al, 10
    je      .end_val
    cmp     al, 13
    je      .end_val
    cmp     al, ' '
    je      .end_val
    cmp     al, 9
    je      .end_val
    cmp     ecx, 0
    je      .allow_hash
    cmp     al, '#'
    je      .end_val
.allow_hash:
    cmp     ecx, 126
    jae     .skip_val_ch
    mov     [rdi + rcx], al
    inc     ecx
.skip_val_ch:
    inc     rbx
    jmp     .read_val
.end_val:
    mov     byte [rdi + rcx], 0
    test    ecx, ecx
    jz      .skip_to_eol
    call    apply_kv

.skip_to_eol:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .done
    cmp     al, 10
    je      .next_line
    inc     rbx
    jmp     .skip_to_eol

.next_line:
    inc     rbx
    jmp     .line_loop

.done:
    pop     r12
    pop     rbx
    ret

apply_kv:
    lea     rdi, [key_buf]
    lea     rsi, [k_win_pad]
    call    streq
    test    eax, eax
    jnz     .do_win_pad

    lea     rdi, [key_buf]
    lea     rsi, [k_pad_x]
    call    streq
    test    eax, eax
    jnz     .do_pad_x

    lea     rdi, [key_buf]
    lea     rsi, [k_pad_y]
    call    streq
    test    eax, eax
    jnz     .do_pad_y

    lea     rdi, [key_buf]
    lea     rsi, [k_win_w]
    call    streq
    test    eax, eax
    jnz     .do_win_w

    lea     rdi, [key_buf]
    lea     rsi, [k_win_h]
    call    streq
    test    eax, eax
    jnz     .do_win_h

    lea     rdi, [key_buf]
    lea     rsi, [k_opacity]
    call    streq
    test    eax, eax
    jnz     .do_opacity

    lea     rdi, [key_buf]
    lea     rsi, [k_blur]
    call    streq
    test    eax, eax
    jnz     .do_blur

    lea     rdi, [key_buf]
    lea     rsi, [k_scroll]
    call    streq
    test    eax, eax
    jnz     .do_scroll

    lea     rdi, [key_buf]
    lea     rsi, [k_rep_delay]
    call    streq
    test    eax, eax
    jnz     .do_rep_delay

    lea     rdi, [key_buf]
    lea     rsi, [k_rep_rate]
    call    streq
    test    eax, eax
    jnz     .do_rep_rate

    lea     rdi, [key_buf]
    lea     rsi, [k_bg]
    call    streq
    test    eax, eax
    jnz     .do_bg

    lea     rdi, [key_buf]
    lea     rsi, [k_fg]
    call    streq
    test    eax, eax
    jnz     .do_fg

    lea     rdi, [key_buf]
    lea     rsi, [k_cursor]
    call    streq
    test    eax, eax
    jnz     .do_cursor

    lea     rdi, [key_buf]
    lea     rsi, [k_sel_bg]
    call    streq
    test    eax, eax
    jnz     .do_sel_bg

    lea     rdi, [key_buf]
    lea     rsi, [k_sel_fg]
    call    streq
    test    eax, eax
    jnz     .do_sel_fg

    lea     rdi, [key_buf]
    lea     rsi, [k_include]
    call    streq
    test    eax, eax
    jnz     .do_include

    lea     rdi, [key_buf]
    cmp     dword [rdi], 0x6f6c6f63
    jne     .kv_ret
    cmp     byte [rdi + 4], 'r'
    jne     .kv_ret
    add     rdi, 5
    call    parse_uint
    cmp     eax, 15
    ja      .kv_ret
    push    rax
    lea     rdi, [val_buf]
    call    parse_hex_color
    pop     rcx
    test    edx, edx
    jz      .kv_ret
    lea     rdx, [ansi_colors]
    mov     [rdx + rcx*4], eax
    ret
.kv_ret:
    ret

.do_win_pad:
    lea     rdi, [val_buf]
    call    parse_uint
    cmp     eax, 128
    ja      .kv_ret
    mov     [cfg_pad_x], eax
    mov     [cfg_pad_y], eax
    ret

.do_pad_x:
    lea     rdi, [val_buf]
    call    parse_uint
    cmp     eax, 128
    ja      .kv_ret
    mov     [cfg_pad_x], eax
    ret

.do_pad_y:
    lea     rdi, [val_buf]
    call    parse_uint
    cmp     eax, 128
    ja      .kv_ret
    mov     [cfg_pad_y], eax
    ret

.do_win_w:
    lea     rdi, [val_buf]
    call    parse_uint
    cmp     eax, 100
    jb      .kv_ret
    cmp     eax, 7680
    ja      .kv_ret
    mov     [cfg_win_w], eax
    ret

.do_win_h:
    lea     rdi, [val_buf]
    call    parse_uint
    cmp     eax, 100
    jb      .kv_ret
    cmp     eax, 4320
    ja      .kv_ret
    mov     [cfg_win_h], eax
    ret

.do_opacity:
    lea     rdi, [val_buf]
    call    parse_opacity
    mov     [cfg_opacity], eax
    ret

.do_blur:
    lea     rdi, [val_buf]
    call    parse_uint
    mov     [cfg_blur], eax
    ret

.do_scroll:
    lea     rdi, [val_buf]
    call    parse_uint
    test    eax, eax
    jz      .kv_ret
    cmp     eax, 64
    ja      .kv_ret
    mov     [cfg_scroll_lines], eax
    ret

.do_rep_delay:
    lea     rdi, [val_buf]
    call    parse_uint
    cmp     eax, 20
    jb      .kv_ret
    cmp     eax, 5000
    ja      .kv_ret
    mov     [repeat_delay], eax
    ret

.do_rep_rate:
    lea     rdi, [val_buf]
    call    parse_uint
    test    eax, eax
    jz      .kv_ret
    cmp     eax, 250
    ja      .kv_ret
    mov     [repeat_rate], eax
    ret

.do_bg:
    lea     rdi, [val_buf]
    call    parse_hex_color
    test    edx, edx
    jz      .kv_ret
    mov     [cfg_bg], eax
    ret

.do_fg:
    lea     rdi, [val_buf]
    call    parse_hex_color
    test    edx, edx
    jz      .kv_ret
    mov     [cfg_fg], eax
    ret

.do_cursor:
    lea     rdi, [val_buf]
    call    parse_hex_color
    test    edx, edx
    jz      .kv_ret
    mov     [cfg_cursor], eax
    ret

.do_sel_bg:
    lea     rdi, [val_buf]
    call    parse_hex_color
    test    edx, edx
    jz      .kv_ret
    mov     [cfg_sel_bg], eax
    ret

.do_sel_fg:
    lea     rdi, [val_buf]
    call    parse_hex_color
    test    edx, edx
    jz      .kv_ret
    mov     [cfg_sel_fg], eax
    ret

.do_include:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    cmp     byte [val_buf], '/'
    je      .inc_abs

    test    r12, r12
    jz      .inc_done
    cmp     byte [r12], 0
    je      .inc_done

    lea     rdi, [inc_path]
    mov     rsi, r12
    call    strcpy
    mov     rdi, rax
    lea     rsi, [s_slash_kitty]
    call    strcpy
    mov     rdi, rax
    lea     rsi, [val_buf]
    call    strcpy
    jmp     .inc_open

.inc_abs:
    lea     rdi, [inc_path]
    lea     rsi, [val_buf]
    call    strcpy

.inc_open:
    mov     eax, SYS_OPEN
    lea     rdi, [inc_path]
    mov     esi, O_RDONLY
    xor     edx, edx
    syscall
    test    rax, rax
    js      .inc_done
    mov     ebx, eax

    mov     eax, SYS_READ
    mov     edi, ebx
    lea     rsi, [inc_buf]
    mov     edx, 16383
    syscall
    mov     r13, rax

    mov     eax, SYS_CLOSE
    mov     edi, ebx
    syscall

    test    r13, r13
    jle     .inc_done
    lea     rax, [inc_buf]
    mov     byte [rax + r13], 0

    lea     rdi, [inc_buf]
    call    parse_included_buf

.inc_done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

parse_included_buf:
    push    rbx
    push    r12
    mov     rbx, rdi

.inc_line_loop:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .inc_buf_done

.inc_skip_ws1:
    movzx   eax, byte [rbx]
    cmp     al, ' '
    je      .inc_next_ws1
    cmp     al, 9
    je      .inc_next_ws1
    cmp     al, 13
    je      .inc_next_ws1
    jmp     .inc_check_line
.inc_next_ws1:
    inc     rbx
    jmp     .inc_skip_ws1

.inc_check_line:
    test    al, al
    jz      .inc_buf_done
    cmp     al, 10
    je      .inc_next_line
    cmp     al, '#'
    je      .inc_skip_to_eol

    lea     rdi, [key_buf]
    xor     ecx, ecx
.inc_read_key:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .inc_end_key
    cmp     al, 10
    je      .inc_end_key
    cmp     al, 13
    je      .inc_end_key
    cmp     al, ' '
    je      .inc_end_key
    cmp     al, 9
    je      .inc_end_key
    cmp     al, '='
    je      .inc_end_key
    cmp     ecx, 126
    jae     .inc_skip_key_ch
    mov     [rdi + rcx], al
    inc     ecx
.inc_skip_key_ch:
    inc     rbx
    jmp     .inc_read_key
.inc_end_key:
    mov     byte [rdi + rcx], 0

.inc_skip_sep:
    movzx   eax, byte [rbx]
    cmp     al, ' '
    je      .inc_next_sep
    cmp     al, 9
    je      .inc_next_sep
    cmp     al, '='
    je      .inc_next_sep
    jmp     .inc_read_val_start
.inc_next_sep:
    inc     rbx
    jmp     .inc_skip_sep

.inc_read_val_start:
    lea     rdi, [val_buf]
    xor     ecx, ecx
.inc_read_val:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .inc_end_val
    cmp     al, 10
    je      .inc_end_val
    cmp     al, 13
    je      .inc_end_val
    cmp     al, ' '
    je      .inc_end_val
    cmp     al, 9
    je      .inc_end_val
    cmp     ecx, 0
    je      .inc_allow_hash
    cmp     al, '#'
    je      .inc_end_val
.inc_allow_hash:
    cmp     ecx, 126
    jae     .inc_skip_val_ch
    mov     [rdi + rcx], al
    inc     ecx
.inc_skip_val_ch:
    inc     rbx
    jmp     .inc_read_val
.inc_end_val:
    mov     byte [rdi + rcx], 0
    test    ecx, ecx
    jz      .inc_skip_to_eol

    lea     rdi, [key_buf]
    lea     rsi, [k_include]
    call    streq
    test    eax, eax
    jnz     .inc_skip_to_eol

    call    apply_kv

.inc_skip_to_eol:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .inc_buf_done
    cmp     al, 10
    je      .inc_next_line
    inc     rbx
    jmp     .inc_skip_to_eol

.inc_next_line:
    inc     rbx
    jmp     .inc_line_loop

.inc_buf_done:
    pop     r12
    pop     rbx
    ret

parse_uint:
    xor     eax, eax
.u_loop:
    movzx   ecx, byte [rdi]
    cmp     cl, '0'
    jb      .u_done
    cmp     cl, '9'
    ja      .u_done
    imul    eax, 10
    lea     eax, [rax + rcx - '0']
    inc     rdi
    jmp     .u_loop
.u_done:
    ret

parse_opacity:
    movzx   eax, byte [rdi]
    cmp     al, '1'
    jne     .check_zero
    movzx   ecx, byte [rdi + 1]
    test    cl, cl
    jz      .ret_255
    cmp     cl, '.'
    je      .ret_255
    jmp     .as_percent
.check_zero:
    cmp     al, '0'
    jne     .as_percent
    cmp     byte [rdi + 1], '.'
    jne     .ret_0
    movzx   eax, byte [rdi + 2]
    cmp     al, '0'
    jb      .ret_0
    cmp     al, '9'
    ja      .ret_0
    sub     eax, '0'
    imul    eax, 10
    movzx   ecx, byte [rdi + 3]
    cmp     cl, '0'
    jb      .calc_frac
    cmp     cl, '9'
    ja      .calc_frac
    sub     ecx, '0'
    add     eax, ecx
.calc_frac:
    imul    eax, 255
    xor     edx, edx
    mov     ecx, 100
    div     ecx
    ret
.as_percent:
    call    parse_uint
    cmp     eax, 100
    ja      .ret_255
    imul    eax, 255
    xor     edx, edx
    mov     ecx, 100
    div     ecx
    ret
.ret_0:
    xor     eax, eax
    ret
.ret_255:
    mov     eax, 255
    ret

parse_hex_color:
    cmp     byte [rdi], '#'
    jne     .check_0x
    inc     rdi
    jmp     .hex_start
.check_0x:
    cmp     byte [rdi], '0'
    jne     .hex_start
    cmp     byte [rdi + 1], 'x'
    jne     .hex_start
    add     rdi, 2
.hex_start:
    xor     eax, eax
    xor     ecx, ecx
.hex_loop:
    movzx   edx, byte [rdi + rcx]
    test    dl, dl
    jz      .hex_done
    cmp     dl, '0'
    jb      .hex_fail
    cmp     dl, '9'
    jbe     .hex_digit
    or      dl, 0x20
    cmp     dl, 'a'
    jb      .hex_fail
    cmp     dl, 'f'
    ja      .hex_fail
    sub     dl, 'a' - 10
    jmp     .hex_acc
.hex_digit:
    sub     dl, '0'
.hex_acc:
    shl     eax, 4
    or      eax, edx
    inc     ecx
    cmp     ecx, 6
    jb      .hex_loop
.hex_done:
    cmp     ecx, 6
    jne     .hex_fail
    mov     edx, 1
    ret
.hex_fail:
    xor     eax, eax
    xor     edx, edx
    ret
