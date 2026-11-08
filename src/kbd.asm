default rel
%include "syscalls.inc"

global kbd_handle_key
global kbd_handle_modifiers
global kbd_is_modifier
global kbd_input_buf
global kbd_input_len
global kbd_action
global clip_copy_system
global clip_paste_system

extern term_copy_selection
extern term_get_selection
extern term_scroll_view_up
extern term_scroll_view_down
extern term_scroll_view_to_bottom
extern win_pty_fd
extern win_envp
extern write_all

%define KEY_ESC         1
%define KEY_1           2
%define KEY_2           3
%define KEY_3           4
%define KEY_4           5
%define KEY_5           6
%define KEY_6           7
%define KEY_7           8
%define KEY_8           9
%define KEY_9           10
%define KEY_0           11
%define KEY_MINUS       12
%define KEY_EQUAL       13
%define KEY_BACKSPACE   14
%define KEY_TAB         15
%define KEY_Q           16
%define KEY_W           17
%define KEY_E           18
%define KEY_R           19
%define KEY_T           20
%define KEY_Y           21
%define KEY_U           22
%define KEY_I           23
%define KEY_O           24
%define KEY_P           25
%define KEY_LEFTBRACE   26
%define KEY_RIGHTBRACE  27
%define KEY_ENTER       28
%define KEY_LEFTCTRL    29
%define KEY_A           30
%define KEY_S           31
%define KEY_D           32
%define KEY_F           33
%define KEY_G           34
%define KEY_J           36
%define KEY_K           37
%define KEY_L           38
%define KEY_SEMICOLON   39
%define KEY_APOSTROPHE  40
%define KEY_GRAVE       41
%define KEY_LEFTSHIFT   42
%define KEY_BACKSLASH   43
%define KEY_Z           44
%define KEY_X           45
%define KEY_C           46
%define KEY_V           47
%define KEY_B           48
%define KEY_N           49
%define KEY_M           50
%define KEY_COMMA       51
%define KEY_DOT         52
%define KEY_SLASH       53
%define KEY_RIGHTSHIFT  54
%define KEY_KPASTERISK  55
%define KEY_LEFTALT     56
%define KEY_SPACE       57
%define KEY_CAPSLOCK    58
%define KEY_F1          59
%define KEY_F2          60
%define KEY_F3          61
%define KEY_F4          62
%define KEY_F5          63
%define KEY_F6          64
%define KEY_F7          65
%define KEY_F8          66
%define KEY_F9          67
%define KEY_F10         68
%define KEY_NUMLOCK     69
%define KEY_SCROLLLOCK  70
%define KEY_KP7         71
%define KEY_KP8         72
%define KEY_KP9         73
%define KEY_KPMINUS     74
%define KEY_KP4         75
%define KEY_KP5         76
%define KEY_KP6         77
%define KEY_KPPLUS      78
%define KEY_KP1         79
%define KEY_KP2         80
%define KEY_KP3         81
%define KEY_KP0         82
%define KEY_KPDOT       83
%define KEY_F11         87
%define KEY_F12         88
%define KEY_KPENTER     96
%define KEY_RIGHTCTRL   97
%define KEY_KPSLASH     98
%define KEY_RIGHTALT    100
%define KEY_HOME        102
%define KEY_UP          103
%define KEY_PAGEUP      104
%define KEY_LEFT        105
%define KEY_RIGHT       106
%define KEY_END         107
%define KEY_DOWN        108
%define KEY_PAGEDOWN    109
%define KEY_INSERT      110
%define KEY_DELETE      111
%define KEY_LEFTMETA    125
%define KEY_RIGHTMETA   126

section .bss
kbd_input_buf:      resb 64
kbd_input_len:      resd 1
kbd_action:         resd 1
mod_depressed:      resd 1
mod_latched:        resd 1
mod_locked:         resd 1
mod_group:          resd 1
pipe_fds:           resd 2
clip_status:        resd 1
paste_buf:          resb 4096

section .rodata
map_norm:
    db 0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 127, 9
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 13, 0
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\'
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '

map_shift:
    db 0, 27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 127, 9
    db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 13, 0
    db 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0, '|'
    db 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' '

