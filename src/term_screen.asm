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
global term_copy_selection
global term_get_selection
global term_scroll_view_up
global term_scroll_view_down
global term_scroll_view_to_bottom
global term_find_url_at
global term_clear_hover
global term_zoom_in
global term_zoom_out
global term_zoom_reset
global font_w
global font_h
global url_hover_active
global term_scroll_up
global term_find_placeholder_bounds

extern font_glyph_data
extern font_glyph_for_char
extern write_all
extern win_pty_fd
extern cfg_pad_x
extern cfg_pad_y
extern cfg_bg
extern cfg_fg
extern cfg_cursor
extern cfg_sel_bg
extern cfg_sel_fg
extern cfg_bg_pixel
extern ansi_colors
extern parse_hex_color
extern kitty_gfx_init
extern kitty_gfx_clear
extern kitty_gfx_scroll_up
extern kitty_gfx_apc_begin
extern kitty_gfx_apc_char
extern kitty_gfx_apc_end
extern kitty_gfx_render

%define MAX_COLS       256
%define MAX_ROWS       128
%define CELL_SIZE      16
%define SCROLLBACK_MAX 1024
%define CLIP_MAX       65536
%define ALL_VIS_MAX    8192

%define COLOR_BG       0x000000
%define COLOR_FG       0xc9d1d9
%define COLOR_CURSOR   0x39ff14
%define COLOR_SEL_BG   0x264f78
%define COLOR_SEL_FG   0xffffff
%define PAD_X          8
%define PAD_Y          8

section .rodata
da1_resp:       db 27, "[?62;c"
da1_resp_len    equ $ - da1_resp
hex_digits:     db "0123456789abcdef"
xtversion_resp: db 27, "P>|kitty(0.49.2)", 27, "\"
xtversion_resp_len equ $ - xtversion_resp
kitty_kbd_resp: db 27, "[?0u"
kitty_kbd_resp_len equ $ - kitty_kbd_resp

section .data
font_w:             dd 10
font_h:             dd 20

section .bss
cand_cols:          resb 1024
cand_rows:          resb 1024
url_hover_active:   resb 1
url_hover_start_col: resd 1
url_hover_start_row: resd 1
url_hover_end_col:   resd 1
url_hover_end_row:   resd 1
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
cur_row_cols:       resd 1
scrollback_count:   resd 1
scrollback_head:    resd 1
scroll_offset:      resd 1
max_scroll_offset:  resd 1
shrink_scrolled:    resd 1

esc_state:          resd 1
csi_argc:           resd 1
csi_args:           resd 16
csi_private:        resb 1
utf8_state:         resd 1
utf8_codepoint:     resd 1
cursor_visible:     resb 1
auto_wrap:          resb 1
wrap_next:          resb 1
saved_wrap_next:    resb 1
in_alt_screen:      resb 1
alt_wrap_next:      resb 1
alt_cursor_col:     resd 1
alt_cursor_row:     resd 1
cpr_buf:            resb 32
osc_buf:            resb 512
osc_len:            resd 1
placeholder_diacritics_left: resd 1

row_wrapped:        resb MAX_ROWS
alt_row_wrapped:    resb MAX_ROWS
vis_row_ptrs:       resq MAX_ROWS
vis_row_cols:       resd MAX_ROWS
vis_cursor_row:     resd 1
vis_cursor_col:     resd 1
all_vis_ptrs:       resq ALL_VIS_MAX
all_vis_cols:       resd ALL_VIS_MAX

clip_len:           resd 1
clip_buf:           resb CLIP_MAX

grid:               resb MAX_COLS * MAX_ROWS * CELL_SIZE
alt_grid:           resb MAX_COLS * MAX_ROWS * CELL_SIZE
scrollback:         resb SCROLLBACK_MAX * MAX_COLS * CELL_SIZE
empty_line:         resb MAX_COLS * CELL_SIZE



section .text

term_init:
    mov     dword [placeholder_diacritics_left], 0
    mov     dword [term_cols], 80
    mov     dword [term_rows], 24
    mov     dword [term_cursor_col], 0
    mov     dword [term_cursor_row], 0
    mov     dword [saved_cursor_col], 0
    mov     dword [saved_cursor_row], 0
    mov     eax, [cfg_fg]
    mov     [cur_fg], eax
    mov     eax, [cfg_bg]
    mov     [cur_bg], eax
    mov     dword [esc_state], 0
    mov     dword [utf8_state], 0
    mov     byte [cursor_visible], 1
    mov     byte [auto_wrap], 1
    mov     byte [wrap_next], 0
    mov     byte [saved_wrap_next], 0
    mov     byte [in_alt_screen], 0
    mov     byte [term_has_sel], 0
    mov     dword [scrollback_count], 0
    mov     dword [scrollback_head], 0
    mov     dword [scroll_offset], 0
    mov     dword [max_scroll_offset], 0
    mov     dword [shrink_scrolled], 0
    call    init_empty_line
    call    init_scrollback
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

