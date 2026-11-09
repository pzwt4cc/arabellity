default rel
%include "syscalls.inc"

global kitty_gfx_init
global kitty_gfx_clear
global kitty_gfx_scroll_up
global kitty_gfx_apc_begin
global kitty_gfx_apc_char
global kitty_gfx_apc_end
global kitty_gfx_render

extern write_all
extern win_pty_fd
extern term_cursor_col
extern term_cursor_row
extern term_cols
extern term_rows
extern term_scroll_up
extern png_decode
extern term_find_placeholder_bounds
extern in_alt_screen

%define MAX_PLACEMENTS 64
%define PLACE_SIZE 48
%define APC_BUF_MAX 32768

section .rodata
b64_table:
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfd, 0xfd, 0xff, 0xff, 0xfd, 0xff, 0xff
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xfd, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x3e, 0xff, 0xff, 0xff, 0x3f
    db 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0xff, 0xff, 0xff, 0xfe, 0xff, 0xff
    db 0xff, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e
    db 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xff, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28
    db 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32, 0x33, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff

section .bss
align 16
placements:             resb (MAX_PLACEMENTS * PLACE_SIZE)
placement_count:        resd 1

apc_active:             resb 1
apc_is_kitty:           resb 1
apc_buf:                resb APC_BUF_MAX
apc_len:                resd 1

cur_action:             resd 1
cur_fmt:                resd 1
cur_w:                  resd 1
cur_h:                  resd 1
cur_cols:               resd 1
cur_rows:               resd 1
cur_id:                 resd 1
cur_more:               resd 1
cur_quiet:              resd 1
cur_del_type:           resd 1
cur_trans_type:         resd 1
cur_size:               resd 1
cur_cursor_policy:      resd 1
cur_unicode:            resd 1

recv_in_progress:       resb 1
recv_data_ptr:          resq 1
recv_data_size:         resd 1
recv_pixel_count:       resd 1
recv_pixel_cap:         resd 1
recv_fifo:              resb 8
recv_fifo_cnt:          resd 1
recv_w:                 resd 1
recv_h:                 resd 1
recv_cols:              resd 1
recv_rows:              resd 1
recv_id:                resd 1
recv_fmt:               resd 1
recv_action:            resd 1
recv_start_col:         resd 1
recv_start_row:         resd 1
recv_unicode:           resd 1
recv_cursor_policy:     resd 1

quad_bytes:             resb 4
resp_buf:               resb 128
placeholder_bounds:     resd 4
b64_decode_buf:         resb 1024
file_path_buf:          resb 512
stat_buf:               resb 144

render_buf_ptr:         resq 1
render_buf_w:           resd 1
render_buf_h:           resd 1
render_font_w:          resd 1
render_font_h:          resd 1
render_pad_x:           resd 1
render_pad_y:           resd 1

cur_img_data:           resq 1
cur_img_w:              resd 1
cur_img_h:              resd 1
cur_dst_w:              resd 1
cur_dst_h:              resd 1
cur_dst_x0:             resd 1
cur_dst_y0:             resd 1
cur_src_row:            resq 1
cur_dst_row:            resq 1

section .text

kitty_gfx_init:
    call    kitty_gfx_clear
    mov     byte [recv_in_progress], 0
    mov     byte [apc_active], 0
    mov     byte [apc_is_kitty], 0
    mov     dword [apc_len], 0
    ret

kitty_gfx_clear:
    push    rbx
    push    r12
    xor     ebx, ebx
.loop:
    cmp     ebx, MAX_PLACEMENTS
    jae     .done
    mov     eax, ebx
    imul    eax, PLACE_SIZE
    lea     r12, [placements + rax]
    cmp     byte [r12 + 44], 0
    jz      .next
    mov     rdi, [r12 + 8]
    test    rdi, rdi
    jz      .unmap_done
    mov     esi, [r12 + 16]
    test    esi, esi
    jz      .unmap_done
    mov     eax, SYS_MUNMAP
    syscall
.unmap_done:
    mov     byte [r12 + 44], 0
    mov     byte [r12 + 45], 0
    mov     qword [r12 + 8], 0
.next:
    inc     ebx
    jmp     .loop
.done:
    mov     dword [placement_count], 0
    pop     r12
    pop     rbx
    ret

kitty_gfx_scroll_up:
    cmp     byte [in_alt_screen], 0
    jnz     .done_early
    push    rbx
    push    r12
    push    r13
    mov     r13d, edi
    test    r13d, r13d
    jle     .done
    xor     ebx, ebx
.loop:
    cmp     ebx, MAX_PLACEMENTS
    jae     .done
    mov     eax, ebx
    imul    eax, PLACE_SIZE
    lea     r12, [placements + rax]
    cmp     byte [r12 + 44], 0
    jz      .next
    cmp     byte [r12 + 45], 1
    je      .next
    mov     eax, [r12 + 32]
    sub     eax, r13d
    mov     [r12 + 32], eax
    mov     edx, [r12 + 40]
    add     eax, edx
    jg      .next
    mov     rdi, [r12 + 8]
    test    rdi, rdi
    jz      .free_slot
    mov     esi, [r12 + 16]
    test    esi, esi
    jz      .free_slot
    mov     eax, SYS_MUNMAP
    syscall
.free_slot:
    mov     byte [r12 + 44], 0
    mov     byte [r12 + 45], 0
    mov     qword [r12 + 8], 0
.next:
    inc     ebx
    jmp     .loop
.done:
    pop     r13
    pop     r12
    pop     rbx
.done_early:
    ret

kitty_gfx_apc_begin:
    mov     byte [apc_active], 1
    mov     byte [apc_is_kitty], 0
    mov     dword [apc_len], 0
    ret

