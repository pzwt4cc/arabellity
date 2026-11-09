default rel
global tinf_uncompress
global tinf_init
section .text
section .text
    align 16
tinf_build_tree:
    pxor xmm0, xmm0
    mov r8, rdi
    mov r9, rsi
    mov r10d, edx
    mov dword 608[rdi], -1
    movups oword [rdi], xmm0
    movups oword 16[rdi], xmm0
    test edx, edx
    je .L2
    mov ecx, edx
    xor eax, eax
    align 64
    align 16
    align 8
.L4:
    cmp byte [r9+rax], 0
    je .L3
    mov dword 608[r8], eax
    movzx edx, byte [r9+rax]
    add word [r8+rdx*2], 1
.L3:
    add rax, 1
    cmp rax, rcx
    jne .L4
.L2:
    mov rdi, r8
    lea rdx, -40[rsp]
    mov eax, 1
    xor esi, esi
    align 64
    align 16
    align 8
.L7:
    movzx ecx, word [rdi]
    cmp eax, ecx
    jb .L8
    mov word [rdx], si
    sub eax, ecx
    add esi, ecx
    add rdx, 2
    lea rcx, -8[rsp]
    add eax, eax
    add rdi, 2
    cmp rcx, rdx
    jne .L7
    cmp esi, 1
    jbe .L18
    test eax, eax
    jne .L8
.L18:
    cmp esi, 1
    je .L10
    xor eax, eax
    test r10d, r10d
    je .L12
    align 64
    align 16
    align 8
.L14:
    movzx edx, byte [r9+rax]
    test dl, dl
    je .L13
    movzx ecx, word -40[rsp+rdx*2]
    lea edi, 1[rcx]
    mov word 32[r8+rcx*2], ax
    mov word -40[rsp+rdx*2], di
.L13:
    add rax, 1
    cmp eax, r10d
    jb .L14
    cmp esi, 1
    je .L15
.L12:
    xor eax, eax
    ret
    align 16
    align 8
.L8:
    mov eax, -3
    ret
    align 16
    align 8
.L10:
    cmp word 2[r8], 1
    jne .L8
    xor eax, eax
    test r10d, r10d
    jne .L14
.L15:
    mov eax, 2
    mov word 2[r8], ax
    movzx eax, word 608[r8]
    add eax, 1
    mov word 34[r8], ax
    xor eax, eax
    ret
    align 16
tinf_getbits:
    mov r9d, dword 20[rdi]
    cmp esi, r9d
    jle .L36
    mov r8, qword 8[rdi]
    mov ecx, r9d
    jmp .L39
    align 64
    align 16
    align 8
.L42:
    lea rdx, 1[rax]
    mov qword [rdi], rdx
    movzx eax, byte [rax]
    sal eax, cl
    add ecx, 8
    or dword 16[rdi], eax
    mov dword 20[rdi], ecx
    cmp esi, ecx
    jle .L41
.L39:
    mov rax, qword [rdi]
    cmp rax, r8
    jne .L42
    add ecx, 8
    mov dword 24[rdi], 1
    mov dword 20[rdi], ecx
    cmp esi, ecx
    jg .L39
.L41:
    lea eax, -1[rsi]
    sub eax, r9d
    and eax, -8
    lea r9d, 8[r9+rax]
.L36:
    mov edx, dword 16[rdi]
    mov ecx, esi
    sub r9d, esi
    mov dword 20[rdi], r9d
    mov eax, edx
    shr eax, cl
    mov dword 16[rdi], eax
    mov rax, -1
    sal rax, cl
    not eax
    and eax, edx
    ret
    align 16
tinf_decode_symbol:
    mov ecx, dword 20[rdi]
    xor eax, eax
    push rbp
    mov r11, rsi
    push rbx
    lea r9, 2[rsi]
    xor r10d, r10d
    lea ebx, [rax+rax]
    test ecx, ecx
    jg .L50
    align 16
    align 8
.L55:
    mov esi, ecx
    lea eax, 8[rcx]
    mov rbp, qword 8[rdi]
    neg esi
    and esi, -8
    add esi, eax
    jmp .L47
    align 64
    align 16
    align 8
