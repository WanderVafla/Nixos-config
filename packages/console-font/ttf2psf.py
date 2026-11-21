# Builds a 16x32 PSF2 console font from a TrueType font.
# The base PSF (Terminus) supplies the 512 glyph slots and their Unicode table; every slot whose
# character exists in the TTF is redrawn from the TTF as a 1-bit bitmap. Box drawing and block
# elements stay from the base font, because they have to tile across cells.
# Usage: ttf2psf.py FONT.ttf BASE.psf.gz OUT.psf
import gzip
import struct
import sys

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 16, 32
ROW_BYTES = (WIDTH + 7) // 8
PSF2_MAGIC = b"\x72\xb5\x4a\x86"
PSF2_HAS_UNICODE_TABLE = 1
KEEP_FROM_BASE = range(0x2500, 0x25A0)  # box drawing and block elements


def read_base(path):
    data = gzip.decompress(open(path, "rb").read())
    magic, _, header_size, flags, count, char_size, height, width = struct.unpack("<4s7I", data[:32])
    if magic != PSF2_MAGIC or not flags & PSF2_HAS_UNICODE_TABLE:
        sys.exit("base font must be PSF2 with a Unicode table")
    if (width, height) != (WIDTH, HEIGHT):
        sys.exit(f"base font must be {WIDTH}x{HEIGHT}, got {width}x{height}")
    glyphs = [data[header_size + i * char_size: header_size + (i + 1) * char_size] for i in range(count)]
    # One entry per glyph: UTF-8 characters (and 0xFE sequences), ended by 0xFF.
    table = data[header_size + count * char_size:].split(b"\xff")[:count]
    return glyphs, table


def first_char(entry):
    text = entry.split(b"\xfe")[0].decode("utf-8", "ignore")
    return text[0] if text else None


class Renderer:
    def __init__(self, path):
        self.cmap = TTFont(path).getBestCmap()
        probe = ImageFont.truetype(path, 100)
        # Size the font so one advance is exactly one cell wide.
        self.font = ImageFont.truetype(path, int(WIDTH * 100 / probe.getlength("0")))
        ascent, descent = self.font.getmetrics()
        self.baseline = (HEIGHT - (ascent + descent)) // 2 + ascent

    def covers(self, char):
        return ord(char) in self.cmap and ord(char) not in KEEP_FROM_BASE

    def glyph(self, char):
        image = Image.new("1", (WIDTH, HEIGHT))
        draw = ImageDraw.Draw(image)
        draw.fontmode = "1"
        draw.text((0, self.baseline), char, font=self.font, fill=1, anchor="ls")
        out = bytearray()
        for y in range(HEIGHT):
            for byte in range(ROW_BYTES):
                bits = 0
                for bit in range(8):
                    x = byte * 8 + bit
                    if x < WIDTH and image.getpixel((x, y)):
                        bits |= 0x80 >> bit
                out.append(bits)
        return bytes(out)


def main():
    ttf, base, out = sys.argv[1:4]
    glyphs, table = read_base(base)
    renderer = Renderer(ttf)
    redrawn = 0
    for i, entry in enumerate(table):
        char = first_char(entry)
        if char and renderer.covers(char):
            glyphs[i] = renderer.glyph(char)
            redrawn += 1
    header = struct.pack(
        "<4s7I", PSF2_MAGIC, 0, 32, PSF2_HAS_UNICODE_TABLE, len(glyphs), HEIGHT * ROW_BYTES, HEIGHT, WIDTH
    )
    with open(out, "wb") as f:
        f.write(header + b"".join(glyphs) + b"".join(entry + b"\xff" for entry in table))
    print(f"redrew {redrawn} of {len(glyphs)} glyphs from {ttf}")


if __name__ == "__main__":
    main()
