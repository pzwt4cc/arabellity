default rel
%include "syscalls.inc"

global png_decode
extern tinf_uncompress

section .bss
align 16
png_plte: resb 768

section .text

png_decode:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    sub rsp, 88

    mov [rsp + 0], rdi
    mov [rsp + 8], rsi
    mov [rsp + 16], rdx
    mov [rsp + 24], rcx

    cmp rsi, 33
    jb .fail

    mov rax, [rdi]
    mov rdx, 0x0a1a0a0d474e5089
    cmp rax, rdx
    jne .fail

    mov eax, [rdi + 8]
    bswap eax
    cmp eax, 13
    jne .fail

    mov eax, [rdi + 12]
    cmp eax, 0x52444849
    jne .fail

    mov eax, [rdi + 16]
    bswap eax
    mov [rsp + 32], eax
    test eax, eax
    jz .fail

    mov eax, [rdi + 20]
    bswap eax
    mov [rsp + 36], eax
    test eax, eax
    jz .fail

    movzx eax, byte [rdi + 24]
    cmp eax, 8
    jne .fail

    movzx eax, byte [rdi + 25]
    mov [rsp + 40], eax

    cmp eax, 2
    je .ctype_ok
    cmp eax, 3
    je .ctype_ok
    cmp eax, 6
    je .ctype_ok
    jmp .fail

.ctype_ok:
    movzx eax, byte [rdi + 26]
    test eax, eax
    jnz .fail

    movzx eax, byte [rdi + 27]
    test eax, eax
    jnz .fail

    movzx eax, byte [rdi + 28]
    test eax, eax
    jnz .fail

    mov eax, [rsp + 8]
    mov [rsp + 48], eax

    mov eax, SYS_MMAP
    xor edi, edi
    mov esi, [rsp + 48]
    mov edx, PROT_READ | PROT_WRITE
    mov r10d, 0x22
    mov r8d, -1
    xor r9d, r9d
    syscall
    test rax, rax
    js .fail
    mov [rsp + 56], rax
    mov dword [rsp + 64], 0

    mov r12, [rsp + 0]
    mov r13d, 8
    mov r14, [rsp + 8]

.chunk_loop:
    lea eax, [r13d + 12]
    cmp rax, r14
    ja .chunks_done

    mov eax, [r12 + r13]
    bswap eax
    mov ebx, eax

    mov eax, [r12 + r13 + 4]
    mov edx, eax

    lea rsi, [r12 + r13 + 8]
    lea eax, [r13d + ebx + 12]
    cmp rax, r14
    ja .chunks_done

    cmp edx, 0x45544C50
    je .handle_plte
    cmp edx, 0x54414449
    je .handle_idat
    cmp edx, 0x444E4549
    je .handle_iend
    jmp .chunk_next

.handle_plte:
    lea rdi, [png_plte]
    mov ecx, ebx
    cmp ecx, 768
    jbe .plte_copy
    mov ecx, 768
.plte_copy:
    push r12
    push r13
    push r14
    rep movsb
    pop r14
    pop r13
    pop r12
    jmp .chunk_next

.handle_idat:
    mov rdi, [rsp + 56]
    mov eax, [rsp + 64]
    add rdi, rax
    mov ecx, ebx
    add [rsp + 64], ebx
    push r12
    push r13
    push r14
    rep movsb
    pop r14
    pop r13
    pop r12
    jmp .chunk_next

.handle_iend:
    jmp .chunks_done

.chunk_next:
    add r13d, ebx
    add r13d, 12
    jmp .chunk_loop

.chunks_done:
    mov eax, [rsp + 64]
    cmp eax, 6
    jbe .fail_free_idat

    mov eax, [rsp + 40]
    cmp eax, 6
    je .bpp_4
    cmp eax, 2
    je .bpp_3
    mov dword [rsp + 68], 1
    jmp .stride_calc
.bpp_4:
    mov dword [rsp + 68], 4
    jmp .stride_calc
.bpp_3:
    mov dword [rsp + 68], 3

