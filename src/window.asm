default rel
%include "syscalls.inc"
%include "wl.inc"

global win_init
global win_update
global win_redraw
global on_event
global close_requested
global win_pty_fd

extern wl_connect
extern wl_new_id
extern wl_begin
extern wl_u32
extern wl_str
extern wl_end
extern wl_flush
extern wl_flush_fd
extern wl_read
extern streq
extern write_all
extern term_init
extern term_resize
extern term_render
extern term_cols
extern term_rows
extern kbd_handle_key
extern kbd_handle_modifiers
extern kbd_input_buf
extern kbd_input_len

%define DEFAULT_W       800
%define DEFAULT_H       500
%define PAD_X           8
%define PAD_Y           8
%define FONT_W          10
%define FONT_H          20

section .rodata
s_compositor:   db "wl_compositor", 0
s_shm:          db "wl_shm", 0
s_wm_base:      db "xdg_wm_base", 0
s_seat:         db "wl_seat", 0
s_title:        db APP_NAME, 0
err_wl:         db APP_NAME, ": wayland: "
err_wl_len      equ $ - err_wl
nl:             db 10

section .data
win_w:          dd DEFAULT_W
win_h:          dd DEFAULT_H
win_pty_fd:     dd -1

section .bss
id_registry:        resd 1
id_callback:        resd 1
id_compositor:      resd 1
id_shm:             resd 1
id_wm_base:         resd 1
id_seat:            resd 1
id_keyboard:        resd 1
id_surface:         resd 1
id_xdg_surface:     resd 1
id_toplevel:        resd 1
id_buffer:          resd 1
configure_serial:   resd 1
buf_w:              resd 1
buf_h:              resd 1
buf_ptr:            resq 1
buf_size:           resq 1
sync_done:          resb 1
configure_pending:  resb 1
close_requested:    resb 1
winsize_struct:     resw 4

section .text

win_init:
    push    rbx
    push    r12
    mov     r12, rdi
    call    term_init

    mov     rdi, r12
    call    wl_connect
    test    rax, rax
    js      .ret
    mov     rbx, rax

    call    wl_new_id
    mov     [id_registry], eax
    WL_BEGIN WL_DISPLAY_ID, WL_DISPLAY_GET_REGISTRY
    WL_U32  [id_registry]
    WL_END

    call    roundtrip
    test    eax, eax
    js      .fail
    cmp     dword [id_compositor], 0
    je      .fail
    cmp     dword [id_shm], 0
    je      .fail
    cmp     dword [id_wm_base], 0
    je      .fail

    call    wl_new_id
    mov     [id_surface], eax
    WL_BEGIN [id_compositor], WL_COMPOSITOR_CREATE_SURFACE
    WL_U32  [id_surface]
    WL_END

    call    wl_new_id
    mov     [id_xdg_surface], eax
    WL_BEGIN [id_wm_base], XDG_WM_BASE_GET_XDG_SURFACE
    WL_U32  [id_xdg_surface]
    WL_U32  [id_surface]
    WL_END

    call    wl_new_id
    mov     [id_toplevel], eax
    WL_BEGIN [id_xdg_surface], XDG_SURFACE_GET_TOPLEVEL
    WL_U32  [id_toplevel]
    WL_END

    WL_BEGIN [id_toplevel], XDG_TOPLEVEL_SET_TITLE
    WL_STR  s_title
    WL_END

    WL_BEGIN [id_toplevel], XDG_TOPLEVEL_SET_APP_ID
    WL_STR  s_title
    WL_END

    WL_BEGIN [id_surface], WL_SURFACE_COMMIT
    WL_END

    call    wl_flush
    mov     rax, rbx
.ret:
    pop     r12
    pop     rbx
    ret
.fail:
    mov     rax, -1
    jmp     .ret

roundtrip:
    call    wl_new_id
    mov     [id_callback], eax
    mov     byte [sync_done], 0
    WL_BEGIN WL_DISPLAY_ID, WL_DISPLAY_SYNC
    WL_U32  [id_callback]
    WL_END
    call    wl_flush
.loop:
    cmp     byte [sync_done], 0
    jne     .ok
    cmp     byte [close_requested], 0
    jne     .err
    call    wl_read
    test    rax, rax
    jle     .err
    jmp     .loop
.ok:
    xor     eax, eax
    ret
.err:
    mov     eax, -1
    ret

win_update:
    cmp     byte [configure_pending], 0
    je      .flush
    mov     byte [configure_pending], 0

    WL_BEGIN [id_xdg_surface], XDG_SURFACE_ACK_CONFIGURE
    WL_U32  [configure_serial]
    WL_END

    mov     eax, [win_w]
    cmp     eax, [buf_w]
    jne     .resize
    mov     eax, [win_h]
    cmp     eax, [buf_h]
    je      .present
