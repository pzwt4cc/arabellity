; Настройки tty, в котором мы запущены (raw-режим, размер окна).
; Временная часть: уйдёт, когда появится своё окно.

default rel
%include "syscalls.inc"

global term_raw
global term_restore
global term_copy_winsize

%define TERMIOS_SIZE    36              ; struct termios ядра
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

; -------------------------------------------------------------
; term_raw: перевести stdin в raw-режим (как cfmakeraw)
; -------------------------------------------------------------
term_raw:
    mov     eax, SYS_IOCTL
    mov     edi, STDIN
    mov     esi, TCGETS
    lea     rdx, [saved]
    syscall
    test    rax, rax
    js      .ret                        ; stdin не терминал

    lea     rsi, [saved]
    lea     rdi, [raw]
    mov     ecx, TERMIOS_SIZE
    rep     movsb

    ; IGNBRK BRKINT PARMRK ISTRIP INLCR IGNCR ICRNL IXON
    and     dword [raw + T_IFLAG], ~0x7EB
    ; OPOST
    and     dword [raw + T_OFLAG], ~0x1
    ; CSIZE PARENB -> CS8
    and     dword [raw + T_CFLAG], ~0x130
    or      dword [raw + T_CFLAG], 0x30
    ; ECHO ECHONL ICANON ISIG IEXTEN
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

; -------------------------------------------------------------
; term_restore: вернуть исходные настройки stdin
; -------------------------------------------------------------
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

; -------------------------------------------------------------
; term_copy_winsize: rdi = master fd
;   копирует размер нашего tty в pty
; -------------------------------------------------------------
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
