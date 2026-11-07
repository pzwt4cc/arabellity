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
    incbin "assets/ter-v20n.psf"

%include "cyr_table.inc"

section .text

font_glyph_data:
    imul    rax, rdi, FONT_BPG
    lea     rdx, [font_data + 32]
    add     rax, rdx
    ret

font_glyph_for_char:
    cmp     edi, 0x80
    jb      .ascii
    cmp     edi, 0x400
    jb      .fallback
    cmp     edi, 0x460
    jae     .fallback
    sub     edi, 0x400
    lea     rax, [cyr_to_glyph]
    movzx   eax, word [rax + rdi*2]
    ret
.ascii:
    mov     eax, edi
    ret
.fallback:
    mov     eax, '?'
    ret
