default rel
%include "syscalls.inc"
%include "wl.inc"

global win_init
global win_update
global win_redraw
global win_handle_repeat
global on_event
global close_requested
global win_pty_fd
global win_envp
global repeat_timer_fd
global repeat_delay
global repeat_rate
global win_w
global win_h
global update_pty_winsize

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
extern config_load
extern cfg_pad_x
extern cfg_pad_y
extern cfg_scroll_lines
extern term_init
extern term_resize
extern term_render
extern term_feed
extern term_cols
extern term_rows
extern term_scroll_view_up
extern term_scroll_view_down
extern term_scroll_view_to_bottom
extern term_set_sel_start
extern term_update_sel_end
extern term_clear_sel
extern term_copy_selection
extern term_sel_start_col
extern term_sel_start_row
extern term_sel_end_col
extern term_sel_end_row
extern kbd_handle_key
extern kbd_handle_modifiers
extern kbd_get_modifiers
extern term_find_url_at
extern term_clear_sel
extern term_clear_hover
extern url_hover_active
extern font_w
extern font_h
extern term_zoom_in
extern term_zoom_out
extern term_zoom_reset
extern kbd_is_modifier
extern kbd_input_buf
extern kbd_input_len
extern kbd_action
extern clip_copy_system
extern clip_paste_system

%define DEFAULT_W       800
%define DEFAULT_H       500
%define PAD_X           8
%define PAD_Y           8


section .rodata
s_compositor:   db "wl_compositor", 0
s_shm:          db "wl_shm", 0
s_wm_base:      db "xdg_wm_base", 0
s_seat:         db "wl_seat", 0
s_title:        db APP_NAME, 0
err_wl:         db APP_NAME, ": wayland: "
err_wl_len      equ $ - err_wl
nl:             db 10
s_dev_null:     db "/dev/null", 0
s_xdg_open_cmd: db "xdg-open", 0
s_xdg_open_usr: db "/usr/bin/xdg-open", 0
s_xdg_open_bin: db "/bin/xdg-open", 0
s_cursor_shape_mgr: db "wp_cursor_shape_manager_v1", 0

section .data
win_w:          dd DEFAULT_W
win_h:          dd DEFAULT_H
win_pty_fd:     dd -1
win_envp:       dq 0
repeat_timer_fd: dd -1
repeat_rate:    dd 35
repeat_delay:   dd 280
repeat_key:     dd -1

section .bss
id_registry:        resd 1
id_callback:        resd 1
id_compositor:      resd 1
id_shm:             resd 1
id_wm_base:         resd 1
id_seat:            resd 1
id_keyboard:        resd 1
id_pointer:         resd 1
mouse_x:            resd 1
mouse_y:            resd 1
mouse_pressed:      resb 1
id_surface:         resd 1
id_xdg_surface:     resd 1
id_toplevel:        resd 1
id_buffer:          resd 1
id_buffer2:         resd 1
configure_serial:   resd 1
buf_w:              resd 1
buf_h:              resd 1
buf_ptr:            resq 1
frame_size:         resq 1
buf_size:           resq 1
cur_buf:            resb 1
sync_done:          resb 1
configure_pending:  resb 1
close_requested:    resb 1
winsize_struct:     resw 4
itimerspec:         resq 4
timer_exp:          resq 1
url_argv:           resq 3
click_url_buf:      resb 1024
id_cursor_shape_mgr: resd 1
id_cursor_shape_device: resd 1
pointer_enter_serial: resd 1
cur_cursor_shape:   resd 1

section .text

win_init:
    push    rbx
    push    r12
    mov     r12, rdi
    mov     [win_envp], rdi
    mov     dword [id_pointer], 0
    mov     dword [id_cursor_shape_mgr], 0
    mov     dword [id_cursor_shape_device], 0
    mov     dword [pointer_enter_serial], 0
    mov     dword [cur_cursor_shape], 0
    mov     byte [mouse_pressed], 0
    mov     dword [repeat_key], -1
    mov     rdi, r12
    call    config_load
    call    term_init

    mov     eax, SYS_TIMERFD_CREATE
    mov     edi, CLOCK_MONOTONIC
    mov     esi, TFD_CLOEXEC | TFD_NONBLOCK
    syscall
    test    rax, rax
    js      .no_timer
    mov     [repeat_timer_fd], eax
