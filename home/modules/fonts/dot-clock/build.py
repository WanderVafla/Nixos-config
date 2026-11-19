"""Build the Dot Clock font from dot grids.

Usage: build.py <glyphs.txt> <output.ttf> <family name> <dot scale> <tracking>
- glyphs.txt holds one 9-row grid per character ("#" is a dot), see its header;
- dot scale is the dot diameter relative to a grid cell (1.0 makes neighbours touch);
- tracking is extra space after every character, in font units (a cell is 100);
  characters are already GAP cells apart without it.
"""
import math
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

CELL = 100  # font units per grid cell
ROWS = 9
GAP = 2  # empty cells between two characters, split evenly on both sides


def parse(path):
    """Return {char: [row strings]} in file order."""
    glyphs, char, rows = {}, None, []
    for raw in open(path, encoding="utf-8"):
        line = raw.strip()
        if line.startswith("="):
            if char is not None:
                glyphs[char] = rows
            name = line[1:].strip()
            char, rows = (" " if name == "space" else name), []
        elif line and not line.startswith("# ") and char is not None:  # "# " starts a comment
            rows.append(line)
    if char is not None:
        glyphs[char] = rows
    for c, rows in glyphs.items():
        if len(rows) != ROWS or len({len(r) for r in rows}) != 1:
            sys.exit(f"glyph {c!r}: needs {ROWS} rows of equal width, got {[len(r) for r in rows]}")
    return glyphs


def draw_dot(pen, cx, cy, r):
    """A circle as one TrueType contour of 8 off-curve points, clockwise."""
    far = r / math.cos(math.pi / 8)
    points = [(round(cx + far * math.cos(-k * math.pi / 4)), round(cy + far * math.sin(-k * math.pi / 4)))
              for k in range(8)]
    pen.qCurveTo(*points, None)
    pen.closePath()


def glyph_name(c):
    return {" ": "space", ":": "colon", ".": "period", "-": "hyphen", "/": "slash"}.get(c, f"uni{ord(c):04X}")


def main():
    src, dst, family = sys.argv[1], sys.argv[2], sys.argv[3]
    dot_scale, tracking = float(sys.argv[4]), int(sys.argv[5])
    glyphs = parse(src)
    radius = CELL / 2 * dot_scale

    order, cmap, outlines, metrics = [".notdef"], {}, {}, {}
    empty = TTGlyphPen(None)
    outlines[".notdef"], metrics[".notdef"] = empty.glyph(), (CELL * 4, 0)

    for c, rows in glyphs.items():
        name = glyph_name(c)
        pen = TTGlyphPen(None)
        for row_index, row in enumerate(rows):
            for col, cell in enumerate(row):
                if cell == "#":
                    cx = (col + GAP / 2) * CELL + CELL / 2
                    cy = (ROWS - 1 - row_index) * CELL + CELL / 2
                    draw_dot(pen, cx, cy, radius)
        width = len(rows[0])
        order.append(name)
        cmap[ord(c)] = name
        outlines[name] = pen.glyph()
        metrics[name] = ((width + GAP) * CELL + tracking, int(GAP / 2 * CELL))

    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(outlines)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ROWS * CELL + 50, descent=-150)
    style = "Regular"
    fb.setupNameTable({
        "familyName": family,
        "styleName": style,
        "uniqueFontIdentifier": f"{family} {style}",
        "fullName": f"{family} {style}",
        "psName": family.replace(" ", "") + "-" + style,
        "version": "Version 1.0",
    })
    fb.setupOS2(sTypoAscender=ROWS * CELL + 50, sTypoDescender=-150, usWinAscent=ROWS * CELL + 50,
                usWinDescent=150, sCapHeight=ROWS * CELL, sxHeight=ROWS * CELL, usWeightClass=400)
    fb.setupPost()
    fb.save(dst)


if __name__ == "__main__":
    main()