.resize:
    call    buffer_create
    test    rax, rax
    js      .fail

    mov     eax, [buf_w]
    sub     eax, PAD_X * 2
    xor     edx, edx
    mov     ecx, FONT_W
    div     ecx
    mov     edi, eax

    mov     eax, [buf_h]
    sub     eax, PAD_Y * 2
    xor     edx, edx
    mov     ecx, FONT_H
    div     ecx
    mov     esi, eax

    call    term_resize
    call    update_pty_winsize

.present:
    call    win_redraw
.flush:
    jmp     wl_flush
.fail:
    mov     byte [close_requested], 1
    ret

update_pty_winsize:
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .ret
    mov     eax, [term_rows]
    mov     [winsize_struct], ax
    mov     eax, [term_cols]
    mov     [winsize_struct + 2], ax
    mov     eax, [buf_w]
    mov     [winsize_struct + 4], ax
    mov     eax, [buf_h]
    mov     [winsize_struct + 6], ax
    mov     eax, SYS_IOCTL
    mov     esi, TIOCSWINSZ
    lea     rdx, [winsize_struct]
    syscall
.ret:
    ret

win_redraw:
    cmp     qword [buf_ptr], 0
    je      .ret

    mov     rdi, [buf_ptr]
    mov     esi, [buf_w]
    mov     edx, [buf_h]
    call    term_render

    WL_BEGIN [id_surface], WL_SURFACE_ATTACH
    WL_U32  [id_buffer]
    WL_U32  0
    WL_U32  0
    WL_END

    WL_BEGIN [id_surface], WL_SURFACE_DAMAGE
    WL_U32  0
    WL_U32  0
    WL_U32  [buf_w]
    WL_U32  [buf_h]
    WL_END

    WL_BEGIN [id_surface], WL_SURFACE_COMMIT
    WL_END
    call    wl_flush
.ret:
    ret

buffer_create:
    push    rbx
    push    r12
    cmp     dword [id_buffer], 0
    je      .new
    WL_BEGIN [id_buffer], WL_BUFFER_DESTROY
    WL_END
    mov     eax, SYS_MUNMAP
    mov     rdi, [buf_ptr]
    mov     rsi, [buf_size]
    syscall
.new:
    mov     eax, [win_w]
    mov     [buf_w], eax
    mov     ecx, [win_h]
    mov     [buf_h], ecx
    shl     eax, 2
    imul    rax, rcx
    mov     [buf_size], rax

    mov     eax, SYS_MEMFD_CREATE
    lea     rdi, [s_title]
    mov     esi, MFD_CLOEXEC
    syscall
    test    rax, rax
    js      .ret
    mov     rbx, rax

    mov     eax, SYS_FTRUNCATE
    mov     rdi, rbx
    mov     rsi, [buf_size]
    syscall
    test    rax, rax
    js      .close_fail

    mov     eax, SYS_MMAP
    xor     edi, edi
    mov     rsi, [buf_size]
    mov     edx, PROT_READ | PROT_WRITE
    mov     r10d, MAP_SHARED
    mov     r8, rbx
    xor     r9d, r9d
    syscall
    cmp     rax, -4096
    ja      .close_fail
    mov     [buf_ptr], rax

    call    wl_new_id
    mov     r12d, eax
    WL_BEGIN [id_shm], WL_SHM_CREATE_POOL
    WL_U32  r12d
    WL_U32  [buf_size]
    WL_END
    mov     edi, ebx
    call    wl_flush_fd

    call    wl_new_id
    mov     [id_buffer], eax
    WL_BEGIN r12d, WL_SHM_POOL_CREATE_BUFFER
    WL_U32  [id_buffer]
    WL_U32  0
    WL_U32  [buf_w]
    WL_U32  [buf_h]
    mov     edi, [buf_w]
    shl     edi, 2
    call    wl_u32
    WL_U32  WL_SHM_FORMAT_XRGB8888
    WL_END

    WL_BEGIN r12d, WL_SHM_POOL_DESTROY
    WL_END

    mov     eax, SYS_CLOSE
    mov     rdi, rbx
    syscall
    xor     eax, eax
.ret:
    pop     r12
    pop     rbx
    ret
.close_fail:
    mov     eax, SYS_CLOSE
    mov     rdi, rbx
    syscall
    mov     rax, -1
    jmp     .ret

on_event:
    cmp     edi, WL_DISPLAY_ID
    je      .display
    cmp     edi, [id_registry]
    je      .registry
    cmp     edi, [id_callback]
    je      .callback
    cmp     edi, [id_wm_base]
    je      .wm_base
    cmp     edi, [id_xdg_surface]
    je      .xdg_surface
    cmp     edi, [id_toplevel]
    je      .toplevel
    cmp     edi, [id_seat]
    je      .seat
    cmp     edi, [id_keyboard]
    je      .keyboard
    ret