.L53:
    lea r8, 1[rdx]
    mov qword [rdi], r8
    movzx edx, byte [rdx]
    mov dword 20[rdi], eax
    sal edx, cl
    mov ecx, eax
    or dword 16[rdi], edx
    cmp eax, esi
    je .L44
.L54:
    add eax, 8
.L47:
    mov rdx, qword [rdi]
    cmp rdx, rbp
    jne .L53
    mov dword 24[rdi], 1
    mov ecx, eax
    mov dword 20[rdi], eax
    cmp eax, esi
    jne .L54
.L44:
    mov eax, dword 16[rdi]
    lea ecx, -1[rsi]
    mov dword 20[rdi], ecx
    mov edx, eax
    and eax, 1
    shr edx, 1
    add eax, ebx
    mov dword 16[rdi], edx
    movzx edx, word [r9]
    cmp edx, eax
    jg .L48
    sub eax, edx
    add r9, 2
    add r10d, edx
    lea ebx, [rax+rax]
    test ecx, ecx
    jle .L55
.L50:
    mov esi, ecx
    jmp .L44
    align 16
    align 8
.L48:
    add eax, r10d
    pop rbx
    pop rbp
    cdqe
    movzx eax, word 32[r11+rax*2]
    ret
    align 16
tinf_inflate_block_data:
    push r15
    mov r15, rsi
    push r14
    push r13
    push r12
    lea r12, [length_base_4]
    push rbp
    lea rbp, 2[rsi]
    push rbx
    mov rbx, rdx
    align 16
    align 8
.L57:
    mov ecx, dword 20[rdi]
    xor eax, eax
    mov r11, rbp
    xor r10d, r10d
    lea r9d, [rax+rax]
    test ecx, ecx
    jg .L74
    align 16
    align 8
.L89:
    mov esi, ecx
    lea eax, 8[rcx]
    mov r8, qword 8[rdi]
    neg esi
    and esi, -8
    add esi, eax
    jmp .L61
    align 64
    align 16
    align 8
.L87:
    lea r13, 1[rdx]
    mov qword [rdi], r13
    movzx edx, byte [rdx]
    mov dword 20[rdi], eax
    sal edx, cl
    mov ecx, eax
    or dword 16[rdi], edx
    cmp esi, eax
    je .L58
.L88:
    add eax, 8
.L61:
    mov rdx, qword [rdi]
    cmp rdx, r8
    jne .L87
    mov dword 24[rdi], 1
    mov ecx, eax
    mov dword 20[rdi], eax
    cmp esi, eax
    jne .L88
.L58:
    mov eax, dword 16[rdi]
    lea ecx, -1[rsi]
    mov dword 20[rdi], ecx
    mov edx, eax
    and eax, 1
    shr edx, 1
    add eax, r9d
    mov dword 16[rdi], edx
    movzx edx, word [r11]
    cmp eax, edx
    jl .L62
    sub eax, edx
    add r11, 2
    add r10d, edx
    lea r9d, [rax+rax]
    test ecx, ecx
    jle .L89
.L74:
    mov esi, ecx
    jmp .L58
    align 16
    align 8
.L62:
    mov ecx, dword 24[rdi]
    test ecx, ecx
    jne .L64
    add eax, r10d
    cdqe
    movzx eax, word 32[r15+rax*2]
    mov edx, eax
    cmp eax, 255
    jg .L65
    mov rax, qword 40[rdi]
    cmp rax, qword 48[rdi]
    je .L71
    lea rcx, 1[rax]
    mov qword 40[rdi], rcx
    mov byte [rax], dl
    jmp .L57
.L65:
    cmp eax, 256
    je .L56
    cmp dword 608[r15], eax
    jl .L64
    cmp eax, 285
    jg .L64
    cmp dword 608[rbx], -1
    je .L64
    sub eax, 257
    lea rsi, [length_bits_3]
    xor r14d, r14d
    movzx esi, byte [rsi+rax]
    movzx r13d, word [r12+rax*2]
    test esi, esi
    jne .L90