map_ru_norm:
    dw 0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 127, 9
    dw 0x0439, 0x0446, 0x0443, 0x043A, 0x0435, 0x043D, 0x0433, 0x0448, 0x0449, 0x0437, 0x0445, 0x044A, 13, 0
    dw 0x0444, 0x044B, 0x0432, 0x0430, 0x043F, 0x0440, 0x043E, 0x043B, 0x0434, 0x0436, 0x044D, 0x0451, 0, '\'
    dw 0x044F, 0x0447, 0x0441, 0x043C, 0x0438, 0x0442, 0x044C, 0x0431, 0x044E, '.', 0, '*', 0, ' '

map_ru_shift:
    dw 0, 27, '!', '"', 0x2116, ';', '%', ':', '?', '*', '(', ')', '_', '+', 127, 9
    dw 0x0419, 0x0426, 0x0423, 0x041A, 0x0415, 0x041D, 0x0413, 0x0428, 0x0429, 0x0417, 0x0425, 0x042A, 13, 0
    dw 0x0424, 0x042B, 0x0412, 0x0410, 0x041F, 0x0420, 0x041E, 0x041B, 0x0414, 0x0416, 0x042D, 0x0401, 0, '/'
    dw 0x042F, 0x0427, 0x0421, 0x041C, 0x0418, 0x0422, 0x042C, 0x0411, 0x042E, ',', 0, '*', 0, ' '

map_kp:
    db '7', '8', '9', '-', '4', '5', '6', '+', '1', '2', '3', '0', '.'

seq_up:         db 27, '[', 'A'
seq_down:       db 27, '[', 'B'
seq_right:      db 27, '[', 'C'
seq_left:       db 27, '[', 'D'
seq_home:       db 27, '[', 'H'
seq_end:        db 27, '[', 'F'
seq_f1:         db 27, 'O', 'P'
seq_f2:         db 27, 'O', 'Q'
seq_f3:         db 27, 'O', 'R'
seq_f4:         db 27, 'O', 'S'
seq_ctrl_right: db 27, '[', '1', ';', '5', 'C'
seq_ctrl_left:  db 27, '[', '1', ';', '5', 'D'
seq_ctrl_up:    db 27, '[', '1', ';', '5', 'A'
seq_ctrl_down:  db 27, '[', '1', ';', '5', 'B'
seq_insert:     db 27, '[', '2', '~'
seq_delete:     db 27, '[', '3', '~'
seq_pageup:     db 27, '[', '5', '~'
seq_pagedown:   db 27, '[', '6', '~'
seq_f5:         db 27, '[', '1', '5', '~'
seq_f6:         db 27, '[', '1', '7', '~'
seq_f7:         db 27, '[', '1', '8', '~'
seq_f8:         db 27, '[', '1', '9', '~'
seq_f9:         db 27, '[', '2', '0', '~'
seq_f10:        db 27, '[', '2', '1', '~'
seq_f11:        db 27, '[', '2', '3', '~'
seq_f12:        db 27, '[', '2', '4', '~'

wl_copy_path:   db "/usr/bin/wl-copy", 0
wl_paste_path:  db "/usr/bin/wl-paste", 0
wl_paste_arg1:  db "-n", 0

section .text

kbd_is_modifier:
    cmp     edi, KEY_LEFTCTRL
    je      .yes
    cmp     edi, KEY_RIGHTCTRL
    je      .yes
    cmp     edi, KEY_LEFTSHIFT
    je      .yes
    cmp     edi, KEY_RIGHTSHIFT
    je      .yes
    cmp     edi, KEY_LEFTALT
    je      .yes
    cmp     edi, KEY_RIGHTALT
    je      .yes
    cmp     edi, KEY_CAPSLOCK
    je      .yes
    cmp     edi, KEY_NUMLOCK
    je      .yes
    cmp     edi, KEY_SCROLLLOCK
    je      .yes
    cmp     edi, KEY_LEFTMETA
    je      .yes
    cmp     edi, KEY_RIGHTMETA
    je      .yes
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret

kbd_handle_modifiers:
    mov     [mod_depressed], edi
    mov     [mod_latched], esi
    mov     [mod_locked], edx
    mov     [mod_group], ecx
    ret

kbd_handle_key:
    mov     dword [kbd_input_len], 0
    mov     dword [kbd_action], 0
    test    esi, esi
    jz      .ret

    mov     eax, [mod_depressed]
    or      eax, [mod_latched]

    test    eax, 1
    jz      .not_shift_special
    cmp     edi, KEY_PAGEUP
    je      .do_scroll_page_up
    cmp     edi, KEY_PAGEDOWN
    je      .do_scroll_page_down
    cmp     edi, KEY_INSERT
    je      .do_paste
    test    eax, 4
    jz      .not_shift_special
    cmp     edi, KEY_C
    je      .do_copy
    cmp     edi, KEY_V
    je      .do_paste
    cmp     edi, KEY_UP
    je      .do_scroll_line_up
    cmp     edi, KEY_DOWN
    je      .do_scroll_line_down
.not_shift_special:

    test    eax, 4
    jz      .not_ctrl_special
    cmp     edi, KEY_INSERT
    je      .do_copy
    cmp     edi, KEY_LEFT
    je      .send_ctrl_left
    cmp     edi, KEY_RIGHT
    je      .send_ctrl_right
    cmp     edi, KEY_UP
    je      .send_ctrl_up
    cmp     edi, KEY_DOWN
    je      .send_ctrl_down
    cmp     edi, KEY_BACKSPACE
    je      .send_ctrl_bs
.not_ctrl_special:

    cmp     edi, KEY_UP
    je      .send_up
    cmp     edi, KEY_DOWN
    je      .send_down
    cmp     edi, KEY_RIGHT
    je      .send_right
    cmp     edi, KEY_LEFT
    je      .send_left
    cmp     edi, KEY_HOME
    je      .send_home
    cmp     edi, KEY_END
    je      .send_end
    cmp     edi, KEY_INSERT
    je      .send_insert
    cmp     edi, KEY_DELETE
    je      .send_delete
    cmp     edi, KEY_PAGEUP
    je      .send_pageup
    cmp     edi, KEY_PAGEDOWN
    je      .send_pagedown
    cmp     edi, KEY_F1
    je      .send_f1
    cmp     edi, KEY_F2
    je      .send_f2
    cmp     edi, KEY_F3
    je      .send_f3
    cmp     edi, KEY_F4
    je      .send_f4
    cmp     edi, KEY_F5
    je      .send_f5
    cmp     edi, KEY_F6
    je      .send_f6
    cmp     edi, KEY_F7
    je      .send_f7
    cmp     edi, KEY_F8
    je      .send_f8
    cmp     edi, KEY_F9
    je      .send_f9
    cmp     edi, KEY_F10
    je      .send_f10
    cmp     edi, KEY_F11
    je      .send_f11
    cmp     edi, KEY_F12
    je      .send_f12

    cmp     edi, KEY_KPENTER
    je      .send_kpenter
    cmp     edi, KEY_KPSLASH
    je      .send_kpslash
    cmp     edi, KEY_KP7
    jb      .not_kp
    cmp     edi, KEY_KPDOT
    ja      .not_kp
    sub     edi, KEY_KP7
    lea     rdx, [map_kp]
    movzx   eax, byte [rdx + rdi]
    jmp     .write_one
.not_kp:

    cmp     edi, 58
    jae     .ret

    mov     ecx, [mod_depressed]
    or      ecx, [mod_latched]
    test    ecx, 4
    jnz     .us_layout

    cmp     dword [mod_group], 0
    jne     .ru_layout

.us_layout:
    mov     eax, [mod_depressed]
    or      eax, [mod_latched]
    and     eax, 1
    lea     rdx, [map_norm]
    test    eax, eax
    jz      .us_check_caps
    lea     rdx, [map_shift]
.us_check_caps:
    movzx   eax, byte [rdx + rdi]
    test    byte [mod_locked], 2
    jz      .got_us_char
    cmp     al, 'a'
    jb      .us_caps_upper
    cmp     al, 'z'
    ja      .got_us_char
    sub     al, 32
    jmp     .got_us_char
