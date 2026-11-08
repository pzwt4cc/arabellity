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

quad_bytes:             resb 4
resp_buf:               resb 64

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
    mov     qword [r12 + 8], 0
.next:
    inc     ebx
    jmp     .loop
.done:
    pop     r13
    pop     r12
    pop     rbx
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

kitty_gfx_apc_end:
    cmp     byte [apc_active], 0
    jz      .no_action
    cmp     byte [apc_is_kitty], 0
    jz      .no_action
    mov     byte [apc_active], 0
    mov     byte [apc_is_kitty], 0
    mov     eax, [apc_len]
    mov     byte [apc_buf + rax], 0
    call    execute_kitty_command
    ret
.no_action:
    mov     byte [apc_active], 0
    mov     byte [apc_is_kitty], 0
    xor     eax, eax
    ret

execute_kitty_command:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     dword [cur_action], 'T'
    mov     dword [cur_fmt], 32
    mov     dword [cur_w], 0
    mov     dword [cur_h], 0
    mov     dword [cur_cols], 0
    mov     dword [cur_rows], 0
    mov     dword [cur_id], 0
    mov     dword [cur_more], 0
    mov     dword [cur_quiet], 0
    mov     dword [cur_del_type], 0
    mov     dword [cur_trans_type], 0

    lea     rsi, [apc_buf + 1]

.parse_kv:
    movzx   eax, byte [rsi]
    test    al, al
    jz      .kv_done
    cmp     al, ';'
    je      .kv_done
    cmp     al, ','
    je      .kv_next

    mov     bl, al
    inc     rsi
    cmp     byte [rsi], '='
    jne     .skip_val
    inc     rsi

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
    lea     rsi, [resp_buf + 60]
    mov     byte [rsi], 0

.dispatch:
    mov     r12, rsi

    cmp     dword [cur_action], 'q'
    je      .do_query
    cmp     dword [cur_action], 'd'
    je      .do_delete
    cmp     dword [cur_action], 'p'
    je      .do_put
    cmp     dword [cur_action], 'T'
    je      .do_transmit
    cmp     dword [cur_action], 't'
    je      .do_transmit

    xor     eax, eax
    jmp     .ret

.do_query:
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
    cmp     eax, 't'
    je      .query_enosys
    cmp     eax, 's'
    je      .query_enosys
    cmp     eax, 'f'
    je      .query_enosys

    mov     byte [rdi], ';'
    mov     byte [rdi + 1], 'O'
    mov     byte [rdi + 2], 'K'
    mov     byte [rdi + 3], 27
    mov     byte [rdi + 4], '\'
    add     rdi, 5
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
    mov     byte [rdi + 8], '\'
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
    jmp     .ret

.do_delete:
    cmp     dword [cur_del_type], 'a'
    je      .del_all
    cmp     dword [cur_del_type], 'i'
    je      .del_id
    xor     eax, eax
    jmp     .ret
.del_all:
    call    kitty_gfx_clear
    mov     eax, 1
    jmp     .ret
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
    mov     qword [r13 + 8], 0
.del_id_next:
    inc     ebx
    jmp     .del_id_loop
.del_id_done:
    mov     eax, 1
    jmp     .ret

.do_put:
    mov     r8d, [cur_id]
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
    mov     eax, [term_cursor_col]
    mov     [r13 + 28], eax
    mov     eax, [term_cursor_row]
    mov     [r13 + 32], eax
    mov     eax, 1
    jmp     .ret
.put_fail:
    xor     eax, eax
    jmp     .ret

.do_transmit:
    cmp     byte [recv_in_progress], 0
    jnz     .have_alloc

    mov     eax, [cur_w]
    test    eax, eax
    jz      .trans_fail
    mov     ecx, [cur_h]
    test    ecx, ecx
    jz      .trans_fail

    imul    eax, ecx
    mov     [recv_pixel_cap], eax
    shl     eax, 2
    mov     [recv_data_size], eax

    mov     eax, SYS_MMAP
    xor     edi, edi
    mov     esi, [recv_data_size]
    mov     edx, PROT_READ | PROT_WRITE
    mov     r10d, 0x22
    mov     r8d, -1
    xor     r9d, r9d
    syscall
    test    rax, rax
    js      .trans_fail

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
    mov     byte [recv_in_progress], 1

