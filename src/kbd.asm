default rel
%include "syscalls.inc"

global kbd_handle_key
global kbd_handle_modifiers
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
%define KEY_H           35
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
%define KEY_LEFTALT     56
%define KEY_SPACE       57
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

seq_up:         db 27, '[', 'A'
seq_down:       db 27, '[', 'B'
seq_right:      db 27, '[', 'C'
seq_left:       db 27, '[', 'D'
seq_home:       db 27, '[', 'H'
seq_end:        db 27, '[', 'F'
seq_ctrl_right: db 27, '[', '1', ';', '5', 'C'
seq_ctrl_left:  db 27, '[', '1', ';', '5', 'D'
seq_ctrl_up:    db 27, '[', '1', ';', '5', 'A'
seq_ctrl_down:  db 27, '[', '1', ';', '5', 'B'
seq_delete:     db 27, '[', '3', '~'
seq_pageup:     db 27, '[', '5', '~'
seq_pagedown:   db 27, '[', '6', '~'

wl_copy_path:   db "/usr/bin/wl-copy", 0
wl_paste_path:  db "/usr/bin/wl-paste", 0
wl_paste_arg1:  db "-n", 0

section .text

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
    cmp     edi, KEY_DELETE
    je      .send_delete
    cmp     edi, KEY_PAGEUP
    je      .send_pageup
    cmp     edi, KEY_PAGEDOWN
    je      .send_pagedown

    cmp     edi, 58
    jae     .ret

    mov     eax, [mod_depressed]
    test    eax, 1
    jnz     .with_shift

    lea     rdx, [map_norm]
    movzx   eax, byte [rdx + rdi]
    jmp     .got_char

.with_shift:
    lea     rdx, [map_shift]
    movzx   eax, byte [rdx + rdi]

.got_char:
    test    al, al
    jz      .ret

    mov     ecx, [mod_depressed]
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
    test    ecx, 8
    jz      .write_one
    lea     rdx, [kbd_input_buf]
    mov     byte [rdx], 27
    mov     [rdx + 1], al
    mov     dword [kbd_input_len], 2
    ret

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
.send_3:
    lea     rdi, [kbd_input_buf]
    mov     eax, [rsi]
    mov     [rdi], ax
    mov     al, [rsi + 2]
    mov     [rdi + 2], al
    mov     dword [kbd_input_len], 3
    ret

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