.display:
    cmp     esi, WL_DISPLAY_ERROR
    jne     .ret
    push    rdx
    mov     edi, STDERR
    lea     rsi, [err_wl]
    mov     edx, err_wl_len
    call    write_all
    pop     rax
    mov     edx, [rax + 8]
    dec     edx
    lea     rsi, [rax + 12]
    mov     edi, STDERR
    call    write_all
    mov     edi, STDERR
    lea     rsi, [nl]
    mov     edx, 1
    call    write_all
    mov     byte [close_requested], 1
    ret

.callback:
    cmp     esi, WL_CALLBACK_DONE
    jne     .ret
    mov     byte [sync_done], 1
    ret

.wm_base:
    cmp     esi, XDG_WM_BASE_PING
    jne     .ret
    mov     eax, [rdx]
    push    rax
    WL_BEGIN [id_wm_base], XDG_WM_BASE_PONG
    pop     rdi
    call    wl_u32
    WL_END
    ret

.xdg_surface:
    cmp     esi, XDG_SURFACE_CONFIGURE
    jne     .ret
    mov     eax, [rdx]
    mov     [configure_serial], eax
    mov     byte [configure_pending], 1
    ret

.toplevel:
    cmp     esi, XDG_TOPLEVEL_CLOSE
    je      .close
    cmp     esi, XDG_TOPLEVEL_CONFIGURE
    jne     .ret
    mov     eax, [rdx]
    test    eax, eax
    jle     .h
    mov     [win_w], eax
.h:
    mov     eax, [rdx + 4]
    test    eax, eax
    jle     .ret
    mov     [win_h], eax
    ret
.close:
    mov     byte [close_requested], 1
    ret

.seat:
    cmp     esi, WL_SEAT_CAPABILITIES
    jne     .ret
    mov     eax, [rdx]
    test    eax, WL_SEAT_CAP_KEYBOARD
    jz      .ret
    cmp     dword [id_keyboard], 0
    jne     .ret
    call    wl_new_id
    mov     [id_keyboard], eax
    WL_BEGIN [id_seat], WL_SEAT_GET_KEYBOARD
    WL_U32  [id_keyboard]
    WL_END
    ret

.keyboard:
    cmp     esi, WL_KEYBOARD_KEY
    je      .kbd_key
    cmp     esi, WL_KEYBOARD_MODIFIERS
    je      .kbd_mod
    ret

.kbd_key:
    mov     edi, [rdx + 8]
    mov     esi, [rdx + 12]
    call    kbd_handle_key

    mov     edx, [kbd_input_len]
    test    edx, edx
    jz      .ret
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .ret
    lea     rsi, [kbd_input_buf]
    call    write_all
    ret

.kbd_mod:
    mov     edi, [rdx + 4]
    mov     esi, [rdx + 8]
    mov     r8d, [rdx + 12]
    mov     ecx, [rdx + 16]
    mov     edx, r8d
    call    kbd_handle_modifiers
    ret

.registry:
    cmp     esi, WL_REGISTRY_GLOBAL
    jne     .ret
    push    rbx
    push    r12
    push    r13
    mov     r12d, [rdx]
    lea     rbx, [rdx + 8]
    mov     eax, [rdx + 4]
    add     eax, 3
    and     eax, ~3
    mov     r13d, [rbx + rax]

    mov     rdi, rbx
    lea     rsi, [s_compositor]
    call    streq
    test    eax, eax
    jz      .not_compositor
    mov     ecx, 4
    lea     r8, [s_compositor]
    lea     r9, [id_compositor]
    jmp     .bind

.not_compositor:
    mov     rdi, rbx
    lea     rsi, [s_shm]
    call    streq
    test    eax, eax
    jz      .not_shm
    mov     ecx, 1
    lea     r8, [s_shm]
    lea     r9, [id_shm]
    jmp     .bind

.not_shm:
    mov     rdi, rbx
    lea     rsi, [s_wm_base]
    call    streq
    test    eax, eax
    jz      .not_wm_base
    mov     ecx, 1
    lea     r8, [s_wm_base]
    lea     r9, [id_wm_base]
    jmp     .bind

.not_wm_base:
    mov     rdi, rbx
    lea     rsi, [s_seat]
    call    streq
    test    eax, eax
    jz      .registry_done
    mov     ecx, 7
    lea     r8, [s_seat]
    lea     r9, [id_seat]

.bind:
    cmp     r13d, ecx
    cmova   r13d, ecx
    call    wl_new_id
    mov     [r9], eax
    push    rax
    push    r8
    WL_BEGIN [id_registry], WL_REGISTRY_BIND
    WL_U32  r12d
    pop     rdi
    call    wl_str
    WL_U32  r13d
    pop     rdi
    call    wl_u32
    WL_END

.registry_done:
    pop     r13
    pop     r12
    pop     rbx
.ret:
    ret