.no_timer:

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

.wait_configure:
    cmp     byte [configure_pending], 0
    jne     .configured
    cmp     byte [close_requested], 0
    jne     .fail
    call    wl_read
    test    rax, rax
    jle     .fail
    jmp     .wait_configure

.configured:
    call    win_update

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
    mov     ecx, [cfg_pad_x]
    shl     ecx, 1
    sub     eax, ecx
    jns     .w_pos
    xor     eax, eax
.w_pos:
    xor     edx, edx
    mov     ecx, [font_w]
    div     ecx
    test    eax, eax
    jnz     .w_nz
    mov     eax, 1
.w_nz:
    cmp     eax, 256
    jbe     .w_max
    mov     eax, 256
.w_max:
    mov     r8d, eax

    mov     eax, [buf_h]
    mov     ecx, [cfg_pad_y]
    shl     ecx, 1
    sub     eax, ecx
    jns     .h_pos
    xor     eax, eax
.h_pos:
    xor     edx, edx
    mov     ecx, [font_h]
    div     ecx
    test    eax, eax
    jnz     .h_nz
    mov     eax, 1
.h_nz:
    cmp     eax, 128
    jbe     .h_max
    mov     eax, 128
.h_max:
    mov     r9d, eax

    cmp     r8d, [term_cols]
    jne     .do_term_resize
    cmp     r9d, [term_rows]
    je      .present

.do_term_resize:
    push    r8
    push    r9
    xor     edi, edi
    call    drain_pty_sync
    pop     rsi
    pop     rdi
    call    term_resize
    call    update_pty_winsize
    mov     edi, 8
    call    drain_pty_sync

.present:
    call    win_redraw
.flush:
    jmp     wl_flush
.fail:
    mov     byte [close_requested], 1
    ret

drain_pty_sync:
    cmp     dword [win_pty_fd], 0
    jl      .ret
    push    rbx
    sub     rsp, 4112
    mov     ebx, edi
.poll_loop:
    mov     eax, [win_pty_fd]
    mov     [rsp], eax
    mov     word [rsp + 4], POLLIN
    mov     word [rsp + 6], 0
    mov     eax, SYS_POLL
    mov     rdi, rsp
    mov     esi, 1
    mov     edx, ebx
    syscall
    test    rax, rax
    jle     .done
    test    word [rsp + 6], POLLIN
    jz      .done
    mov     eax, SYS_READ
    mov     edi, [win_pty_fd]
    lea     rsi, [rsp + 16]
    mov     edx, 4096
    syscall
    test    rax, rax
    jle     .done
    lea     rdi, [rsp + 16]
    mov     rsi, rax
    call    term_feed
    mov     ebx, 1
    jmp     .poll_loop
.done:
    add     rsp, 4112
    pop     rbx
.ret:
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
    test    eax, eax
    jnz     .w_ok
    mov     eax, [term_cols]
    imul    eax, [font_w]
.w_ok:
    mov     [winsize_struct + 4], ax
    mov     eax, [buf_h]
    test    eax, eax
    jnz     .h_ok
    mov     eax, [term_rows]
    imul    eax, [font_h]
.h_ok:
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
    push    rbx

    mov     rdi, [buf_ptr]
    mov     ebx, [id_buffer]
    cmp     byte [cur_buf], 0
    je      .buf0
    add     rdi, [frame_size]
    mov     ebx, [id_buffer2]
    mov     byte [cur_buf], 0
    jmp     .do_render
.buf0:
    mov     byte [cur_buf], 1
.do_render:
    mov     esi, [buf_w]
    mov     edx, [buf_h]
    call    term_render

    WL_BEGIN [id_surface], WL_SURFACE_ATTACH
    WL_U32  ebx
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
    pop     rbx
.ret:
    ret

