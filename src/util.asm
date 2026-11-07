; Общие вспомогательные функции

default rel
%include "syscalls.inc"

global write_all
global find_shell

section .rodata
default_shell:  db "/bin/sh", 0

section .text

; -------------------------------------------------------------
; write_all: rdi = fd, rsi = буфер, rdx = длина
;   пишет всё целиком -> rax = 0 или ошибка (< 0)
; -------------------------------------------------------------
write_all:
.again:
    test    rdx, rdx
    jz      .ok
    mov     eax, SYS_WRITE
    syscall
    cmp     rax, -EINTR
    je      .again
    test    rax, rax
    js      .ret
    add     rsi, rax
    sub     rdx, rax
    jmp     .again
.ok:
    xor     eax, eax
.ret:
    ret

; -------------------------------------------------------------
; find_shell: rdi = envp
;   -> rax = значение $SHELL или "/bin/sh"
; -------------------------------------------------------------
find_shell:
.next:
    mov     rsi, [rdi]
    test    rsi, rsi
    jz      .fallback
    cmp     dword [rsi], 'SHEL'
    jne     .skip
    cmp     word [rsi + 4], 'L='
    jne     .skip
    lea     rax, [rsi + 6]
    cmp     byte [rax], 0
    je      .fallback
    ret
.skip:
    add     rdi, 8
    jmp     .next
.fallback:
    lea     rax, [default_shell]
    ret