.L69:
    mov rsi, rbx
    call tinf_decode_symbol
    cmp dword 608[rbx], eax
    jl .L64
    cmp eax, 29
    jg .L64
    mov eax, eax
    lea rsi, [dist_base_2]
    movzx r10d, word [rsi+rax*2]
    lea rsi, [dist_bits_1]
    movzx esi, byte [rsi+rax]
    xor eax, eax
    test esi, esi
    jne .L91
.L70:
    mov rcx, qword 40[rdi]
    movzx edx, r10w
    add edx, eax
    movsxd rsi, edx
    mov rax, rcx
    sub rax, qword 32[rdi]
    cmp rsi, rax
    jg .L64
    mov rax, qword 48[rdi]
    movzx r8d, r13w
    add r8d, r14d
    sub rax, rcx
    movsxd r9, r8d
    cmp rax, r9
    jl .L71
    test r8d, r8d
    jle .L72
    neg edx
    mov r8d, r8d
    xor eax, eax
    movsxd rdx, edx
    align 32
    align 16
    align 8
.L73:
    movzx esi, byte [rcx+rdx]
    add rdx, 1
    mov byte [rcx+rax], sil
    add rax, 1
    mov rcx, qword 40[rdi]
    cmp r8, rax
    jne .L73
.L72:
    add rcx, r9
    mov qword 40[rdi], rcx
    jmp .L57
.L90:
    call tinf_getbits
    mov r14d, eax
    jmp .L69
.L91:
    call tinf_getbits
    jmp .L70
.L64:
    mov ecx, -3
.L56:
    pop rbx
    mov eax, ecx
    pop rbp
    pop r12
    pop r13
    pop r14
    pop r15
    ret
.L71:
    mov ecx, -4
    pop rbx
    pop rbp
    mov eax, ecx
    pop r12
    pop r13
    pop r14
    pop r15
    ret
    align 16
tinf_init:
    ret
    align 16
tinf_uncompress:
    sub rsp, 1672
    mov eax, ecx
    pxor xmm6, xmm6
    mov qword 336[rsp], rdx
    add rdx, rax
    mov eax, dword [rsi]
    movdqa xmm3, xmm6
    mov qword 376[rsp], rdi
    mov qword 368[rsp], rdi
    add rdi, rax
    mov qword 1624[rsp], rbx
    mov qword 1656[rsp], r14
    mov qword 344[rsp], rdx
    mov dword 352[rsp], 0
    mov dword 360[rsp], 0
    mov qword 384[rsp], rdi
    mov qword 1664[rsp], r15
    xor r15d, r15d
    mov qword [rsp], rsi
    xor esi, esi
.L162:
    test esi, esi
    jg .L94
    mov rax, qword 336[rsp]
    mov ecx, esi
    xor r8d, r8d
    xor edx, edx
    mov rdi, qword 344[rsp]
    jmp .L96
    align 32
    align 16
    align 8
.L270:
    movzx edx, byte [rax]
    add rax, 1
    sal edx, cl
    add ecx, 8
    or r15d, edx
    mov edx, 1
    test ecx, ecx
    jg .L269
.L96:
    cmp rdi, rax
    jne .L270
    add ecx, 8
    mov r8d, 1
    test ecx, ecx
    jle .L96
.L269:
    mov ecx, esi
    neg ecx
    and ecx, -8
    lea esi, 8[rsi+rcx]
    test r8b, r8b
    je .L97
    mov dword 360[rsp], 1
.L97:
    test dl, dl
    je .L98
    mov dword 352[rsp], r15d
    mov qword 336[rsp], rax
.L98:
    mov r15d, dword 352[rsp]
.L94:
    mov edx, r15d
    lea edi, -1[rsi]
    shr edx, 1
    mov dword 352[rsp], edx
    cmp edi, 1
    jg .L99
    mov rax, qword 336[rsp]
    cmp qword 344[rsp], rax
    je .L164
    lea r8, 1[rax]
    movzx eax, byte [rax]
    mov ecx, edi
    sal eax, cl
    mov ecx, 1
    or edx, eax
    xor eax, eax
.L100:
    lea edi, 7[rsi]
    test al, al
    je .L101
    mov dword 360[rsp], 1
    align 16
    align 8
