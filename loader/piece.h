/* Loading a piece: flat position-independent machine code plus a table of entry offsets. */
#ifndef TROUGH_PIECE_H
#define TROUGH_PIECE_H
#include <stddef.h>
typedef struct piece { void *base; size_t size; int count; char names[8][32]; void *entry[8]; double load_us; const char *how; } piece;
/* Reads <stem>.bin and <stem>.entries into memory that is then made executable and read-only. 0 on success. */
int piece_load(piece *p, const char *stem);
void *piece_entry(const piece *p, const char *name);
#endif
