#!/usr/bin/env python3
"""Turn a TrueType font into a table of letter shapes at one pixel size.

Reads the font's outlines itself (no font library): the cmap, loca, glyf, hmtx, head and hhea tables; simple and
composite glyphs; quadratic curves flattened to short lines; coverage measured with 4x4 samples per pixel and the
non-zero winding rule. Output: a C header for the text piece, and optionally a PNG sheet to look at.

  font_table.py <font.ttf> <pixel size> <out.h> [sheet.png]
"""
import struct, sys, zlib

def tables(data):
    count = struct.unpack_from('>H', data, 4)[0]; out = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack_from('>4sIII', data, 12 + 16 * i); out[tag.decode()] = (offset, length)
    return out

def cmap(data, t):
    base = t['cmap'][0]; n = struct.unpack_from('>H', data, base + 2)[0]; best = None
    for i in range(n):
        plat, enc, off = struct.unpack_from('>HHI', data, base + 4 + 8 * i); fmt = struct.unpack_from('>H', data, base + off)[0]
        if fmt == 4 and (plat, enc) in ((3, 1), (0, 3), (0, 4)): best = base + off
    if best is None: raise SystemExit('no usable character map')
    segs = struct.unpack_from('>H', data, best + 6)[0] // 2; p = best + 14
    ends = struct.unpack_from('>%dH' % segs, data, p); p += 2 * segs + 2
    starts = struct.unpack_from('>%dH' % segs, data, p); p += 2 * segs
    deltas = struct.unpack_from('>%dh' % segs, data, p); p += 2 * segs
    ro = p; offsets = struct.unpack_from('>%dH' % segs, data, p)
    def lookup(c):
        for i in range(segs):
            if starts[i] <= c <= ends[i]:
                if offsets[i] == 0: return (c + deltas[i]) & 0xffff
                g = struct.unpack_from('>H', data, ro + 2 * i + offsets[i] + 2 * (c - starts[i]))[0]
                return (g + deltas[i]) & 0xffff if g else 0
        return 0
    return lookup

def glyph_contours(data, t, loca, index, depth=0):
    """Contours of one glyph in font units: a list of lists of (x, y, on_curve)."""
    start, end = loca[index], loca[index + 1]
    if start == end or depth > 4: return []
    p = t['glyf'][0] + start; n = struct.unpack_from('>h', data, p)[0]; p += 10
    if n >= 0:
        ends = struct.unpack_from('>%dH' % n, data, p); p += 2 * n
        p += 2 + struct.unpack_from('>H', data, p)[0]; total = ends[-1] + 1 if n else 0
        flags = []
        while len(flags) < total:
            f = data[p]; p += 1; flags.append(f)
            if f & 8:
                r = data[p]; p += 1; flags.extend([f] * r)
        def coords(short, same):
            nonlocal p; out = []; v = 0
            for f in flags:
                if f & short:
                    d = data[p]; p += 1; v += d if f & same else -d
                elif not f & same:
                    v += struct.unpack_from('>h', data, p)[0]; p += 2
                out.append(v)
            return out
        xs = coords(2, 16); ys = coords(4, 32); out = []; a = 0
        for e in ends:
            out.append([(xs[i], ys[i], bool(flags[i] & 1)) for i in range(a, e + 1)]); a = e + 1
        return out
    out = []
    while True:                                                  # composite: other glyphs, moved and scaled
        flags, child = struct.unpack_from('>HH', data, p); p += 4
        if flags & 1: dx, dy = struct.unpack_from('>hh', data, p); p += 4
        else: dx, dy = struct.unpack_from('>bb', data, p); p += 2
        a, b, c, d = 1.0, 0.0, 0.0, 1.0
        if flags & 8: a = d = struct.unpack_from('>h', data, p)[0] / 16384.0; p += 2
        elif flags & 0x40: a, d = [v / 16384.0 for v in struct.unpack_from('>hh', data, p)]; p += 4
        elif flags & 0x80: a, b, c, d = [v / 16384.0 for v in struct.unpack_from('>hhhh', data, p)]; p += 8
        for contour in glyph_contours(data, t, loca, child, depth + 1):
            out.append([(a * x + c * y + dx, b * x + d * y + dy, on) for x, y, on in contour])
        if not flags & 0x20: break
    return out

def flatten(contour, scale):
    """Quadratic outline to a closed list of points in pixels (y still upward)."""
    pts = [(x * scale, y * scale, on) for x, y, on in contour]; n = len(pts)
    if n < 2: return []
    full = []                                                   # make the implied on-curve midpoints explicit
    for i in range(n):
        x, y, on = pts[i]; nx, ny, non = pts[(i + 1) % n]; full.append((x, y, on))
        if not on and not non: full.append(((x + nx) / 2, (y + ny) / 2, True))
    first = next((i for i, q in enumerate(full) if q[2]), None)
    if first is None: return []
    full = full[first:] + full[:first]; out = [full[0][:2]]; i = 1; m = len(full)
    while i <= m:
        x, y, on = full[i % m]
        if on: out.append((x, y)); i += 1
        else:
            x0, y0 = out[-1]; x2, y2, _ = full[(i + 1) % m]
            for k in range(1, 9):
                s = k / 8.0; out.append(((1 - s) ** 2 * x0 + 2 * s * (1 - s) * x + s * s * x2, (1 - s) ** 2 * y0 + 2 * s * (1 - s) * y + s * s * y2))
            i += 2
    return out