kitty_gfx_apc_char:
    cmp     byte [apc_active], 0
    jz      .ret
    cmp     dword [apc_len], 0
    jnz     .check_body
    cmp     edi, 'G'
    jne     .not_kitty
    mov     byte [apc_is_kitty], 1
    mov     eax, [apc_len]
    mov     [apc_buf + rax], dil
    inc     dword [apc_len]
    ret
.not_kitty:
    mov     byte [apc_active], 0
    ret
.check_body:
    cmp     byte [apc_is_kitty], 0
    jz      .ret
    mov     eax, [apc_len]
    cmp     eax, APC_BUF_MAX - 4
    jae     .ret
    mov     [apc_buf + rax], dil
    inc     dword [apc_len]
.ret:
    ret

check_cursor_scroll:
.css_loop:
    mov     eax, [term_cursor_row]
    mov     ecx, [term_rows]
    dec     ecx
    cmp     eax, ecx
    jle     .css_done
    push    rcx
    call    term_scroll_up
    pop     rcx
    dec     dword [term_cursor_row]
    jmp     .css_loop
.css_done:
    ret

alloc_placement_slot:
    mov     r8d, [cur_id]
    test    r8d, r8d
    jz      .find_empty
    xor     eax, eax
.find_id_loop:
    cmp     eax, MAX_PLACEMENTS
    jae     .find_empty
    mov     edx, eax
    imul    edx, PLACE_SIZE
    lea     rcx, [placements + rdx]
    cmp     byte [rcx + 44], 0
    jz      .find_id_next
    cmp     [rcx], r8d
    jne     .find_id_next
    mov     rdi, [rcx + 8]
    test    rdi, rdi
    jz      .slot_found
    mov     esi, [rcx + 16]
    test    esi, esi
    jz      .slot_found
    push    rcx
    mov     eax, SYS_MUNMAP
    syscall
    pop     rcx
    mov     qword [rcx + 8], 0
    jmp     .slot_found
.find_id_next:
    inc     eax
    jmp     .find_id_loop

.find_empty:
    xor     eax, eax
.find_empty_loop:
    cmp     eax, MAX_PLACEMENTS
    jae     .find_fallback
    mov     edx, eax
    imul    edx, PLACE_SIZE
    lea     rcx, [placements + rdx]
    cmp     byte [rcx + 44], 0
    jz      .slot_found
    inc     eax
    jmp     .find_empty_loop

.find_fallback:
    lea     rcx, [placements]
    mov     rdi, [rcx + 8]
    test    rdi, rdi
    jz      .slot_found
    mov     esi, [rcx + 16]
    test    esi, esi
    jz      .slot_found
    push    rcx
    mov     eax, SYS_MUNMAP
    syscall
    pop     rcx
.slot_found:
    mov     rax, rcx
    ret

create_cur_placement:
    push    rbx
    push    rcx
    push    rdx

    mov     eax, [cur_cols]
    test    eax, eax
    jnz     .cols_ok
    mov     eax, [cur_w]
    add     eax, 9
    xor     edx, edx
    mov     ecx, 10
    div     ecx
    mov     [cur_cols], eax
.cols_ok:

    mov     eax, [cur_rows]
    test    eax, eax
    jnz     .rows_ok
    mov     eax, [cur_h]
    add     eax, 19
    xor     edx, edx
    mov     ecx, 20
    div     ecx
    mov     [cur_rows], eax
.rows_ok:

    call    alloc_placement_slot
    mov     rbx, rax

    mov     eax, [cur_id]
    mov     [rbx], eax
    mov     [rbx + 8], r13
    mov     [rbx + 16], r14d
    mov     eax, [cur_w]
    mov     [rbx + 20], eax
    mov     eax, [cur_h]
    mov     [rbx + 24], eax
    mov     eax, [term_cursor_col]
    mov     [rbx + 28], eax
    mov     eax, [term_cursor_row]
    mov     [rbx + 32], eax
    mov     eax, [cur_cols]
    mov     [rbx + 36], eax
    mov     eax, [cur_rows]
    mov     [rbx + 40], eax
    mov     byte [rbx + 44], 1

    cmp     dword [cur_unicode], 1
    je      .is_virtual
    mov     byte [rbx + 45], 0
    inc     dword [placement_count]

    cmp     dword [cur_cursor_policy], 1
    je      .done
    cmp     dword [cur_action], 'T'
    jne     .done

    mov     ecx, [rbx + 40]
    test    ecx, ecx
    jz      .done
    add     [term_cursor_row], ecx
    mov     dword [term_cursor_col], 0
    call    check_cursor_scroll
    jmp     .done

.is_virtual:
    mov     byte [rbx + 45], 1
    inc     dword [placement_count]

.done:
    pop     rdx
    pop     rcx
    pop     rbx
    ret

format_num:
    xor     ecx, ecx
    mov     r8d, 10
.f_div:
    xor     edx, edx
    div     r8d
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

decode_base64_string:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rsi
    mov     r13, rdi
    mov     r14d, edx
    xor     r15d, r15d

.b64s_quad:
    xor     ecx, ecx