buffer_create:
    push    rbx
    push    r12
    cmp     dword [id_buffer], 0
    je      .new
    WL_BEGIN [id_buffer], WL_BUFFER_DESTROY
    WL_END
    WL_BEGIN [id_buffer2], WL_BUFFER_DESTROY
    WL_END
    mov     eax, SYS_MUNMAP
    mov     rdi, [buf_ptr]
    mov     rsi, [buf_size]
    syscall
.new:
    mov     byte [cur_buf], 0
    mov     eax, [win_w]
    mov     [buf_w], eax
    mov     ecx, [win_h]
    mov     [buf_h], ecx
    shl     eax, 2
    imul    rax, rcx
    mov     [frame_size], rax
    shl     rax, 1
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
    WL_U32  WL_SHM_FORMAT_ARGB8888
    WL_END

    call    wl_new_id
    mov     [id_buffer2], eax
    WL_BEGIN r12d, WL_SHM_POOL_CREATE_BUFFER
    WL_U32  [id_buffer2]
    WL_U32  [frame_size]
    WL_U32  [buf_w]
    WL_U32  [buf_h]
    mov     edi, [buf_w]
    shl     edi, 2
    call    wl_u32
    WL_U32  WL_SHM_FORMAT_ARGB8888
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

arm_repeat_timer:
    mov     edi, [repeat_timer_fd]
    test    edi, edi
    js      .ret
    mov     eax, [repeat_rate]
    test    eax, eax
    jle     .disarm

    mov     ecx, eax
    mov     eax, 1000000000
    xor     edx, edx
    div     ecx
    xor     ecx, ecx
    cmp     eax, 1000000000
    jb      .int_ok
    mov     ecx, 1
    xor     eax, eax
.int_ok:
    mov     [itimerspec], rcx
    mov     [itimerspec + 8], rax

    mov     eax, [repeat_delay]
    test    eax, eax
    jle     .disarm
    xor     edx, edx
    mov     ecx, 1000
    div     ecx
    mov     [itimerspec + 16], rax
    imul    edx, 1000000
    mov     [itimerspec + 24], rdx

    mov     eax, SYS_TIMERFD_SETTIME
    mov     edi, [repeat_timer_fd]
    xor     esi, esi
    lea     rdx, [itimerspec]
    xor     r10d, r10d
    syscall
.ret:
    ret
.disarm:
    jmp     disarm_repeat_timer

disarm_repeat_timer:
    mov     dword [repeat_key], -1
    mov     edi, [repeat_timer_fd]
    test    edi, edi
    js      .ret
    xor     eax, eax
    mov     [itimerspec], rax
    mov     [itimerspec + 8], rax
    mov     [itimerspec + 16], rax
    mov     [itimerspec + 24], rax
    mov     eax, SYS_TIMERFD_SETTIME
    xor     esi, esi
    lea     rdx, [itimerspec]
    xor     r10d, r10d
    syscall
.ret:
    ret

win_handle_repeat:
    mov     edi, [repeat_timer_fd]
    test    edi, edi
    js      .ret
    mov     eax, SYS_READ
    lea     rsi, [timer_exp]
    mov     edx, 8
    syscall
    test    rax, rax
    jle     .ret

    mov     edi, [repeat_key]
    test    edi, edi
    js      .ret
    mov     esi, 1
    call    process_key_dispatch
.ret:
    ret

process_key_dispatch:
    call    kbd_handle_key

    cmp     dword [kbd_action], 0
    je      .check_kbd_input
    cmp     dword [kbd_action], 2
    je      .zoom_in
    cmp     dword [kbd_action], 3
    je      .zoom_out
    cmp     dword [kbd_action], 4
    je      .zoom_reset
    call    win_redraw
    ret

.zoom_in:
    call    term_zoom_in
    test    eax, eax
    jz      .ret
    call    win_apply_zoom
    ret

.zoom_out:
    call    term_zoom_out
    test    eax, eax
    jz      .ret
    call    win_apply_zoom
    ret

.zoom_reset:
    call    term_zoom_reset
    call    win_apply_zoom
    ret

.check_kbd_input:
    mov     edx, [kbd_input_len]
    test    edx, edx
    jz      .ret
    call    term_scroll_view_to_bottom
    mov     edx, [kbd_input_len]
    mov     edi, [win_pty_fd]
    test    edi, edi
    js      .ret
    lea     rsi, [kbd_input_buf]
    call    write_all
