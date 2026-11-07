default rel

global font_glyph_data
global font_glyph_for_char
global FONT_WIDTH
global FONT_HEIGHT
global FONT_BPG

%define FONT_WIDTH  10
%define FONT_HEIGHT 20
%define FONT_BPG    40

section .rodata
font_data:
    incbin "assets/nerd_font.bin"

section .text

font_glyph_data:
    imul    rax, rdi, FONT_BPG
    lea     rdx, [font_data + 8]
    add     rax, rdx
    ret

font_glyph_for_char:
    mov     r8d, [font_data]
    mov     r9d, [font_data + 4]
    test    r9d, r9d
    jz      .fallback

    imul    rax, r8, FONT_BPG
    lea     rsi, [font_data + 8]
    add     rsi, rax

    xor     eax, eax
    mov     edx, r9d
    dec     edx

.bin_search:
    cmp     eax, edx
    ja      .fallback
    lea     ecx, [rax + rdx]
    shr     ecx, 1
    mov     r10d, [rsi + rcx*8]
    cmp     edi, r10d
    je      .found
    jb      .left
    lea     eax, [rcx + 1]
    jmp     .bin_search
.left:
    lea     edx, [rcx - 1]
    jmp     .bin_search

.found:
    mov     eax, [rsi + rcx*8 + 4]
    ret

.fallback:
    mov     edi, '?'
    jmp     font_glyph_for_char