.b64s_char:
    movzx   eax, byte [r12]
    test    al, al
    jz      .b64s_done
    cmp     al, ';'
    je      .b64s_done
    cmp     al, 27
    je      .b64s_done
    inc     r12
    lea     rdx, [b64_table]
    movzx   edx, byte [rdx + rax]
    cmp     dl, 0xfd
    je      .b64s_char
    cmp     dl, 0xff
    je      .b64s_char
    mov     [quad_bytes + rcx], dl
    inc     ecx
    cmp     ecx, 4
    jb      .b64s_char

    movzx   r8d, byte [quad_bytes]
    movzx   r9d, byte [quad_bytes + 1]
    movzx   r10d, byte [quad_bytes + 2]
    movzx   r11d, byte [quad_bytes + 3]

    cmp     r10d, 0xfe
    je      .b64s_emit1
    cmp     r11d, 0xfe
    je      .b64s_emit2

    mov     eax, r8d
    shl     eax, 2
    mov     edx, r9d
    shr     edx, 4
    or      eax, edx
    cmp     r15d, r14d
    jae     .b64s_done
    mov     [r13 + r15], al
    inc     r15d

    mov     eax, r9d
    and     eax, 0x0f
    shl     eax, 4
    mov     edx, r10d
    shr     edx, 2
    or      eax, edx
    cmp     r15d, r14d
    jae     .b64s_done
    mov     [r13 + r15], al
    inc     r15d

    mov     eax, r10d
    and     eax, 0x03
    shl     eax, 6
    or      eax, r11d
    cmp     r15d, r14d
    jae     .b64s_done
    mov     [r13 + r15], al
    inc     r15d
    jmp     .b64s_quad

.b64s_emit1:
    mov     eax, r8d
    shl     eax, 2
    mov     edx, r9d
    shr     edx, 4
    or      eax, edx
    cmp     r15d, r14d
    jae     .b64s_done
    mov     [r13 + r15], al
    inc     r15d
    jmp     .b64s_done

.b64s_emit2:
    mov     eax, r8d
    shl     eax, 2
    mov     edx, r9d
    shr     edx, 4
    or      eax, edx
    cmp     r15d, r14d
    jae     .b64s_done
    mov     [r13 + r15], al
    inc     r15d

    mov     eax, r9d
    and     eax, 0x0f
    shl     eax, 4
    mov     edx, r10d
    shr     edx, 2
    or      eax, edx
    cmp     r15d, r14d
    jae     .b64s_done
    mov     [r13 + r15], al
    inc     r15d
    jmp     .b64s_done

.b64s_done:
    mov     byte [r13 + r15], 0
    mov     eax, r15d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

push_fifo_byte:
    mov     edx, [recv_fifo_cnt]
    cmp     edx, 7
    jae     .p_ret
    mov     [recv_fifo + rdx], al
    inc     dword [recv_fifo_cnt]
.p_ret:
    ret

drain_fifo_pixels:
    cmp     dword [recv_fmt], 32
    je      .drain_32

.drain_24:
    cmp     dword [recv_fifo_cnt], 3
    jb      .d_ret
    movzx   eax, byte [recv_fifo]
    movzx   ecx, byte [recv_fifo + 1]
    movzx   edx, byte [recv_fifo + 2]
    shl     eax, 16
    shl     ecx, 8
    or      eax, 0xff000000
    or      eax, ecx
    or      eax, edx
    call    store_pixel
    mov     al, [recv_fifo + 3]
    mov     [recv_fifo], al
    mov     al, [recv_fifo + 4]
    mov     [recv_fifo + 1], al
    mov     al, [recv_fifo + 5]
    mov     [recv_fifo + 2], al
    sub     dword [recv_fifo_cnt], 3
    jmp     .drain_24

.drain_32:
    cmp     dword [recv_fifo_cnt], 4
    jb      .d_ret
    movzx   eax, byte [recv_fifo]
    movzx   ecx, byte [recv_fifo + 1]
    movzx   edx, byte [recv_fifo + 2]
    movzx   r8d, byte [recv_fifo + 3]
    shl     r8d, 24
    shl     eax, 16
    shl     ecx, 8
    or      eax, r8d
    or      eax, ecx
    or      eax, edx
    call    store_pixel
    mov     al, [recv_fifo + 4]
    mov     [recv_fifo], al
    mov     al, [recv_fifo + 5]
    mov     [recv_fifo + 1], al
    mov     al, [recv_fifo + 6]
    mov     [recv_fifo + 2], al
    sub     dword [recv_fifo_cnt], 4
    jmp     .drain_32

.d_ret:
    ret

store_pixel:
    mov     edx, [recv_pixel_count]
    cmp     edx, [recv_pixel_cap]
    jae     .s_ret
    mov     rdi, [recv_data_ptr]
    mov     [rdi + rdx*4], eax
    inc     dword [recv_pixel_count]
.s_ret:
    ret

decode_base64_stream:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rsi

.read_quad:
    xor     ebx, ebx
.get_char:
    movzx   eax, byte [r12]
    test    al, al
    jz      .stream_end
    cmp     al, 27
    je      .stream_end
    inc     r12
    lea     rdx, [b64_table]
    movzx   edx, byte [rdx + rax]
    cmp     dl, 0xfd
    je      .get_char
    cmp     dl, 0xff
    je      .get_char
    mov     [quad_bytes + rbx], dl
    inc     ebx
    cmp     ebx, 4
    jb      .get_char

    movzx   r13d, byte [quad_bytes]
    movzx   r14d, byte [quad_bytes + 1]
    movzx   r15d, byte [quad_bytes + 2]
    movzx   ebp, byte [quad_bytes + 3]

    cmp     r15d, 0xfe
    je      .emit_1
    cmp     ebp, 0xfe
    je      .emit_2

    mov     eax, r13d
    shl     eax, 2
    mov     edx, r14d
    shr     edx, 4
    or      eax, edx
    call    push_fifo_byte

    mov     eax, r14d
    and     eax, 0x0f
    shl     eax, 4
    mov     edx, r15d
    shr     edx, 2
    or      eax, edx
    call    push_fifo_byte

    mov     eax, r15d
    and     eax, 0x03
    shl     eax, 6
    or      eax, ebp
    call    push_fifo_byte
    jmp     .drain_fifo