.have_alloc:
    mov     rsi, r12
    call    decode_base64_stream

    cmp     dword [cur_more], 1
    je      .trans_more

    mov     byte [recv_in_progress], 0

    cmp     dword [recv_action], 'T'
    jne     .trans_stored

    call    alloc_placement_slot
    mov     r13, rax

    mov     eax, [recv_id]
    mov     [r13], eax
    mov     rax, [recv_data_ptr]
    mov     [r13 + 8], rax
    mov     eax, [recv_data_size]
    mov     [r13 + 16], eax
    mov     eax, [recv_w]
    mov     [r13 + 20], eax
    mov     eax, [recv_h]
    mov     [r13 + 24], eax
    mov     eax, [recv_start_col]
    mov     [r13 + 28], eax
    mov     eax, [recv_start_row]
    mov     [r13 + 32], eax

    mov     eax, [recv_cols]
    test    eax, eax
    jnz     .cols_ok
    mov     eax, [recv_w]
    add     eax, 9
    xor     edx, edx
    mov     ecx, 10
    div     ecx
.cols_ok:
    mov     [r13 + 36], eax

    mov     eax, [recv_rows]
    test    eax, eax
    jnz     .rows_ok
    mov     eax, [recv_h]
    add     eax, 19
    xor     edx, edx
    mov     ecx, 20
    div     ecx
.rows_ok:
    mov     [r13 + 40], eax
    mov     byte [r13 + 44], 1
    inc     dword [placement_count]

    mov     ecx, [r13 + 40]
    add     [term_cursor_row], ecx
    mov     dword [term_cursor_col], 0
.cursor_scroll_check:
    mov     eax, [term_cursor_row]
    mov     ecx, [term_rows]
    dec     ecx
    cmp     eax, ecx
    jle     .cursor_ok
    push    r13
    call    term_scroll_up
    pop     r13
    dec     dword [term_cursor_row]
    jmp     .cursor_scroll_check
.cursor_ok:

    mov     eax, 1
    jmp     .ret

.trans_stored:
    mov     eax, 1
    jmp     .ret

.trans_more:
    xor     eax, eax
    jmp     .ret

.trans_fail:
    xor     eax, eax
.ret:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

alloc_placement_slot:
    xor     eax, eax
.find_loop:
    cmp     eax, MAX_PLACEMENTS
    jae     .find_fallback
    mov     edx, eax
    imul    edx, PLACE_SIZE
    lea     rcx, [placements + rdx]
    cmp     byte [rcx + 44], 0
    jz      .found
    inc     eax
    jmp     .find_loop
.find_fallback:
    lea     rcx, [placements]
    mov     rdi, [rcx + 8]
    test    rdi, rdi
    jz      .found
    mov     esi, [rcx + 16]
    test    esi, esi
    jz      .found
    push    rcx
    mov     eax, SYS_MUNMAP
    syscall
    pop     rcx
.found:
    mov     rax, rcx
    ret

format_num:
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

decode_base64_stream:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rsi

.read_quad:
    xor     ecx, ecx
.get_char:
    movzx   eax, byte [r12]
    test    al, al
    jz      .stream_end
    inc     r12
    lea     rdx, [b64_table]
    movzx   edx, byte [rdx + rax]
    cmp     dl, 0xfd
    je      .get_char
    cmp     dl, 0xff
    je      .get_char
    mov     [quad_bytes + rcx], dl
    inc     ecx
    cmp     ecx, 4
    jb      .get_char

    movzx   r8d, byte [quad_bytes]
    movzx   r9d, byte [quad_bytes + 1]
    movzx   r10d, byte [quad_bytes + 2]
    movzx   r11d, byte [quad_bytes + 3]

    cmp     r10d, 0xfe
    je      .emit_1
    cmp     r11d, 0xfe
    je      .emit_2

    mov     eax, r8d
    shl     eax, 2
    mov     edx, r9d
    shr     edx, 4
    or      eax, edx
    call    push_fifo_byte

    mov     eax, r9d
    and     eax, 0x0f
    shl     eax, 4
    mov     edx, r10d
    shr     edx, 2
    or      eax, edx
    call    push_fifo_byte

    mov     eax, r10d
    and     eax, 0x03
    shl     eax, 6
    or      eax, r11d
    call    push_fifo_byte
    jmp     .drain_fifo