.L101:
    test cl, cl
    je .L102
    mov dword 352[rsp], edx
    mov qword 336[rsp], r8
.L102:
    mov edx, dword 352[rsp]
.L99:
    mov ecx, edx
    lea eax, -2[rdi]
    shr edx, 2
    and ecx, 3
    mov dword 352[rsp], edx
    mov dword 356[rsp], eax
    cmp ecx, 1
    je .L103
    cmp ecx, 2
    je .L104
    test ecx, ecx
    jne .L106
    mov rax, qword 344[rsp]
    mov rsi, qword 336[rsp]
    mov rdx, rax
    sub rdx, rsi
    cmp rdx, 3
    jle .L106
    movzx edx, word 2[rsi]
    movzx r9d, word [rsi]
    not edx
    mov rcx, r9
    cmp dx, r9w
    jne .L106
    lea r8, 4[rsi]
    sub rax, r8
    mov qword 336[rsp], r8
    cmp rax, r9
    jl .L106
    mov rdi, qword 376[rsp]
    mov rax, qword 384[rsp]
    sub rax, rdi
    cmp r9, rax
    jg .L165
    test r9d, r9d
    je .L110
    sub r9d, 1
    xor eax, eax
    align 32
    align 16
    align 8
.L111:
    movzx edx, byte 4[rsi+rax]
    mov byte [rdi+rax], dl
    add rax, 1
    cmp rax, rcx
    jne .L111
    lea rax, 1[r8+r9]
    mov qword 336[rsp], rax
    lea rax, 1[rdi+r9]
    mov qword 376[rsp], rax
.L110:
    mov qword 352[rsp], 0
.L112:
    and r15d, 1
    jne .L161
    mov esi, dword 356[rsp]
    mov r15d, dword 352[rsp]
    jmp .L162
    align 16
    align 8
.L164:
    mov r8, rax
    xor ecx, ecx
    mov eax, 1
    jmp .L100
.L130:
    mov dword 352[rsp], edx
    mov dword 356[rsp], ecx
    test r10b, r10b
    je .L133
    mov dword 360[rsp], 1
.L133:
    test dil, dil
    je .L134
    mov qword 336[rsp], rsi
.L134:
    mov edx, 19
    lea rsi, 16[rsp]
    lea rdi, 392[rsp]
    call tinf_build_tree
    test eax, eax
    jne .L260
    mov ebx, dword 1000[rsp]
    cmp ebx, -1
    jne .L271
.L260:
    mov rbp, qword 1632[rsp]
.L106:
    mov eax, -3
.L93:
    mov rbx, qword 1624[rsp]
    mov r14, qword 1656[rsp]
    mov r15, qword 1664[rsp]
    add rsp, 1672
    ret
.L104:
    cmp eax, 4
    jg .L108
    mov rcx, qword 336[rsp]
    cmp qword 344[rsp], rcx
    je .L166
    movzx esi, byte [rcx]
    lea r8, 1[rcx]
    mov ecx, eax
    sal esi, cl
    xor ecx, ecx
    or edx, esi
    mov esi, 1
.L116:
    lea eax, 6[rdi]
    test cl, cl
    je .L117
    mov dword 360[rsp], 1
    align 16
    align 8
.L117:
    test sil, sil
    je .L118
    mov dword 352[rsp], edx
    mov qword 336[rsp], r8
.L118:
    mov edx, dword 352[rsp]
.L108:
    mov r8d, edx
    lea esi, -5[rax]
    and edx, 31
    shr r8d, 5
    lea r11d, 257[rdx]
    mov dword 352[rsp], r8d
    cmp esi, 4
    jg .L119
    mov rdx, qword 336[rsp]
    cmp qword 344[rsp], rdx
    je .L167
    lea rdi, 1[rdx]
    movzx edx, byte [rdx]
    mov ecx, esi
    sal edx, cl
    mov ecx, 1
    or r8d, edx
    xor edx, edx
.L120:
    lea esi, 3[rax]
    test dl, dl
    je .L121
    mov dword 360[rsp], 1
    align 16
    align 8
.L121:
    test cl, cl
    je .L122
    mov dword 352[rsp], r8d
    mov qword 336[rsp], rdi