.emit_1:
    mov     eax, r13d
    shl     eax, 2
    mov     edx, r14d
    shr     edx, 4
    or      eax, edx
    call    push_fifo_byte
    jmp     .stream_end

.emit_2:
    mov     eax, r13d
    shl     eax, 2
    mov     edx, r14d
    shr     edx, 4
    or      eax, edx
    call    push_fifo_byte

    mov     eax, r14d
    and     eax, 0x0f
    shl     eax, 4
    mov     edx, r15d
    shr     edx, 2
    or      eax, edx
    call    push_fifo_byte
    jmp     .stream_end

.drain_fifo:
    call    drain_fifo_pixels
    jmp     .read_quad

.stream_end:
    call    drain_fifo_pixels
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

do_query:
    mov     eax, [cur_quiet]
    cmp     eax, 1
    je      .query_quiet
    cmp     eax, 2
    je      .query_quiet

    lea     rdi, [resp_buf]
    mov     byte [rdi], 27
    mov     byte [rdi + 1], '_'
    mov     byte [rdi + 2], 'G'
    add     rdi, 3

    mov     eax, [cur_id]
    test    eax, eax
    jz      .query_no_id
    mov     byte [rdi], 'i'
    mov     byte [rdi + 1], '='
    add     rdi, 2
    mov     eax, [cur_id]
    call    format_num
.query_no_id:
    mov     eax, [cur_trans_type]
    cmp     eax, 's'
    je      .query_shm
    cmp     eax, 't'
    je      .query_enosys

    mov     byte [rdi], ';'
    mov     byte [rdi + 1], 'O'
    mov     byte [rdi + 2], 'K'
    mov     byte [rdi + 3], 27
    mov     byte [rdi + 4], 92
    add     rdi, 5
    jmp     .query_send

.query_shm:
    push    rdi
    mov     rsi, r12
    lea     rdi, [b64_decode_buf + 8]
    mov     edx, 240
    call    decode_base64_string
    mov     dword [b64_decode_buf], 0x7665642f
    mov     dword [b64_decode_buf + 4], 0x6d68732f
    mov     eax, SYS_OPEN
    lea     rdi, [b64_decode_buf]
    xor     esi, esi
    xor     edx, edx
    syscall
    pop     rdi
    test    rax, rax
    js      .shm_query_ebadf
    push    rdi
    mov     rdi, rax
    mov     eax, SYS_CLOSE
    syscall
    pop     rdi
    mov     byte [rdi], ';'
    mov     byte [rdi + 1], 'O'
    mov     byte [rdi + 2], 'K'
    mov     byte [rdi + 3], 27
    mov     byte [rdi + 4], 92
    add     rdi, 5
    jmp     .query_send

.shm_query_ebadf:
    mov     byte [rdi], ';'
    mov     byte [rdi + 1], 'E'
    mov     byte [rdi + 2], 'B'
    mov     byte [rdi + 3], 'A'
    mov     byte [rdi + 4], 'D'
    mov     byte [rdi + 5], 'F'
    mov     byte [rdi + 6], ':'
    mov     byte [rdi + 7], 'F'
    mov     byte [rdi + 8], 'a'
    mov     byte [rdi + 9], 'i'
    mov     byte [rdi + 10], 'l'
    mov     byte [rdi + 11], 'e'
    mov     byte [rdi + 12], 'd'
    mov     byte [rdi + 13], ' '
    mov     byte [rdi + 14], 't'
    mov     byte [rdi + 15], 'o'
    mov     byte [rdi + 16], ' '
    mov     byte [rdi + 17], 'r'
    mov     byte [rdi + 18], 'e'
    mov     byte [rdi + 19], 'a'
    mov     byte [rdi + 20], 'd'
    mov     byte [rdi + 21], ' '
    mov     byte [rdi + 22], 'i'
    mov     byte [rdi + 23], 'm'
    mov     byte [rdi + 24], 'a'
    mov     byte [rdi + 25], 'g'
    mov     byte [rdi + 26], 'e'
    mov     byte [rdi + 27], ' '
    mov     byte [rdi + 28], 'f'
    mov     byte [rdi + 29], 'i'
    mov     byte [rdi + 30], 'l'
    mov     byte [rdi + 31], 'e'
    mov     byte [rdi + 32], 27
    mov     byte [rdi + 33], 92
    add     rdi, 34
    jmp     .query_send

.query_enosys:
    mov     byte [rdi], ';'
    mov     byte [rdi + 1], 'E'
    mov     byte [rdi + 2], 'N'
    mov     byte [rdi + 3], 'O'
    mov     byte [rdi + 4], 'S'
    mov     byte [rdi + 5], 'Y'
    mov     byte [rdi + 6], 'S'
    mov     byte [rdi + 7], 27
    mov     byte [rdi + 8], 92
    add     rdi, 9

.query_send:
    lea     rsi, [resp_buf]
    mov     rdx, rdi
    sub     rdx, rsi
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .query_quiet
    call    write_all
.query_quiet:
    xor     eax, eax
    ret

do_delete:
    cmp     dword [cur_del_type], 0
    je      .del_all
    cmp     dword [cur_del_type], 'a'
    je      .del_all
    cmp     dword [cur_del_type], 'A'
    je      .del_all
    cmp     dword [cur_del_type], 'i'
    je      .del_id
    cmp     dword [cur_del_type], 'I'
    je      .del_id
    cmp     dword [cur_del_type], 'p'
    je      .del_id
    cmp     dword [cur_del_type], 'P'
    je      .del_id
    xor     eax, eax
    ret

.del_all:
    call    kitty_gfx_clear
    mov     eax, 1
    ret

.del_id:
    mov     r8d, [cur_id]
    xor     ebx, ebx
