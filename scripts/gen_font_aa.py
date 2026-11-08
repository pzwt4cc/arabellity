import struct
from fontTools.ttLib import TTFont
from PIL import Image, ImageFont, ImageDraw

FONT_PATHS = [
    ('/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Medium.ttf', 15),
    ('/usr/share/fonts/TTF/NotoSansMNerdFontMono-Medium.ttf', 15),
    ('/usr/share/fonts/TTF/DejaVuSansMono.ttf', 14),
    ('/usr/share/fonts/IosevkaNerdFont/IosevkaNerdFontMono-Medium.ttf', 16),
    ('/usr/share/fonts/noto/NotoSansMath-Regular.ttf', 14),
    ('/usr/share/fonts/noto/NotoSansSymbols-Medium.ttf', 14),
    ('/usr/share/fonts/noto/NotoSansSymbols2-Regular.ttf', 14),
]

OUT_PATH = 'assets/nerd_font.bin'
WIDTH = 10
HEIGHT = 20

loaded_fonts = []
for path, sz in FONT_PATHS:
    try:
        tt = TTFont(path)
        cmap = tt.getBestCmap()
        pf = ImageFont.truetype(path, sz)
        loaded_fonts.append((cmap, pf))
    except Exception as e:
        print(f"Skipping {path}: {e}")

all_codepoints = {}
for cmap, pf in reversed(loaded_fonts):
    for cp in cmap.keys():
        if cp <= 0x10ffff and not (0xd800 <= cp <= 0xdfff):
            all_codepoints[cp] = pf

unique_glyphs = {}
glyph_data = bytearray()
mapping = []

blank = bytes(WIDTH * HEIGHT)
unique_glyphs[blank] = 0
glyph_data.extend(blank)

def render_char(ch, cp, pfont):
    im = Image.new('L', (WIDTH, HEIGHT), 0)
    d = ImageDraw.Draw(im)
    d.text((0, 0), ch, font=pfont, fill=255)
    raw = bytearray(im.tobytes())
    if 0x2500 <= cp <= 0x257F:
        for y in range(HEIGHT):
            if raw[y * WIDTH + 8] > 128:
                raw[y * WIDTH + 9] = raw[y * WIDTH + 8]
    return bytes(raw)

q_bytes = render_char('?', 63, loaded_fonts[0][1])
unique_glyphs[q_bytes] = 1
glyph_data.extend(q_bytes)

for cp in sorted(all_codepoints.keys()):
    pfont = all_codepoints[cp]
    try:
        raw = render_char(chr(cp), cp, pfont)
    except:
        continue
    if raw not in unique_glyphs:
        idx = len(unique_glyphs)
        unique_glyphs[raw] = idx
        glyph_data.extend(raw)
    else:
        idx = unique_glyphs[raw]
    mapping.append((cp, idx))

mapping_dict = dict(mapping)
mapping_dict[32] = 0
mapping_dict[63] = 1
mapping = sorted(mapping_dict.items())

glyph_count = len(unique_glyphs)
map_count = len(mapping)

print(f"Generating {OUT_PATH}:")
print(f"  Unique glyphs: {glyph_count}")
print(f"  Unicode mappings: {map_count}")

with open(OUT_PATH, 'wb') as f:
    f.write(struct.pack('<II', glyph_count, map_count))
    f.write(glyph_data)
    for cp, idx in mapping:
        f.write(struct.pack('<II', cp, idx))

print("Done. File size:", len(glyph_data) + len(mapping)*8 + 8, "bytes")