.L122:
    mov r8d, dword 352[rsp]
.L119:
    mov edi, r8d
    and r8d, 31
    lea ecx, -5[rsi]
    shr edi, 5
    lea eax, 1[r8]
    mov dword 352[rsp], edi
    mov dword 8[rsp], eax
    cmp ecx, 3
    jg .L123
    mov rax, qword 336[rsp]
    cmp qword 344[rsp], rax
    je .L168
    lea r8, 1[rax]
    movzx eax, byte [rax]
    mov edx, 1
    sal eax, cl
    or edi, eax
    xor eax, eax
.L124:
    lea ecx, 3[rsi]
    test al, al
    je .L125
    mov dword 360[rsp], 1
    align 16
    align 8
.L125:
    test dl, dl
    je .L126
    mov dword 352[rsp], edi
    mov qword 336[rsp], r8
.L126:
    mov edi, dword 352[rsp]
.L123:
    cmp r11d, 286
    seta al
    cmp dword 8[rsp], 30
    seta dl
    or al, dl
    jne .L106
    mov edx, edi
    xor eax, eax
    and edi, 15
    mov qword 1632[rsp], rbp
    lea r8, [clcidx_0]
    shr edx, 4
    sub ecx, 4
    xor r10d, r10d
    mov word 32[rsp], ax
    lea r9, 4[r8+rdi]
    mov rax, qword 336[rsp]
    xor edi, edi
    mov byte 34[rsp], 0
    mov rbp, qword 344[rsp]
    movups oword 16[rsp], xmm6
    jmp .L128
    align 16
    align 8
.L272:
    lea rsi, 1[rax]
    movzx eax, byte [rax]
    mov edi, 1
    sal eax, cl
    or edx, eax
.L129:
    add ecx, 8
.L132:
    movzx eax, byte [r8]
    mov ebx, edx
    add r8, 1
    shr edx, 3
    and ebx, 7
    sub ecx, 3
    mov byte 16[rsp+rax], bl
    cmp r8, r9
    je .L130
    mov rax, rsi
.L128:
    mov rsi, rax
    cmp ecx, 2
    jg .L132
    cmp rax, rbp
    jne .L272
    mov rsi, rbp
    mov r10d, 1
    jmp .L129
    align 16
    align 8
.L168:
    mov r8, rax
    xor edx, edx
    mov eax, 1
    jmp .L124
    align 16
    align 8
.L167:
    mov rdi, rdx
    xor ecx, ecx
    mov edx, 1
    jmp .L120
    align 16
    align 8
.L166:
    mov r8, rcx
    xor esi, esi
    mov ecx, 1
    jmp .L116
.L103:
    movdqa xmm1, oword [LC_2]
    mov eax, 8
    mov ecx, 112
    movups oword 408[rsp], xmm6
    movd xmm0, eax
    movdqa xmm2, oword [LC_0]
    mov eax, 4
    movups oword 392[rsp], xmm6
    movups oword 424[rsp], xmm1
    movd xmm8, eax
    movdqa xmm1, oword [LC_3]
    pshufd xmm0, xmm0, 0
    mov dword 406[rsp], 9961496
    pshufd xmm8, xmm8, 0
    lea r14, 336[rsp]
    lea rax, 472[rsp]
    movups oword 440[rsp], xmm1
    movdqa xmm7, xmm8
    movdqa xmm5, xmm0
    movdqa xmm1, oword [LC_4]
    mov word 410[rsp], cx
    lea rdx, 760[rsp]
    movups oword 456[rsp], xmm1
    movdqa xmm1, xmm2
    align 16
    align 8
.L113:
    movdqa xmm4, xmm1
    movdqa xmm10, xmm1
    movdqa xmm9, xmm1
    add rax, 16
    paddd xmm4, xmm7
    paddd xmm1, xmm5
    punpcklwd xmm10, xmm4
    punpckhwd xmm9, xmm4
    movdqa xmm12, xmm10
    movdqa xmm4, xmm10
    punpckhwd xmm4, xmm9
    punpcklwd xmm12, xmm9
    punpcklwd xmm12, xmm4
    movups oword -16[rax], xmm12
    cmp rax, rdx
    jne .L113
    mov ebx, 9437328
    movdqa xmm5, xmm8
    movdqa xmm4, xmm0
    movdqa xmm1, oword [LC_7]
    movd xmm7, ebx
    lea rax, 440[r14]
    lea rdx, 664[r14]
    movups oword 760[rsp], xmm1
    movdqa xmm1, xmm2
    pshufd xmm7, xmm7, 0
    align 16
    align 8