.del_id_loop:
    cmp     ebx, MAX_PLACEMENTS
    jae     .del_id_done
    mov     eax, ebx
    imul    eax, PLACE_SIZE
    lea     r13, [placements + rax]
    cmp     byte [r13 + 44], 0
    jz      .del_id_next
    cmp     [r13], r8d
    jne     .del_id_next
    mov     rdi, [r13 + 8]
    test    rdi, rdi
    jz      .del_id_free
    mov     esi, [r13 + 16]
    test    esi, esi
    jz      .del_id_free
    mov     eax, SYS_MUNMAP
    syscall
.del_id_free:
    mov     byte [r13 + 44], 0
    mov     byte [r13 + 45], 0
    mov     qword [r13 + 8], 0
.del_id_next:
    inc     ebx
    jmp     .del_id_loop
.del_id_done:
    mov     eax, 1
    ret

do_put:
    mov     r8d, [cur_id]
    test    r8d, r8d
    jz      .put_fail
    xor     ebx, ebx
.put_find:
    cmp     ebx, MAX_PLACEMENTS
    jae     .put_fail
    mov     eax, ebx
    imul    eax, PLACE_SIZE
    lea     r13, [placements + rax]
    cmp     byte [r13 + 44], 0
    jz      .put_next
    cmp     [r13], r8d
    je      .put_found
.put_next:
    inc     ebx
    jmp     .put_find

.put_found:
    cmp     dword [cur_unicode], 1
    jne     .put_not_virt
    mov     byte [r13 + 45], 1
.put_not_virt:
    mov     eax, [term_cursor_col]
    mov     [r13 + 28], eax
    mov     eax, [term_cursor_row]
    mov     [r13 + 32], eax
    mov     eax, [cur_cols]
    test    eax, eax
    jz      .put_rows
    mov     [r13 + 36], eax
.put_rows:
    mov     eax, [cur_rows]
    test    eax, eax
    jz      .put_done
    mov     [r13 + 40], eax
.put_done:
    mov     eax, 1
    ret
.put_fail:
    xor     eax, eax
    ret

trans_shm:
    mov     rsi, r12
    lea     rdi, [b64_decode_buf + 8]
    mov     edx, 240
    call    decode_base64_string

    mov     dword [b64_decode_buf], 0x7665642f
    mov     dword [b64_decode_buf + 4], 0x6d68732f

    mov     eax, SYS_OPEN
    lea     rdi, [b64_decode_buf]
    xor     esi, esi
    xor     edx, edx
    syscall
    test    rax, rax
    js      .tshm_fail
    mov     r14, rax

    mov     eax, SYS_MMAP
    xor     edi, edi
    mov     esi, [cur_size]
    mov     edx, PROT_READ
    mov     r10d, MAP_SHARED
    mov     r8, r14
    xor     r9d, r9d
    syscall
    test    rax, rax
    js      .tshm_close_fail
    mov     r15, rax

    mov     eax, SYS_CLOSE
    mov     rdi, r14
    syscall

    mov     eax, SYS_UNLINK
    lea     rdi, [b64_decode_buf]
    syscall

    mov     eax, [cur_w]
    test    eax, eax
    jz      .tshm_munmap_fail
    mov     ecx, [cur_h]
    test    ecx, ecx
    jz      .tshm_munmap_fail

    imul    eax, ecx
    shl     eax, 2
    mov     r14d, eax

    mov     eax, SYS_MMAP
    xor     edi, edi
    mov     esi, r14d
    mov     edx, PROT_READ | PROT_WRITE
    mov     r10d, MAP_PRIVATE | MAP_ANONYMOUS
    mov     r8d, -1
    xor     r9d, r9d
    syscall
    test    rax, rax
    js      .tshm_munmap_fail
    mov     r13, rax

    mov     eax, [cur_w]
    imul    eax, [cur_h]
    xor     ecx, ecx
    cmp     dword [cur_fmt], 24
    je      .tshm_conv24

.tshm_conv32:
    cmp     ecx, eax
    jae     .tshm_conv_done
    mov     edx, [r15 + rcx*4]
    mov     [r13 + rcx*4], edx
    inc     ecx
    jmp     .tshm_conv32

.tshm_conv24:
    cmp     ecx, eax
    jae     .tshm_conv_done
    mov     edx, ecx
    lea     edx, [rdx + rdx*2]
    movzx   esi, byte [r15 + rdx]
    movzx   edi, byte [r15 + rdx + 1]
    movzx   ebp, byte [r15 + rdx + 2]
    shl     esi, 16
    shl     edi, 8
    or      esi, 0xff000000
    or      esi, edi
    or      esi, ebp
    mov     [r13 + rcx*4], esi
    inc     ecx
    jmp     .tshm_conv24

.tshm_conv_done:
    push    r13
    push    r14
    mov     eax, SYS_MUNMAP
    mov     rdi, r15
    mov     esi, [cur_size]
    syscall
    pop     r14
    pop     r13

    call    create_cur_placement
    mov     eax, 1
    ret

.tshm_munmap_fail:
    mov     eax, SYS_MUNMAP
    mov     rdi, r15
    mov     esi, [cur_size]
    syscall
    xor     eax, eax
    ret

.tshm_close_fail:
    mov     eax, SYS_CLOSE
    mov     rdi, r14
    syscall
.tshm_fail:
    xor     eax, eax
    ret

