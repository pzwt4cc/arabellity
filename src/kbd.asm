default rel

global kbd_handle_key
global kbd_handle_modifiers
global kbd_input_buf
global kbd_input_len

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
%define KEY_UP          103
%define KEY_LEFT        105
%define KEY_RIGHT       106
%define KEY_DOWN        108

section .bss
kbd_input_buf:      resb 64
kbd_input_len:      resd 1
mod_depressed:      resd 1
mod_latched:        resd 1
mod_locked:         resd 1
mod_group:          resd 1

section .rodata
map_norm:
    db 0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8, 9
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 13, 0
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\'
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '

map_shift:
    db 0, 27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 8, 9
    db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 13, 0
    db 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0, '|'
    db 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' '

seq_up:     db 27, '[', 'A'
seq_down:   db 27, '[', 'B'
seq_right:  db 27, '[', 'C'
seq_left:   db 27, '[', 'D'

section .text

kbd_handle_modifiers:
    mov     [mod_depressed], edi
    mov     [mod_latched], esi
    mov     [mod_locked], edx
    mov     [mod_group], ecx
    ret

kbd_handle_key:
    mov     dword [kbd_input_len], 0
    test    esi, esi
    jz      .ret

    cmp     edi, KEY_UP
    je      .send_up
    cmp     edi, KEY_DOWN
    je      .send_down
    cmp     edi, KEY_RIGHT
    je      .send_right
    cmp     edi, KEY_LEFT
    je      .send_left

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
    jz      .write_one

    cmp     al, 'a'
    jb      .ctrl_upper
    cmp     al, 'z'
    ja      .write_one
    sub     al, 'a' - 1
    jmp     .write_one
.ctrl_upper:
    cmp     al, 'A'
    jb      .write_one
    cmp     al, 'Z'
    ja      .write_one
    sub     al, 'A' - 1

.write_one:
    lea     rdx, [kbd_input_buf]
    mov     [rdx], al
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
.send_3:
    lea     rdi, [kbd_input_buf]
    mov     eax, [rsi]
    mov     [rdi], ax
    mov     al, [rsi + 2]
    mov     [rdi + 2], al
    mov     dword [kbd_input_len], 3
.ret:
    ret
