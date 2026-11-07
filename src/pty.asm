default rel
%include "syscalls.inc"

global pty_open
global pty_spawn

section .rodata
ptmx_path:  db "/dev/ptmx", 0

section .text

pty_open:
    mov     eax, SYS_OPEN
    lea     rdi, [ptmx_path]
    mov     esi, O_RDWR | O_NOCTTY | O_CLOEXEC
    xor     edx, edx
    syscall
    test    rax, rax
    js      .ret
    mov     r8, rax

    push    0
    mov     eax, SYS_IOCTL
    mov     rdi, r8
    mov     esi, TIOCSPTLCK
    mov     rdx, rsp
    syscall
    add     rsp, 8
    test    rax, rax
    js      .ret

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

pty_spawn:
    push    rbx
    push    r12
    push    r13
    mov     rbx, rsi
    mov     r12, rdx
    mov     r13, rcx

    mov     eax, SYS_FORK
    syscall
    test    rax, rax
    jnz     .parent

    mov     eax, SYS_SETSID
    syscall

    mov     eax, SYS_IOCTL
    mov     rdi, rbx
    mov     esi, TIOCSCTTY
    xor     edx, edx
    syscall

    xor     esi, esi
.dup:
    mov     eax, SYS_DUP2
    mov     rdi, rbx
    syscall
    inc     esi
    cmp     esi, 3
    jb      .dup

    push    0
    push    r12
    mov     eax, SYS_EXECVE
    mov     rdi, r12
    mov     rsi, rsp
    mov     rdx, r13
    syscall

    mov     eax, SYS_EXIT
    mov     edi, 127
    syscall

.parent:
    pop     r13
    pop     r12
    pop     rbx
    ret