.us_caps_upper:
    cmp     al, 'A'
    jb      .got_us_char
    cmp     al, 'Z'
    ja      .got_us_char
    add     al, 32

.got_us_char:
    test    al, al
    jz      .ret

    mov     ecx, [mod_depressed]
    or      ecx, [mod_latched]
    test    ecx, 4
    jz      .check_alt

    cmp     al, 'a'
    jb      .ctrl_upper
    cmp     al, 'z'
    ja      .ctrl_other
    sub     al, 'a' - 1
    jmp     .check_alt
.ctrl_upper:
    cmp     al, 'A'
    jb      .ctrl_other
    cmp     al, 'Z'
    ja      .ctrl_other
    sub     al, 'A' - 1
    jmp     .check_alt
.ctrl_other:
    cmp     al, '['
    je      .ctrl_esc
    cmp     al, '\'
    je      .ctrl_fs
    cmp     al, ']'
    je      .ctrl_gs
    cmp     al, '/'
    je      .ctrl_us
    cmp     al, '_'
    je      .ctrl_us
    cmp     al, ' '
    je      .ctrl_nul
    jmp     .check_alt
.ctrl_esc:
    mov     al, 27
    jmp     .check_alt
.ctrl_fs:
    mov     al, 28
    jmp     .check_alt
.ctrl_gs:
    mov     al, 29
    jmp     .check_alt
.ctrl_us:
    mov     al, 31
    jmp     .check_alt
.ctrl_nul:
    xor     al, al

.check_alt:
    mov     ecx, [mod_depressed]
    or      ecx, [mod_latched]
    test    ecx, 8
    jz      .write_one
    lea     rdx, [kbd_input_buf]
    mov     byte [rdx], 27
    mov     [rdx + 1], al
    mov     dword [kbd_input_len], 2
    ret

.ru_layout:
    mov     eax, [mod_depressed]
    or      eax, [mod_latched]
    and     eax, 1
    lea     rdx, [map_ru_norm]
    test    eax, eax
    jz      .ru_check_caps
    lea     rdx, [map_ru_shift]
.ru_check_caps:
    movzx   eax, word [rdx + rdi*2]
    test    eax, eax
    jz      .ret

    test    byte [mod_locked], 2
    jz      .encode_utf8
    cmp     eax, 0x0430
    jb      .ru_caps_check_upper
    cmp     eax, 0x044F
    ja      .ru_caps_check_yo
    sub     eax, 0x20
    jmp     .encode_utf8
.ru_caps_check_yo:
    cmp     eax, 0x0451
    jne     .encode_utf8
    mov     eax, 0x0401
    jmp     .encode_utf8
.ru_caps_check_upper:
    cmp     eax, 0x0410
    jb      .ru_caps_check_yo_up
    cmp     eax, 0x042F
    ja      .encode_utf8
    add     eax, 0x20
    jmp     .encode_utf8
.ru_caps_check_yo_up:
    cmp     eax, 0x0401
    jne     .encode_utf8
    mov     eax, 0x0451

.encode_utf8:
    lea     rdx, [kbd_input_buf]
    xor     ecx, ecx
    mov     r8d, [mod_depressed]
    or      r8d, [mod_latched]
    test    r8d, 8
    jz      .no_ru_alt
    mov     byte [rdx], 27
    inc     rdx
    inc     ecx
.no_ru_alt:
    cmp     eax, 0x80
    jb      .utf8_1
    cmp     eax, 0x800
    jb      .utf8_2

    mov     esi, eax
    shr     esi, 12
    and     sil, 0x0F
    or      sil, 0xE0
    mov     [rdx], sil
    mov     esi, eax
    shr     esi, 6
    and     sil, 0x3F
    or      sil, 0x80
    mov     [rdx + 1], sil
    and     al, 0x3F
    or      al, 0x80
    mov     [rdx + 2], al
    add     ecx, 3
    mov     [kbd_input_len], ecx
    ret

.utf8_2:
    mov     esi, eax
    shr     esi, 6
    and     sil, 0x1F
    or      sil, 0xC0
    mov     [rdx], sil
    and     al, 0x3F
    or      al, 0x80
    mov     [rdx + 1], al
    add     ecx, 2
    mov     [kbd_input_len], ecx
    ret