.stride_calc:
    mov eax, [rsp + 32]
    imul eax, [rsp + 68]
    mov [rsp + 72], eax

    inc eax
    imul eax, [rsp + 36]
    mov [rsp + 76], eax

    mov eax, SYS_MMAP
    xor edi, edi
    mov esi, [rsp + 76]
    mov edx, PROT_READ | PROT_WRITE
    mov r10d, 0x22
    mov r8d, -1
    xor r9d, r9d
    syscall
    test rax, rax
    js .fail_free_idat
    mov [rsp + 80], rax

    mov rdi, rax
    lea rsi, [rsp + 76]
    mov rdx, [rsp + 56]
    add rdx, 2
    mov ecx, [rsp + 64]
    sub ecx, 6
    call tinf_uncompress
    test eax, eax
    jnz .fail_free_raw

    mov eax, SYS_MUNMAP
    mov rdi, [rsp + 56]
    mov esi, [rsp + 48]
    syscall

    mov r12, [rsp + 80]
    mov r13d, [rsp + 72]
    mov r14d, [rsp + 68]
    lea r15d, [r13d + 1]

    xor ebp, ebp
.unfilter_row:
    cmp ebp, [rsp + 36]
    jae .unfilter_done

    mov eax, ebp
    imul eax, r15d
    lea rbx, [r12 + rax]

    movzx eax, byte [rbx]
    inc rbx
    mov r11, rbx
    sub r11, r15

    cmp eax, 1
    je .filter_sub
    cmp eax, 2
    je .filter_up
    cmp eax, 3
    je .filter_avg
    cmp eax, 4
    je .filter_paeth
    jmp .unfilter_next

.filter_sub:
    mov ecx, r14d
.f_sub_loop:
    cmp ecx, r13d
    jae .unfilter_next
    movzx eax, byte [rbx + rcx]
    sub ecx, r14d
    movzx edx, byte [rbx + rcx]
    add ecx, r14d
    add eax, edx
    mov [rbx + rcx], al
    inc ecx
    jmp .f_sub_loop

.filter_up:
    test ebp, ebp
    jz .unfilter_next
    mov rdx, rbx
    sub rdx, r15
    xor ecx, ecx
.f_up_loop:
    cmp ecx, r13d
    jae .unfilter_next
    movzx eax, byte [rbx + rcx]
    movzx edx, byte [r11 + rcx]
    add eax, edx
    mov [rbx + rcx], al
    inc ecx
    jmp .f_up_loop

.filter_avg:
    xor ecx, ecx
.f_avg_loop:
    cmp ecx, r13d
    jae .unfilter_next
    xor edx, edx
    cmp ecx, r14d
    jb .f_avg_no_a
    sub ecx, r14d
    movzx edx, byte [rbx + rcx]
    add ecx, r14d
.f_avg_no_a:
    xor eax, eax
    test ebp, ebp
    jz .f_avg_calc
    movzx eax, byte [r11 + rcx]
.f_avg_calc:
    add eax, edx
    shr eax, 1
    movzx edx, byte [rbx + rcx]
    add eax, edx
    mov [rbx + rcx], al
    inc ecx
    jmp .f_avg_loop

.filter_paeth:
    xor ecx, ecx
.f_paeth_loop:
    cmp ecx, r13d
    jae .unfilter_next
    xor esi, esi
    cmp ecx, r14d
    jb .f_paeth_no_a
    sub ecx, r14d
    movzx esi, byte [rbx + rcx]
    add ecx, r14d
.f_paeth_no_a:
    xor edi, edi
    xor edx, edx
    test ebp, ebp
    jz .f_paeth_calc
    movzx edi, byte [r11 + rcx]
    cmp ecx, r14d
    jb .f_paeth_calc
    sub ecx, r14d
    movzx edx, byte [r11 + rcx]
    add ecx, r14d
.f_paeth_calc:
    push rcx
    push rdx
    mov eax, esi
    add eax, edi
    sub eax, edx
    mov r8d, eax
    sub r8d, esi
    test r8d, r8d
    jns .pa_pos
    neg r8d
.pa_pos:
    mov r9d, eax
    sub r9d, edi
    test r9d, r9d
    jns .pb_pos
    neg r9d