.ret:
    ret

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
    cmp     edi, [id_pointer]
    je      .pointer
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
    mov     r10d, [rdx]
    test    r10d, WL_SEAT_CAP_KEYBOARD
    jz      .check_ptr
    cmp     dword [id_keyboard], 0
    jne     .check_ptr
    call    wl_new_id
    mov     [id_keyboard], eax
    WL_BEGIN [id_seat], WL_SEAT_GET_KEYBOARD
    WL_U32  [id_keyboard]
    WL_END
.check_ptr:
    test    r10d, WL_SEAT_CAP_POINTER
    jz      .flush_seat
    cmp     dword [id_pointer], 0
    jne     .flush_seat
    call    wl_new_id
    mov     [id_pointer], eax
    WL_BEGIN [id_seat], WL_SEAT_GET_POINTER
    WL_U32  [id_pointer]
    WL_END
    call    init_cursor_shape_device
.flush_seat:
    jmp     wl_flush

.keyboard:
    cmp     esi, WL_KEYBOARD_KEY
    je      .kbd_key
    cmp     esi, WL_KEYBOARD_MODIFIERS
    je      .kbd_mod
    cmp     esi, WL_KEYBOARD_REPEAT_INFO
    je      .kbd_repeat_info
    cmp     esi, WL_KEYBOARD_LEAVE
    je      .kbd_leave
    ret

.kbd_repeat_info:
    mov     eax, [rdx]
    mov     [repeat_rate], eax
    mov     eax, [rdx + 4]
    mov     [repeat_delay], eax
    ret

.kbd_leave:
    jmp     disarm_repeat_timer

.kbd_key:
    mov     edi, [rdx + 8]
    mov     esi, [rdx + 12]
    test    esi, esi
    jz      .key_released

    push    rdi
    push    rsi
    call    kbd_is_modifier
    pop     rsi
    pop     rdi
    test    eax, eax
    jnz     .no_arm
    mov     [repeat_key], edi
    push    rdi
    push    rsi
    call    arm_repeat_timer
    pop     rsi
    pop     rdi
.no_arm:
    jmp     process_key_dispatch

.key_released:
    cmp     edi, [repeat_key]
    jne     .ret
    jmp     disarm_repeat_timer

.kbd_mod:
    mov     edi, [rdx + 4]
    mov     esi, [rdx + 8]
    mov     r8d, [rdx + 12]
    mov     ecx, [rdx + 16]
    mov     edx, r8d
    call    kbd_handle_modifiers
    call    update_hover_state
    ret

.pointer:
    cmp     esi, WL_POINTER_MOTION
    je      .ptr_motion
    cmp     esi, WL_POINTER_BUTTON
    je      .ptr_button
    cmp     esi, WL_POINTER_ENTER
    je      .ptr_enter
    cmp     esi, WL_POINTER_LEAVE
    je      .ptr_leave
    cmp     esi, WL_POINTER_AXIS
    je      .ptr_axis
    ret

.ptr_leave:
    cmp     byte [url_hover_active], 0
    jz      .ret
    call    term_clear_hover
    call    win_redraw
    ret

.ptr_axis:
    mov     eax, [rdx + 4]
    test    eax, eax
    jnz     .ret
    mov     eax, [rdx + 8]
    test    eax, eax
    js      .scroll_up
    jle     .ret
.scroll_down:
    mov     edi, [cfg_scroll_lines]
    call    term_scroll_view_down
    call    win_redraw
    ret
.scroll_up:
    mov     edi, [cfg_scroll_lines]
    call    term_scroll_view_up
    call    win_redraw
    ret

.ptr_enter:
    mov     eax, [rdx]
    mov     [pointer_enter_serial], eax
    mov     dword [cur_cursor_shape], 0
    mov     eax, [rdx + 8]
    mov     [mouse_x], eax
    mov     eax, [rdx + 12]
    mov     [mouse_y], eax
    mov     edi, 9
    call    set_cursor_shape
    call    update_hover_state
    ret

