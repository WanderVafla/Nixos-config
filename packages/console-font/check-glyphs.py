# Fails when text the greeter draws uses characters missing from a PSF2 console font.
# Usage: check-glyphs.py FONT.psf NAME=TEXT...   (names "dot" and "cursor" must be one character)
import gzip
import struct
import sys

SINGLE = {"dot", "cursor"}


def font_chars(path):
    data = open(path, "rb").read()
    if data[:2] == b"\x1f\x8b":
        data = gzip.decompress(data)
    _, _, header_size, flags, count, char_size, _, _ = struct.unpack("<4s7I", data[:32])
    if not flags & 1:
        sys.exit(f"{path} has no Unicode table")
    table = data[header_size + count * char_size:]
    return set(table.replace(b"\xfe", b"\xff").decode("utf-8", "ignore")) - {"￿"}


def main():
    available = font_chars(sys.argv[1])
    errors = []
    for pair in sys.argv[2:]:
        name, _, text = pair.partition("=")
        if name in SINGLE and len(text) != 1:
            errors.append(f"{name} must be exactly one character, got {text!r}")
        missing = sorted({c for c in text if c != " " and c not in available})
        if missing:
            errors.append(f"{name} uses characters the console font lacks: {' '.join(missing)}")
    if errors:
        sys.exit("dot-greeter: " + "\n  ".join(errors))


if __name__ == "__main__":
    main()
