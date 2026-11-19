"""Freeze Doto at its heaviest weight with round dots, shrink every dot and rename the family.

Usage: doto-round.py <Doto.ttf> <output.ttf> <family name> <dot scale>
A dot scale below 1 makes each dot smaller around its own center, so the gaps between dots grow
while the dot grid, and with it the glyph size and spacing, stays the same.
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

src, dst, family, dot_scale = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])

font = instantiateVariableFont(TTFont(src), {"wght": 900, "ROND": 100})

glyf = font["glyf"]
for name in font.getGlyphOrder():
    glyph = glyf[name]
    if glyph.isComposite() or glyph.numberOfContours <= 0:
        continue  # composites reuse simple glyphs, which are scaled already
    coords = glyph.coordinates
    start = 0
    for end in glyph.endPtsOfContours:
        xs = [coords[i][0] for i in range(start, end + 1)]
        ys = [coords[i][1] for i in range(start, end + 1)]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        for i in range(start, end + 1):
            x, y = coords[i]
            coords[i] = (round(cx + (x - cx) * dot_scale), round(cy + (y - cy) * dot_scale))
        start = end + 1
    glyph.recalcBounds(glyf)

names = font["name"]
for name_id in (16, 17, 21, 22):  # typographic and WWS names would override the family below
    names.removeNames(nameID=name_id)
names.setName(family, 1, 3, 1, 0x409)
names.setName("Regular", 2, 3, 1, 0x409)
names.setName(f"{family} Regular", 4, 3, 1, 0x409)
names.setName(family.replace(" ", "") + "-Regular", 6, 3, 1, 0x409)
font["OS/2"].usWeightClass = 400
font.save(dst)
