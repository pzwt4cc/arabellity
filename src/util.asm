default rel
%include "syscalls.inc"

global write_all
global getenv
global find_shell
global streq
global strcpy

section .rodata
default_shell:  db "/bin/sh", 0
env_shell:      db "SHELL", 0

section .text

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

getenv:
.next:
    mov     r8, [rdi]
    test    r8, r8
    jz      .none
    xor     ecx, ecx
.cmp:
    mov     al, [rsi + rcx]
    test    al, al
    jz      .end
    cmp     al, [r8 + rcx]
    jne     .skip
    inc     rcx
    jmp     .cmp
.end:
    cmp     byte [r8 + rcx], '='
    jne     .skip
    lea     rax, [r8 + rcx + 1]
    ret
.skip:
    add     rdi, 8
    jmp     .next
.none:
    xor     eax, eax
    ret

find_shell:
    lea     rsi, [env_shell]
    call    getenv
    test    rax, rax
    jz      .fallback
    cmp     byte [rax], 0
    je      .fallback
    ret
.fallback:
    lea     rax, [default_shell]
    ret

streq:
    xor     ecx, ecx
.loop:
    mov     al, [rdi + rcx]
    cmp     al, [rsi + rcx]
    jne     .ne
    inc     rcx
    test    al, al
    jnz     .loop
    mov     eax, 1
    ret
.ne:
    xor     eax, eax
    ret

strcpy:
    mov     al, [rsi]
    mov     [rdi], al
    test    al, al
    jz      .done
    inc     rsi
    inc     rdi
    jmp     strcpy
.done:
    mov     rax, rdi
    ret
