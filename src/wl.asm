default rel
%include "syscalls.inc"

global wl_connect
global wl_fd
global wl_new_id
global wl_begin
global wl_u32
global wl_str
global wl_end
global wl_flush
global wl_flush_fd
global wl_read

extern getenv
extern strcpy
extern write_all
extern on_event

%define OUT_SIZE    4096
%define IN_SIZE     16384

section .rodata
env_runtime:     db "XDG_RUNTIME_DIR", 0
env_display:     db "WAYLAND_DISPLAY", 0
default_display: db "wayland-0", 0

section .data
wl_fd:      dd -1
next_id:    dd 2

section .bss
addr:       resb 112
out_buf:    resb OUT_SIZE
out_len:    resd 1
msg_start:  resd 1
msg_op:     resd 1
in_buf:     resb IN_SIZE
in_len:     resd 1
iov:        resq 2
msgh:       resb 56
cmsg:       resb 24

section .text

wl_connect:
    push    rbx
    mov     rbx, rdi
    lea     rsi, [env_display]
    call    getenv
    test    rax, rax
    jnz     .have_display
    lea     rax, [default_display]
.have_display:
    mov     word [addr], AF_UNIX
    lea     rdi, [addr + 2]
    cmp     byte [rax], '/'
    je      .copy_display

    push    rax
    mov     rdi, rbx
    lea     rsi, [env_runtime]
    call    getenv
    pop     rsi
    test    rax, rax
    jz      .fail
    push    rsi
    lea     rdi, [addr + 2]
    mov     rsi, rax
    call    strcpy
    mov     byte [rax], '/'
    lea     rdi, [rax + 1]
    pop     rax
.copy_display:
    mov     rsi, rax
    call    strcpy

    mov     eax, SYS_SOCKET
    mov     edi, AF_UNIX
    mov     esi, SOCK_STREAM | SOCK_CLOEXEC
    xor     edx, edx
    syscall
    test    rax, rax
    js      .ret
    mov     [wl_fd], eax

    mov     rdi, rax
    mov     eax, SYS_CONNECT
    lea     rsi, [addr]
    mov     edx, 110
    syscall
    test    rax, rax
    js      .ret
    mov     eax, [wl_fd]
    jmp     .ret
.fail:
    mov     rax, -1
.ret:
    pop     rbx
    ret

wl_new_id:
    mov     eax, [next_id]
    inc     dword [next_id]
    ret

wl_begin:
    mov     eax, [out_len]
    mov     [msg_start], eax
    mov     [msg_op], esi
    lea     rcx, [out_buf]
    mov     [rcx + rax], edi
    add     eax, 8
    mov     [out_len], eax
    ret

wl_u32:
    mov     eax, [out_len]
    lea     rcx, [out_buf]
    mov     [rcx + rax], edi
    add     eax, 4
    mov     [out_len], eax
    ret

wl_str:
    mov     rsi, rdi
    xor     ecx, ecx
.len:
    cmp     byte [rsi + rcx], 0
    je      .got
    inc     ecx
    jmp     .len
.got:
    inc     ecx
    mov     edx, ecx
    add     edx, 3
    and     edx, ~3
    mov     eax, [out_len]
    lea     rdi, [out_buf]
    add     rdi, rax
    lea     r8d, [eax + edx + 4]
    mov     [out_len], r8d
    mov     [rdi], ecx
    add     rdi, 4
    sub     edx, ecx
    rep     movsb
    mov     ecx, edx
    xor     eax, eax
    rep     stosb
    ret

wl_end:
    mov     eax, [out_len]
    mov     ecx, [msg_start]
    sub     eax, ecx
    shl     eax, 16
    or      eax, [msg_op]
    lea     rdx, [out_buf]
    mov     [rdx + rcx + 4], eax
    ret

wl_flush:
    mov     edx, [out_len]
    test    edx, edx
    jz      .empty
    mov     edi, [wl_fd]
    lea     rsi, [out_buf]
    call    write_all
    mov     dword [out_len], 0
    ret
.empty:
    xor     eax, eax
    ret

wl_flush_fd:
    lea     rax, [out_buf]
    mov     [iov], rax
    mov     eax, [out_len]
    mov     [iov + 8], rax

    xor     eax, eax
    mov     [msgh], rax
    mov     [msgh + 8], rax
    lea     rax, [iov]
    mov     [msgh + 16], rax
    mov     qword [msgh + 24], 1
    lea     rax, [cmsg]
    mov     [msgh + 32], rax
    mov     qword [msgh + 40], 24
    mov     dword [msgh + 48], 0

    mov     qword [cmsg], 20
    mov     dword [cmsg + 8], SOL_SOCKET
    mov     dword [cmsg + 12], SCM_RIGHTS
    mov     [cmsg + 16], edi
    mov     dword [cmsg + 20], 0

    mov     eax, SYS_SENDMSG
    mov     edi, [wl_fd]
    lea     rsi, [msgh]
    xor     edx, edx
    syscall
    mov     dword [out_len], 0
    ret

wl_read:
    push    rbx
    push    r12
    mov     ecx, [in_len]
    lea     rsi, [in_buf]
    add     rsi, rcx
    mov     edx, IN_SIZE
    sub     edx, ecx
    mov     eax, SYS_READ
    mov     edi, [wl_fd]
    syscall
    test    rax, rax
    jle     .ret

    push    rax
    add     [in_len], eax
    xor     ebx, ebx
.next:
    mov     eax, [in_len]
    sub     eax, ebx
    cmp     eax, 8
    jb      .compact
    lea     r12, [in_buf]
    add     r12, rbx
    mov     ecx, [r12 + 4]
    shr     ecx, 16
    cmp     ecx, 8
    jb      .bad
    cmp     eax, ecx
    jb      .compact
    add     ebx, ecx
    mov     edi, [r12]
    movzx   esi, word [r12 + 4]
    lea     rdx, [r12 + 8]
    sub     ecx, 8
    call    on_event
    jmp     .next

.compact:
    mov     ecx, [in_len]
    sub     ecx, ebx
    mov     [in_len], ecx
    lea     rdi, [in_buf]
    lea     rsi, [rdi + rbx]
    rep     movsb
    pop     rax
.ret:
    pop     r12
    pop     rbx
    ret
.bad:
    pop     rax
    mov     rax, -1
    jmp     .ret
