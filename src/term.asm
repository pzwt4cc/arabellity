default rel
%include "syscalls.inc"

global term_raw
global term_restore
global term_copy_winsize

%define TERMIOS_SIZE    36
%define T_IFLAG         0
%define T_OFLAG         4
%define T_CFLAG         8
%define T_LFLAG         12
%define T_CC            17
%define VTIME           5
%define VMIN            6

section .bss
saved:      resb TERMIOS_SIZE
raw:        resb TERMIOS_SIZE
have_saved: resb 1
winsize:    resb 8

section .text

term_raw:
    mov     eax, SYS_IOCTL
    mov     edi, STDIN
    mov     esi, TCGETS
    lea     rdx, [saved]
    syscall
    test    rax, rax
    js      .ret

    lea     rsi, [saved]
    lea     rdi, [raw]
    mov     ecx, TERMIOS_SIZE
    rep     movsb

    and     dword [raw + T_IFLAG], ~0x7EB
    and     dword [raw + T_OFLAG], ~0x1
    and     dword [raw + T_CFLAG], ~0x130
    or      dword [raw + T_CFLAG], 0x30
    and     dword [raw + T_LFLAG], ~0x804B
    mov     byte [raw + T_CC + VMIN], 1
    mov     byte [raw + T_CC + VTIME], 0

    mov     eax, SYS_IOCTL
    mov     edi, STDIN
    mov     esi, TCSETS
    lea     rdx, [raw]
    syscall
    test    rax, rax
    js      .ret
    mov     byte [have_saved], 1
.ret:
    ret

term_restore:
    cmp     byte [have_saved], 0
    je      .ret
    mov     eax, SYS_IOCTL
    mov     edi, STDIN
    mov     esi, TCSETS
    lea     rdx, [saved]
    syscall
.ret:
    ret

term_copy_winsize:
    mov     r8, rdi
    mov     eax, SYS_IOCTL
    mov     edi, STDIN
    mov     esi, TIOCGWINSZ
    lea     rdx, [winsize]
    syscall
    test    rax, rax
    js      .ret

    mov     eax, SYS_IOCTL
    mov     rdi, r8
    mov     esi, TIOCSWINSZ
    lea     rdx, [winsize]
    syscall
.ret:
    ret