.utf8_1:
    mov     [rdx], al
    inc     ecx
    mov     [kbd_input_len], ecx
    ret

.send_kpenter:
    mov     al, 13
    jmp     .write_one
.send_kpslash:
    mov     al, '/'

.write_one:
    lea     rdx, [kbd_input_buf]
    mov     [rdx], al
    mov     dword [kbd_input_len], 1
    ret

.send_ctrl_bs:
    lea     rdx, [kbd_input_buf]
    mov     byte [rdx], 23
    mov     dword [kbd_input_len], 1
    ret

.send_up:
    lea     rsi, [seq_up]
    jmp     .send_3
.send_down:
    lea     rsi, [seq_down]
    jmp     .send_3
.send_right:
    lea     rsi, [seq_right]
    jmp     .send_3
.send_left:
    lea     rsi, [seq_left]
    jmp     .send_3
.send_home:
    lea     rsi, [seq_home]
    jmp     .send_3
.send_end:
    lea     rsi, [seq_end]
    jmp     .send_3
.send_f1:
    lea     rsi, [seq_f1]
    jmp     .send_3
.send_f2:
    lea     rsi, [seq_f2]
    jmp     .send_3
.send_f3:
    lea     rsi, [seq_f3]
    jmp     .send_3
.send_f4:
    lea     rsi, [seq_f4]
.send_3:
    lea     rdi, [kbd_input_buf]
    mov     eax, [rsi]
    mov     [rdi], ax
    mov     al, [rsi + 2]
    mov     [rdi + 2], al
    mov     dword [kbd_input_len], 3
    ret

.send_insert:
    lea     rsi, [seq_insert]
    jmp     .send_4
.send_delete:
    lea     rsi, [seq_delete]
    jmp     .send_4
.send_pageup:
    lea     rsi, [seq_pageup]
    jmp     .send_4
.send_pagedown:
    lea     rsi, [seq_pagedown]
.send_4:
    lea     rdi, [kbd_input_buf]
    mov     eax, [rsi]
    mov     [rdi], eax
    mov     dword [kbd_input_len], 4
    ret

.send_f5:
    lea     rsi, [seq_f5]
    jmp     .send_5
.send_f6:
    lea     rsi, [seq_f6]
    jmp     .send_5
.send_f7:
    lea     rsi, [seq_f7]
    jmp     .send_5
.send_f8:
    lea     rsi, [seq_f8]
    jmp     .send_5
.send_f9:
    lea     rsi, [seq_f9]
    jmp     .send_5
.send_f10:
    lea     rsi, [seq_f10]
    jmp     .send_5
.send_f11:
    lea     rsi, [seq_f11]
    jmp     .send_5
.send_f12:
    lea     rsi, [seq_f12]
.send_5:
    lea     rdi, [kbd_input_buf]
    mov     eax, [rsi]
    mov     [rdi], eax
    mov     al, [rsi + 4]
    mov     [rdi + 4], al
    mov     dword [kbd_input_len], 5
    ret

.send_ctrl_right:
    lea     rsi, [seq_ctrl_right]
    jmp     .send_6
.send_ctrl_left:
    lea     rsi, [seq_ctrl_left]
    jmp     .send_6
.send_ctrl_up:
    lea     rsi, [seq_ctrl_up]
    jmp     .send_6
.send_ctrl_down:
    lea     rsi, [seq_ctrl_down]
.send_6:
    lea     rdi, [kbd_input_buf]
    mov     eax, [rsi]
    mov     [rdi], eax
    movzx   eax, word [rsi + 4]
    mov     [rdi + 4], ax
    mov     dword [kbd_input_len], 6
    ret

.do_scroll_page_up:
    mov     edi, 10
    call    term_scroll_view_up
    mov     dword [kbd_action], 1
    ret

.do_scroll_page_down:
    mov     edi, 10
    call    term_scroll_view_down
    mov     dword [kbd_action], 1
    ret

