default rel

global term_init
global term_resize
global term_feed
global term_render
global term_cols
global term_rows
global term_cursor_col
global term_cursor_row
global term_sel_start_col
global term_sel_start_row
global term_sel_end_col
global term_sel_end_row
global term_has_sel
global term_set_sel_start
global term_update_sel_end
global term_clear_sel
global term_scroll_view_up
global term_scroll_view_down
global term_scroll_view_to_bottom

extern font_glyph_data
extern font_glyph_for_char
extern write_all
extern win_pty_fd

%define MAX_COLS       256
%define MAX_ROWS       128
%define CELL_SIZE      16
%define SCROLLBACK_MAX 1024

%define COLOR_BG       0x000000
%define COLOR_FG       0xc9d1d9
%define COLOR_CURSOR   0x39ff14
%define COLOR_SEL_BG   0x264f78
%define COLOR_SEL_FG   0xffffff
%define PAD_X          8
%define PAD_Y          8

%define FONT_W         10
%define FONT_H         20

section .bss
term_cols:          resd 1
term_rows:          resd 1
term_cursor_col:    resd 1
term_cursor_row:    resd 1
saved_cursor_col:   resd 1
saved_cursor_row:   resd 1
cur_fg:             resd 1
cur_bg:             resd 1

term_sel_start_col: resd 1
term_sel_start_row: resd 1
term_sel_end_col:   resd 1
term_sel_end_row:   resd 1
term_has_sel:       resb 1

cur_row_ptr:        resq 1
scrollback_count:   resd 1
scrollback_head:    resd 1
scroll_offset:      resd 1

esc_state:          resd 1
csi_argc:           resd 1
csi_args:           resd 16
csi_private:        resb 1
utf8_state:         resd 1
utf8_codepoint:     resd 1
cursor_visible:     resb 1
cpr_buf:            resb 32

grid:               resb MAX_COLS * MAX_ROWS * CELL_SIZE
scrollback:         resb SCROLLBACK_MAX * MAX_COLS * CELL_SIZE
empty_line:         resb MAX_COLS * CELL_SIZE

section .rodata
ansi_colors:
    dd 0x000000, 0xcd0000, 0x00cd00, 0xcdcd00
    dd 0x0000ee, 0xcd00cd, 0x00cdcd, 0xe5e5e5
    dd 0x7f7f7f, 0xff0000, 0x00ff00, 0xffff00
    dd 0x5c5cff, 0xff00ff, 0x00ffff, 0xffffff

section .text

term_init:
    mov     dword [term_cols], 80
    mov     dword [term_rows], 24
    mov     dword [term_cursor_col], 0
    mov     dword [term_cursor_row], 0
    mov     dword [saved_cursor_col], 0
    mov     dword [saved_cursor_row], 0
    mov     dword [cur_fg], COLOR_FG
    mov     dword [cur_bg], COLOR_BG
    mov     dword [esc_state], 0
    mov     dword [utf8_state], 0
    mov     byte [cursor_visible], 1
    mov     byte [term_has_sel], 0
    mov     dword [scrollback_count], 0
    mov     dword [scrollback_head], 0
    mov     dword [scroll_offset], 0
    call    init_empty_line
    call    term_clear_grid
    ret

