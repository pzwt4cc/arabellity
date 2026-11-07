default rel

global term_init
global term_resize
global term_feed
global term_render
global term_cols
global term_rows
global term_cursor_col
global term_cursor_row

extern font_glyph_data
extern font_glyph_for_char

%define MAX_COLS       256
%define MAX_ROWS       128
%define CELL_SIZE      16

%define COLOR_BG       0x0d1117
%define COLOR_FG       0xc9d1d9
%define COLOR_CURSOR   0x39ff14
%define PAD_X          8
%define PAD_Y          8

%define FONT_W         10
%define FONT_H         20

section .bss
term_cols:          resd 1
term_rows:          resd 1
term_cursor_col:    resd 1
term_cursor_row:    resd 1
cur_fg:             resd 1
cur_bg:             resd 1

esc_state:          resd 1
csi_argc:           resd 1
csi_args:           resd 16
utf8_state:         resd 1
utf8_codepoint:     resd 1

grid:               resb MAX_COLS * MAX_ROWS * CELL_SIZE

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
    mov     dword [cur_fg], COLOR_FG
    mov     dword [cur_bg], COLOR_BG
    mov     dword [esc_state], 0
    mov     dword [utf8_state], 0
    call    term_clear_grid
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
    mov     dword [esc_state], 0
    ret

.to_csi:
    mov     dword [esc_state], 2
    mov     dword [csi_argc], 0
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
    cmp     edi, '?'
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
    ret

term_handle_csi:
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
    ret
.ed_all:
    call    term_clear_grid
    mov     dword [term_cursor_col], 0
    mov     dword [term_cursor_row], 0
    ret

.el:
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
    xor     ebp, ebp
.col_loop:
    cmp     ebp, [term_cols]
    jae     .row_next

    mov     eax, r15d
    imul    eax, MAX_COLS
    add     eax, ebp
    shl     eax, 4
    lea     rbx, [grid + rax]

    mov     edi, [rbx]
    mov     r8d, [rbx + 4]
    mov     r9d, [rbx + 8]

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

    xor     ebx, ebx
.line_loop:
    cmp     ebx, FONT_H
    jae     .done

    movzx   r12d, byte [rsi]
    shl     r12d, 8
    movzx   eax, byte [rsi + 1]
    or      r12d, eax
    add     rsi, 2

    mov     rdi, r11
    mov     ecx, FONT_W
    mov     r13d, 0x8000

.pixel_loop:
    test    r12d, r13d
    jz      .bg_pixel
    mov     eax, r8d
    jmp     .write_pixel
.bg_pixel:
    mov     eax, r9d
.write_pixel:
    mov     [rdi], eax
    add     rdi, 4
    shr     r13d, 1
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