init_scrollback:
    lea     rdi, [scrollback]
    mov     ecx, SCROLLBACK_MAX * MAX_COLS
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.sb_fill:
    mov     dword [rdi], eax
    mov     dword [rdi + 4], edx
    mov     dword [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .sb_fill
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

term_get_selection:
    lea     rax, [clip_buf]
    mov     edx, [clip_len]
    ret

term_copy_selection:
    cmp     byte [term_has_sel], 0
    jz      .empty_ret

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    call    build_vis_rows

    mov     r8d, [term_sel_start_row]
    mov     r9d, [term_sel_start_col]
    mov     r10d, [term_sel_end_row]
    mov     r11d, [term_sel_end_col]

    cmp     r8d, r10d
    jb      .sel_ordered
    ja      .sel_swap
    cmp     r9d, r11d
    jbe     .sel_ordered
.sel_swap:
    xchg    r8d, r10d
    xchg    r9d, r11d
.sel_ordered:
    mov     r12d, r8d
    mov     r13d, r9d
    mov     r14d, r10d
    mov     r15d, r11d

    lea     rbx, [clip_buf]
    lea     rbp, [clip_buf + CLIP_MAX - 8]

.copy_row_loop:
    cmp     r12d, r14d
    ja      .copy_done

    mov     edi, r12d
    call    get_row_ptr
    mov     rsi, rax

    xor     ecx, ecx
    cmp     r12d, r14d
    je      .same_end_row
    mov     edx, [term_cols]
    dec     edx
    jmp     .got_end_col
.same_end_row:
    mov     edx, r15d
.got_end_col:
    cmp     r12d, [term_sel_start_row]
    je      .check_start
    cmp     r12d, [term_sel_end_row]
    je      .check_start
    jmp     .got_start_col
.check_start:
    mov     ecx, r13d
    mov     r13d, 0
.got_start_col:
    mov     r8, rbx

.copy_col_loop:
    cmp     ecx, edx
    ja      .row_copied
    cmp     rbx, rbp
    jae     .copy_done

    mov     eax, ecx
    shl     eax, 4
    mov     edi, [rsi + rax]
    cmp     edi, 32
    jae     .cp_valid
    mov     edi, 32
.cp_valid:
    cmp     edi, 0x80
    jb      .utf8_1
    cmp     edi, 0x800
    jb      .utf8_2
    cmp     edi, 0x10000
    jb      .utf8_3

    mov     eax, edi
    shr     eax, 18
    and     al, 0x07
    or      al, 0xF0
    mov     [rbx], al
    mov     eax, edi
    shr     eax, 12
    and     al, 0x3F
    or      al, 0x80
    mov     [rbx + 1], al
    mov     eax, edi
    shr     eax, 6
    and     al, 0x3F
    or      al, 0x80
    mov     [rbx + 2], al
    mov     eax, edi
    and     al, 0x3F
    or      al, 0x80
    mov     [rbx + 3], al
    add     rbx, 4
    mov     r8, rbx
    jmp     .next_col

.utf8_3:
    mov     eax, edi
    shr     eax, 12
    and     al, 0x0F
    or      al, 0xE0
    mov     [rbx], al
    mov     eax, edi
    shr     eax, 6
    and     al, 0x3F
    or      al, 0x80
    mov     [rbx + 1], al
    mov     eax, edi
    and     al, 0x3F
    or      al, 0x80
    mov     [rbx + 2], al
    add     rbx, 3
    mov     r8, rbx
    jmp     .next_col

.utf8_2:
    mov     eax, edi
    shr     eax, 6
    and     al, 0x1F
    or      al, 0xC0
    mov     [rbx], al
    mov     eax, edi
    and     al, 0x3F
    or      al, 0x80
    mov     [rbx + 1], al
    add     rbx, 2
    mov     r8, rbx
    jmp     .next_col

.utf8_1:
    mov     [rbx], dil
    inc     rbx
    cmp     dil, 32
    je      .next_col
    mov     r8, rbx

.next_col:
    inc     ecx
    jmp     .copy_col_loop

.row_copied:
    cmp     r12d, r14d
    je      .no_trim
    mov     rbx, r8
    cmp     rbx, rbp
    jae     .copy_done
    mov     byte [rbx], 10
    inc     rbx
.no_trim:
    inc     r12d
    jmp     .copy_row_loop

.copy_done:
    lea     rax, [clip_buf]
    mov     rdx, rbx
    sub     rdx, rax
    mov     [clip_len], edx

    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.empty_ret:
    xor     eax, eax
    xor     edx, edx
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

    lea     rdi, [row_wrapped]
    mov     ecx, MAX_ROWS
    xor     eax, eax
    rep     stosb
    mov     dword [shrink_scrolled], 0
    call    kitty_gfx_clear
    ret

term_resize:
    push    rbx
    push    r12
    push    r13

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
    mov     r12d, edi
    mov     r13d, esi

    cmp     byte [in_alt_screen], 0
    jne     .tui_resize
    cmp     byte [cursor_visible], 0
    je      .tui_resize

    cmp     r13d, [term_rows]
    jbe     .check_v_shrink
    mov     ebx, r13d
    sub     ebx, [term_rows]
.expand_scroll_loop:
    test    ebx, ebx
    jz      .rows_fit
    cmp     dword [shrink_scrolled], 0
    je      .rows_fit
    cmp     dword [scrollback_count], 0
    je      .rows_fit
    mov     eax, [term_cursor_row]
    inc     eax
    cmp     eax, r13d
    jae     .rows_fit
    call    term_pop_scrollback
    inc     dword [term_cursor_row]
    inc     dword [saved_cursor_row]
    dec     dword [shrink_scrolled]
    dec     ebx
    jmp     .expand_scroll_loop

.check_v_shrink:
    mov     eax, [term_cursor_row]
    cmp     eax, r13d
    jb      .rows_fit

    mov     ebx, eax
    sub     ebx, r13d
    inc     ebx
.shrink_scroll_loop:
    test    ebx, ebx
    jz      .rows_fit
    call    term_scroll_up
    dec     dword [term_cursor_row]
    cmp     dword [saved_cursor_row], 0
    je      .no_dec_saved
    dec     dword [saved_cursor_row]
.no_dec_saved:
    inc     dword [shrink_scrolled]
    dec     ebx
    jmp     .shrink_scroll_loop

    jmp     .rows_fit

.tui_resize:
    xor     ebx, ebx
.tui_r_loop:
    cmp     ebx, MAX_ROWS
    jae     .rows_fit
    cmp     ebx, r13d
    jae     .tui_clear_full_row
    mov     ecx, r12d
    cmp     ecx, MAX_COLS
    jae     .tui_r_next
    imul    eax, ebx, MAX_COLS
    add     eax, ecx
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     edx, MAX_COLS
    sub     edx, ecx
.tui_c_loop:
    mov     dword [rdi], ' '
    mov     eax, [cfg_fg]
    mov     [rdi + 4], eax
    mov     eax, [cfg_bg]
    mov     [rdi + 8], eax
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     edx
    jnz     .tui_c_loop
    jmp     .tui_r_next
.tui_clear_full_row:
    imul    eax, ebx, MAX_COLS * CELL_SIZE
    lea     rdi, [grid + rax]
    mov     edx, MAX_COLS
.tui_f_loop:
    mov     dword [rdi], ' '
    mov     eax, [cfg_fg]
    mov     [rdi + 4], eax
    mov     eax, [cfg_bg]
    mov     [rdi + 8], eax
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     edx
    jnz     .tui_f_loop
.tui_r_next:
    mov     byte [row_wrapped + rbx], 0
    inc     ebx
    jmp     .tui_r_loop

.rows_fit:
    mov     [term_cols], r12d
    mov     [term_rows], r13d
    mov     byte [wrap_next], 0

    mov     eax, [term_cursor_col]
    cmp     eax, r12d
    jb      .c_ok
    lea     eax, [r12d - 1]
    mov     [term_cursor_col], eax
.c_ok:
    mov     eax, [term_cursor_row]
    cmp     eax, r13d
    jb      .r_ok
    lea     eax, [r13d - 1]
    mov     [term_cursor_row], eax
.r_ok:
    pop     r13
    pop     r12
    pop     rbx
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
    cmp     edx, 4
    je      .state_osc_esc
    cmp     edx, 5
    je      .state_dcs
    cmp     edx, 6
    je      .state_dcs_esc
    cmp     edx, 7
    je      .state_charset
    ret

.state_charset:
    mov     dword [esc_state], 0
    ret

.state_ground:
    cmp     edi, 27
    je      .to_esc
    cmp     edi, 32
    jae     .printable_char

    mov     dword [placeholder_diacritics_left], 0
    cmp     edi, 10
    je      .linefeed
    cmp     edi, 11
    je      .linefeed
    cmp     edi, 12
    je      .linefeed
    cmp     edi, 13
    je      .cr
    cmp     edi, 8
    je      .backspace
    cmp     edi, 9
    je      .tab
    ret

.printable_char:
    cmp     dword [placeholder_diacritics_left], 0
    jz      .not_ph_diacritic
    cmp     edi, 0x0300
    jb      .reset_ph_diacritic
    dec     dword [placeholder_diacritics_left]
    ret
.reset_ph_diacritic:
    mov     dword [placeholder_diacritics_left], 0
.not_ph_diacritic:

    cmp     edi, 0x0300
    jb      .put_char
    cmp     edi, 0x036F
    jbe     .ret
    jmp     .put_char

.to_esc:
    mov     dword [placeholder_diacritics_left], 0
    mov     dword [esc_state], 1
    ret

.state_esc:
    cmp     edi, '['
    je      .to_csi
    cmp     edi, ']'
    je      .to_osc
    cmp     edi, '_'
    je      .to_apc
    cmp     edi, 'P'
    je      .to_dcs
    cmp     edi, '^'
    je      .to_dcs
    cmp     edi, 'c'
    je      .reset
    cmp     edi, '7'
    je      .save_cursor
    cmp     edi, '8'
    je      .restore_cursor
    cmp     edi, 'M'
    je      .reverse_index
    cmp     edi, 'D'
    je      .index_down
    cmp     edi, 'E'
    je      .next_line
    cmp     edi, '('
    je      .to_charset
    cmp     edi, ')'
    je      .to_charset
    cmp     edi, '*'
    je      .to_charset
    cmp     edi, '+'
    je      .to_charset
    cmp     edi, '#'
    je      .to_charset
    mov     dword [esc_state], 0
    ret

.to_apc:
    mov     dword [esc_state], 5
    call    kitty_gfx_apc_begin
    ret

.to_charset:
    mov     dword [esc_state], 7
    ret

.index_down:
    mov     dword [esc_state], 0
    jmp     .linefeed

.next_line:
    mov     dword [esc_state], 0
    mov     dword [term_cursor_col], 0
    jmp     .linefeed

.save_cursor:
    mov     eax, [term_cursor_col]
    mov     [saved_cursor_col], eax
    mov     eax, [term_cursor_row]
    mov     [saved_cursor_row], eax
    mov     al, [wrap_next]
    mov     [saved_wrap_next], al
    mov     dword [esc_state], 0
    ret

.restore_cursor:
    mov     eax, [saved_cursor_col]
    mov     [term_cursor_col], eax
    mov     eax, [saved_cursor_row]
    mov     [term_cursor_row], eax
    mov     al, [saved_wrap_next]
    mov     [wrap_next], al
    mov     dword [esc_state], 0
    ret

.reverse_index:
    mov     byte [wrap_next], 0
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
    push    rdi
    lea     rdi, [csi_args]
    xor     eax, eax
    mov     ecx, 16
    rep     stosd
    pop     rdi
    ret

.to_osc:
    mov     dword [osc_len], 0
    mov     dword [esc_state], 3
    ret

.to_dcs:
    mov     dword [esc_state], 5
    ret

.state_osc:
    cmp     edi, 7
    je      .osc_end
    cmp     edi, 27
    je      .osc_to_esc
    mov     eax, [osc_len]
    cmp     eax, 500
    jae     .osc_ignore
    lea     rdx, [osc_buf]
    mov     [rdx + rax], dil
    inc     dword [osc_len]
.osc_ignore:
    ret
.osc_to_esc:
    mov     dword [esc_state], 4
    ret
.state_osc_esc:
    cmp     edi, '\'
    je      .osc_end
    mov     dword [esc_state], 0
    jmp     .state_esc
.osc_end:
    mov     dword [esc_state], 0
    mov     eax, [osc_len]
    lea     rdx, [osc_buf]
    mov     byte [rdx + rax], 0
    call    handle_osc_command
    ret

.state_dcs:
    cmp     edi, 7
    je      .apc_bel
    cmp     edi, 27
    je      .dcs_to_esc
    call    kitty_gfx_apc_char
    ret
.dcs_to_esc:
    mov     dword [esc_state], 6
    ret
.state_dcs_esc:
    cmp     edi, '\'
    je      .apc_st
    mov     dword [esc_state], 5
    push    rdi
    mov     edi, 27
    call    kitty_gfx_apc_char
    pop     rdi
    call    kitty_gfx_apc_char
    ret
.apc_bel:
.apc_st:
    call    kitty_gfx_apc_end
    mov     dword [esc_state], 0
    ret

.state_csi:
    cmp     edi, '?'
    jne     .csi_not_qmark
    mov     byte [csi_private], 1
    ret
.csi_not_qmark:
    cmp     edi, '<'
    jb      .csi_check_digit
    cmp     edi, '>'
    ja      .csi_check_digit
    mov     byte [csi_private], 2
    ret

.csi_check_digit:
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
    cmp     edi, ':'
    je      .csi_sep
    cmp     edi, 0x20
    jb      .csi_abort
    cmp     edi, 0x2F
    jbe     .ret
    cmp     edi, 0x40
    jb      .ret
    cmp     edi, 0x7E
    ja      .csi_abort
    cmp     byte [csi_private], 2
    jne     .csi_not_priv2
    cmp     edi, 'q'
    jne     .csi_abort
    call    send_xtversion
    jmp     .csi_abort
.csi_not_priv2:
    push    rdi
    mov     eax, [csi_argc]
    inc     eax
    mov     [csi_argc], eax
    pop     rdi
    call    term_handle_csi
.csi_abort:
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
    mov     byte [row_wrapped + rax], 0
.linefeed_soft:
    mov     byte [wrap_next], 0
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
    mov     byte [wrap_next], 0
    mov     dword [term_cursor_col], 0
    ret

.backspace:
    mov     byte [wrap_next], 0
    mov     eax, [term_cursor_col]
    test    eax, eax
    jz      .ret
    dec     eax
    mov     [term_cursor_col], eax
    ret

.tab:
    mov     byte [wrap_next], 0
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
    cmp     byte [wrap_next], 0
    je      .no_pending_wrap
    mov     byte [wrap_next], 0
    cmp     byte [auto_wrap], 0
    je      .clamp_no_wrap
    mov     eax, [term_cursor_row]
    mov     byte [row_wrapped + rax], 1
    mov     dword [term_cursor_col], 0
    push    rdi
    call    .linefeed_soft
    pop     rdi
    jmp     .no_pending_wrap

.clamp_no_wrap:
    mov     eax, [term_cols]
    dec     eax
    mov     [term_cursor_col], eax

.no_pending_wrap:
    mov     eax, [term_cursor_col]
    cmp     eax, [term_cols]
    jb      .pc_col_ok
    mov     eax, [term_cols]
    dec     eax
    mov     [term_cursor_col], eax
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

    cmp     edi, 0x10EEEE
    jne     .not_ph_cell
    mov     dword [placeholder_diacritics_left], 2
.not_ph_cell:

    mov     eax, [term_cursor_col]
    inc     eax
    cmp     eax, [term_cols]
    jae     .at_right_margin
    mov     [term_cursor_col], eax
    ret

.at_right_margin:
    cmp     byte [auto_wrap], 0
    je      .ret
    cmp     byte [in_alt_screen], 0
    jne     .ret
    cmp     byte [cursor_visible], 0
    je      .ret
    mov     byte [wrap_next], 1
.ret:
    ret

term_scroll_up:
    push    rbx
    push    rsi
    push    rdi

    cmp     byte [in_alt_screen], 0
    jne     .sb_c_ok

    mov     eax, [scrollback_head]
    imul    eax, MAX_COLS * CELL_SIZE
    lea     rdi, [scrollback + rax]
    lea     rsi, [grid]
    mov     ecx, MAX_COLS * (CELL_SIZE / 4)
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
    mov     ecx, (MAX_ROWS - 1) * MAX_COLS * (CELL_SIZE / 4)
    rep     movsd

    lea     rdi, [row_wrapped]
    lea     rsi, [row_wrapped + 1]
    mov     ecx, MAX_ROWS - 1
    rep     movsb
    mov     byte [row_wrapped + MAX_ROWS - 1], 0

    lea     rdi, [grid + (MAX_ROWS - 1) * MAX_COLS * CELL_SIZE]
    mov     ecx, MAX_COLS
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

    mov     edi, 1
    call    kitty_gfx_scroll_up
    pop     rdi
    pop     rsi
    pop     rbx
    ret

term_pop_scrollback:
    push    rsi
    push    rdi

    lea     rdi, [grid + MAX_ROWS * MAX_COLS * CELL_SIZE - 4]
    lea     rsi, [rdi - MAX_COLS * CELL_SIZE]
    mov     ecx, (MAX_ROWS - 1) * MAX_COLS * (CELL_SIZE / 4)
    std
    rep     movsd
    cld

    lea     rdi, [row_wrapped + MAX_ROWS - 1]
    lea     rsi, [row_wrapped + MAX_ROWS - 2]
    mov     ecx, MAX_ROWS - 1
    std
    rep     movsb
    cld
    mov     byte [row_wrapped], 0

    mov     eax, [scrollback_head]
    dec     eax
    jns     .pop_h_ok
    add     eax, SCROLLBACK_MAX
.pop_h_ok:
    mov     [scrollback_head], eax
    dec     dword [scrollback_count]

    imul    eax, MAX_COLS * CELL_SIZE
    lea     rsi, [scrollback + rax]
    lea     rdi, [grid]
    mov     ecx, MAX_COLS * (CELL_SIZE / 4)
    rep     movsd

    pop     rdi
    pop     rsi
    ret

term_scroll_down:
    push    rsi
    push    rdi
    lea     rdi, [grid + MAX_ROWS * MAX_COLS * CELL_SIZE - 4]
    lea     rsi, [rdi - MAX_COLS * CELL_SIZE]
    mov     ecx, (MAX_ROWS - 1) * MAX_COLS * (CELL_SIZE / 4)
    std
    rep     movsd
    cld

    lea     rdi, [row_wrapped + MAX_ROWS - 1]
    lea     rsi, [row_wrapped + MAX_ROWS - 2]
    mov     ecx, MAX_ROWS - 1
    std
    rep     movsb
    cld
    mov     byte [row_wrapped], 0

    lea     rdi, [grid]
    mov     ecx, MAX_COLS
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

term_scroll_up_from_cursor:
    push    rsi
    push    rdi
    mov     eax, [term_cursor_row]
    mov     ecx, [term_rows]
    dec     ecx
    sub     ecx, eax
    jle     .clear_bottom
    imul    eax, MAX_COLS * CELL_SIZE
    lea     rdi, [grid + rax]
    lea     rsi, [rdi + MAX_COLS * CELL_SIZE]
    imul    ecx, MAX_COLS * (CELL_SIZE / 4)
    rep     movsd
.clear_bottom:
    mov     eax, [term_rows]
    dec     eax
    imul    eax, MAX_COLS * CELL_SIZE
    lea     rdi, [grid + rax]
    mov     ecx, MAX_COLS
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.cb_loop:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .cb_loop
    pop     rdi
    pop     rsi
    ret

term_scroll_down_from_cursor:
    push    rsi
    push    rdi
    mov     eax, [term_rows]
    dec     eax
    mov     ecx, eax
    sub     ecx, [term_cursor_row]
    jle     .clear_cur
    imul    eax, MAX_COLS * CELL_SIZE
    lea     rdi, [grid + rax + MAX_COLS * CELL_SIZE - 4]
    lea     rsi, [rdi - MAX_COLS * CELL_SIZE]
    imul    ecx, MAX_COLS * (CELL_SIZE / 4)
    std
    rep     movsd
    cld
.clear_cur:
    mov     eax, [term_cursor_row]
    imul    eax, MAX_COLS * CELL_SIZE
    lea     rdi, [grid + rax]
    mov     ecx, MAX_COLS
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.cc_loop:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .cc_loop
    pop     rdi
    pop     rsi
    ret

term_scroll_view_up:
    mov     eax, [scroll_offset]
    add     eax, edi
    mov     ecx, [max_scroll_offset]
    cmp     ecx, [scrollback_count]
    cmovb   ecx, [scrollback_count]
    cmp     eax, ecx
    jbe     .up_ok
    mov     eax, ecx
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

get_logical_row_len:
    mov     ecx, MAX_COLS - 1
.scan_len:
    mov     eax, ecx
    shl     eax, 4
    mov     edx, [cfg_bg]
    cmp     dword [rsi + rax + 8], edx
    jne     .found_len
    mov     edx, [rsi + rax]
    cmp     edx, ' '
    je      .next_len
    test    edx, edx
    jnz     .found_len
.next_len:
    dec     ecx
    jns     .scan_len
    xor     eax, eax
    ret
.found_len:
    lea     eax, [ecx + 1]
    ret

emit_logical_row:
    test    edx, edx
    jz      .emit_single
    call    get_logical_row_len
    cmp     eax, r12d
    jbe     .emit_single

    mov     ecx, eax
    xor     r8d, r8d
.sub_loop:
    cmp     r13d, ALL_VIS_MAX
    jae     .emit_ret
    mov     eax, r8d
    shl     eax, 4
    lea     r9, [rsi + rax]
    mov     [all_vis_ptrs + r13*8], r9
    mov     eax, MAX_COLS
    sub     eax, r8d
    cmp     eax, r12d
    cmova   eax, r12d
    mov     [all_vis_cols + r13*4], eax
    inc     r13d
    add     r8d, r12d
    cmp     r8d, ecx
    jb      .sub_loop
    ret

.emit_single:
    cmp     r13d, ALL_VIS_MAX
    jae     .emit_ret
    mov     [all_vis_ptrs + r13*8], rsi
    mov     [all_vis_cols + r13*4], r12d
    inc     r13d
.emit_ret:
    ret

build_vis_rows:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12d, [term_cols]
    test    r12d, r12d
    jnz     .w_valid
    mov     r12d, 1
.w_valid:
    xor     r13d, r13d
    xor     ebp, ebp

    cmp     byte [in_alt_screen], 0
    jne     .alt_vis_fast
    cmp     byte [cursor_visible], 0
    je      .alt_vis_fast

    cmp     dword [scroll_offset], 0
    je      .sb_done

    xor     ebx, ebx
.sb_loop:
    cmp     ebx, [scrollback_count]
    jae     .sb_done
    mov     eax, [scrollback_head]
    sub     eax, [scrollback_count]
    add     eax, ebx
.sb_mod_neg:
    test    eax, eax
    jns     .sb_mod_pos
    add     eax, SCROLLBACK_MAX
    jmp     .sb_mod_neg
.sb_mod_pos:
    cmp     eax, SCROLLBACK_MAX
    jb      .sb_idx_ok
    sub     eax, SCROLLBACK_MAX
    jmp     .sb_mod_pos
.sb_idx_ok:
    imul    rax, MAX_COLS * CELL_SIZE
    lea     rsi, [scrollback + rax]
    mov     edx, 1
    call    emit_logical_row
    inc     ebx
    jmp     .sb_loop
.sb_done:
    mov     ebp, r13d

    mov     r14d, [term_cursor_row]
    mov     ebx, [term_rows]
    dec     ebx
.find_last_loop:
    cmp     ebx, r14d
    jle     .found_last
    imul    eax, ebx, MAX_COLS * CELL_SIZE
    lea     rsi, [grid + rax]
    call    get_logical_row_len
    test    eax, eax
    jnz     .set_last
    dec     ebx
    jmp     .find_last_loop
.set_last:
    mov     r14d, ebx
.found_last:

    xor     ebx, ebx
.grid_loop:
    cmp     ebx, r14d
    ja      .grid_done

    cmp     ebx, [term_cursor_row]
    jne     .not_cur_row
    mov     [vis_cursor_row], r13d
    mov     eax, [term_cursor_col]
    cmp     eax, r12d
    jb      .cur_col_ok
    lea     eax, [r12d - 1]
.cur_col_ok:
    mov     [vis_cursor_col], eax
.not_cur_row:
    imul    eax, ebx, MAX_COLS * CELL_SIZE
    lea     rsi, [grid + rax]
    xor     edx, edx
    lea     eax, [ebx + 1]
    cmp     eax, [term_cursor_row]
    jae     .do_emit_grid
    mov     edx, 1
.do_emit_grid:
    call    emit_logical_row
    inc     ebx
    jmp     .grid_loop
.grid_done:

    mov     eax, r13d
    sub     eax, ebp
    mov     ecx, ebp
    cmp     eax, [term_rows]
    jbe     .start_vis_ok
    mov     ecx, r13d
    sub     ecx, [term_rows]
.start_vis_ok:
    mov     edx, ecx
    cmp     dword [scroll_offset], 0
    jne     .Store_max_sc
    add     edx, [scrollback_count]
.Store_max_sc:
    mov     [max_scroll_offset], edx
    mov     edx, [scroll_offset]
    cmp     edx, ecx
    jbe     .scroll_ok
    mov     edx, ecx
    mov     [scroll_offset], edx
.scroll_ok:
    sub     ecx, edx
    sub     [vis_cursor_row], ecx

    xor     edi, edi
.fill_vis_loop:
    cmp     edi, [term_rows]
    jae     .vis_done
    lea     edx, [ecx + edi]
    cmp     edx, r13d
    jae     .vis_empty
    mov     rax, [all_vis_ptrs + rdx*8]
    mov     r8d, [all_vis_cols + rdx*4]
    jmp     .vis_store
.vis_empty:
    lea     rax, [empty_line]
    mov     r8d, r12d
.vis_store:
    mov     [vis_row_ptrs + rdi*8], rax
    mov     [vis_row_cols + rdi*4], r8d
    inc     edi
    jmp     .fill_vis_loop

    jmp     .vis_done

.alt_vis_fast:
    mov     dword [max_scroll_offset], 0
    mov     dword [scroll_offset], 0
    mov     eax, [term_cursor_row]
    mov     [vis_cursor_row], eax
    mov     eax, [term_cursor_col]
    mov     [vis_cursor_col], eax
    xor     edi, edi
.alt_fill_loop:
    cmp     edi, [term_rows]
    jae     .vis_done
    imul    eax, edi, MAX_COLS * CELL_SIZE
    lea     rdx, [grid + rax]
    mov     [vis_row_ptrs + rdi*8], rdx
    mov     [vis_row_cols + rdi*4], r12d
    inc     edi
    jmp     .alt_fill_loop

.vis_done:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

get_row_ptr:
    cmp     edi, [term_rows]
    jae     .empty_row
    mov     rax, [vis_row_ptrs + rdi*8]
    test    rax, rax
    jz      .empty_row
    ret
.empty_row:
    lea     rax, [empty_line]
    ret

term_find_placeholder_bounds:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12d, edi
    and     r12d, 0x00ffffff
    mov     r13, rsi

    mov     dword [r13], 999999
    mov     dword [r13 + 4], 999999
    mov     dword [r13 + 8], -1
    mov     dword [r13 + 12], -1

    xor     ebx, ebx
    xor     r14d, r14d

.ph_row_loop:
    cmp     ebx, [term_rows]
    jae     .ph_check_found

    mov     rdi, rbx
    call    get_row_ptr
    mov     r15, rax

    xor     ebp, ebp
.ph_col_loop:
    cmp     ebp, [term_cols]
    jae     .ph_row_next

    mov     eax, ebp
    shl     eax, 4
    lea     rax, [r15 + rax]

    cmp     dword [rax], 0x10EEEE
    jne     .ph_col_next

    mov     edx, [rax + 4]
    and     edx, 0x00ffffff
    cmp     edx, r12d
    jne     .ph_col_next

    mov     r14d, 1

    cmp     ebp, [r13]
    jge     .ph_col_min_ok
    mov     [r13], ebp
.ph_col_min_ok:
    cmp     ebx, [r13 + 4]
    jge     .ph_row_min_ok
    mov     [r13 + 4], ebx
.ph_row_min_ok:
    cmp     ebp, [r13 + 8]
    jle     .ph_col_max_ok
    mov     [r13 + 8], ebp
.ph_col_max_ok:
    cmp     ebx, [r13 + 12]
    jle     .ph_row_max_ok
    mov     [r13 + 12], ebx
.ph_row_max_ok:

.ph_col_next:
    inc     ebp
    jmp     .ph_col_loop

.ph_row_next:
    inc     ebx
    jmp     .ph_row_loop

.ph_check_found:
    mov     eax, r14d
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
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
    cmp     edi, 'E'
    je      .cnl
    cmp     edi, 'F'
    je      .cpl
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
    cmp     edi, 'X'
    je      .ech
    cmp     edi, 'L'
    je      .il
    cmp     edi, 'M'
    je      .dl
    cmp     edi, 'S'
    je      .su
    cmp     edi, 'T'
    je      .sd
    cmp     edi, 'c'
    je      .da1
    cmp     edi, 't'
    je      .window_ops
    ret

.csi_priv:
    cmp     edi, 'h'
    je      .priv_set
    cmp     edi, 'l'
    je      .priv_reset
    cmp     edi, 'c'
    je      .da1
    cmp     edi, 'u'
    je      .kitty_kbd
    ret

.kitty_kbd:
    lea     rsi, [kitty_kbd_resp]
    mov     edx, kitty_kbd_resp_len
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .kbd_ret
    call    write_all
.kbd_ret:
    ret

.da1:
    lea     rsi, [da1_resp]
    mov     edx, da1_resp_len
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .da1_ret
    call    write_all
.da1_ret:
    ret

.window_ops:
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    cmp     eax, 14
    je      .win_op_14
    cmp     eax, 16
    je      .win_op_16
    cmp     eax, 18
    je      .win_op_18
    ret
.win_op_14:
    mov     edi, 4
    mov     eax, [term_rows]
    imul    eax, [font_h]
    mov     esi, eax
    mov     eax, [term_cols]
    imul    eax, [font_w]
    mov     edx, eax
    call    send_size_report
    ret
.win_op_16:
    mov     edi, 6
    mov     esi, [font_h]
    mov     edx, [font_w]
    call    send_size_report
    ret
.win_op_18:
    mov     edi, 8
    mov     esi, [term_rows]
    mov     edx, [term_cols]
    call    send_size_report
    ret

.priv_set:
    xor     ecx, ecx
.ps_loop:
    cmp     ecx, [csi_argc]
    jae     .priv_ret
    lea     rdx, [csi_args]
    mov     eax, [rdx + rcx*4]
    cmp     eax, 7
    je      .ps_wrap
    cmp     eax, 25
    je      .ps_cursor
    cmp     eax, 1049
    je      .ps_alt
    cmp     eax, 47
    je      .ps_alt
    cmp     eax, 1047
    je      .ps_alt
    jmp     .ps_next
.ps_wrap:
    mov     byte [auto_wrap], 1
    jmp     .ps_next
.ps_cursor:
    mov     byte [cursor_visible], 1
    jmp     .ps_next
.ps_alt:
    push    rcx
    call    .enter_alt_screen
    pop     rcx
.ps_next:
    inc     ecx
    jmp     .ps_loop
.priv_ret:
    ret

.priv_reset:
    xor     ecx, ecx
.pr_loop:
    cmp     ecx, [csi_argc]
    jae     .priv_ret
    lea     rdx, [csi_args]
    mov     eax, [rdx + rcx*4]
    cmp     eax, 7
    je      .pr_wrap
    cmp     eax, 25
    je      .pr_cursor
    cmp     eax, 1049
    je      .pr_alt
    cmp     eax, 47
    je      .pr_alt
    cmp     eax, 1047
    je      .pr_alt
    jmp     .pr_next
.pr_wrap:
    mov     byte [auto_wrap], 0
    mov     byte [wrap_next], 0
    jmp     .pr_next
.pr_cursor:
    mov     byte [cursor_visible], 0
    jmp     .pr_next
.pr_alt:
    push    rcx
    call    .leave_alt_screen
    pop     rcx
.pr_next:
    inc     ecx
    jmp     .pr_loop

.enter_alt_screen:
    cmp     byte [in_alt_screen], 0
    jne     .alt_ret
    mov     byte [in_alt_screen], 1
    mov     eax, [term_cursor_col]
    mov     [alt_cursor_col], eax
    mov     eax, [term_cursor_row]
    mov     [alt_cursor_row], eax
    mov     al, [wrap_next]
    mov     [alt_wrap_next], al
    mov     dword [scroll_offset], 0
    push    rsi
    push    rdi
    lea     rdi, [alt_grid]
    lea     rsi, [grid]
    mov     ecx, MAX_COLS * MAX_ROWS * (CELL_SIZE / 4)
    rep     movsd
    lea     rdi, [alt_row_wrapped]
    lea     rsi, [row_wrapped]
    mov     ecx, MAX_ROWS
    rep     movsb
    call    term_clear_grid
    mov     dword [term_cursor_col], 0
    mov     dword [term_cursor_row], 0
    mov     byte [wrap_next], 0
    pop     rdi
    pop     rsi
.alt_ret:
    ret

.leave_alt_screen:
    cmp     byte [in_alt_screen], 0
    je      .alt_ret
    mov     byte [in_alt_screen], 0
    mov     dword [scroll_offset], 0
    push    rsi
    push    rdi
    lea     rdi, [grid]
    lea     rsi, [alt_grid]
    mov     ecx, MAX_COLS * MAX_ROWS * (CELL_SIZE / 4)
    rep     movsd
    lea     rdi, [row_wrapped]
    lea     rsi, [alt_row_wrapped]
    mov     ecx, MAX_ROWS
    rep     movsb
    mov     eax, [alt_cursor_col]
    mov     [term_cursor_col], eax
    mov     eax, [alt_cursor_row]
    mov     [term_cursor_row], eax
    mov     al, [alt_wrap_next]
    mov     [wrap_next], al
    pop     rdi
    pop     rsi
    ret

.save_cursor_csi:
    mov     eax, [term_cursor_col]
    mov     [saved_cursor_col], eax
    mov     eax, [term_cursor_row]
    mov     [saved_cursor_row], eax
    mov     al, [wrap_next]
    mov     [saved_wrap_next], al
    ret

.restore_cursor_csi:
    mov     eax, [saved_cursor_col]
    mov     [term_cursor_col], eax
    mov     eax, [saved_cursor_row]
    mov     [term_cursor_row], eax
    mov     al, [saved_wrap_next]
    mov     [wrap_next], al
    ret

.cnl:
    mov     byte [wrap_next], 0
    mov     dword [term_cursor_col], 0
    jmp     .cud

.cpl:
    mov     byte [wrap_next], 0
    mov     dword [term_cursor_col], 0
    jmp     .cuu

.cha:
    mov     byte [wrap_next], 0
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
    mov     byte [wrap_next], 0
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

.ech:
    mov     byte [wrap_next], 0
    lea     rdx, [csi_args]
    mov     ecx, [rdx]
    test    ecx, ecx
    jnz     .ech_v
    mov     ecx, 1
.ech_v:
    mov     eax, [term_cols]
    sub     eax, [term_cursor_col]
    jle     .ech_done
    cmp     ecx, eax
    cmova   ecx, eax
    mov     eax, [term_cursor_row]
    imul    eax, MAX_COLS
    add     eax, [term_cursor_col]
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.ech_loop:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .ech_loop
.ech_done:
    ret

.dch:
    mov     byte [wrap_next], 0
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
    shl     ecx, 2
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

.il:
    mov     byte [wrap_next], 0
    lea     rdx, [csi_args]
    mov     ecx, [rdx]
    test    ecx, ecx
    jnz     .il_loop
    mov     ecx, 1
.il_loop:
    push    rcx
    call    term_scroll_down_from_cursor
    pop     rcx
    dec     ecx
    jnz     .il_loop
    ret

.dl:
    mov     byte [wrap_next], 0
    lea     rdx, [csi_args]
    mov     ecx, [rdx]
    test    ecx, ecx
    jnz     .dl_loop
    mov     ecx, 1
.dl_loop:
    push    rcx
    call    term_scroll_up_from_cursor
    pop     rcx
    dec     ecx
    jnz     .dl_loop
    ret

.su:
    lea     rdx, [csi_args]
    mov     ecx, [rdx]
    test    ecx, ecx
    jnz     .su_loop
    mov     ecx, 1
.su_loop:
    push    rcx
    call    term_scroll_up
    pop     rcx
    dec     ecx
    jnz     .su_loop
    ret

.sd:
    lea     rdx, [csi_args]
    mov     ecx, [rdx]
    test    ecx, ecx
    jnz     .sd_loop
    mov     ecx, 1
.sd_loop:
    push    rcx
    call    term_scroll_down
    pop     rcx
    dec     ecx
    jnz     .sd_loop
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
    mov     eax, [cfg_fg]
    mov     [cur_fg], eax
    mov     eax, [cfg_bg]
    mov     [cur_bg], eax
    jmp     .sgr_next
.not_0:
    cmp     eax, 8
    jne     .not_conceal
    mov     eax, [cur_bg]
    mov     [cur_fg], eax
    jmp     .sgr_next
.not_conceal:
    cmp     eax, 28
    jne     .not_reveal
    mov     eax, [cfg_fg]
    mov     [cur_fg], eax
    jmp     .sgr_next
.not_reveal:
    cmp     eax, 39
    je      .sgr_fg_default
    cmp     eax, 49
    je      .sgr_bg_default
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

.sgr_fg_default:
    mov     eax, [cfg_fg]
    mov     [cur_fg], eax
    jmp     .sgr_next

.sgr_bg_default:
    mov     eax, [cfg_bg]
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
    mov     byte [wrap_next], 0
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
    mov     byte [wrap_next], 0
    lea     rdx, [csi_args]
    mov     eax, [rdx]
    cmp     eax, 2
    je      .ed_all
    cmp     eax, 3
    je      .ed_all
    cmp     eax, 1
    je      .ed_above
    cmp     eax, 0
    je      .ed_below
    ret
.ed_all:
    call    term_clear_grid
    ret
.ed_above:
    mov     eax, [term_cursor_row]
    imul    eax, MAX_COLS
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     ecx, [term_cursor_col]
    inc     ecx
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.ed_ab_cur:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .ed_ab_cur
    xor     eax, eax
.ed_ab_row:
    cmp     eax, [term_cursor_row]
    jae     .ed_done
    mov     byte [row_wrapped + rax], 0
    imul    ecx, eax, MAX_COLS
    shl     ecx, 4
    lea     rdi, [grid + rcx]
    push    rax
    mov     ecx, MAX_COLS
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.ed_ab_fill:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .ed_ab_fill
    pop     rax
    inc     eax
    jmp     .ed_ab_row

.ed_below:
    cmp     dword [term_cursor_col], 0
    jne     .ed_no_unwrap
.ed_unwrap_loop:
    mov     eax, [term_cursor_row]
    test    eax, eax
    jz      .ed_no_unwrap
    cmp     byte [row_wrapped + rax - 1], 0
    je      .ed_no_unwrap
    dec     eax
    mov     [term_cursor_row], eax
    jmp     .ed_unwrap_loop
.ed_no_unwrap:
    mov     eax, [term_cursor_row]
    mov     byte [row_wrapped + rax], 0
    imul    eax, MAX_COLS
    add     eax, [term_cursor_col]
    shl     eax, 4
    lea     rdi, [grid + rax]
    mov     ecx, MAX_COLS
    sub     ecx, [term_cursor_col]
    jle     .ed_below_rows
    mov     eax, ' '
    mov     edx, [cur_fg]
    mov     r8d, [cur_bg]
.ed_bel_cur:
    mov     [rdi], eax
    mov     [rdi + 4], edx
    mov     [rdi + 8], r8d
    mov     dword [rdi + 12], 0
    add     rdi, CELL_SIZE
    dec     ecx
    jnz     .ed_bel_cur
.ed_below_rows:
    mov     eax, [term_cursor_row]
    inc     eax
.ed_row_loop:
    cmp     eax, MAX_ROWS
    jae     .ed_done
    mov     byte [row_wrapped + rax], 0
    imul    ecx, eax, MAX_COLS
    shl     ecx, 4
    lea     rdi, [grid + rcx]
    push    rax
    mov     ecx, MAX_COLS
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
    mov     eax, [term_cursor_row]
    mov     byte [row_wrapped + rax], 0
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
    mov     ecx, MAX_COLS
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
    mov     ecx, MAX_COLS
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
    mov     byte [wrap_next], 0
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
    mov     byte [wrap_next], 0
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
    mov     byte [wrap_next], 0
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
    mov     byte [wrap_next], 0
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

send_xtversion:
    lea     rsi, [xtversion_resp]
    mov     edx, xtversion_resp_len
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .xt_ret
    call    write_all
.xt_ret:
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

send_size_report:
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     r12d, edi
    mov     r13d, esi
    mov     r14d, edx
    lea     rdi, [cpr_buf]
    mov     byte [rdi], 27
    mov     byte [rdi + 1], '['
    add     rdi, 2
    mov     eax, r12d
    call    format_u32
    mov     byte [rdi], ';'
    inc     rdi
    mov     eax, r13d
    call    format_u32
    mov     byte [rdi], ';'
    inc     rdi
    mov     eax, r14d
    call    format_u32
    mov     byte [rdi], 't'
    inc     rdi
    lea     rsi, [cpr_buf]
    mov     rdx, rdi
    sub     rdx, rsi
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .ssr_ret
    call    write_all
.ssr_ret:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

handle_osc_command:
    lea     rsi, [osc_buf]

    cmp     byte [rsi], '4'
    jne     .check_10
    cmp     byte [rsi + 1], ';'
    je      .handle_osc_4

.check_10:
    cmp     word [rsi], 0x3031
    jne     .check_11
    cmp     byte [rsi + 2], ';'
    jne     .h_ret
    cmp     byte [rsi + 3], '?'
    jne     .set_10
    mov     edi, [cfg_fg]
    mov     al, '0'
    call    send_osc_color_resp
    ret
.set_10:
    lea     rdi, [rsi + 3]
    call    parse_hex_color
    test    edx, edx
    jz      .h_ret
    mov     [cfg_fg], eax
    ret

.check_11:
    cmp     word [rsi], 0x3131
    jne     .check_12
    cmp     byte [rsi + 2], ';'
    jne     .h_ret
    cmp     byte [rsi + 3], '?'
    jne     .set_11
    mov     edi, [cfg_bg]
    mov     al, '1'
    call    send_osc_color_resp
    ret
.set_11:
    lea     rdi, [rsi + 3]
    cmp     byte [rdi], '['
    jne     .parse_11_color
.skip_bracket:
    cmp     byte [rdi], 0
    jz      .parse_11_color
    cmp     byte [rdi], ']'
    je      .after_bracket
    inc     rdi
    jmp     .skip_bracket
.after_bracket:
    inc     rdi
.parse_11_color:
    call    parse_hex_color
    test    edx, edx
    jz      .h_ret
    mov     [cfg_bg], eax
    or      eax, 0xff000000
    mov     [cfg_bg_pixel], eax
    ret

.check_12:
    cmp     word [rsi], 0x3231
    jne     .h_ret
    cmp     byte [rsi + 2], ';'
    jne     .h_ret
    lea     rdi, [rsi + 3]
    call    parse_hex_color
    test    edx, edx
    jz      .h_ret
    mov     [cfg_cursor], eax
    ret

.handle_osc_4:
    add     rsi, 2
    xor     eax, eax
.osc_4_idx:
    movzx   edx, byte [rsi]
    sub     edx, '0'
    cmp     edx, 9
    ja      .osc_4_idx_done
    imul    eax, 10
    add     eax, edx
    inc     rsi
    jmp     .osc_4_idx
.osc_4_idx_done:
    cmp     byte [rsi], ';'
    jne     .h_ret
    inc     rsi
    cmp     eax, 15
    ja      .h_ret
    push    rax
    mov     rdi, rsi
    call    parse_hex_color
    pop     rcx
    test    edx, edx
    jz      .h_ret
    lea     rdx, [ansi_colors]
    mov     [rdx + rcx*4], eax
.h_ret:
    ret

send_osc_color_resp:
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12d, edi
    mov     r13b, al

    lea     rdi, [cpr_buf]
    mov     byte [rdi], 27
    mov     byte [rdi + 1], ']'
    mov     byte [rdi + 2], '1'
    mov     [rdi + 3], r13b
    mov     byte [rdi + 4], ';'
    mov     byte [rdi + 5], 'r'
    mov     byte [rdi + 6], 'g'
    mov     byte [rdi + 7], 'b'
    mov     byte [rdi + 8], ':'
    add     rdi, 9

    mov     eax, r12d
    shr     eax, 16
    and     eax, 0xff
    call    emit_hex_byte2
    mov     byte [rdi], '/'
    inc     rdi

    mov     eax, r12d
    shr     eax, 8
    and     eax, 0xff
    call    emit_hex_byte2
    mov     byte [rdi], '/'
    inc     rdi

    mov     eax, r12d
    and     eax, 0xff
    call    emit_hex_byte2

    mov     byte [rdi], 27
    mov     byte [rdi + 1], 92
    add     rdi, 2

    lea     rsi, [cpr_buf]
    mov     rdx, rdi
    sub     rdx, rsi
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .socr_done
    call    write_all
.socr_done:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

emit_hex_byte2:
    lea     rcx, [hex_digits]
    mov     edx, eax
    shr     edx, 4
    and     edx, 0x0f
    mov     dl, [rcx + rdx]
    mov     [rdi], dl
    mov     [rdi + 1], dl
    mov     edx, eax
    and     edx, 0x0f
    mov     dl, [rcx + rdx]
    mov     [rdi + 2], dl
    mov     [rdi + 3], dl
    add     rdi, 4
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
    mov     eax, [cfg_bg_pixel]
    rep     stosd

    call    build_vis_rows

    xor     r15d, r15d
.row_loop:
    cmp     r15d, [term_rows]
    jae     .draw_gfx
    mov     rax, [vis_row_ptrs + r15*8]
    mov     [cur_row_ptr], rax
    mov     eax, [vis_row_cols + r15*4]
    mov     [cur_row_cols], eax
    xor     ebp, ebp
.col_loop:
    cmp     ebp, [cur_row_cols]
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
    mov     r8d, [cfg_sel_fg]
    mov     r9d, [cfg_sel_bg]
.not_sel:
    cmp     edi, ' '
    je      .space_cell
    test    edi, edi
    jz      .space_cell
    cmp     edi, 0x10EEEE
    je      .space_cell

    or      r8d, 0xff000000
    cmp     r9d, [cfg_bg]
    jne     .non_def_bg
    mov     r9d, [cfg_bg_pixel]
    jmp     .bg_ready
.non_def_bg:
    or      r9d, 0xff000000
.bg_ready:
    push    r8
    push    r9
    call    font_glyph_for_char
    mov     edi, eax
    call    font_glyph_data
    pop     r9
    pop     r8
    mov     rsi, rax

    mov     eax, ebp
    imul    eax, [font_w]
    add     eax, [cfg_pad_x]
    mov     ecx, r15d
    imul    ecx, [font_h]
    add     ecx, [cfg_pad_y]

    mov     rdi, r12
    mov     edx, r13d
    call    draw_glyph

    push    r12
    push    r13
    mov     edi, ebp
    mov     esi, r15d
    call    is_cell_url_hovered
    test    eax, eax
    jz      .no_wavy1
    mov     edi, ebp
    mov     esi, r15d
    mov     rdx, r12
    mov     ecx, r13d
    call    draw_wavy_underline
.no_wavy1:
    pop     r13
    pop     r12

.col_next:
    inc     ebp
    jmp     .col_loop

.space_cell:
    cmp     r9d, [cfg_bg]
    je      .check_space_wavy
    mov     eax, ebp
    imul    eax, [font_w]
    add     eax, [cfg_pad_x]
    mov     ecx, r15d
    imul    ecx, [font_h]
    add     ecx, [cfg_pad_y]
    imul    ecx, r13d
    add     ecx, eax
    lea     rdi, [r12 + rcx*4]
    mov     edx, [font_h]
    mov     eax, r9d
    or      eax, 0xff000000
.sp_row:
    mov     rsi, rdi
    mov     ecx, [font_w]
    rep     stosd
    lea     rdi, [rsi + r13*4]
    dec     edx
    jnz     .sp_row
.check_space_wavy:
    push    r12
    push    r13
    mov     edi, ebp
    mov     esi, r15d
    call    is_cell_url_hovered
    test    eax, eax
    jz      .no_wavy2
    mov     edi, ebp
    mov     esi, r15d
    mov     rdx, r12
    mov     ecx, r13d
    call    draw_wavy_underline
.no_wavy2:
    pop     r13
    pop     r12
    jmp     .col_next
.row_next:
    inc     r15d
    jmp     .row_loop

.draw_gfx:
    push    r12
    push    r13
    push    r14
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, [font_w]
    mov     r8d, [font_h]
    mov     r9d, [cfg_pad_x]
    sub     rsp, 8
    mov     eax, [cfg_pad_y]
    mov     [rsp], rax
    call    kitty_gfx_render
    add     rsp, 8
    pop     r14
    pop     r13
    pop     r12

.draw_cursor:
    cmp     dword [scroll_offset], 0
    jne     .render_done
    cmp     byte [cursor_visible], 0
    je      .render_done

    mov     eax, [vis_cursor_col]
    cmp     eax, [term_cols]
    jae     .render_done
    mov     ecx, [vis_cursor_row]
    cmp     ecx, [term_rows]
    jae     .render_done

    imul    eax, [font_w]
    add     eax, [cfg_pad_x]
    imul    ecx, [font_h]
    add     ecx, [cfg_pad_y]

    imul    ecx, r13d
    add     ecx, eax
    lea     rdi, [r12 + rcx*4]

    mov     edx, [font_h]
    mov     eax, [cfg_cursor]
    or      eax, 0xff000000
.c_row:
    mov     rsi, rdi
    mov     ecx, [font_w]
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
    push    r15
    push    rbp

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
    cmp     ebx, [font_h]
    jae     .done

    imul    eax, ebx, 20
    xor     edx, edx
    div     dword [font_h]
    imul    eax, 10
    lea     r14, [rsi + rax]

    mov     rdi, r11
    xor     r15d, r15d

.pixel_loop:
    cmp     r15d, [font_w]
    jae     .next_line

    imul    eax, r15d, 10
    xor     edx, edx
    div     dword [font_w]
    movzx   eax, byte [r14 + rax]

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
    inc     r15d
    jmp     .pixel_loop

.next_line:
    lea     r11, [r11 + r10*4]
    inc     ebx
    jmp     .line_loop

.done:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

get_cell_char:
    cmp     esi, [term_rows]
    jae     .cell_invalid
    cmp     edi, [term_cols]
    jae     .cell_invalid
    mov     rax, [vis_row_ptrs + rsi*8]
    test    rax, rax
    jz      .cell_invalid
    mov     edx, edi
    shl     edx, 4
    mov     eax, [rax + rdx]
    ret
.cell_invalid:
    xor     eax, eax
    ret

is_url_char:
    cmp     eax, 33
    jb      .not_url_char
    cmp     eax, 126
    ja      .not_url_char
    cmp     al, 34
    je      .not_url_char
    cmp     al, 39
    je      .not_url_char
    cmp     al, 96
    je      .not_url_char
    cmp     al, '<'
    je      .not_url_char
    cmp     al, '>'
    je      .not_url_char
    cmp     al, 92
    je      .not_url_char
    cmp     al, '^'
    je      .not_url_char
    cmp     al, '{'
    je      .not_url_char
    cmp     al, '|'
    je      .not_url_char
    cmp     al, '}'
    je      .not_url_char
    mov     eax, 1
    ret
.not_url_char:
    xor     eax, eax
    ret

step_prev_cell:
    test    edi, edi
    jz      .prev_row
    dec     edi
    mov     eax, 1
    ret
.prev_row:
    test    esi, esi
    jz      .cannot_prev
    dec     esi
    mov     rax, [vis_row_ptrs + rsi*8 + 8]
    mov     rdx, [vis_row_ptrs + rsi*8]
    test    rax, rax
    jz      .check_wrapped_flag
    test    rdx, rdx
    jz      .check_wrapped_flag
    mov     ecx, [term_cols]
    shl     ecx, 4
    add     rdx, rcx
    cmp     rax, rdx
    je      .is_prev_wrapped
.check_wrapped_flag:
    cmp     byte [row_wrapped + rsi], 0
    jz      .prev_fail
.is_prev_wrapped:
    mov     edi, [term_cols]
    dec     edi
    mov     eax, 1
    ret
.prev_fail:
    inc     esi
.cannot_prev:
    xor     eax, eax
    ret

step_next_cell:
    lea     eax, [edi + 1]
    cmp     eax, [term_cols]
    jae     .next_row
    mov     edi, eax
    mov     eax, 1
    ret
.next_row:
    lea     edx, [esi + 1]
    cmp     edx, [term_rows]
    jae     .cannot_next
    mov     rax, [vis_row_ptrs + rsi*8]
    mov     rdx, [vis_row_ptrs + rdx*8]
    test    rax, rax
    jz      .check_wrapped_next
    test    rdx, rdx
    jz      .check_wrapped_next
    mov     ecx, [term_cols]
    shl     ecx, 4
    add     rax, rcx
    cmp     rdx, rax
    je      .is_next_wrapped
.check_wrapped_next:
    cmp     byte [row_wrapped + rsi], 0
    jz      .cannot_next
.is_next_wrapped:
    inc     esi
    xor     edi, edi
    mov     eax, 1
    ret
.cannot_next:
    xor     eax, eax
    ret

term_find_url_at:
    cmp     edi, [term_cols]
    jae     .early_fail
    cmp     esi, [term_rows]
    jae     .early_fail
    cmp     ecx, 16
    jbe     .early_fail

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12d, edi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15d, ecx

    call    build_vis_rows

    mov     edi, r12d
    mov     esi, r13d
    call    get_cell_char
    call    is_url_char
    test    eax, eax
    jz      .fail

    mov     ebx, r12d
    mov     ebp, r13d

.scan_back:
    mov     edi, ebx
    mov     esi, ebp
    call    step_prev_cell
    test    eax, eax
    jz      .start_found
    push    rdi
    push    rsi
    call    get_cell_char
    call    is_url_char
    test    eax, eax
    jz      .pop_stop
    pop     rbp
    pop     rbx
    jmp     .scan_back

.pop_stop:
    add     rsp, 16
.start_found:

    xor     r8d, r8d
    mov     r9d, -1

.scan_fwd:
    cmp     ebx, r12d
    jne     .not_click
    cmp     ebp, r13d
    jne     .not_click
    mov     r9d, r8d

.not_click:
    mov     edi, ebx
    mov     esi, ebp
    call    get_cell_char
    mov     r10d, eax
    call    is_url_char
    test    eax, eax
    jz      .fwd_done

    mov     [r14 + r8], r10b
    mov     byte [cand_cols + r8], bl
    mov     byte [cand_rows + r8], bpl
    inc     r8d
    lea     eax, [r15d - 2]
    cmp     r8d, eax
    jae     .fwd_done

    mov     edi, ebx
    mov     esi, ebp
    call    step_next_cell
    test    eax, eax
    jz      .fwd_done
    mov     ebx, edi
    mov     ebp, esi
    jmp     .scan_fwd

.fwd_done:
    test    r9d, r9d
    js      .fail
    cmp     r8d, 10
    jb      .fail

    xor     ecx, ecx
.search_scheme:
    lea     eax, [ecx + 7]
    cmp     eax, r8d
    ja      .fail

    cmp     byte [r14 + rcx], 'h'
    jne     .next_scheme_idx
    cmp     byte [r14 + rcx + 1], 't'
    jne     .next_scheme_idx
    cmp     byte [r14 + rcx + 2], 't'
    jne     .next_scheme_idx
    cmp     byte [r14 + rcx + 3], 'p'
    jne     .next_scheme_idx
    cmp     byte [r14 + rcx + 4], ':'
    jne     .check_https
    cmp     byte [r14 + rcx + 5], '/'
    jne     .next_scheme_idx
    cmp     byte [r14 + rcx + 6], '/'
    jne     .next_scheme_idx
    jmp     .scheme_found

.check_https:
    lea     eax, [ecx + 8]
    cmp     eax, r8d
    ja      .next_scheme_idx
    cmp     byte [r14 + rcx + 4], 's'
    jne     .next_scheme_idx
    cmp     byte [r14 + rcx + 5], ':'
    jne     .next_scheme_idx
    cmp     byte [r14 + rcx + 6], '/'
    jne     .next_scheme_idx
    cmp     byte [r14 + rcx + 7], '/'
    jne     .next_scheme_idx
    jmp     .scheme_found

.next_scheme_idx:
    inc     ecx
    jmp     .search_scheme

.scheme_found:
    cmp     r9d, ecx
    jb      .fail

    lea     edx, [r8d - 1]
.trim_loop:
    cmp     edx, ecx
    jle     .fail
    movzx   eax, byte [r14 + rdx]
    cmp     al, '.'
    je      .do_trim
    cmp     al, ','
    je      .do_trim
    cmp     al, ';'
    je      .do_trim
    cmp     al, ':'
    je      .do_trim
    cmp     al, '!'
    je      .do_trim
    cmp     al, '?'
    je      .do_trim
    cmp     al, '>'
    je      .do_trim
    cmp     al, 34
    je      .do_trim
    cmp     al, 39
    je      .do_trim
    cmp     al, ')'
    je      .trim_paren
    cmp     al, ']'
    je      .trim_bracket
    jmp     .trim_done

.trim_paren:
    push    rdx
    push    rcx
    xor     eax, eax
    xor     r10d, r10d
.count_paren:
    cmp     ecx, edx
    ja      .counted_paren
    cmp     byte [r14 + rcx], '('
    jne     .not_open_p
    inc     eax
.not_open_p:
    cmp     byte [r14 + rcx], ')'
    jne     .not_close_p
    inc     r10d
.not_close_p:
    inc     ecx
    jmp     .count_paren
.counted_paren:
    pop     rcx
    pop     rdx
    cmp     eax, r10d
    jae     .trim_done
    jmp     .do_trim

.trim_bracket:
    push    rdx
    push    rcx
    xor     eax, eax
    xor     r10d, r10d
.count_bracket:
    cmp     ecx, edx
    ja      .counted_bracket
    cmp     byte [r14 + rcx], '['
    jne     .not_open_b
    inc     eax
.not_open_b:
    cmp     byte [r14 + rcx], ']'
    jne     .not_close_b
    inc     r10d
.not_close_b:
    inc     ecx
    jmp     .count_bracket
.counted_bracket:
    pop     rcx
    pop     rdx
    cmp     eax, r10d
    jae     .trim_done

.do_trim:
    dec     edx
    jmp     .trim_loop

.trim_done:
    cmp     r9d, edx
    ja      .fail

    mov     eax, edx
    sub     eax, ecx
    inc     eax
    cmp     eax, 10
    jb      .fail
    mov     r8d, eax

    test    ecx, ecx
    jz      .null_term
    xor     esi, esi
.shift_loop:
    cmp     esi, r8d
    jae     .null_term
    lea     edi, [ecx + esi]
    mov     al, [r14 + rdi]
    mov     [r14 + rsi], al
    inc     esi
    jmp     .shift_loop

.null_term:
    mov     byte [r14 + r8], 0
    movzx   eax, byte [cand_cols + rcx]
    mov     [url_hover_start_col], eax
    movzx   eax, byte [cand_rows + rcx]
    mov     [url_hover_start_row], eax
    movzx   eax, byte [cand_cols + rdx]
    mov     [url_hover_end_col], eax
    movzx   eax, byte [cand_rows + rdx]
    mov     [url_hover_end_row], eax
    mov     byte [url_hover_active], 1
    mov     eax, r8d
    jmp     .done

.fail:
    mov     byte [url_hover_active], 0
    xor     eax, eax
.done:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.early_fail:
    xor     eax, eax
    ret

is_cell_url_hovered:
    cmp     byte [url_hover_active], 0
    jz      .no_hover
    cmp     esi, [url_hover_start_row]
    jb      .no_hover
    cmp     esi, [url_hover_end_row]
    ja      .no_hover
    cmp     esi, [url_hover_start_row]
    jne     .check_end
    cmp     edi, [url_hover_start_col]
    jb      .no_hover
.check_end:
    cmp     esi, [url_hover_end_row]
    jne     .hover_yes
    cmp     edi, [url_hover_end_col]
    ja      .no_hover
.hover_yes:
    mov     eax, 1
    ret
.no_hover:
    xor     eax, eax
    ret

draw_wavy_underline:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     eax, edi
    imul    eax, [font_w]
    add     eax, [cfg_pad_x]
    mov     r14d, eax

    mov     eax, esi
    imul    eax, [font_h]
    add     eax, [cfg_pad_y]
    add     eax, [font_h]
    sub     eax, 2
    mov     r15d, eax

    mov     r12, rdx
    mov     r13d, ecx

    xor     ebx, ebx
.wave_x:
    cmp     ebx, [font_w]
    jae     .wave_done

    lea     eax, [r14d + ebx]
    mov     edx, eax
    shr     edx, 1
    and     edx, 1

    mov     eax, r15d
    sub     eax, edx

    imul    eax, r13d
    lea     edx, [r14d + ebx]
    add     eax, edx
    lea     rax, [r12 + rax*4]

    mov     dword [rax], 0xff58a6ff

    inc     ebx
    jmp     .wave_x

.wave_done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

term_clear_hover:
    mov     byte [url_hover_active], 0
    ret

term_zoom_in:
    cmp     dword [font_w], 28
    jge     .zoom_ret
    inc     dword [font_w]
    mov     eax, [font_w]
    shl     eax, 1
    mov     [font_h], eax
    mov     eax, 1
    ret
.zoom_ret:
    xor     eax, eax
    ret

term_zoom_out:
    cmp     dword [font_w], 6
    jle     .zoom_ret
    dec     dword [font_w]
    mov     eax, [font_w]
    shl     eax, 1
    mov     [font_h], eax
    mov     eax, 1
    ret
.zoom_ret:
    xor     eax, eax
    ret

term_zoom_reset:
    mov     dword [font_w], 10
    mov     dword [font_h], 20
    mov     eax, 1
    ret
