default rel
%include "syscalls.inc"

%define BUF_SIZE   65536

extern pty_open
extern pty_spawn
extern find_shell
extern win_init
extern win_update
extern win_redraw
extern win_handle_repeat
extern update_pty_winsize
extern wl_read
extern wl_fd
extern repeat_timer_fd
extern close_requested
extern win_pty_fd
extern term_feed

section .rodata
err_window:     db APP_NAME, ": failed to open wayland window", 10
err_window_len  equ $ - err_window

section .bss
buf:            resb BUF_SIZE
pfds:           resb 24
status:         resd 1

section .text
global _start

_start:
    mov     rax, [rsp]
    lea     r15, [rsp + rax*8 + 16]

    mov     rdi, r15
    call    win_init
    test    rax, rax
    js      .fail_window

    mov     rdi, r15
    call    find_shell
    mov     r14, rax

    call    pty_open
    test    rax, rax
    js      .fail
    mov     rbx, rax
    mov     r12, rdx
    mov     [win_pty_fd], ebx

    call    update_pty_winsize

    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, r14
    mov     rcx, r15
    call    pty_spawn
    test    rax, rax
    js      .fail
    mov     r13, rax

    mov     eax, SYS_CLOSE
    mov     rdi, r12
    syscall

.loop:
    cmp     byte [close_requested], 0
    jne     .closed

    mov     dword [pfds], ebx
    mov     word [pfds + 4], POLLIN
    mov     word [pfds + 6], 0
    mov     eax, [wl_fd]
    mov     dword [pfds + 8], eax
    mov     word [pfds + 12], POLLIN
    mov     word [pfds + 14], 0
    mov     eax, [repeat_timer_fd]
    mov     dword [pfds + 16], eax
    mov     word [pfds + 20], POLLIN
    mov     word [pfds + 22], 0

    mov     eax, SYS_POLL
    lea     rdi, [pfds]
    mov     esi, 3
    mov     edx, -1
    syscall
    cmp     rax, -EINTR
    je      .loop
    test    rax, rax
    js      .done

.pty:
    test    word [pfds + 6], POLLIN | POLLHUP | POLLERR
    jz      .wl
    mov     eax, SYS_READ
    mov     edi, ebx
    lea     rsi, [buf]
    mov     edx, BUF_SIZE
    syscall
    test    rax, rax
    jle     .done

    lea     rdi, [buf]
    mov     rsi, rax
    call    term_feed

    mov     ebp, 16
.coalesce_pty:
    mov     dword [pfds], ebx
    mov     word [pfds + 4], POLLIN
    mov     word [pfds + 6], 0
    mov     eax, SYS_POLL
    lea     rdi, [pfds]
    mov     esi, 1
    mov     edx, 1
    syscall
    test    rax, rax
    jle     .pty_redraw
    test    word [pfds + 6], POLLIN
    jz      .pty_redraw
    mov     eax, SYS_READ
    mov     edi, ebx
    lea     rsi, [buf]
    mov     edx, BUF_SIZE
    syscall
    test    rax, rax
    jle     .pty_redraw
    lea     rdi, [buf]
    mov     rsi, rax
    call    term_feed
    dec     ebp
    jnz     .coalesce_pty

.pty_redraw:
    call    win_redraw

.wl:
    test    word [pfds + 14], POLLIN | POLLHUP | POLLERR
    jz      .timer
    call    wl_read
    test    rax, rax
    jle     .closed
    call    win_update

.timer:
    test    word [pfds + 22], POLLIN
    jz      .loop
    call    win_handle_repeat
    jmp     .loop

.done:
    mov     eax, SYS_WAIT4
    mov     rdi, r13
    lea     rsi, [status]
    xor     edx, edx
    xor     r10d, r10d
    syscall

.closed:
    mov     eax, SYS_EXIT
    xor     edi, edi
    syscall

.fail_window:
    mov     edi, STDERR
    lea     rsi, [err_window]
    mov     edx, err_window_len
    mov     eax, SYS_WRITE
    syscall
    mov     eax, SYS_EXIT
    mov     edi, 1
    syscall

.fail:
    mov     eax, SYS_EXIT
    mov     edi, 1
    syscall
