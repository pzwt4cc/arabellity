; =============================================================
;  noname — терминал на чистом ассемблере (x86-64 Linux, без libc)
;  Название — заглушка. Меняется в одном месте: NAME в Makefile.
; =============================================================

default rel

%ifndef APP_NAME
  %define APP_NAME "noname"
%endif

; --- системные вызовы Linux x86-64 ---
%define SYS_READ   0
%define SYS_WRITE  1
%define SYS_EXIT   60

%define STDIN      0
%define STDOUT     1

%define BUF_SIZE   4096

section .data
banner:      db 27, "[1;32m", APP_NAME, 27, "[0m v0.0.1  (Ctrl+D — выход)", 10
banner_len   equ $ - banner

prompt:      db 27, "[36m", "> ", 27, "[0m"
prompt_len   equ $ - prompt

newline:     db 10

section .bss
buf:         resb BUF_SIZE

section .text
global _start

_start:
    lea     rsi, [banner]
    mov     edx, banner_len
    call    print

.loop:
    lea     rsi, [prompt]
    mov     edx, prompt_len
    call    print

    ; read(STDIN, buf, BUF_SIZE)
    mov     eax, SYS_READ
    mov     edi, STDIN
    lea     rsi, [buf]
    mov     edx, BUF_SIZE
    syscall

    test    rax, rax
    jle     .exit               ; 0 = EOF (Ctrl+D), <0 = ошибка

    ; пока просто эхо введённой строки
    mov     rdx, rax
    lea     rsi, [buf]
    call    print
    jmp     .loop

.exit:
    lea     rsi, [newline]
    mov     edx, 1
    call    print

    mov     eax, SYS_EXIT
    xor     edi, edi
    syscall

; -------------------------------------------------------------
; print: rsi = указатель, rdx = длина
; -------------------------------------------------------------
print:
    mov     eax, SYS_WRITE
    mov     edi, STDOUT
    syscall
    ret
