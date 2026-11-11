/* Bench renderer: call drawing entries of pieces on a fresh surface and write the picture as raw RGBA.
 *   render <out dir> <width> <height> <out.rgba> < commands
 * Each command line: <piece variant stem> <entry> <colour hex> [numbers...]   e.g. out/fill.ref fill_path ff000000 3 0 0 160 0 80 160
 * Lines starting with @ manage pictures:  @surface <handle> <w> <h>  makes a picture and puts it at that handle;
 *   @file <handle> <path>  puts a file's bytes at that handle;  @target <handle>  draws on that picture from now on;  @target main  goes back to the output picture.
 * The call table is filled from the reference builds, as in vectors.c. Prints each entry's answer. */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static void *table[512]; static piece loaded[64]; static char loaded_stem[64][256]; static int loaded_count;
static piece *get(const char *stem) {
    for (int i = 0; i < loaded_count; i++) if (!strcmp(loaded_stem[i], stem)) return &loaded[i];
    if (loaded_count >= 64 || piece_load(&loaded[loaded_count], stem)) return 0;
    strncpy(loaded_stem[loaded_count], stem, 255); return &loaded[loaded_count++];
}
int main(int argc, char **argv) {
    if (argc != 5) return 2;
    char path[600]; snprintf(path, sizeof path, "%s/../slots.txt", argv[1]); FILE *f = fopen(path, "r");
    if (f) { char line[256]; while (fgets(line, sizeof line, f)) { int slot; char name[64], entry[64]; if (line[0] == '#' || sscanf(line, "%d %63s %63s", &slot, name, entry) != 3) continue;
        snprintf(path, sizeof path, "%s/%s.ref", argv[1], name); piece *p = get(path); if (p && slot >= 0 && slot < 512) table[slot] = piece_entry(p, entry); } fclose(f); }
    int w = atoi(argv[2]), h = atoi(argv[3]); size_t size = 64 + (size_t)w * h * 4; uint8_t *s = calloc(1, size);
    uint32_t head[4] = {1, (uint32_t)w, (uint32_t)h, 4u * (uint32_t)w}; uint64_t z = size; memcpy(s, head, 16); memcpy(s + 16, &z, 8);
    static char line[400000]; static int16_t numbers[70000]; uint8_t *target = s, *output = s; long long last = 0;
    while (fgets(line, sizeof line, stdin)) {
        char *tok = strtok(line, " \t\n"); if (!tok || tok[0] == '#') continue;
        if (!strcmp(tok, "@surface")) { int hd = atoi(strtok(0, " \t\n")), bw = atoi(strtok(0, " \t\n")), bh = atoi(strtok(0, " \t\n")); if (hd < 0 || hd > 255) return 1;
            size_t bs = 64 + (size_t)bw * bh * 4; uint8_t *b = calloc(1, bs); uint32_t hh[4] = {1, (uint32_t)bw, (uint32_t)bh, 4u * (uint32_t)bw}; uint64_t bz = bs; memcpy(b, hh, 16); memcpy(b + 16, &bz, 8);
            table[256 + hd] = b; continue; }
        if (!strcmp(tok, "@file")) { int hd = atoi(strtok(0, " \t\n")); char *name = strtok(0, " \t\n"); FILE *in = name ? fopen(name, "rb") : 0; if (!in || hd < 0 || hd > 255) { printf("cannot read file\n"); return 1; }
            fseek(in, 0, SEEK_END); long len = ftell(in); fseek(in, 0, SEEK_SET); uint8_t *b = calloc(1, 64 + (size_t)len); uint32_t kind = 2; uint64_t bz = 64 + (uint64_t)len; memcpy(b, &kind, 4); memcpy(b + 16, &bz, 8);
            if (fread(b + 64, 1, (size_t)len, in) != (size_t)len) return 1; fclose(in); table[256 + hd] = b; continue; }   /* plain bytes (a font, a document) at a handle */
        if (!strcmp(tok, "@block")) { int hd = atoi(strtok(0, " \t\n")); uint32_t kind = (uint32_t)atoi(strtok(0, " \t\n")); long bytes = atol(strtok(0, " \t\n")); if (hd < 0 || hd > 255 || bytes < 64) return 1;
            uint8_t *b = calloc(1, (size_t)bytes); if (kind) { uint64_t bz = (uint64_t)bytes; memcpy(b, &kind, 4); memcpy(b + 16, &bz, 8); } table[256 + hd] = b; continue; }   /* zeroed memory; kind 0 leaves it all zero (a fresh state block) */
        if (!strcmp(tok, "@resize")) { int hd = atoi(strtok(0, " \t\n")); char *how = strtok(0, " \t\n"); uint8_t *b = hd >= 0 && hd < 256 ? (uint8_t *)table[256 + hd] : 0; if (!b || !how) return 1;
            uint64_t bz = 64 + (uint64_t)(!strcmp(how, "last") ? (last < 0 ? 0 : last) : atoll(how)); memcpy(b + 16, &bz, 8); continue; }   /* a block's payload is now this long ("last": the previous answer) */
        if (!strcmp(tok, "@output")) { output = (uint8_t *)table[256 + atoi(strtok(0, " \t\n"))]; if (!output) return 1; continue; }   /* which picture is written out at the end */
        if (!strcmp(tok, "@target")) { char *which = strtok(0, " \t\n"); target = !strcmp(which, "main") ? s : (uint8_t *)table[256 + atoi(which)]; if (!target) return 1; continue; }
        piece *p = get(tok); if (!p) { printf("cannot load %s\n", tok); return 1; }
        char *entry = strtok(0, " \t\n"), *colour = strtok(0, " \t\n"); if (!entry || !colour) return 1;
        void *e = piece_entry(p, entry); if (!e) { printf("no entry %s\n", entry); return 1; }
        int n = 0; while ((tok = strtok(0, " \t\n")) && n < 70000) numbers[n++] = (int16_t)atoi(tok);
        long long answer = last = ((int64_t (*)(void *, const int16_t *, int64_t, int64_t, void *))e)(target, numbers, n, (int64_t)strtoull(colour, 0, 16), table);
        printf("%s -> %lld\n", entry, answer);
    }
    { uint64_t out_size; memcpy(&out_size, output + 16, 8); f = fopen(argv[4], "wb"); fwrite(output + 64, 1, (size_t)out_size - 64, f); fclose(f); } return 0;
}