trans_file:
    mov     rsi, r12
    lea     rdi, [file_path_buf]
    mov     edx, 500
    call    decode_base64_string

    mov     eax, SYS_OPEN
    lea     rdi, [file_path_buf]
    xor     esi, esi
    xor     edx, edx
    syscall
    test    rax, rax
    js      .tf_fail
    mov     r14, rax

    mov     eax, SYS_FSTAT
    mov     rdi, r14
    lea     rsi, [stat_buf]
    syscall

    mov     r15, [stat_buf + 48]
    test    r15, r15
    jle     .tf_close_fail

    mov     eax, SYS_MMAP
    xor     edi, edi
    mov     rsi, r15
    mov     edx, PROT_READ
    mov     r10d, MAP_PRIVATE
    mov     r8, r14
    xor     r9d, r9d
    syscall
    test    rax, rax
    js      .tf_close_fail
    mov     r13, rax

    mov     eax, SYS_CLOSE
    mov     rdi, r14
    syscall

    mov     rdi, r13
    mov     rsi, r15
    lea     rdx, [cur_w]
    lea     rcx, [cur_h]
    call    png_decode

    push    rax
    mov     eax, SYS_MUNMAP
    mov     rdi, r13
    mov     rsi, r15
    syscall
    pop     r13

    test    r13, r13
    jz      .tf_fail

    mov     eax, [cur_w]
    imul    eax, [cur_h]
    shl     eax, 2
    mov     r14d, eax

    call    create_cur_placement
    mov     eax, 1
    ret

.tf_close_fail:
    mov     eax, SYS_CLOSE
    mov     rdi, r14
    syscall
.tf_fail:
    xor     eax, eax
    ret

trans_direct:
    cmp     byte [recv_in_progress], 0
    jnz     .have_alloc

    mov     eax, [cur_w]
    test    eax, eax
    jz      .td_fail
    mov     ecx, [cur_h]
    test    ecx, ecx
    jz      .td_fail

    imul    eax, ecx
    mov     [recv_pixel_cap], eax
    shl     eax, 2
    mov     [recv_data_size], eax

    mov     eax, SYS_MMAP
    xor     edi, edi
    mov     esi, [recv_data_size]
    mov     edx, PROT_READ | PROT_WRITE
    mov     r10d, MAP_PRIVATE | MAP_ANONYMOUS
    mov     r8d, -1
    xor     r9d, r9d
    syscall
    test    rax, rax
    js      .td_fail

    mov     [recv_data_ptr], rax
    mov     dword [recv_pixel_count], 0
    mov     dword [recv_fifo_cnt], 0
    mov     eax, [cur_w]
    mov     [recv_w], eax
    mov     eax, [cur_h]
    mov     [recv_h], eax
    mov     eax, [cur_cols]
    mov     [recv_cols], eax
    mov     eax, [cur_rows]
    mov     [recv_rows], eax
    mov     eax, [cur_id]
    mov     [recv_id], eax
    mov     eax, [cur_fmt]
    mov     [recv_fmt], eax
    mov     eax, [cur_action]
    mov     [recv_action], eax
    mov     eax, [term_cursor_col]
    mov     [recv_start_col], eax
    mov     eax, [term_cursor_row]
    mov     [recv_start_row], eax
    mov     eax, [cur_unicode]
    mov     [recv_unicode], eax
    mov     eax, [cur_cursor_policy]
    mov     [recv_cursor_policy], eax
    mov     byte [recv_in_progress], 1

.have_alloc:
    mov     rsi, r12
    call    decode_base64_stream

    cmp     dword [cur_more], 1
    je      .td_more

    mov     byte [recv_in_progress], 0

    cmp     dword [recv_action], 'T'
    je      .td_place
    cmp     dword [recv_unicode], 1
    je      .td_place
    jmp     .td_stored

.td_place:
    mov     eax, [recv_id]
    mov     [cur_id], eax
    mov     eax, [recv_w]
    mov     [cur_w], eax
    mov     eax, [recv_h]
    mov     [cur_h], eax
    mov     eax, [recv_cols]
    mov     [cur_cols], eax
    mov     eax, [recv_rows]
    mov     [cur_rows], eax
    mov     eax, [recv_unicode]
    mov     [cur_unicode], eax
    mov     eax, [recv_cursor_policy]
    mov     [cur_cursor_policy], eax
    mov     eax, [recv_action]
    mov     [cur_action], eax
    mov     eax, [recv_start_col]
    mov     [term_cursor_col], eax
    mov     eax, [recv_start_row]
    mov     [term_cursor_row], eax
    mov     r13, [recv_data_ptr]
    mov     r14d, [recv_data_size]
    call    create_cur_placement

.td_stored:
    mov     eax, 1
    ret

.td_more:
    xor     eax, eax
    ret

.td_fail:
    xor     eax, eax
    ret

kitty_gfx_apc_end:
    cmp     byte [apc_active], 0
    jz      .no_action
    cmp     byte [apc_is_kitty], 0
    jz      .no_action
    mov     byte [apc_active], 0

    mov     eax, [apc_len]
    mov     byte [apc_buf + rax], 0

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     dword [cur_action], 't'
    mov     dword [cur_fmt], 32
    mov     dword [cur_w], 0
    mov     dword [cur_h], 0
    mov     dword [cur_cols], 0
    mov     dword [cur_rows], 0
    mov     dword [cur_id], 0
    mov     dword [cur_more], 0
    mov     dword [cur_quiet], 0
    mov     dword [cur_del_type], 0
    mov     dword [cur_trans_type], 'd'
    mov     dword [cur_size], 0
    mov     dword [cur_cursor_policy], 0
    mov     dword [cur_unicode], 0

    lea     rsi, [apc_buf + 1]

.parse_kv:
    movzx   eax, byte [rsi]
    test    al, al
    jz      .kv_done
    cmp     al, ';'
    je      .kv_done
    cmp     byte [rsi + 1], '='
    jne     .skip_val

    movzx   ebx, al
    add     rsi, 2

    cmp     bl, 'a'
    je      .val_action
    cmp     bl, 'd'
    je      .val_del
    cmp     bl, 't'
    je      .val_trans
    jmp     .val_num