.do_scroll_line_up:
    mov     edi, 1
    call    term_scroll_view_up
    mov     dword [kbd_action], 1
    ret

.do_scroll_line_down:
    mov     edi, 1
    call    term_scroll_view_down
    mov     dword [kbd_action], 1
    ret

.do_copy:
    call    term_copy_selection
    test    edx, edx
    jz      .ret
    mov     rdi, rax
    mov     esi, edx
    call    clip_copy_system
    mov     dword [kbd_action], 1
    ret

.do_paste:
    call    term_scroll_view_to_bottom
    call    clip_paste_system
    mov     dword [kbd_action], 1
.ret:
    ret

clip_copy_system:
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13d, esi

    mov     eax, SYS_PIPE2
    lea     rdi, [pipe_fds]
    mov     esi, O_CLOEXEC
    syscall
    test    rax, rax
    js      .done

    mov     eax, SYS_FORK
    syscall
    test    rax, rax
    js      .close_both
    jnz     .parent

    mov     eax, SYS_DUP2
    mov     edi, [pipe_fds]
    xor     esi, esi
    syscall

    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds]
    syscall
    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds + 4]
    syscall

    push    0
    lea     rax, [wl_copy_path]
    push    rax
    mov     rdi, rax
    mov     rsi, rsp
    mov     rdx, [win_envp]
    mov     eax, SYS_EXECVE
    syscall

    mov     eax, SYS_EXIT
    mov     edi, 127
    syscall

.parent:
    mov     rbx, rax
    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds]
    syscall

    mov     edi, [pipe_fds + 4]
    mov     rsi, r12
    mov     edx, r13d
    call    write_all

    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds + 4]
    syscall

    mov     eax, SYS_WAIT4
    mov     rdi, rbx
    lea     rsi, [clip_status]
    xor     edx, edx
    xor     r10d, r10d
    syscall
    jmp     .done

.close_both:
    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds]
    syscall
    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds + 4]
    syscall

.done:
    pop     r13
    pop     r12
    pop     rbx
    ret

clip_paste_system:
    push    rbx
    push    r12

    mov     eax, SYS_PIPE2
    lea     rdi, [pipe_fds]
    mov     esi, O_CLOEXEC
    syscall
    test    rax, rax
    js      .fallback_internal

    mov     eax, SYS_FORK
    syscall
    test    rax, rax
    js      .close_both_paste
    jnz     .parent_paste

    mov     eax, SYS_DUP2
    mov     edi, [pipe_fds + 4]
    mov     esi, 1
    syscall

    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds]
    syscall
    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds + 4]
    syscall

    push    0
    lea     rax, [wl_paste_arg1]
    push    rax
    lea     rax, [wl_paste_path]
    push    rax
    mov     rdi, rax
    mov     rsi, rsp
    mov     rdx, [win_envp]
    mov     eax, SYS_EXECVE
    syscall

    mov     eax, SYS_EXIT
    mov     edi, 127
    syscall

.parent_paste:
    mov     rbx, rax
    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds + 4]
    syscall

    xor     r12d, r12d
.read_paste_loop:
    mov     eax, SYS_READ
    mov     edi, [pipe_fds]
    lea     rsi, [paste_buf]
    mov     edx, 4096
    syscall
    test    rax, rax
    jle     .read_paste_done
    add     r12d, eax
    mov     edx, eax
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .read_paste_loop
    lea     rsi, [paste_buf]
    call    write_all
    jmp     .read_paste_loop

.read_paste_done:
    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds]
    syscall

    mov     eax, SYS_WAIT4
    mov     rdi, rbx
    lea     rsi, [clip_status]
    xor     edx, edx
    xor     r10d, r10d
    syscall

    test    r12d, r12d
    jnz     .paste_done
    jmp     .fallback_internal

.close_both_paste:
    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds]
    syscall
    mov     eax, SYS_CLOSE
    mov     edi, [pipe_fds + 4]
    syscall

.fallback_internal:
    call    term_get_selection
    test    edx, edx
    jz      .paste_done
    mov     rsi, rax
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .paste_done
    call    write_all

.paste_done:
    pop     r12
    pop     rbx
    ret
