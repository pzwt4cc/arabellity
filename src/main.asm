default rel
%include "syscalls.inc"

%define BUF_SIZE   4096

extern pty_open
extern pty_spawn
extern term_raw
extern term_restore
extern term_copy_winsize
extern write_all
extern find_shell
extern win_init
extern win_update
extern win_redraw
extern wl_read
extern wl_fd
extern close_requested
extern win_pty_fd
extern term_feed

section .rodata
bye:            db 27, "[1;32m", APP_NAME, 27, "[0m: shell exited", 10
bye_len         equ $ - bye
err_start:      db APP_NAME, ": failed to start shell", 10
err_start_len   equ $ - err_start
err_window:     db APP_NAME, ": failed to open window", 10
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

    mov     rdi, rbx
    call    term_copy_winsize

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

    call    term_raw

.loop:
    cmp     byte [close_requested], 0
    jne     .closed

    mov     dword [pfds], STDIN
    mov     dword [pfds + 4], POLLIN
    mov     dword [pfds + 8], ebx
    mov     dword [pfds + 12], POLLIN
    mov     eax, [wl_fd]
    mov     [pfds + 16], eax
    mov     dword [pfds + 20], POLLIN

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
    test    word [pfds + 14], POLLIN | POLLHUP | POLLERR
    jz      .stdin
    mov     eax, SYS_READ
    mov     edi, ebx
    lea     rsi, [buf]
    mov     edx, BUF_SIZE
    syscall
    test    rax, rax
    jle     .done

    push    rax
    mov     edi, STDOUT
    lea     rsi, [buf]
    mov     rdx, rax
    call    write_all
    pop     rax

    lea     rdi, [buf]
    mov     rsi, rax
    call    term_feed
    call    win_redraw

.stdin:
    test    word [pfds + 6], POLLIN | POLLHUP | POLLERR
    jz      .wl
    mov     eax, SYS_READ
    mov     edi, STDIN
    lea     rsi, [buf]
    mov     edx, BUF_SIZE
    syscall
    test    rax, rax
    jle     .done
    mov     edi, ebx
    lea     rsi, [buf]
    mov     rdx, rax
    call    write_all

.wl:
    test    word [pfds + 22], POLLIN | POLLHUP | POLLERR
    jz      .loop
    call    wl_read
    test    rax, rax
    jle     .closed
    call    win_update
    jmp     .loop

.done:
    call    term_restore
    mov     eax, SYS_WAIT4
    mov     rdi, r13
    lea     rsi, [status]
    xor     edx, edx
    xor     r10d, r10d
    syscall

    mov     edi, STDOUT
    lea     rsi, [bye]
    mov     edx, bye_len
    call    write_all

    movzx   edi, byte [status + 1]
    mov     eax, SYS_EXIT
    syscall

.closed:
    call    term_restore
    mov     eax, SYS_EXIT
    xor     edi, edi
    syscall

.fail_window:
    mov     edi, STDERR
    lea     rsi, [err_window]
    mov     edx, err_window_len
    call    write_all
    mov     eax, SYS_EXIT
    mov     edi, 1
    syscall

.fail:
    call    term_restore
    mov     edi, STDERR
    lea     rsi, [err_start]
    mov     edx, err_start_len
    call    write_all
    mov     eax, SYS_EXIT
    mov     edi, 1
    syscall
