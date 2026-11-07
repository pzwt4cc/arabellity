import struct
from fontTools.ttLib import TTFont
from PIL import Image, ImageFont, ImageDraw

FONT_PATH = '/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Medium.ttf'
OUT_PATH = 'assets/nerd_font.bin'
WIDTH = 10
HEIGHT = 20
FONT_SIZE = 16

font = TTFont(FONT_PATH)
cmap = font.getBestCmap()
pfont = ImageFont.truetype(FONT_PATH, FONT_SIZE)

unique_glyphs = {}
glyph_data = bytearray()
mapping = []

# Glyph 0: blank (space)
blank = bytes(WIDTH * HEIGHT)
unique_glyphs[blank] = 0
glyph_data.extend(blank)

# Glyph 1: '?' fallback
im_q = Image.new('L', (WIDTH, HEIGHT), 0)
d_q = ImageDraw.Draw(im_q)
d_q.text((0, 0), '?', font=pfont, fill=255)
q_bytes = bytes(im_q.tobytes())
unique_glyphs[q_bytes] = 1
glyph_data.extend(q_bytes)

for cp in sorted(cmap.keys()):
    if cp > 0x10ffff or (0xd800 <= cp <= 0xdfff):
        continue
    im = Image.new('L', (WIDTH, HEIGHT), 0)
    d = ImageDraw.Draw(im)
    try:
        d.text((0, 0), chr(cp), font=pfont, fill=255)
    except:
        continue
    raw = bytes(im.tobytes())
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