.val_action:
    movzx   eax, byte [rsi]
    mov     [cur_action], eax
    inc     rsi
    jmp     .skip_val

.val_del:
    movzx   eax, byte [rsi]
    mov     [cur_del_type], eax
    inc     rsi
    jmp     .skip_val

.val_trans:
    movzx   eax, byte [rsi]
    mov     [cur_trans_type], eax
    inc     rsi
    jmp     .skip_val

.val_num:
    xor     eax, eax
.num_loop:
    movzx   edx, byte [rsi]
    sub     edx, '0'
    cmp     edx, 9
    ja      .num_done
    imul    eax, 10
    add     eax, edx
    inc     rsi
    jmp     .num_loop
.num_done:
    cmp     bl, 'f'
    je      .set_fmt
    cmp     bl, 's'
    je      .set_w
    cmp     bl, 'v'
    je      .set_h
    cmp     bl, 'c'
    je      .set_cols
    cmp     bl, 'r'
    je      .set_rows
    cmp     bl, 'i'
    je      .set_id
    cmp     bl, 'm'
    je      .set_more
    cmp     bl, 'q'
    je      .set_quiet
    cmp     bl, 'S'
    je      .set_size
    cmp     bl, 'C'
    je      .set_cursor_policy
    cmp     bl, 'U'
    je      .set_unicode
    jmp     .skip_val

.set_fmt:
    mov     [cur_fmt], eax
    jmp     .skip_val
.set_w:
    mov     [cur_w], eax
    jmp     .skip_val
.set_h:
    mov     [cur_h], eax
    jmp     .skip_val
.set_cols:
    mov     [cur_cols], eax
    jmp     .skip_val
.set_rows:
    mov     [cur_rows], eax
    jmp     .skip_val
.set_id:
    mov     [cur_id], eax
    jmp     .skip_val
.set_more:
    mov     [cur_more], eax
    jmp     .skip_val
.set_quiet:
    mov     [cur_quiet], eax
    jmp     .skip_val
.set_size:
    mov     [cur_size], eax
    jmp     .skip_val
.set_cursor_policy:
    mov     [cur_cursor_policy], eax
    jmp     .skip_val
.set_unicode:
    mov     [cur_unicode], eax
    jmp     .skip_val

.skip_val:
    movzx   eax, byte [rsi]
    test    al, al
    jz      .kv_done
    cmp     al, ';'
    je      .kv_done
    cmp     al, ','
    je      .kv_next
    inc     rsi
    jmp     .skip_val

.kv_next:
    inc     rsi
    jmp     .parse_kv

.kv_done:
    cmp     byte [rsi], ';'
    jne     .payload_empty
    inc     rsi
    jmp     .dispatch
.payload_empty:
    xor     eax, eax
    lea     rsi, [resp_buf + 120]
    mov     byte [rsi], 0

.dispatch:
    mov     r12, rsi

    cmp     dword [cur_action], 'q'
    je      .call_query
    cmp     dword [cur_action], 'd'
    je      .call_delete
    cmp     dword [cur_action], 'p'
    je      .call_put
    cmp     dword [cur_action], 'T'
    je      .call_trans
    cmp     dword [cur_action], 't'
    je      .call_trans

    xor     eax, eax
    jmp     .ret

.call_query:
    call    do_query
    jmp     .ret

.call_delete:
    call    do_delete
    jmp     .ret

.call_put:
    call    do_put
    jmp     .ret

.call_trans:
    cmp     dword [cur_trans_type], 's'
    je      .trans_is_shm
    cmp     dword [cur_trans_type], 'f'
    je      .trans_is_file
    call    trans_direct
    jmp     .ret

.trans_is_shm:
    call    trans_shm
    jmp     .ret

.trans_is_file:
    call    trans_file
    jmp     .ret

.ret:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.no_action:
    xor     eax, eax
    ret

draw_current_image:
    push    rbp
    cmp     dword [cur_dst_w], 0
    jle     .dci_done
    cmp     dword [cur_dst_h], 0
    jle     .dci_done

    mov     eax, [cur_dst_x0]
    cmp     eax, [render_buf_w]
    jge     .dci_done
    mov     eax, [cur_dst_y0]
    cmp     eax, [render_buf_h]
    jge     .dci_done

    mov     eax, [cur_dst_x0]
    add     eax, [cur_dst_w]
    jle     .dci_done
    mov     eax, [cur_dst_y0]
    add     eax, [cur_dst_h]
    jle     .dci_done

    xor     r14d, r14d
    mov     eax, [cur_dst_y0]
    cmp     eax, 0
    jge     .dci_ymin_ok
    neg     eax
    mov     r14d, eax
.dci_ymin_ok:

.dci_y_loop:
    cmp     r14d, [cur_dst_h]
    jae     .dci_done

    mov     eax, [cur_dst_y0]
    add     eax, r14d
    cmp     eax, [render_buf_h]
    jae     .dci_done

    mov     eax, r14d
    imul    eax, [cur_img_h]
    xor     edx, edx
    div     dword [cur_dst_h]
    imul    eax, [cur_img_w]
    mov     rcx, [cur_img_data]
    lea     rcx, [rcx + rax*4]
    mov     [cur_src_row], rcx

    mov     eax, [cur_dst_y0]
    add     eax, r14d
    imul    eax, [render_buf_w]
    mov     rcx, [render_buf_ptr]
    lea     rcx, [rcx + rax*4]
    mov     [cur_dst_row], rcx

    xor     r15d, r15d
    mov     eax, [cur_dst_x0]
    cmp     eax, 0
    jge     .dci_xmin_ok
    neg     eax
    mov     r15d, eax
