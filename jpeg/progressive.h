/* Progressive JPEG: the picture's coefficients arrive over several scans (first a coarse version, then more
 * patterns, then finer values), so they are kept in the scratch block until the last scan and transformed
 * once. Shared by reference.c and the fast variants; each defines IDCT(in, out, stride) and PREPARE(h) first. */
static void prog_dht(jpg *j, uint64_t body, uint64_t end) {
    for (uint64_t q = body; q < end && !j->bad; ) { uint32_t tc = rd8(j, q) >> 4, th = rd8(j, q) & 15; if (tc > 1 || th > 3) { j->bad = 1; return; } q++; huff *h = tc ? &j->ac[th] : &j->dc[th];
        int total = 0; h->count[0] = 0; for (int i = 1; i <= 16; i++) { h->count[i] = (uint8_t)rd8(j, q++); total += h->count[i]; } if (total > 256) { j->bad = 1; return; }
        for (int i = 0; i < total; i++) h->symbol[i] = (uint8_t)rd8(j, q++); h->present = 1; PREPARE(h); }
}
static void prog_refine(jpg *j, int16_t *v, int p1) { if (bit(j) && !(*v & p1)) *v = (int16_t)(*v >= 0 ? *v + p1 : *v - p1); }
static void prog_block(jpg *j, int16_t *b, comp *c, int ss, int se, int ah, int al, int *eobrun) {
    int p1 = 1 << al;
    if (ss == 0) { if (!ah) { int t = symbol(j, &j->dc[c->dc]); if (t > 11) { j->bad = 1; return; } c->pred += extend(receive(j, t), t); b[0] = (int16_t)(c->pred * p1); } else if (bit(j)) b[0] = (int16_t)(b[0] | p1); return; }
    const huff *h = &j->ac[c->ac];
    if (!ah) { if (*eobrun > 0) { (*eobrun)--; return; }
        for (int k = ss; k <= se && !j->bad; k++) { int rs = symbol(j, h), r = rs >> 4, s = rs & 15;
            if (!s) { if (r < 15) { *eobrun = (1 << r) - 1; if (r) *eobrun += receive(j, r); return; } k += 15; }
            else { k += r; if (k > se) { j->bad = 1; return; } b[zigzag[k]] = (int16_t)(extend(receive(j, s), s) * p1); } }
        return; }
    int k = ss;
    if (*eobrun == 0) for (; k <= se && !j->bad; k++) { int rs = symbol(j, h), r = rs >> 4, s = rs & 15, value = 0;
        if (s) { if (s != 1) { j->bad = 1; return; } value = bit(j) ? p1 : -p1; }
        else if (r != 15) { *eobrun = 1 << r; if (r) *eobrun += receive(j, r); break; }
        for (; k <= se; k++) { int16_t *v = &b[zigzag[k]]; if (*v) prog_refine(j, v, p1); else if (--r < 0) break; }
        if (value) { if (k > se) { j->bad = 1; return; } b[zigzag[k]] = (int16_t)value; } }
    if (*eobrun > 0) { for (; k <= se; k++) { int16_t *v = &b[zigzag[k]]; if (*v) prog_refine(j, v, p1); } (*eobrun)--; }
}
static int prog_scan(jpg *j, int16_t *co, const uint64_t *cat, uint64_t body, uint64_t end, uint32_t mx, uint32_t my) {
    int ns = (int)rd8(j, body), ci[3]; if (ns < 1 || ns > j->comps || body + 4 + 2 * (uint64_t)ns > end) return 0;
    for (int i = 0; i < ns; i++) { uint32_t id = rd8(j, body + 1 + 2 * (uint64_t)i), t = rd8(j, body + 2 + 2 * (uint64_t)i); ci[i] = -1; for (int k = 0; k < j->comps; k++) if ((uint32_t)j->c[k].id == id) ci[i] = k;
        if (ci[i] < 0 || (t >> 4) > 3 || (t & 15) > 3) return 0; j->c[ci[i]].dc = (int)(t >> 4); j->c[ci[i]].ac = (int)(t & 15); j->c[ci[i]].pred = 0; }
    int ss = (int)rd8(j, body + 1 + 2 * (uint64_t)ns), se = (int)rd8(j, body + 2 + 2 * (uint64_t)ns), ah = (int)(rd8(j, body + 3 + 2 * (uint64_t)ns) >> 4), al = (int)(rd8(j, body + 3 + 2 * (uint64_t)ns) & 15);
    if (j->bad || ss > se || se > 63 || al > 13 || (ss == 0 && se != 0) || (ss > 0 && ns != 1)) return 0;
    for (int i = 0; i < ns; i++) if (ss == 0 ? (!ah && !j->dc[j->c[ci[i]].dc].present) : !j->ac[j->c[ci[i]].ac].present) return 0;
    j->pos = end; j->have = 0; j->bits = 0; j->marker = 0; int eobrun = 0; comp *one = &j->c[ci[0]];
    uint32_t bw = (((j->width * (uint32_t)one->h + (uint32_t)j->hmax - 1) / (uint32_t)j->hmax) + 7) / 8, bh = (((j->height * (uint32_t)one->v + (uint32_t)j->vmax - 1) / (uint32_t)j->vmax) + 7) / 8;
    uint32_t total = ns == 1 ? bw * bh : mx * my;
    for (uint32_t n = 0; n < total; n++) {
        if (j->restart && n && n % (uint32_t)j->restart == 0) { j->have = 0; j->bits = 0;
            if (j->marker) { j->pos += 2; j->marker = 0; } else { while (j->pos + 1 < j->n && !(j->d[j->pos] == 0xff && j->d[j->pos + 1] >= 0xd0 && j->d[j->pos + 1] <= 0xd7)) j->pos++; j->pos += 2; }
            for (int i = 0; i < ns; i++) j->c[ci[i]].pred = 0; eobrun = 0; }
        if (ns == 1) prog_block(j, co + cat[ci[0]] + ((uint64_t)(n / bw) * (one->pw / 8) + n % bw) * 64, one, ss, se, ah, al, &eobrun);
        else for (int i = 0; i < ns; i++) { comp *c = &j->c[ci[i]]; for (int by = 0; by < c->v; by++) for (int bx = 0; bx < c->h; bx++)
            prog_block(j, co + cat[ci[i]] + ((uint64_t)((n / mx) * (uint32_t)c->v + (uint32_t)by) * (c->pw / 8) + (n % mx) * (uint32_t)c->h + (uint32_t)bx) * 64, c, ss, se, ah, al, &eobrun); }
        if (j->bad) return 0; }
    return 1;
}
/* Runs every scan, then turns the finished coefficients into the planes at the start of the scratch block. */
static int progressive(jpg *j, block *scratch, uint64_t planes, uint32_t mx, uint32_t my) {
    uint64_t start = (planes + 7) & ~7ull, cat[3], count = 0; for (int i = 0; i < j->comps; i++) { cat[i] = count; count += (uint64_t)(j->c[i].pw / 8) * (j->c[i].ph / 8) * 64; }
    if (scratch->size - 64 < start + 2 * count) return 0;
    int16_t *co = (int16_t *)(void *)(scratch->bytes + start); for (uint64_t i = 0; i < count; i++) co[i] = 0;
    int scans = 0;
    for (uint64_t at = j->scan; at + 4 <= j->n; ) {
        if (j->d[at] != 0xff) return 0; uint32_t m = j->d[at + 1]; if (m == 0xff) { at++; continue; } if (m == 0xd9) break;
        uint32_t len = rd16(j, at + 2); uint64_t body = at + 4, end = at + 2 + len; if (len < 2 || end > j->n) break;
        if (m == 0xc4) { prog_dht(j, body, end); if (j->bad) return 0; }
        else if (m == 0xdd) j->restart = (int)rd16(j, body);
        else if (m == 0xda) { if (!prog_scan(j, co, cat, body, end, mx, my)) return 0; scans++;
            at = end; while (at + 1 < j->n && !(j->d[at] == 0xff && j->d[at + 1] != 0 && !(j->d[at + 1] >= 0xd0 && j->d[at + 1] <= 0xd7))) at++; continue; }
        at = end; }
    if (!scans) return 0;
    for (int i = 0; i < j->comps; i++) { const uint16_t *q = j->quant[j->c[i].q]; uint32_t across = j->c[i].pw / 8, down = j->c[i].ph / 8;
        for (uint32_t by = 0; by < down; by++) for (uint32_t bx = 0; bx < across; bx++) { const int16_t *b = co + cat[i] + ((uint64_t)by * across + bx) * 64; int32_t t[64];
            for (int k = 0; k < 64; k++) t[zigzag[k]] = b[zigzag[k]] * q[k];
            IDCT(t, scratch->bytes + j->c[i].at + (uint64_t)by * 8 * j->c[i].pw + (uint64_t)bx * 8, j->c[i].pw); } }
    return 1;
}
