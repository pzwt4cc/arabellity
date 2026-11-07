; PTY: создание пары master/slave и запуск шелла

default rel
%include "syscalls.inc"

global pty_open
global pty_spawn

section .rodata
ptmx_path:  db "/dev/ptmx", 0

section .text

; -------------------------------------------------------------
; pty_open
;   -> rax = master fd, rdx = slave fd  (rax < 0 при ошибке)
; -------------------------------------------------------------
pty_open:
    mov     eax, SYS_OPEN
    lea     rdi, [ptmx_path]
    mov     esi, O_RDWR | O_NOCTTY | O_CLOEXEC
    xor     edx, edx
    syscall
    test    rax, rax
    js      .ret
    mov     r8, rax                     ; master

    ; разблокировать slave: ioctl(master, TIOCSPTLCK, &0)
    push    0
    mov     eax, SYS_IOCTL
    mov     rdi, r8
    mov     esi, TIOCSPTLCK
    mov     rdx, rsp
    syscall
    add     rsp, 8
    test    rax, rax
    js      .ret

    ; открыть slave прямо из master (Linux 4.13+)
    mov     eax, SYS_IOCTL
    mov     rdi, r8
    mov     esi, TIOCGPTPEER
    mov     edx, O_RDWR | O_NOCTTY | O_CLOEXEC
    syscall
    test    rax, rax
    js      .ret

    mov     rdx, rax
    mov     rax, r8
.ret:
    ret

; -------------------------------------------------------------
; pty_spawn
;   rdi = master fd, rsi = slave fd, rdx = путь к шеллу, rcx = envp
;   -> rax = pid ребёнка (rax < 0 при ошибке)
; -------------------------------------------------------------
pty_spawn:
    push    rbx
    push    r12
    push    r13
    mov     rbx, rsi                    ; slave
    mov     r12, rdx                    ; shell
    mov     r13, rcx                    ; envp

    mov     eax, SYS_FORK
    syscall
    test    rax, rax
    jnz     .parent                     ; pid > 0 или ошибка

    ; --- ребёнок ---
    mov     eax, SYS_SETSID             ; новая сессия
    syscall

    mov     eax, SYS_IOCTL              ; slave -> управляющий терминал
    mov     rdi, rbx
    mov     esi, TIOCSCTTY
    xor     edx, edx
    syscall

    xor     esi, esi                    ; dup2(slave, 0/1/2)
.dup:
    mov     eax, SYS_DUP2
    mov     rdi, rbx
    syscall
    inc     esi
    cmp     esi, 3
    jb      .dup

    push    0                           ; argv = { shell, NULL }
    push    r12
    mov     eax, SYS_EXECVE
    mov     rdi, r12
    mov     rsi, rsp
    mov     rdx, r13
    syscall

    mov     eax, SYS_EXIT               ; execve не сработал
    mov     edi, 127
    syscall

.parent:
    pop     r13
    pop     r12
    pop     rbx
    ret