.ptr_motion:
    mov     eax, [rdx + 4]
    mov     [mouse_x], eax
    mov     r8d, [rdx + 8]
    mov     [mouse_y], r8d
    cmp     byte [mouse_pressed], 0
    jz      .motion_no_drag
    call    coord_to_cell
    call    term_update_sel_end
    call    win_redraw
    ret
.motion_no_drag:
    call    update_hover_state
    ret

.ptr_button:
    mov     eax, [rdx + 8]
    cmp     eax, 274
    je      .middle_btn
    cmp     eax, 272
    jne     .ret
    mov     eax, [rdx + 12]
    test    eax, eax
    jz      .btn_released
    call    kbd_get_modifiers
    test    eax, 4
    jz      .normal_click
    mov     eax, [mouse_x]
    mov     r8d, [mouse_y]
    call    coord_to_cell
    lea     rdx, [click_url_buf]
    mov     ecx, 1024
    call    term_find_url_at
    test    eax, eax
    jz      .ret
    call    term_clear_sel
    lea     rdi, [click_url_buf]
    call    launch_url
    ret

.normal_click:
    mov     byte [mouse_pressed], 1
    mov     eax, [mouse_x]
    mov     r8d, [mouse_y]
    call    coord_to_cell
    call    term_set_sel_start
    call    win_redraw
    ret

.middle_btn:
    mov     eax, [rdx + 12]
    test    eax, eax
    jz      .ret
    call    term_scroll_view_to_bottom
    call    clip_paste_system
    call    win_redraw
    ret

.btn_released:
    mov     byte [mouse_pressed], 0
    mov     eax, [term_sel_start_col]
    cmp     eax, [term_sel_end_col]
    jne     .copy_on_select
    mov     eax, [term_sel_start_row]
    cmp     eax, [term_sel_end_row]
    jne     .copy_on_select
    call    term_clear_sel
    call    win_redraw
    ret

.copy_on_select:
    call    term_copy_selection
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
    lea     rsi, [s_cursor_shape_mgr]
    call    streq
    test    eax, eax
    jz      .not_cursor_shape_mgr
    mov     ecx, 1
    lea     r8, [s_cursor_shape_mgr]
    lea     r9, [id_cursor_shape_mgr]
    jmp     .bind

.not_cursor_shape_mgr:
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
    call    init_cursor_shape_device

.registry_done:
    pop     r13
    pop     r12
    pop     rbx
.ret:
    ret

coord_to_cell:
    sar     eax, 8
    sub     eax, [cfg_pad_x]
    jns     .x_ok
    xor     eax, eax
.x_ok:
    xor     edx, edx
    mov     ecx, [font_w]
    div     ecx
    mov     edi, eax
    mov     eax, [term_cols]
    test    eax, eax
    jz      .col_zero
    dec     eax
    cmp     edi, eax
    cmova   edi, eax
    jmp     .col_done
.col_zero:
    xor     edi, edi
.col_done:

    sar     r8d, 8
    sub     r8d, [cfg_pad_y]
    jns     .y_ok
    xor     r8d, r8d
.y_ok:
    mov     eax, r8d
    xor     edx, edx
    mov     ecx, [font_h]
    div     ecx
    mov     esi, eax
    mov     eax, [term_rows]
    test    eax, eax
    jz      .row_zero
    dec     eax
    cmp     esi, eax
    cmova   esi, eax
    jmp     .row_done
.row_zero:
    xor     esi, esi
.row_done:
    ret

launch_url:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi

    mov     eax, SYS_FORK
    syscall
    test    rax, rax
    js      .url_ret
    jnz     .url_parent

    mov     eax, SYS_FORK
    syscall
    test    rax, rax
    js      .url_child_fail
    jnz     .url_child_exit

    mov     eax, SYS_SETSID
    syscall

    mov     eax, SYS_OPEN
    lea     rdi, [s_dev_null]
    mov     esi, O_RDWR
    xor     edx, edx
    syscall
    test    rax, rax
    js      .url_do_exec
    mov     r13, rax
    xor     esi, esi
.url_dup:
    mov     eax, SYS_DUP2
    mov     rdi, r13
    syscall
    inc     esi
    cmp     esi, 3
    jb      .url_dup
    mov     eax, SYS_CLOSE
    mov     rdi, r13
    syscall