.dci_xmin_ok:

.dci_x_loop:
    cmp     r15d, [cur_dst_w]
    jae     .dci_x_done

    mov     eax, [cur_dst_x0]
    add     eax, r15d
    cmp     eax, [render_buf_w]
    jae     .dci_x_done
    mov     ebp, eax

    mov     eax, r15d
    imul    eax, [cur_img_w]
    xor     edx, edx
    div     dword [cur_dst_w]
    mov     rcx, [cur_src_row]
    mov     edx, [rcx + rax*4]

    mov     eax, edx
    shr     eax, 24
    test    eax, eax
    jz      .dci_skip_px
    cmp     eax, 255
    je      .dci_opaque

    movzx   r8d, al
    mov     rcx, [cur_dst_row]
    mov     r9d, [rcx + rbp*4]

    mov     eax, edx
    shr     eax, 16
    and     eax, 0xff
    imul    eax, r8d

    mov     ebx, r9d
    shr     ebx, 16
    and     ebx, 0xff
    mov     r10d, 255
    sub     r10d, r8d
    imul    ebx, r10d
    add     eax, ebx
    shr     eax, 8
    shl     eax, 16
    mov     r11d, eax

    mov     eax, edx
    shr     eax, 8
    and     eax, 0xff
    imul    eax, r8d

    mov     ebx, r9d
    shr     ebx, 8
    and     ebx, 0xff
    imul    ebx, r10d
    add     eax, ebx
    shr     eax, 8
    shl     eax, 8
    or      r11d, eax

    mov     eax, edx
    and     eax, 0xff
    imul    eax, r8d

    mov     ebx, r9d
    and     ebx, 0xff
    imul    ebx, r10d
    add     eax, ebx
    shr     eax, 8
    or      r11d, eax

    or      r11d, 0xff000000
    mov     [rcx + rbp*4], r11d
    jmp     .dci_skip_px

.dci_opaque:
    mov     rcx, [cur_dst_row]
    mov     [rcx + rbp*4], edx

.dci_skip_px:
    inc     r15d
    jmp     .dci_x_loop

.dci_x_done:
    inc     r14d
    jmp     .dci_y_loop

.dci_done:
    pop     rbp
    ret

kitty_gfx_render:
    cmp     byte [in_alt_screen], 0
    jnz     .r_alt_skip

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     [render_buf_ptr], rdi
    mov     [render_buf_w], esi
    mov     [render_buf_h], edx
    mov     [render_font_w], ecx
    mov     [render_font_h], r8d
    mov     [render_pad_x], r9d
    mov     eax, [rsp + 56]
    mov     [render_pad_y], eax

    xor     ebx, ebx
.r_place_loop:
    cmp     ebx, MAX_PLACEMENTS
    jae     .r_virtual_check

    mov     eax, ebx
    imul    eax, PLACE_SIZE
    lea     rax, [placements + rax]

    cmp     byte [rax + 44], 0
    jz      .r_next_place
    cmp     byte [rax + 45], 1
    je      .r_next_place

    mov     rcx, [rax + 8]
    mov     [cur_img_data], rcx
    mov     ecx, [rax + 20]
    mov     [cur_img_w], ecx
    mov     ecx, [rax + 24]
    mov     [cur_img_h], ecx

    mov     ecx, [rax + 28]
    imul    ecx, [render_font_w]
    add     ecx, [render_pad_x]
    mov     [cur_dst_x0], ecx

    mov     ecx, [rax + 32]
    imul    ecx, [render_font_h]
    add     ecx, [render_pad_y]
    mov     [cur_dst_y0], ecx

    mov     ecx, [rax + 36]
    imul    ecx, [render_font_w]
    mov     [cur_dst_w], ecx

    mov     ecx, [rax + 40]
    imul    ecx, [render_font_h]
    mov     [cur_dst_h], ecx

    call    draw_current_image

.r_next_place:
    inc     ebx
    jmp     .r_place_loop

.r_virtual_check:
    xor     ebx, ebx
.r_virt_loop:
    cmp     ebx, MAX_PLACEMENTS
    jae     .r_done

    mov     eax, ebx
    imul    eax, PLACE_SIZE
    lea     r12, [placements + rax]

    cmp     byte [r12 + 44], 0
    jz      .r_virt_next
    cmp     byte [r12 + 45], 1
    jne     .r_virt_next

    mov     edi, [r12]
    lea     rsi, [placeholder_bounds]
    call    term_find_placeholder_bounds
    test    eax, eax
    jz      .r_virt_next

    mov     eax, [placeholder_bounds]
    imul    eax, [render_font_w]
    add     eax, [render_pad_x]
    mov     [cur_dst_x0], eax

    mov     eax, [placeholder_bounds + 4]
    imul    eax, [render_font_h]
    add     eax, [render_pad_y]
    mov     [cur_dst_y0], eax

    mov     eax, [placeholder_bounds + 8]
    sub     eax, [placeholder_bounds]
    inc     eax
    imul    eax, [render_font_w]
    mov     [cur_dst_w], eax

    mov     eax, [placeholder_bounds + 12]
    sub     eax, [placeholder_bounds + 4]
    inc     eax
    imul    eax, [render_font_h]
    mov     [cur_dst_h], eax

    mov     rax, [r12 + 8]
    mov     [cur_img_data], rax
    mov     eax, [r12 + 20]
    mov     [cur_img_w], eax
    mov     eax, [r12 + 24]
    mov     [cur_img_h], eax

    call    draw_current_image

.r_virt_next:
    inc     ebx
    jmp     .r_virt_loop

.r_done:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.r_alt_skip:
    ret
