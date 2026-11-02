#!/usr/bin/env python3
"""Cut the static fonts used by the ui2 interface from Google Sans Flex.

Qt 5.15 cannot set the axes of a variable font, so every type role of the
new interface is cut here as its own static font with its own family name.
Tabular figures are baked into the cmap because Qt 5 cannot turn on
OpenType features either.

Needs fontTools and skia-pathops (pip install fonttools skia-pathops).

Usage:
    python tools/build_ui2_fonts.py path/to/GoogleSansFlex[ROND,opsz,slnt,wdth,wght].ttf

The source font and its OFL.txt come from
https://github.com/google/fonts/tree/main/ofl/googlesansflex
The fonts are renamed "Pulse ..." as the Open Font License asks of
modified versions.
"""

import os
import sys

from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "src", "ui2", "fonts")

HERO_CHARS = "0123456789:.,-+% −"
TEXT_CODEPOINTS = (
    list(range(0x20, 0x7F))
    + list(range(0xA0, 0x100))
    + [0x2009, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2026, 0x202F, 0x2191, 0x2193, 0x2212]
)

# family name, file name, axis location, characters
CUTS = [
    ("Pulse Display", "PulseDisplay.ttf", {"opsz": 144, "wdth": 112, "wght": 640, "ROND": 0}, None),
    ("Pulse Celebrate", "PulseCelebrate.ttf", {"opsz": 144, "wdth": 125, "wght": 820, "ROND": 100}, None),
    ("Pulse Tall", "PulseTall.ttf", {"opsz": 36, "wdth": 70, "wght": 640, "ROND": 0}, None),
    ("Pulse Text", "PulseText.ttf", {"opsz": 18, "wdth": 104, "wght": 400, "ROND": 20}, None),
    ("Pulse Text Medium", "PulseTextMedium.ttf", {"opsz": 18, "wdth": 104, "wght": 500, "ROND": 20}, None),
    ("Pulse Text Semibold", "PulseTextSemibold.ttf", {"opsz": 18, "wdth": 104, "wght": 600, "ROND": 20}, None),
]
# the ride hero numeral gets heavier with every zone: 550, 580 ... 730
for zone in range(1, 8):
    weight = 550 + (zone - 1) * 30
    CUTS.append(("Pulse Hero " + str(zone), "PulseHero" + str(zone) + ".ttf",
                 {"opsz": 144, "wdth": 112, "wght": weight, "ROND": 0}, HERO_CHARS))


def tnum_map(font):
    """Glyph substitutions of the tnum feature, as {glyph: tabular glyph}."""
    gsub = font["GSUB"].table
    lookup_ids = set()
    for record in gsub.FeatureList.FeatureRecord:
        if record.FeatureTag == "tnum":
            lookup_ids.update(record.Feature.LookupListIndex)
    mapping = {}
    for index in sorted(lookup_ids):
        lookup = gsub.LookupList.Lookup[index]
        for sub in lookup.SubTable:
            if lookup.LookupType == 7:
                sub = sub.ExtSubTable
            if hasattr(sub, "mapping"):
                mapping.update(sub.mapping)
    return mapping


def bake_tabular_figures(font):
    mapping = tnum_map(font)
    for table in font["cmap"].tables:
        for codepoint, glyph in list(table.cmap.items()):
            if glyph in mapping:
                table.cmap[codepoint] = mapping[glyph]


def rename(font, family):
    postscript = family.replace(" ", "") + "-Regular"
    name = font["name"]
    for name_id in (16, 17, 21, 22, 25):
        name.removeNames(nameID=name_id)
    for name_id, value in ((1, family), (2, "Regular"), (3, postscript), (4, family), (6, postscript)):
        name.setName(value, name_id, 3, 1, 0x409)
        name.setName(value, name_id, 1, 0, 0)
    os2 = font["OS/2"]
    os2.usWeightClass = 400
    os2.usWidthClass = 5
    os2.fsSelection = (os2.fsSelection & ~0b1100001) | 0b1000000


def cut(source, family, file_name, location, chars):
    font = TTFont(source)
    location = dict(location)
    location["slnt"] = 0
    # overlaps of the variable outlines would show as spikes once the font is static
    font = instancer.instantiateVariableFont(font, location, overlap=instancer.OverlapMode.REMOVE)
    bake_tabular_figures(font)

    options = Options()
    options.layout_features = ["kern", "liga", "calt", "ccmp", "locl", "mark", "mkmk"]
    options.hinting = False
    options.name_IDs = ["*"]
    options.notdef_outline = True
    subsetter = Subsetter(options)
    if chars is None:
        subsetter.populate(unicodes=TEXT_CODEPOINTS)
    else:
        subsetter.populate(text=chars)
    subsetter.subset(font)

    rename(font, family)
    path = os.path.join(OUT_DIR, file_name)
    font.save(path)
    print(file_name, os.path.getsize(path), "bytes")


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 1
    os.makedirs(OUT_DIR, exist_ok=True)
    for family, file_name, location, chars in CUTS:
        cut(sys.argv[1], family, file_name, location, chars)
    return 0


if __name__ == "__main__":
    sys.exit(main())