.url_do_exec:
    lea     rax, [s_xdg_open_cmd]
    mov     [url_argv], rax
    mov     [url_argv + 8], r12
    mov     qword [url_argv + 16], 0

    mov     eax, SYS_EXECVE
    lea     rdi, [s_xdg_open_usr]
    lea     rsi, [url_argv]
    mov     rdx, [win_envp]
    syscall

    mov     eax, SYS_EXECVE
    lea     rdi, [s_xdg_open_bin]
    lea     rsi, [url_argv]
    mov     rdx, [win_envp]
    syscall

.url_child_fail:
    mov     eax, SYS_EXIT
    mov     edi, 1
    syscall

.url_child_exit:
    mov     eax, SYS_EXIT
    xor     edi, edi
    syscall

.url_parent:
    mov     edi, eax
    xor     esi, esi
    xor     edx, edx
    xor     r10, r10
    mov     eax, SYS_WAIT4
    syscall

.url_ret:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

init_cursor_shape_device:
    cmp     dword [id_cursor_shape_device], 0
    jnz     .ret
    cmp     dword [id_cursor_shape_mgr], 0
    jz      .ret
    cmp     dword [id_pointer], 0
    jz      .ret
    call    wl_new_id
    mov     [id_cursor_shape_device], eax
    WL_BEGIN [id_cursor_shape_mgr], 1
    WL_U32  [id_cursor_shape_device]
    WL_U32  [id_pointer]
    WL_END
    call    wl_flush
.ret:
    ret

set_cursor_shape:
    cmp     dword [id_cursor_shape_device], 0
    jz      .ret
    cmp     dword [pointer_enter_serial], 0
    jz      .ret
    cmp     edi, [cur_cursor_shape]
    je      .ret
    mov     [cur_cursor_shape], edi
    WL_BEGIN [id_cursor_shape_device], 1
    WL_U32  [pointer_enter_serial]
    WL_U32  [cur_cursor_shape]
    WL_END
    call    wl_flush
.ret:
    ret

update_hover_state:
    call    kbd_get_modifiers
    test    eax, 4
    jz      .no_ctrl

    mov     eax, [mouse_x]
    mov     r8d, [mouse_y]
    call    coord_to_cell
    lea     rdx, [click_url_buf]
    mov     ecx, 1024
    call    term_find_url_at
    test    eax, eax
    jz      .no_url

    mov     edi, 4
    call    set_cursor_shape
    call    win_redraw
    ret

.no_url:
    cmp     byte [url_hover_active], 0
    jz      .shape_text
    call    term_clear_hover
    call    win_redraw
.shape_text:
    mov     edi, 9
    call    set_cursor_shape
    ret

.no_ctrl:
    cmp     byte [url_hover_active], 0
    jz      .shape_text_no_ctrl
    call    term_clear_hover
    call    win_redraw
.shape_text_no_ctrl:
    mov     edi, 9
    call    set_cursor_shape
    ret

win_apply_zoom:
    mov     eax, [buf_w]
    mov     ecx, [cfg_pad_x]
    shl     ecx, 1
    sub     eax, ecx
    jns     .w_pos
    xor     eax, eax
.w_pos:
    xor     edx, edx
    mov     ecx, [font_w]
    div     ecx
    test    eax, eax
    jnz     .w_nz
    mov     eax, 1
.w_nz:
    cmp     eax, 256
    jbe     .w_max
    mov     eax, 256
.w_max:
    mov     r8d, eax

    mov     eax, [buf_h]
    mov     ecx, [cfg_pad_y]
    shl     ecx, 1
    sub     eax, ecx
    jns     .h_pos
    xor     eax, eax
.h_pos:
    xor     edx, edx
    mov     ecx, [font_h]
    div     ecx
    test    eax, eax
    jnz     .h_nz
    mov     eax, 1
.h_nz:
    cmp     eax, 128
    jbe     .h_max
    mov     eax, 128
.h_max:
    mov     r9d, eax

    mov     edi, r8d
    mov     esi, r9d
    call    term_resize
    call    update_pty_winsize
    call    win_redraw
    ret