.emit_1:
    mov     eax, r8d
    shl     eax, 2
    mov     edx, r9d
    shr     edx, 4
    or      eax, edx
    call    push_fifo_byte
    jmp     .drain_fifo

.emit_2:
    mov     eax, r8d
    shl     eax, 2
    mov     edx, r9d
    shr     edx, 4
    or      eax, edx
    call    push_fifo_byte

    mov     eax, r9d
    and     eax, 0x0f
    shl     eax, 4
    mov     edx, r10d
    shr     edx, 2
    or      eax, edx
    call    push_fifo_byte

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

kitty_gfx_render:
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
    jae     .r_done

    mov     eax, ebx
    imul    eax, PLACE_SIZE
    lea     rax, [placements + rax]

    cmp     byte [rax + 44], 0
    jz      .r_next_place

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

    cmp     dword [cur_dst_w], 0
    jle     .r_next_place
    cmp     dword [cur_dst_h], 0
    jle     .r_next_place

    mov     eax, [cur_dst_x0]
    cmp     eax, [render_buf_w]
    jge     .r_next_place
    mov     eax, [cur_dst_y0]
    cmp     eax, [render_buf_h]
    jge     .r_next_place

    mov     eax, [cur_dst_x0]
    add     eax, [cur_dst_w]
    jle     .r_next_place
    mov     eax, [cur_dst_y0]
    add     eax, [cur_dst_h]
    jle     .r_next_place

    xor     r14d, r14d
    mov     eax, [cur_dst_y0]
    cmp     eax, 0
    jge     .y_min_ok
    neg     eax
    mov     r14d, eax
.y_min_ok:

.draw_y_loop:
    cmp     r14d, [cur_dst_h]
    jae     .r_next_place

    mov     eax, [cur_dst_y0]
    add     eax, r14d
    cmp     eax, [render_buf_h]
    jae     .r_next_place

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
    jge     .x_min_ok
    neg     eax
    mov     r15d, eax
.x_min_ok:

.draw_x_loop:
    cmp     r15d, [cur_dst_w]
    jae     .draw_x_done

    mov     eax, [cur_dst_x0]
    add     eax, r15d
    cmp     eax, [render_buf_w]
    jae     .draw_x_done

    mov     eax, r15d
    imul    eax, [cur_img_w]
    xor     edx, edx
    div     dword [cur_dst_w]

    mov     rcx, [cur_src_row]
    mov     esi, [rcx + rax*4]

    mov     edx, esi
    shr     edx, 24
    test    dl, dl
    jz      .px_next

    mov     eax, [cur_dst_x0]
    add     eax, r15d
    mov     rcx, [cur_dst_row]
    lea     rcx, [rcx + rax*4]

    cmp     dl, 255
    je      .px_opaque

    mov     eax, [rcx]

    movzx   r10d, dl
    mov     r11d, 255
    sub     r11d, r10d

    movzx   r8d, sil
    imul    r8d, r10d
    movzx   r9d, al
    imul    r9d, r11d
    add     r8d, r9d
    shr     r8d, 8

    mov     edx, esi
    shr     edx, 8
    movzx   r9d, dl
    imul    r9d, r10d
    mov     edx, eax
    shr     edx, 8
    movzx   r12d, dl
    imul    r12d, r11d
    add     r9d, r12d
    shr     r9d, 8

    mov     edx, esi
    shr     edx, 16
    movzx   r12d, dl
    imul    r12d, r10d
    mov     edx, eax
    shr     edx, 16
    movzx   edx, dl
    imul    edx, r11d
    add     edx, r12d
    shr     edx, 8

    shl     edx, 16
    shl     r9d, 8
    or      edx, r9d
    or      edx, r8d
    or      edx, 0xff000000
    mov     [rcx], edx
    jmp     .px_next

.px_opaque:
    mov     [rcx], esi

.px_next:
    inc     r15d
    jmp     .draw_x_loop

.draw_x_done:
    inc     r14d
    jmp     .draw_y_loop

.r_next_place:
    inc     ebx
    jmp     .r_place_loop

.r_done:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