.L114:
    movdqa xmm2, xmm1
    movdqa xmm0, xmm1
    add rax, 16
    paddd xmm2, xmm5
    movdqa xmm14, xmm2
    movdqa xmm2, xmm1
    paddd xmm1, xmm4
    punpcklwd xmm0, xmm14
    punpckhwd xmm2, xmm14
    movdqa xmm11, xmm0
    punpcklwd xmm0, xmm2
    punpckhwd xmm11, xmm2
    punpcklwd xmm0, xmm11
    paddw xmm0, xmm7
    movups oword -16[rax], xmm0
    cmp rdx, rax
    jne .L114
    movdqa xmm0, oword [LC_9]
    mov edx, 32
    mov rdi, r14
    movups oword 1004[rsp], xmm6
    lea rsi, 392[rsp]
    mov word 1014[rsp], dx
    lea rdx, 1004[rsp]
    movups oword 1036[rsp], xmm0
    movdqa xmm0, oword [LC_10]
    mov dword 1000[rsp], 285
    movups oword 1052[rsp], xmm0
    movdqa xmm0, oword [LC_11]
    mov dword 1612[rsp], 29
    movups oword 1068[rsp], xmm0
    movdqa xmm0, oword [LC_12]
    movups oword 1020[rsp], xmm6
    movups oword 1084[rsp], xmm0
    call tinf_inflate_block_data
.L115:
    test eax, eax
    je .L112
    jmp .L93
.L271:
    mov eax, dword 8[rsp]
    mov dword 12[rsp], r11d
    lea r14, 336[rsp]
    mov qword 1640[rsp], r12
    mov qword 1648[rsp], r13
    lea r12d, [r11+rax]
    mov r13, rbp
    xor ebp, ebp
    align 16
    align 8
.L160:
    lea rsi, 392[rsp]
    mov rdi, r14
    call tinf_decode_symbol
    cmp ebx, eax
    jl .L268
    cmp eax, 17
    je .L136
    cmp eax, 18
    je .L137
    cmp eax, 16
    je .L138
    mov edi, eax
    mov ecx, 1
    mov eax, ebp
    xor esi, esi
    align 16
    align 8
.L139:
    add esi, eax
    align 16
    align 16
    align 8
.L159:
    mov r8d, eax
    add eax, 1
    mov byte 16[rsp+r8], dil
    cmp r8d, esi
    jne .L159
.L158:
    add ebp, ecx
    cmp ebp, r12d
    jb .L160
    mov r11d, dword 12[rsp]
    cmp byte 272[rsp], 0
    je .L268
    mov edx, r11d
    lea rsi, 16[rsp]
    lea rdi, 392[rsp]
    call tinf_build_tree
    test eax, eax
    jne .L268
    mov edx, dword 8[rsp]
    lea rsi, 16[rsp+r11]
    lea rdi, 1004[rsp]
    call tinf_build_tree
    test eax, eax
    jne .L268
    lea rdx, 1004[rsp]
    lea rsi, 392[rsp]
    mov rdi, r14
    call tinf_inflate_block_data
    mov rbp, qword 1632[rsp]
    mov r12, qword 1640[rsp]
    mov r13, qword 1648[rsp]
    jmp .L115
.L138:
    test ebp, ebp
    je .L268
    mov r10d, dword 356[rsp]
    lea eax, -1[rbp]
    mov edx, dword 352[rsp]
    movzx edi, byte 16[rsp+rax]
    cmp r10d, 1
    jg .L144
    mov rax, qword 336[rsp]
    mov r9d, edx
    mov ecx, r10d
    xor esi, esi
    xor r11d, r11d
    jmp .L146
    align 32
    align 16
    align 8