init_empty_line:
    lea     rdi, [empty_line]
    mov     ecx, MAX_COLS
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.el_fill:
    mov     dword [rdi], eax
    mov     dword [rdi + 4], edx
    mov     dword [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .el_fill
    ret

term_set_sel_start:
    mov     [term_sel_start_col], edi
    mov     [term_sel_start_row], esi
    mov     [term_sel_end_col], edi
    mov     [term_sel_end_row], esi
    mov     byte [term_has_sel], 1
    ret

term_update_sel_end:
    mov     [term_sel_end_col], edi
    mov     [term_sel_end_row], esi
    ret

term_clear_sel:
    mov     byte [term_has_sel], 0
    ret

term_clear_grid:
    lea     rdi, [grid]
    mov     ecx, MAX_COLS * MAX_ROWS
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.fill:
    mov     dword [rdi], eax
    mov     dword [rdi + 4], edx
    mov     dword [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .fill
    ret

term_resize:
    cmp     edi, MAX_COLS
    jbe     .w_ok
    mov     edi, MAX_COLS
.w_ok:
    test    edi, edi
    jnz     .w_nz
    mov     edi, 1
.w_nz:
    cmp     esi, MAX_ROWS
    jbe     .h_ok
    mov     esi, MAX_ROWS
.h_ok:
    test    esi, esi
    jnz     .h_nz
    mov     esi, 1
.h_nz:
    mov     [term_cols], edi
    mov     [term_rows], esi
    mov     eax, [term_cursor_col]
    cmp     eax, edi
    jb      .c_ok
    lea     eax, [rdi - 1]
    mov     [term_cursor_col], eax
.c_ok:
    mov     eax, [term_cursor_row]
    cmp     eax, esi
    jb      .r_ok
    lea     eax, [rsi - 1]
    mov     [term_cursor_row], eax
.r_ok:
    ret

term_feed:
    push    rbx
    push    r12
    push    r13
    mov     rbx, rdi
    mov     r12, rsi
.loop:
    test    r12, r12
    jz      .done
    movzx   eax, byte [rbx]
    inc     rbx
    dec     r12

    mov     ecx, [utf8_state]
    test    ecx, ecx
    jnz     .utf8_cont

    test    al, 0x80
    jz      .ascii

    cmp     al, 0xE0
    jae     .utf8_3
    and     eax, 0x1F
    mov     [utf8_codepoint], eax
    mov     dword [utf8_state], 1
    jmp     .loop

.utf8_3:
    cmp     al, 0xF0
    jae     .utf8_4
    and     eax, 0x0F
    mov     [utf8_codepoint], eax
    mov     dword [utf8_state], 2
    jmp     .loop

.utf8_4:
    and     eax, 0x07
    mov     [utf8_codepoint], eax
    mov     dword [utf8_state], 3
    jmp     .loop

.utf8_cont:
    mov     edx, [utf8_codepoint]
    shl     edx, 6
    and     eax, 0x3F
    or      edx, eax
    mov     [utf8_codepoint], edx
    dec     dword [utf8_state]
    jnz     .loop
    mov     eax, edx

.ascii:
    mov     edi, eax
    call    term_process_char
    jmp     .loop

.done:
    pop     r13
    pop     r12
    pop     rbx
    ret

term_process_char:
    mov     edx, [esc_state]
    test    edx, edx
    jz      .state_ground
    cmp     edx, 1
    je      .state_esc
    cmp     edx, 2
    je      .state_csi
    cmp     edx, 3
    je      .state_osc
    ret

.state_ground:
    cmp     edi, 27
    je      .to_esc
    cmp     edi, 10
    je      .linefeed
    cmp     edi, 13
    je      .cr
    cmp     edi, 8
    je      .backspace
    cmp     edi, 9
    je      .tab
    cmp     edi, 7
    je      .ret
    cmp     edi, 32
    jb      .ret
    jmp     .put_char

.to_esc:
    mov     dword [esc_state], 1
    ret

.state_esc:
    cmp     edi, '['
    je      .to_csi
    cmp     edi, ']'
    je      .to_osc
    cmp     edi, 'c'
    je      .reset
    cmp     edi, '7'
    je      .save_cursor
    cmp     edi, '8'
    je      .restore_cursor
    cmp     edi, 'M'
    je      .reverse_index
    mov     dword [esc_state], 0
    ret

.save_cursor:
    mov     eax, [term_cursor_col]
    mov     [saved_cursor_col], eax
    mov     eax, [term_cursor_row]
    mov     [saved_cursor_row], eax
    mov     dword [esc_state], 0
    ret

.restore_cursor:
    mov     eax, [saved_cursor_col]
    mov     [term_cursor_col], eax
    mov     eax, [saved_cursor_row]
    mov     [term_cursor_row], eax
    mov     dword [esc_state], 0
    ret

.reverse_index:
    mov     eax, [term_cursor_row]
    test    eax, eax
    jz      .ri_scroll
    dec     eax
    mov     [term_cursor_row], eax
    mov     dword [esc_state], 0
    ret
.ri_scroll:
    call    term_scroll_down
    mov     dword [esc_state], 0
    ret

.to_csi:
    mov     dword [esc_state], 2
    mov     dword [csi_argc], 0
    mov     byte [csi_private], 0
    lea     rax, [csi_args]
    mov     dword [rax], 0
    ret

.to_osc:
    mov     dword [esc_state], 3
    ret

.state_osc:
    cmp     edi, 7
    je      .osc_end
    cmp     edi, 27
    je      .osc_end
    ret
.osc_end:
    mov     dword [esc_state], 0
    ret

.state_csi:
    cmp     edi, '?'
    jne     .csi_not_priv
    mov     byte [csi_private], 1
    ret

.csi_not_priv:
    cmp     edi, '0'
    jb      .csi_not_digit
    cmp     edi, '9'
    ja      .csi_not_digit
    mov     ecx, [csi_argc]
    cmp     ecx, 16
    jae     .ret
    lea     rdx, [csi_args]
    mov     eax, [rdx + rcx*4]
    imul    eax, 10
    lea     eax, [rax + rdi - '0']
    mov     [rdx + rcx*4], eax
    ret

.csi_not_digit:
    cmp     edi, ';'
    je      .csi_sep
    cmp     edi, '$'
    je      .ret
    push    rdi
    mov     eax, [csi_argc]
    inc     eax
    mov     [csi_argc], eax
    pop     rdi
    call    term_handle_csi
    mov     dword [esc_state], 0
    ret

.csi_sep:
    mov     eax, [csi_argc]
    inc     eax
    cmp     eax, 16
    jae     .ret
    mov     [csi_argc], eax
    lea     rdx, [csi_args]
    mov     dword [rdx + rax*4], 0
    ret

.reset:
    call    term_init
    ret

.linefeed:
    mov     eax, [term_cursor_row]
    inc     eax
    cmp     eax, [term_rows]
    jb      .lf_set
    call    term_scroll_up
    mov     eax, [term_rows]
    dec     eax
.lf_set:
    mov     [term_cursor_row], eax
    ret

.cr:
    mov     dword [term_cursor_col], 0
    ret

.backspace:
    mov     eax, [term_cursor_col]
    test    eax, eax
    jz      .ret
    dec     eax
    mov     [term_cursor_col], eax
    ret

.tab:
    mov     eax, [term_cursor_col]
    add     eax, 8
    and     eax, ~7
    cmp     eax, [term_cols]
    jb      .tab_set
    mov     eax, [term_cols]
    dec     eax
.tab_set:
    mov     [term_cursor_col], eax
    ret

.put_char:
    mov     eax, [term_cursor_col]
    cmp     eax, [term_cols]
    jb      .pc_col_ok
    mov     dword [term_cursor_col], 0
    call    .linefeed
.pc_col_ok:
    mov     eax, [term_cursor_row]
    imul    eax, MAX_COLS
    add     eax, [term_cursor_col]
    shl     eax, 4
    lea     rdx, [grid]
    add     rdx, rax

    mov     [rdx], edi
    mov     eax, [cur_fg]
    mov     [rdx + 4], eax
    mov     eax, [cur_bg]
    mov     [rdx + 8], eax
    inc     dword [term_cursor_col]
.ret:
    ret

term_scroll_up:
    push    rbx
    push    rsi
    push    rdi

    mov     eax, [scrollback_head]
    imul    eax, MAX_COLS * CELL_SIZE
    lea     rdi, [scrollback + rax]
    lea     rsi, [grid]
    mov     ecx, [term_cols]
    shl     ecx, 2
    rep     movsd

    mov     eax, [scrollback_head]
    inc     eax
    cmp     eax, SCROLLBACK_MAX
    jb      .sb_h_ok
    xor     eax, eax
.sb_h_ok:
    mov     [scrollback_head], eax

    mov     eax, [scrollback_count]
    cmp     eax, SCROLLBACK_MAX
    jae     .sb_c_ok
    inc     eax
    mov     [scrollback_count], eax
.sb_c_ok:

    lea     rdi, [grid]
    lea     rsi, [grid + MAX_COLS * CELL_SIZE]
    mov     ecx, [term_rows]
    dec     ecx
    imul    ecx, MAX_COLS * (CELL_SIZE / 4)
    rep     movsd

    mov     eax, [term_rows]
    dec     eax
    imul    eax, MAX_COLS
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     ecx, [term_cols]
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.clear_last:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .clear_last

    pop     rdi
    pop     rsi
    pop     rbx
    ret

term_scroll_down:
    push    rsi
    push    rdi
    mov     eax, [term_rows]
    dec     eax
    imul    eax, MAX_COLS
    shl     eax, 4
    lea     rdi, [grid + rax]
    lea     rsi, [rdi - MAX_COLS * CELL_SIZE]
    mov     ecx, [term_rows]
    dec     ecx
    imul    ecx, MAX_COLS * (CELL_SIZE / 4)
    std
    rep     movsd
    cld

    lea     rdi, [grid]
    mov     ecx, [term_cols]
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.clear_first:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .clear_first
    pop     rdi
    pop     rsi
    ret

term_scroll_view_up:
    mov     eax, [scroll_offset]
    add     eax, edi
    cmp     eax, [scrollback_count]
    jbe     .up_ok
    mov     eax, [scrollback_count]
.up_ok:
    mov     [scroll_offset], eax
    ret

term_scroll_view_down:
    mov     eax, [scroll_offset]
    sub     eax, edi
    jns     .down_ok
    xor     eax, eax
.down_ok:
    mov     [scroll_offset], eax
    ret

term_scroll_view_to_bottom:
    mov     dword [scroll_offset], 0
    ret

get_row_ptr:
    mov     eax, [term_rows]
    dec     eax
    sub     eax, edi
    add     eax, [scroll_offset]
    cmp     eax, [term_rows]
    jae     .in_scrollback

    mov     ecx, [term_rows]
    dec     ecx
    sub     ecx, eax
    imul    rcx, MAX_COLS * CELL_SIZE
    lea     rax, [grid + rcx]
    ret

.in_scrollback:
    sub     eax, [term_rows]
    cmp     eax, [scrollback_count]
    jae     .empty_row

    mov     ecx, [scrollback_head]
    dec     ecx
    sub     ecx, eax
.mod_loop:
    test    ecx, ecx
    jns     .mod_done
    add     ecx, SCROLLBACK_MAX
    jmp     .mod_loop
.mod_done:
    imul    rcx, MAX_COLS * CELL_SIZE
    lea     rax, [scrollback + rcx]
    ret

.empty_row:
    lea     rax, [empty_line]
    ret

term_handle_csi:
    cmp     byte [csi_private], 1
    je      .csi_priv

    cmp     edi, 'm'
    je      .sgr
    cmp     edi, 'H'
    je      .cup
    cmp     edi, 'f'
    je      .cup
    cmp     edi, 'J'
    je      .ed
    cmp     edi, 'K'
    je      .el
    cmp     edi, 'A'
    je      .cuu
    cmp     edi, 'B'
    je      .cud
    cmp     edi, 'C'
    je      .cuf
    cmp     edi, 'D'
    je      .cub
    cmp     edi, 'G'
    je      .cha
    cmp     edi, 'd'
    je      .vpa
    cmp     edi, 'n'
    je      .dsr
    cmp     edi, 's'
    je      .save_cursor_csi
    cmp     edi, 'u'
    je      .restore_cursor_csi
    cmp     edi, 'P'
    je      .dch
    cmp     edi, '@'
    je      .ich
    ret

.csi_priv:
    cmp     edi, 'h'
    je      .priv_set
    cmp     edi, 'l'
    je      .priv_reset
    ret

.priv_set:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    cmp     eax, 25
    jne     .priv_ret
    mov     byte [cursor_visible], 1
.priv_ret:
    ret

.priv_reset:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    cmp     eax, 25
    jne     .priv_ret
    mov     byte [cursor_visible], 0
    ret

.save_cursor_csi:
    mov     eax, [term_cursor_col]
    mov     [saved_cursor_col], eax
    mov     eax, [term_cursor_row]
    mov     [saved_cursor_row], eax
    ret

.restore_cursor_csi:
    mov     eax, [saved_cursor_col]
    mov     [term_cursor_col], eax
    mov     eax, [saved_cursor_row]
    mov     [term_cursor_row], eax
    ret

.cha:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    test    eax, eax
    jnz     .cha_v
    mov     eax, 1
.cha_v:
    dec     eax
    cmp     eax, [term_cols]
    jb      .cha_ok
    mov     eax, [term_cols]
    dec     eax
.cha_ok:
    mov     [term_cursor_col], eax
    ret

.vpa:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    test    eax, eax
    jnz     .vpa_v
    mov     eax, 1
.vpa_v:
    dec     eax
    cmp     eax, [term_rows]
    jb      .vpa_ok
    mov     eax, [term_rows]
    dec     eax
.vpa_ok:
    mov     [term_cursor_row], eax
    ret

.dch:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    test    eax, eax
    jnz     .dch_v
    mov     eax, 1
.dch_v:
    mov     r8d, eax
    mov     eax, [term_cursor_row]
    imul    eax, MAX_COLS
    add     eax, [term_cursor_col]
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     ecx, [term_cols]
    sub     ecx, [term_cursor_col]
    sub     ecx, r8d
    jle     .dch_clear
    mov     rax, r8
    shl     rax, 4
    lea     rsi, [rdi + rax]
    rep     movsd
.dch_clear:
    mov     eax, [term_cursor_row]
    imul    eax, MAX_COLS
    add     eax, [term_cols]
    sub     eax, r8d
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     ecx, r8d
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r9d, [cur_bg]
.dch_loop:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r9d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .dch_loop
    ret

.ich:
    ret

.dsr:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    cmp     eax, 6
    jne     .dsr_ret
    call    send_cpr
.dsr_ret:
    ret

.sgr:
    xor     ecx, ecx
.sgr_loop:
    cmp     ecx, [csi_argc]
    jae     .sgr_done
    lea     rdx, [csi_args]
    mov     eax, [rdx + rcx*4]
    test    eax, eax
    jnz     .not_0
    mov     dword [cur_fg], COLOR_FG
    mov     dword [cur_bg], COLOR_BG
    jmp     .sgr_next
.not_0:
    cmp     eax, 38
    je      .sgr_fg_extended
    cmp     eax, 48
    je      .sgr_bg_extended
    cmp     eax, 30
    jb      .not_fg
    cmp     eax, 37
    ja      .not_fg
    sub     eax, 30
    lea     rdx, [ansi_colors]
    mov     eax, [rdx + rax*4]
    mov     [cur_fg], eax
    jmp     .sgr_next
.not_fg:
    cmp     eax, 90
    jb      .not_bfg
    cmp     eax, 97
    ja      .not_bfg
    sub     eax, 82
    lea     rdx, [ansi_colors]
    mov     eax, [rdx + rax*4]
    mov     [cur_fg], eax
    jmp     .sgr_next
.not_bfg:
    cmp     eax, 40
    jb      .not_bg
    cmp     eax, 47
    ja      .not_bg
    sub     eax, 40
    lea     rdx, [ansi_colors]
    mov     eax, [rdx + rax*4]
    mov     [cur_bg], eax
    jmp     .sgr_next
.not_bg:
    cmp     eax, 100
    jb      .sgr_next
    cmp     eax, 107
    ja      .sgr_next
    sub     eax, 92
    lea     rdx, [ansi_colors]
    mov     eax, [rdx + rax*4]
    mov     [cur_bg], eax
    jmp     .sgr_next

.sgr_fg_extended:
    inc     ecx
    cmp     ecx, [csi_argc]
    jae     .sgr_done
    lea     rdx, [csi_args]
    mov     eax, [rdx + rcx*4]
    cmp     eax, 5
    je      .fg_256
    cmp     eax, 2
    je      .fg_rgb
    jmp     .sgr_next

.fg_256:
    inc     ecx
    cmp     ecx, [csi_argc]
    jae     .sgr_done
    lea     rdx, [csi_args]
    mov     eax, [rdx + rcx*4]
    call    color_from_256
    mov     [cur_fg], eax
    jmp     .sgr_next

.fg_rgb:
    add     ecx, 3
    cmp     ecx, [csi_argc]
    jae     .sgr_done
    lea     rdx, [csi_args]
    movzx   eax, byte [rdx + rcx*4 - 8]
    shl     eax, 8
    mov     al, [rdx + rcx*4 - 4]
    shl     eax, 8
    mov     al, [rdx + rcx*4]
    mov     [cur_fg], eax
    jmp     .sgr_next

.sgr_bg_extended:
    inc     ecx
    cmp     ecx, [csi_argc]
    jae     .sgr_done
    lea     rdx, [csi_args]
    mov     eax, [rdx + rcx*4]
    cmp     eax, 5
    je      .bg_256
    cmp     eax, 2
    je      .bg_rgb
    jmp     .sgr_next

.bg_256:
    inc     ecx
    cmp     ecx, [csi_argc]
    jae     .sgr_done
    lea     rdx, [csi_args]
    mov     eax, [rdx + rcx*4]
    call    color_from_256
    mov     [cur_bg], eax
    jmp     .sgr_next

.bg_rgb:
    add     ecx, 3
    cmp     ecx, [csi_argc]
    jae     .sgr_done
    lea     rdx, [csi_args]
    movzx   eax, byte [rdx + rcx*4 - 8]
    shl     eax, 8
    mov     al, [rdx + rcx*4 - 4]
    shl     eax, 8
    mov     al, [rdx + rcx*4]
    mov     [cur_bg], eax
    jmp     .sgr_next

.sgr_next:
    inc     ecx
    jmp     .sgr_loop
.sgr_done:
    ret

.cup:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    test    eax, eax
    jnz     .cup_r
    mov     eax, 1
.cup_r:
    dec     eax
    cmp     eax, [term_rows]
    jb      .cup_r_ok
    mov     eax, [term_rows]
    dec     eax
.cup_r_ok:
    mov     [term_cursor_row], eax

    mov     eax, [rdx + 4]
    test    eax, eax
    jnz     .cup_c
    mov     eax, 1
.cup_c:
    dec     eax
    cmp     eax, [term_cols]
    jb      .cup_c_ok
    mov     eax, [term_cols]
    dec     eax
.cup_c_ok:
    mov     [term_cursor_col], eax
    ret

.ed:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    cmp     eax, 2
    je      .ed_all
    cmp     eax, 0
    je      .ed_below
    ret
.ed_all:
    call    term_clear_grid
    mov     dword [term_cursor_col], 0
    mov     dword [term_cursor_row], 0
    ret
.ed_below:
    call    .el
    mov     eax, [term_cursor_row]
    inc     eax
.ed_row_loop:
    cmp     eax, [term_rows]
    jae     .ed_done
    imul    ecx, eax, MAX_COLS
    shl     ecx, 4
    lea     rdi, [grid + rcx]
    push    rax
    mov     ecx, [term_cols]
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.ed_row_fill:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .ed_row_fill
    pop     rax
    inc     eax
    jmp     .ed_row_loop
.ed_done:
    ret

.el:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    cmp     eax, 1
    je      .el_left
    cmp     eax, 2
    je      .el_entire

    mov     eax, [term_cursor_row]
    imul    eax, MAX_COLS
    add     eax, [term_cursor_col]
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     ecx, [term_cols]
    sub     ecx, [term_cursor_col]
    jle     .el_done
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.el_loop:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .el_loop
.el_done:
    ret

.el_left:
    mov     eax, [term_cursor_row]
    imul    eax, MAX_COLS
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     ecx, [term_cursor_col]
    inc     ecx
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.el_left_loop:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .el_left_loop
    ret

.el_entire:
    mov     eax, [term_cursor_row]
    imul    eax, MAX_COLS
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     ecx, [term_cols]
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.el_entire_loop:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .el_entire_loop
    ret

.cuu:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    test    eax, eax
    jnz     .cuu_v
    mov     eax, 1
.cuu_v:
    mov     ecx, [term_cursor_row]
    sub     ecx, eax
    jns     .cuu_ok
    xor     ecx, ecx
.cuu_ok:
    mov     [term_cursor_row], ecx
    ret

.cud:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    test    eax, eax
    jnz     .cud_v
    mov     eax, 1
.cud_v:
    mov     ecx, [term_cursor_row]
    add     ecx, eax
    mov     edx, [term_rows]
    dec     edx
    cmp     ecx, edx
    jle     .cud_ok
    mov     ecx, edx
.cud_ok:
    mov     [term_cursor_row], ecx
    ret

.cuf:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    test    eax, eax
    jnz     .cuf_v
    mov     eax, 1
.cuf_v:
    mov     ecx, [term_cursor_col]
    add     ecx, eax
    mov     edx, [term_cols]
    dec     edx
    cmp     ecx, edx
    jle     .cuf_ok
    mov     ecx, edx
.cuf_ok:
    mov     [term_cursor_col], ecx
    ret

.cub:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    test    eax, eax
    jnz     .cub_v
    mov     eax, 1
.cub_v:
    mov     ecx, [term_cursor_col]
    sub     ecx, eax
    jns     .cub_ok
    xor     ecx, ecx
.cub_ok:
    mov     [term_cursor_col], ecx
    ret

color_from_256:
    cmp     eax, 16
    jae     .not_16
    lea     rdx, [ansi_colors]
    mov     eax, [rdx + rax*4]
    ret
.not_16:
    cmp     eax, 232
    jae     .gray
    sub     eax, 16
    xor     edx, edx
    mov     r8d, 36
    div     r8d
    mov     r9d, eax
    mov     eax, edx
    xor     edx, edx
    mov     r8d, 6
    div     r8d
    mov     r10d, eax
    mov     r11d, edx

    call    cube_comp
    shl     eax, 8
    push    rax
    mov     eax, r10d
    call    cube_comp
    pop     rdx
    or      eax, edx
    shl     eax, 8
    push    rax
    mov     eax, r11d
    call    cube_comp
    pop     rdx
    or      eax, edx
    ret

.gray:
    sub     eax, 232
    imul    eax, 10
    add     eax, 8
    mov     edx, eax
    shl     eax, 8
    or      eax, edx
    shl     eax, 8
    or      eax, edx
    ret

cube_comp:
    test    eax, eax
    jz      .cc_ret
    imul    eax, 40
    add     eax, 55
.cc_ret:
    ret

send_cpr:
    push    rbx
    push    r12
    lea     rdi, [cpr_buf]
    mov     byte [rdi], 27
    mov     byte [rdi + 1], '['
    add     rdi, 2

    mov     eax, [term_cursor_row]
    inc     eax
    call    format_u32

    mov     byte [rdi], ';'
    inc     rdi

    mov     eax, [term_cursor_col]
    inc     eax
    call    format_u32

    mov     byte [rdi], 'R'
    inc     rdi

    lea     rsi, [cpr_buf]
    mov     rdx, rdi
    sub     rdx, rsi
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .cpr_ret
    call    write_all
.cpr_ret:
    pop     r12
    pop     rbx
    ret

format_u32:
    xor     ecx, ecx
    mov     ebx, 10
.f_div:
    xor     edx, edx
    div     ebx
    push    rdx
    inc     ecx
    test    eax, eax
    jnz     .f_div
.f_pop:
    pop     rdx
    add     dl, '0'
    mov     [rdi], dl
    inc     rdi
    dec     ecx
    jnz     .f_pop
    ret

is_cell_selected:
    cmp     byte [term_has_sel], 0
    jz      .no

    mov     r8d, [term_sel_start_row]
    mov     r9d, [term_sel_start_col]
    mov     r10d, [term_sel_end_row]
    mov     r11d, [term_sel_end_col]

    cmp     r8d, r10d
    jb      .ordered
    ja      .swap
    cmp     r9d, r11d
    jbe     .ordered
.swap:
    xchg    r8d, r10d
    xchg    r9d, r11d
.ordered:
    cmp     esi, r8d
    jb      .no
    cmp     esi, r10d
    ja      .no
    cmp     esi, r8d
    jne     .not_start_row
    cmp     edi, r9d
    jb      .no
.not_start_row:
    cmp     esi, r10d
    jne     .yes
    cmp     edi, r11d
    ja      .no
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

term_render:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx

    mov     rdi, r12
    mov     ecx, r13d
    imul    ecx, r14d
    mov     eax, COLOR_BG
    rep     stosd

    xor     r15d, r15d
.row_loop:
    cmp     r15d, [term_rows]
    jae     .draw_cursor
    mov     edi, r15d
    call    get_row_ptr
    mov     [cur_row_ptr], rax
    xor     ebp, ebp
.col_loop:
    cmp     ebp, [term_cols]
    jae     .row_next

    mov     rax, [cur_row_ptr]
    mov     ecx, ebp
    shl     ecx, 4
    lea     rbx, [rax + rcx]

    mov     edi, [rbx]
    mov     r8d, [rbx + 4]
    mov     r9d, [rbx + 8]

    push    rdi
    push    r8
    push    r9
    mov     edi, ebp
    mov     esi, r15d
    call    is_cell_selected
    test    eax, eax
    pop     r9
    pop     r8
    pop     rdi
    jz      .not_sel
    mov     r8d, COLOR_SEL_FG
    mov     r9d, COLOR_SEL_BG
.not_sel:
    push    r8
    push    r9
    call    font_glyph_for_char
    mov     edi, eax
    call    font_glyph_data
    pop     r9
    pop     r8
    mov     rsi, rax

    imul    eax, ebp, FONT_W
    add     eax, PAD_X
    imul    ecx, r15d, FONT_H
    add     ecx, PAD_Y

    mov     rdi, r12
    mov     edx, r13d
    call    draw_glyph

    inc     ebp
    jmp     .col_loop
.row_next:
    inc     r15d
    jmp     .row_loop

.draw_cursor:
    cmp     dword [scroll_offset], 0
    jne     .render_done
    cmp     byte [cursor_visible], 0
    je      .render_done

    mov     eax, [term_cursor_col]
    cmp     eax, [term_cols]
    jae     .render_done
    mov     ecx, [term_cursor_row]
    cmp     ecx, [term_rows]
    jae     .render_done

    imul    eax, FONT_W
    add     eax, PAD_X
    imul    ecx, FONT_H
    add     ecx, PAD_Y

    imul    ecx, r13d
    add     ecx, eax
    lea     rdi, [r12 + rcx*4]

    mov     edx, FONT_H
    mov     eax, COLOR_CURSOR
.c_row:
    mov     rsi, rdi
    mov     ecx, FONT_W
    rep     stosd
    lea     rdi, [rsi + r13*4]
    dec     edx
    jnz     .c_row

.render_done:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

draw_glyph:
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r10d, edx
    imul    ecx, r10d
    add     ecx, eax
    lea     r11, [rdi + rcx*4]

    pxor    xmm7, xmm7
    movd    xmm0, r8d
    movd    xmm1, r9d
    punpcklbw xmm0, xmm7
    punpcklbw xmm1, xmm7

    xor     ebx, ebx
.line_loop:
    cmp     ebx, FONT_H
    jae     .done

    mov     rdi, r11
    mov     ecx, FONT_W

.pixel_loop:
    movzx   eax, byte [rsi]
    inc     rsi
    test    eax, eax
    jz      .bg_pixel
    cmp     eax, 255
    je      .fg_pixel

    movd    xmm2, eax
    pshuflw xmm2, xmm2, 0
    mov     r12d, 256
    sub     r12d, eax
    movd    xmm3, r12d
    pshuflw xmm3, xmm3, 0

    movdqa  xmm5, xmm0
    pmullw  xmm5, xmm2
    psrlw   xmm5, 8

    movdqa  xmm6, xmm1
    pmullw  xmm6, xmm3
    psrlw   xmm6, 8

    paddw   xmm5, xmm6
    packuswb xmm5, xmm7
    movd    eax, xmm5
    mov     [rdi], eax
    jmp     .next_pixel

.bg_pixel:
    mov     [rdi], r9d
    jmp     .next_pixel

.fg_pixel:
    mov     [rdi], r8d

.next_pixel:
    add     rdi, 4
    dec     ecx
    jnz     .pixel_loop

    lea     r11, [r11 + r10*4]
    inc     ebx
    jmp     .line_loop

.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