def coverage(polys, left, top, width, height):
    """8-bit coverage of the shape on a width x height pixel grid whose top-left corner is (left, top), y downward."""
    S = 4; grid = [[0] * width for _ in range(height)]
    edges = []
    for poly in polys:
        for i in range(len(poly) - 1):
            (x0, y0), (x1, y1) = poly[i], poly[i + 1]
            if y0 != y1: edges.append((x0 - left, top - y0, x1 - left, top - y1))
    for row in range(height * S):
        y = (row + 0.5) / S; hits = []
        for x0, y0, x1, y1 in edges:
            if (y0 <= y < y1) or (y1 <= y < y0):
                hits.append((x0 + (y - y0) * (x1 - x0) / (y1 - y0), 1 if y1 > y0 else -1))
        hits.sort(); wind = 0; out = grid[row // S]
        for k in range(len(hits) - 1):
            wind += hits[k][1]
            if wind == 0: continue
            a, b = hits[k][0] * S, hits[k + 1][0] * S
            for sx in range(max(0, int(a + 0.5)), min(width * S, int(b + 0.5))): out[sx // S] += 1
    return [[min(255, (v * 255 + S * S // 2) // (S * S)) for v in r] for r in grid]

def png(path, width, height, rows):
    raw = b''.join(b'\0' + bytes(r) for r in rows)
    def chunk(tag, body): return struct.pack('>I', len(body)) + tag + body + struct.pack('>I', zlib.crc32(tag + body) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 0, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))

def main():
    font, size, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]; data = open(font, 'rb').read(); t = tables(data)
    if 'glyf' not in t: raise SystemExit('not a TrueType outline font')
    upm = struct.unpack_from('>H', data, t['head'][0] + 18)[0]; long_loca = struct.unpack_from('>h', data, t['head'][0] + 50)[0]
    glyphs = struct.unpack_from('>H', data, t['maxp'][0] + 4)[0]
    loca = [v if long_loca else v * 2 for v in struct.unpack_from('>%d%s' % (glyphs + 1, 'I' if long_loca else 'H'), data, t['loca'][0])]
    ascent, descent = struct.unpack_from('>hh', data, t['hhea'][0] + 4); hmetrics = struct.unpack_from('>H', data, t['hhea'][0] + 34)[0]
    lookup = cmap(data, t); scale = size / float(upm)
    base = int(round(ascent * scale)); line = int(round((ascent - descent) * scale)) + 1
    table = []; ink = bytearray()
    for code in range(32, 127):
        g = lookup(code); adv = struct.unpack_from('>H', data, t['hmtx'][0] + 4 * min(g, hmetrics - 1))[0]
        polys = [p for p in (flatten(c, scale) for c in glyph_contours(data, t, loca, g)) if p]
        if polys:
            xs = [x for p in polys for x, _ in p]; ys = [y for p in polys for _, y in p]
            left = int(min(xs)) - (1 if min(xs) < 0 else 0); right = int(max(xs)) + 1; top = int(max(ys)) + 1; bottom = int(min(ys)) - (1 if min(ys) < 0 else 0)
            w, h = right - left, top - bottom; cov = coverage(polys, left, top, w, h)
        else: left, top, w, h, cov = 0, 0, 0, 0, []
        table.append((len(ink), w, h, left, base - top, int(round(adv * scale)))); ink.extend(b for r in cov for b in r)
    with open(out, 'w') as f:
        f.write('/* Letter shapes for the text piece: made by tools/font_table.py from %s at %d pixels. Do not edit. */\n' % (font.split('/')[-1], size))
        f.write('#define FONT_LINE %d\n#define FONT_BASE %d\n' % (line, base))
        f.write('/* per character 32..126: offset into the ink, width, height, left, top (down from the line top), advance */\n')
        f.write('static const struct { unsigned short at; unsigned char w, h; signed char left, top; unsigned char advance; } font_glyph[95] = {\n')
        f.write(''.join('  {%d,%d,%d,%d,%d,%d},\n' % g for g in table) + '};\n')
        f.write('static const unsigned char font_ink[%d] = {\n' % len(ink))
        for i in range(0, len(ink), 24): f.write('  ' + ','.join(str(b) for b in ink[i:i + 24]) + ',\n')
        f.write('};\n')
    print('letters: 95, ink bytes: %d, line height %d, baseline %d' % (len(ink), line, base))
    if len(sys.argv) > 4:
        text = ['The quick brown fox jumps over', 'the lazy dog. 0123456789', 'Trough: pieces, not programs!', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz', '@#$%&*()[]{}<>?/\\|~^_=+-;:\'",.']
        W = 8 + max(sum(table[ord(c) - 32][5] for c in l) for l in text) + 8; H = 8 + line * len(text) + 8; img = [[0] * W for _ in range(H)]
        for li, l in enumerate(text):
            x = 8
            for c in l:
                at, w, h, left, top, adv = table[ord(c) - 32]
                for yy in range(h):
                    for xx in range(w):
                        px, py = x + left + xx, 8 + li * line + top + yy
                        if 0 <= px < W and 0 <= py < H: img[py][px] = max(img[py][px], ink[at + yy * w + xx])
                x += adv
        png(sys.argv[4], W, H, img); print('sheet', W, 'x', H)
if __name__ == '__main__':
    main()
