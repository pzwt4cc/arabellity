; =============================================================
;  noname — терминал на чистом ассемблере (x86-64 Linux, без libc)
;  Название — заглушка. Меняется в одном месте: NAME в Makefile.
; =============================================================

default rel
%include "syscalls.inc"

%ifndef APP_NAME
  %define APP_NAME "noname"
%endif

%define BUF_SIZE   4096

extern pty_open, pty_spawn
extern term_raw, term_restore, term_copy_winsize
extern write_all, find_shell

section .rodata
banner:      db 27, "[1;32m", APP_NAME, 27, "[0m v0.0.2", 10
banner_len   equ $ - banner

bye:         db 27, "[1;32m", APP_NAME, 27, "[0m: shell exited", 10
bye_len      equ $ - bye

err_start:   db APP_NAME, ": failed to start shell", 10
err_start_len equ $ - err_start

section .bss
buf:         resb BUF_SIZE
pfds:        resb 16                    ; 2 x struct pollfd
status:      resd 1

section .text
global _start

; Регистры на всё время работы:
;   rbx = master fd, r12 = slave fd, r13 = pid шелла
;   r14 = путь к шеллу, r15 = envp
_start:
    mov     rax, [rsp]                  ; argc
    lea     r15, [rsp + rax*8 + 16]     ; envp

    mov     edi, STDOUT
    lea     rsi, [banner]
    mov     edx, banner_len
    call    write_all

    mov     rdi, r15
    call    find_shell
    mov     r14, rax

    call    pty_open
    test    rax, rax
    js      .fail
    mov     rbx, rax
    mov     r12, rdx

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

    mov     eax, SYS_CLOSE              ; slave родителю не нужен
    mov     rdi, r12
    syscall

    call    term_raw

; --- главный цикл: stdin -> pty, pty -> stdout ---
.loop:
    mov     dword [pfds], STDIN
    mov     dword [pfds + 4], POLLIN    ; events = POLLIN, revents = 0
    mov     dword [pfds + 8], ebx
    mov     dword [pfds + 12], POLLIN

    mov     eax, SYS_POLL
    lea     rdi, [pfds]
    mov     esi, 2
    mov     edx, -1
    syscall
    cmp     rax, -EINTR
    je      .loop
    test    rax, rax
    js      .done

    test    word [pfds + 14], POLLIN | POLLHUP | POLLERR
    jz      .stdin
    mov     eax, SYS_READ
    mov     edi, ebx
    lea     rsi, [buf]
    mov     edx, BUF_SIZE
    syscall
    test    rax, rax
    jle     .done                       ; шелл завершился (EIO)
    mov     edi, STDOUT
    lea     rsi, [buf]
    mov     rdx, rax
    call    write_all

.stdin:
    test    word [pfds + 6], POLLIN | POLLHUP | POLLERR
    jz      .loop
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

    movzx   edi, byte [status + 1]      ; код выхода шелла
    mov     eax, SYS_EXIT
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
