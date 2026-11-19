"""Freeze Doto at its heaviest weight, add Cyrillic, shrink every dot, add tracking, rename.

Usage: doto-round.py <Doto.ttf> <output.ttf> <family name> <dot scale> <roundness> <tracking> <cyrillic.txt>
- dot scale below 1 makes each dot smaller around its own center, so the gaps between dots grow
  while the dot grid, and with it the glyph size, stays the same;
- roundness is Doto's ROND axis: 0 gives square dots, 100 round ones;
- tracking is added to every advance width, in font units (a digit is 600 wide);
- cyrillic.txt lists the Cyrillic letters Doto lacks, as copies of Latin glyphs or dot grids
  (format in its header).
"""
import copy
import sys
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

src, dst, family = sys.argv[1], sys.argv[2], sys.argv[3]
dot_scale, roundness, tracking = float(sys.argv[4]), float(sys.argv[5]), int(sys.argv[6])
extra_glyphs = sys.argv[7]

ADVANCE = 600  # Doto is monospaced
PITCH = 100  # distance between dot centers
FIRST_COLUMN = 50  # x of the first dot column


def parse_glyphs(path):
    """Return [(char, latin_source or None, top_y or None, rows)] from the glyph file."""
    entries, current = [], None
    for raw in open(path, encoding="utf-8"):
        line = raw.strip()
        if line.startswith("="):
            char, arg = line[1:].split()
            current = (char, None, int(arg), []) if arg.lstrip("-").isdigit() else (char, arg, None, [])
            entries.append(current)
        elif line and not line.startswith("# ") and current is not None:
            current[3].append(line)
    return entries


def dot_outline(font):
    """The contour of one Doto dot, relative to its center, taken from the period."""
    glyf, cmap = font["glyf"], font.getBestCmap()
    period = glyf[cmap[ord(".")]]
    coords, flags = period.getCoordinates(glyf)[0], period.flags
    end = period.endPtsOfContours[0]
    xs = [coords[i][0] for i in range(end + 1)]
    ys = [coords[i][1] for i in range(end + 1)]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    return [(coords[i][0] - cx, coords[i][1] - cy, flags[i] & 1) for i in range(end + 1)]


def draw_grid(outline, top, rows):
    pen = TTGlyphPen(None)
    for r, row in enumerate(rows):
        for c, cell in enumerate(row):
            if cell != "#":
                continue
            cx, cy = FIRST_COLUMN + c * PITCH, top - r * PITCH
            points = [(round(cx + x), round(cy + y), on) for x, y, on in outline]
            # Replay the TrueType contour: runs of off-curve points end at the next on-curve one.
            start = next(i for i, p in enumerate(points) if p[2])
            points = points[start:] + points[:start]
            pen.moveTo(points[0][:2])
            pending = []
            for x, y, on in points[1:] + points[:1]:
                if on:
                    if pending:
                        pen.qCurveTo(*pending, (x, y))
                    else:
                        pen.lineTo((x, y))
                    pending = []
                else:
                    pending.append((x, y))
            if pending:
                pen.qCurveTo(*pending, points[0][:2])
            pen.closePath()
    return pen.glyph()


def add_glyphs(font, path):
    glyf, hmtx, cmap = font["glyf"], font["hmtx"], font.getBestCmap()
    outline = dot_outline(font)
    order = font.getGlyphOrder()
    for char, latin, top, rows in parse_glyphs(path):
        name = f"uni{ord(char):04X}"
        if latin is not None:
            glyph = copy.deepcopy(glyf[cmap[ord(latin)]])
        else:
            glyph = draw_grid(outline, top, rows)
        glyph.recalcBounds(glyf)
        order.append(name)
        glyf[name] = glyph
        hmtx.metrics[name] = (ADVANCE, getattr(glyph, "xMin", 0))
        for table in font["cmap"].tables:
            if table.isUnicode():
                table.cmap[ord(char)] = name
    font.setGlyphOrder(order)
    glyf.glyphOrder = order


font = instantiateVariableFont(TTFont(src), {"wght": 900, "ROND": roundness})
add_glyphs(font, extra_glyphs)

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

hmtx = font["hmtx"]
for name, (advance, lsb) in hmtx.metrics.items():
    hmtx.metrics[name] = (max(0, advance + tracking), lsb)

names = font["name"]
for name_id in (16, 17, 21, 22):  # typographic and WWS names would override the family below
    names.removeNames(nameID=name_id)
names.setName(family, 1, 3, 1, 0x409)
names.setName("Regular", 2, 3, 1, 0x409)
names.setName(f"{family} Regular", 4, 3, 1, 0x409)
names.setName(family.replace(" ", "") + "-Regular", 6, 3, 1, 0x409)
font["OS/2"].usWeightClass = 400
font.save(dst)