.pb_pos:
    mov r10d, eax
    sub r10d, edx
    test r10d, r10d
    jns .pc_pos
    neg r10d
.pc_pos:
    cmp r8d, r9d
    ja .check_pb
    cmp r8d, r10d
    ja .check_pb
    mov eax, esi
    jmp .paeth_res
.check_pb:
    cmp r9d, r10d
    ja .check_pc
    mov eax, edi
    jmp .paeth_res
.check_pc:
    mov eax, edx
.paeth_res:
    pop rdx
    pop rcx
    movzx edx, byte [rbx + rcx]
    add eax, edx
    mov [rbx + rcx], al
    inc ecx
    jmp .f_paeth_loop

.unfilter_next:
    inc ebp
    jmp .unfilter_row

.unfilter_done:
    mov eax, [rsp + 32]
    imul eax, [rsp + 36]
    shl eax, 2
    mov [rsp + 48], eax

    mov eax, SYS_MMAP
    xor edi, edi
    mov esi, [rsp + 48]
    mov edx, PROT_READ | PROT_WRITE
    mov r10d, 0x22
    mov r8d, -1
    xor r9d, r9d
    syscall
    test rax, rax
    js .fail_free_raw
    mov r13, rax

    xor ebp, ebp
    xor r14d, r14d

.conv_y:
    cmp ebp, [rsp + 36]
    jae .conv_done

    mov eax, ebp
    imul eax, r15d
    inc eax
    lea rbx, [r12 + rax]

    xor ecx, ecx
.conv_x:
    cmp ecx, [rsp + 32]
    jae .conv_y_next

    mov eax, [rsp + 40]
    cmp eax, 6
    je .conv_rgba
    cmp eax, 2
    je .conv_rgb

.conv_plte:
    movzx eax, byte [rbx + rcx]
    lea rdx, [png_plte]
    lea rdx, [rdx + rax*2]
    add rdx, rax
    movzx eax, byte [rdx]
    movzx esi, byte [rdx + 1]
    movzx edi, byte [rdx + 2]
    shl eax, 16
    shl esi, 8
    or eax, 0xff000000
    or eax, esi
    or eax, edi
    mov [r13 + r14*4], eax
    inc r14d
    inc ecx
    jmp .conv_x

.conv_rgb:
    mov eax, ecx
    lea eax, [rax + rax*2]
    movzx edx, byte [rbx + rax]
    movzx esi, byte [rbx + rax + 1]
    movzx edi, byte [rbx + rax + 2]
    shl edx, 16
    shl esi, 8
    or edx, 0xff000000
    or edx, esi
    or edx, edi
    mov [r13 + r14*4], edx
    inc r14d
    inc ecx
    jmp .conv_x

.conv_rgba:
    mov eax, ecx
    shl eax, 2
    movzx edx, byte [rbx + rax]
    movzx esi, byte [rbx + rax + 1]
    movzx edi, byte [rbx + rax + 2]
    movzx r8d, byte [rbx + rax + 3]
    shl r8d, 24
    shl edx, 16
    shl esi, 8
    or edx, r8d
    or edx, esi
    or edx, edi
    mov [r13 + r14*4], edx
    inc r14d
    inc ecx
    jmp .conv_x

.conv_y_next:
    inc ebp
    jmp .conv_y

.conv_done:
    mov eax, SYS_MUNMAP
    mov rdi, [rsp + 80]
    mov esi, [rsp + 76]
    syscall

    mov rax, [rsp + 16]
    mov edx, [rsp + 32]
    mov [rax], edx

    mov rax, [rsp + 24]
    mov edx, [rsp + 36]
    mov [rax], edx

    mov rax, r13
    jmp .exit

.fail_free_raw:
    mov eax, SYS_MUNMAP
    mov rdi, [rsp + 80]
    mov esi, [rsp + 76]
    syscall

.fail_free_idat:
    mov eax, SYS_MUNMAP
    mov rdi, [rsp + 56]
    mov esi, [rsp + 48]
    syscall

.fail:
    xor eax, eax

.exit:
    add rsp, 88
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
