#!/usr/bin/env python3
"""Words in a real font, as outlines for the fill piece: one line of numbers (counts and x y pairs in sixteenths
of a pixel) per character, each prefixed so loader/render can take it.

  text_path.py <font.ttf> <pixel size> <x> <baseline y> <colour hex> <stem> <words...>
Curves are flattened to short lines here; the fill piece only ever sees corner points.
"""
import struct, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import font_table as ft

def main():
    font, size, x, base, colour, stem = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]), sys.argv[5], sys.argv[6]
    words = ' '.join(sys.argv[7:]); data = open(font, 'rb').read(); t = ft.tables(data)
    upm = struct.unpack_from('>H', data, t['head'][0] + 18)[0]; long_loca = struct.unpack_from('>h', data, t['head'][0] + 50)[0]
    glyphs = struct.unpack_from('>H', data, t['maxp'][0] + 4)[0]
    loca = [v if long_loca else v * 2 for v in struct.unpack_from('>%d%s' % (glyphs + 1, 'I' if long_loca else 'H'), data, t['loca'][0])]
    hmetrics = struct.unpack_from('>H', data, t['hhea'][0] + 34)[0]; lookup = ft.cmap(data, t); scale = size / float(upm)
    for ch in words:
        g = lookup(ord(ch)); adv = struct.unpack_from('>H', data, t['hmtx'][0] + 4 * min(g, hmetrics - 1))[0]
        out = []
        for contour in ft.glyph_contours(data, t, loca, g):
            pts = ft.flatten(contour, scale)
            if len(pts) < 3: continue
            pts = pts[:-1] if pts[0] == pts[-1] else pts
            fixed = [(int(round((x + px) * 16)), int(round((base - py) * 16))) for px, py in pts]
            if len(fixed) > 256: fixed = fixed[::(len(fixed) // 256) + 1]
            out.append(str(len(fixed))); out.extend('%d %d' % q for q in fixed)
        if out: print(stem, 'fill_path', colour, ' '.join(out))
        x += adv * scale
main()
