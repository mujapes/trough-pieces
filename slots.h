/* Generated from slots.txt by hand for now: keep the two in step. */
#ifndef TROUGH_SLOTS_H
#define TROUGH_SLOTS_H
#include <stdint.h>
typedef int64_t (*trough_leaf)(const int16_t *samples, int64_t count, int64_t argument, void *const *table);
enum { SLOT_SOUND_MEASURES_ENERGY = 0, SLOT_SOUND_MEASURES_CLIMBS = 1, SLOT_PEAK_PEAK = 2,
       SLOT_PAINT_CLEAR = 3, SLOT_PAINT_FILL_RECT = 4, SLOT_TEXT_DRAW = 5, SLOT_TEXT_MEASURE = 6, SLOT_FILL_FILL_PATH = 7, SLOT_FONT_DRAW = 8, SLOT_FONT_MEASURE = 9, SLOT_COVER_COVER_PATH = 10, SLOT_FONT_DRAW_CACHED = 11, SLOT_HOME_RENDER = 12, SLOT_HOME_HIT = 13,
       SLOT_HASH_SHA256 = 14, SLOT_HASH_HMAC_SHA256 = 15, SLOT_HASH_EXPAND_LABEL = 16, SLOT_SEAL_SEAL = 17, SLOT_SEAL_OPEN = 18, SLOT_EXCHANGE_PUBLIC = 19, SLOT_EXCHANGE_SHARED = 20,
       SLOT_HASH_SHA384 = 21, SLOT_HASH_SHA512 = 22,
       SLOT_CERT_NUMBER = 23, SLOT_CERT_BYTES = 24, SLOT_CERT_COVERS = 25, SLOT_RSA_VERIFY_PKCS1 = 26, SLOT_RSA_VERIFY_PSS = 27, SLOT_ECDSA_VERIFY = 28, SLOT_TRUST_CHAIN = 29, SLOT_TRUST_SIGNED_HANDSHAKE = 30,
       SLOT_URL_RESOLVE = 31, SLOT_URL_PART = 32, SLOT_URL_PORT = 33,
       SLOT_AESGCM_SEAL = 34, SLOT_AESGCM_OPEN = 35,
       SLOT_LLM_REQUEST = 36, SLOT_LLM_TEXT = 37, SLOT_LLM_STOPPED = 38, SLOT_RELOAD_RECORD = 39, SLOT_RELOAD_PART = 40 };
/* Entries that work on a block the host owns (a surface): (block, numbers, count, argument, table). */
typedef int64_t (*trough_block)(void *block, const int16_t *numbers, int64_t count, int64_t argument, void *const *table);
#define TROUGH_ON(table, slot, block, numbers, count, argument) (((trough_block)(table)[slot])((block), (numbers), (count), (int64_t)(argument), (table)))
#define TROUGH_CALL(table, slot, samples, count, argument) (((trough_leaf)(table)[slot])((samples), (count), (argument), (table)))
/* Handles: host-owned blocks reachable by number (sockets 256-511). 0 if the handle is empty or out of range. */
#define TROUGH_BLOCK(table, handle) ((handle) >= 0 && (handle) < 256 ? (table)[256 + (handle)] : (void *)0)
#endif