.L274:
    movzx esi, byte [rax]
    add rax, 1
    sal esi, cl
    add ecx, 8
    or r9d, esi
    mov esi, 1
    cmp ecx, 1
    jg .L273
.L146:
    cmp rax, r13
    jne .L274
    add ecx, 8
    mov r11d, 1
    cmp ecx, 1
    jle .L146
.L273:
    mov ecx, 1
    sub ecx, r10d
    and ecx, -8
    lea r10d, 8[r10+rcx]
    test r11b, r11b
    je .L147
    mov dword 360[rsp], 1
.L147:
    test sil, sil
    je .L144
    mov qword 336[rsp], rax
    mov edx, r9d
.L144:
    mov esi, edx
    mov eax, r12d
    shr edx, 2
    sub r10d, 2
    and esi, 3
    sub eax, ebp
    mov dword 352[rsp], edx
    lea ecx, 3[rsi]
    mov dword 356[rsp], r10d
    cmp eax, ecx
    jb .L268
    add esi, 2
    mov eax, ebp
    jmp .L139
.L137:
    mov r9d, dword 356[rsp]
    mov edx, dword 352[rsp]
    cmp r9d, 6
    jg .L141
    mov rax, qword 336[rsp]
    mov edi, edx
    mov ecx, r9d
    xor r10d, r10d
    xor esi, esi
    jmp .L154
    align 32
    align 16
    align 8
.L276:
    movzx esi, byte [rax]
    add rax, 1
    sal esi, cl
    add ecx, 8
    or edi, esi
    mov esi, 1
    cmp ecx, 6
    jg .L275
.L154:
    cmp rax, r13
    jne .L276
    add ecx, 8
    mov r10d, 1
    cmp ecx, 6
    jle .L154
.L275:
    mov ecx, 6
    sub ecx, r9d
    and ecx, -8
    lea r9d, 8[r9+rcx]
    test r10b, r10b
    je .L155
    mov dword 360[rsp], 1
.L155:
    test sil, sil
    je .L141
    mov qword 336[rsp], rax
    mov edx, edi
.L141:
    mov esi, edx
    mov eax, r12d
    shr edx, 7
    sub r9d, 7
    and esi, 127
    sub eax, ebp
    mov dword 352[rsp], edx
    lea ecx, 11[rsi]
    mov dword 356[rsp], r9d
    cmp eax, ecx
    jb .L268
    add esi, 10
    cmp esi, 14
    jbe .L173
    mov edx, ecx
    mov eax, ebp
    shr edx, 4
    lea rax, 16[rsp+rax]
    mov r9d, edx
    sal r9, 4
    lea rdi, [r9+rax]
    and r9d, 16
    je .L157
    movups oword [rax], xmm3
    add rax, 16
    cmp rdi, rax
    je .L255
    align 16
    align 16
    align 8
.L157:
    movups oword [rax], xmm3
    add rax, 32
    movups oword -16[rax], xmm3
    cmp rdi, rax
    jne .L157
.L255:
    sal edx, 4
    cmp ecx, edx
    je .L158
    lea eax, 0[rbp+rdx]
    sub esi, edx
    xor edi, edi
    jmp .L139
.L136:
    mov r9d, dword 356[rsp]
    mov edx, dword 352[rsp]
    cmp r9d, 2
    jg .L143
    mov rax, qword 336[rsp]
    mov edi, edx
    mov ecx, r9d
    xor r10d, r10d
    xor esi, esi
    jmp .L150
    align 32
    align 16
    align 8
.L278:
    movzx esi, byte [rax]
    add rax, 1
    sal esi, cl
    add ecx, 8
    or edi, esi
    mov esi, 1
    cmp ecx, 2
    jg .L277
.L150:
    cmp r13, rax
    jne .L278
    add ecx, 8
    mov r10d, 1
    cmp ecx, 2
    jle .L150
.L277:
    mov ecx, 2
    sub ecx, r9d
    and ecx, -8
    lea r9d, 8[r9+rcx]
    test r10b, r10b
    je .L151
    mov dword 360[rsp], 1
.L151:
    test sil, sil
    je .L143
    mov qword 336[rsp], rax
    mov edx, edi
