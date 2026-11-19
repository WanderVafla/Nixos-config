"""Freeze Doto at its heaviest weight with round dots and give it its own family name."""
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

src, dst, family = sys.argv[1], sys.argv[2], sys.argv[3]
font = instantiateVariableFont(TTFont(src), {"wght": 900, "ROND": 100})
names = font["name"]
for name_id in (16, 17, 21, 22):  # typographic and WWS names would override the family below
    names.removeNames(nameID=name_id)
names.setName(family, 1, 3, 1, 0x409)
names.setName("Regular", 2, 3, 1, 0x409)
names.setName(f"{family} Regular", 4, 3, 1, 0x409)
names.setName(family.replace(" ", "") + "-Regular", 6, 3, 1, 0x409)
font["OS/2"].usWeightClass = 400
font.save(dst)
