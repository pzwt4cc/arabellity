default rel
%include "syscalls.inc"

global pty_open
global pty_spawn

section .rodata
ptmx_path:      db "/dev/ptmx", 0
term_env_str:   db "TERM=xterm-kitty", 0

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

    sub     rsp, 4096
    mov     rdi, rsp
    mov     rsi, r13
    xor     ecx, ecx
    xor     r8d, r8d
.env_loop:
    cmp     ecx, 508
    jae     .env_done
    mov     rax, [rsi + rcx*8]
    test    rax, rax
    jz      .env_done
    cmp     dword [rax], 0x4d524554
    jne     .env_store
    cmp     byte [rax + 4], '='
    jne     .env_store
    lea     rax, [term_env_str]
    mov     r8d, 1
.env_store:
    mov     [rdi + rcx*8], rax
    inc     ecx
    jmp     .env_loop
.env_done:
    test    r8d, r8d
    jnz     .env_null
    lea     rax, [term_env_str]
    mov     [rdi + rcx*8], rax
    inc     ecx
.env_null:
    mov     qword [rdi + rcx*8], 0
    mov     r13, rdi

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