.L143:
    mov esi, edx
    mov eax, r12d
    shr edx, 3
    sub r9d, 3
    and esi, 7
    sub eax, ebp
    mov dword 352[rsp], edx
    lea ecx, 3[rsi]
    mov dword 356[rsp], r9d
    cmp eax, ecx
    jb .L268
    add esi, 2
    mov eax, ebp
    xor edi, edi
    jmp .L139
.L268:
    mov rbp, qword 1632[rsp]
    mov r12, qword 1640[rsp]
    mov r13, qword 1648[rsp]
    jmp .L106
.L161:
    mov eax, dword 360[rsp]
    mov rbx, qword [rsp]
    test eax, eax
    jne .L106
    mov rdx, qword 376[rsp]
    sub rdx, qword 368[rsp]
    mov dword [rbx], edx
    jmp .L93
.L165:
    mov eax, -4
    jmp .L93
.L173:
    mov eax, ebp
    xor edi, edi
    jmp .L139
section .rodata
    align 16
clcidx_0:
    db 0x10, 0x11, 0x12, 0x00, 0x08, 0x07, 0x09, 0x06, 0x0a, 0x05, 0x0b, 0x04, 0x0c, 0x03, 0x0d, 0x02, 0x0e, 0x01, 0x0f
    align 16
dist_bits_1:
    db 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x02, 0x02, 0x03, 0x03, 0x04, 0x04, 0x05, 0x05, 0x06, 0x06, 0x07, 0x07, 0x08, 0x08, 0x09, 0x09, 0x0a, 0x0a, 0x0b, 0x0b, 0x0c, 0x0c, 0x0d, 0x0d
    align 32
dist_base_2:
    dw 1
    dw 2
    dw 3
    dw 4
    dw 5
    dw 7
    dw 9
    dw 13
    dw 17
    dw 25
    dw 33
    dw 49
    dw 65
    dw 97
    dw 129
    dw 193
    dw 257
    dw 385
    dw 513
    dw 769
    dw 1025
    dw 1537
    dw 2049
    dw 3073
    dw 4097
    dw 6145
    dw 8193
    dw 12289
    dw 16385
    dw 24577
    align 16
length_bits_3:
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x02, 0x02, 0x02, 0x02, 0x03, 0x03, 0x03, 0x03, 0x04, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x05, 0x00, 0x7f
    align 32
length_base_4:
    dw 3
    dw 4
    dw 5
    dw 6
    dw 7
    dw 8
    dw 9
    dw 10
    dw 11
    dw 13
    dw 15
    dw 17
    dw 19
    dw 23
    dw 27
    dw 31
    dw 35
    dw 43
    dw 51
    dw 59
    dw 67
    dw 83
    dw 99
    dw 115
    dw 131
    dw 163
    dw 195
    dw 227
    dw 258
    dw 0
section .rodata
    align 16
LC_0:
    dd 0
    dd 1
    dd 2
    dd 3
    align 16
LC_2:
    dw 256
    dw 257
    dw 258
    dw 259
    dw 260
    dw 261
    dw 262
    dw 263
    align 16
LC_3:
    dw 264
    dw 265
    dw 266
    dw 267
    dw 268
    dw 269
    dw 270
    dw 271
    align 16
LC_4:
    dw 272
    dw 273
    dw 274
    dw 275
    dw 276
    dw 277
    dw 278
    dw 279
    align 16
LC_7:
    dw 280
    dw 281
    dw 282
    dw 283
    dw 284
    dw 285
    dw 286
    dw 287
    align 16
LC_9:
    dw 0
    dw 1
    dw 2
    dw 3
    dw 4
    dw 5
    dw 6
    dw 7
    align 16
LC_10:
    dw 8
    dw 9
    dw 10
    dw 11
    dw 12
    dw 13
    dw 14
    dw 15
    align 16
LC_11:
    dw 16
    dw 17
    dw 18
    dw 19
    dw 20
    dw 21
    dw 22
    dw 23
    align 16
LC_12:
    dw 24
    dw 25
    dw 26
    dw 27
    dw 28
    dw 29
    dw 30
    dw 31
section .note.GNU
