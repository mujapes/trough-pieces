/* The piece loader inside Trough's app process. A tiny library of its own (not part of the main native
 * library), with no dependency on the C library: it asks the kernel directly for memory, copies a piece's
 * machine code in, makes it runnable and read-only, and calls it. Java: com.trough.hot.Pieces. */
#include <jni.h>
#include <stdint.h>
static long sys(long n, long a, long b, long c, long d, long e, long f) {
    register long x8 __asm__("x8") = n; register long x0 __asm__("x0") = a; register long x1 __asm__("x1") = b;
    register long x2 __asm__("x2") = c; register long x3 __asm__("x3") = d; register long x4 __asm__("x4") = e; register long x5 __asm__("x5") = f;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5) : "memory", "cc");
    return x0;
}
enum { SYS_close = 57, SYS_write = 64, SYS_munmap = 215, SYS_mmap = 222, SYS_mprotect = 226, SYS_memfd_create = 279 };
enum { P_READ = 1, P_WRITE = 2, P_EXEC = 4, M_PRIVATE = 2, M_ANON = 0x20 };
static void flush(char *from, char *to) {             /* tell the processor these bytes are now instructions */
    unsigned long ctr; __asm__("mrs %0, ctr_el0" : "=r"(ctr));
    unsigned long dline = 4UL << ((ctr >> 16) & 15), iline = 4UL << (ctr & 15);
    for (char *p = (char *)((unsigned long)from & ~(dline - 1)); p < to; p += dline) __asm__ volatile("dc cvau, %0" :: "r"(p));
    __asm__ volatile("dsb ish");
    for (char *p = (char *)((unsigned long)from & ~(iline - 1)); p < to; p += iline) __asm__ volatile("ic ivau, %0" :: "r"(p));
    __asm__ volatile("dsb ish\nisb");
}
/* Returns the address the code was placed at, or a negative number: -1 bad input, -2 no memory, -3 not runnable. */
JNIEXPORT jlong JNICALL Java_com_trough_hot_Pieces_load(JNIEnv *env, jclass c, jbyteArray code) {
    (void)c; if (!code) return -1;
    jsize n = (*env)->GetArrayLength(env, code); if (n <= 0 || n > (1 << 20) || (n & 3)) return -1;
    unsigned long size = ((unsigned long)n + 4095) & ~4095UL;
    long w = sys(SYS_mmap, 0, (long)size, P_READ | P_WRITE, M_PRIVATE | M_ANON, -1, 0);
    if (w < 0 && w > -4096) return -2;
    (*env)->GetByteArrayRegion(env, code, 0, n, (jbyte *)w);
    if (sys(SYS_mprotect, w, (long)size, P_READ | P_EXEC, 0, 0, 0) == 0) { flush((char *)w, (char *)w + n); return (jlong)w; }
    /* Private memory may not be made runnable here: go through an in-memory file instead. */
    long fd = sys(SYS_memfd_create, (long)"trough-piece", 1, 0, 0, 0, 0); long x = -1;
    if (fd >= 0) {
        long done = 0; while (done < n) { long k = sys(SYS_write, fd, w + done, n - done, 0, 0, 0); if (k <= 0) break; done += k; }
        if (done == n) x = sys(SYS_mmap, 0, (long)size, P_READ | P_EXEC, M_PRIVATE, fd, 0);
        sys(SYS_close, fd, 0, 0, 0, 0, 0);
    }
    sys(SYS_munmap, w, (long)size, 0, 0, 0, 0);
    if (x < 0 && x > -4096) return -3;
    if (x == -1) return -3;
    return (jlong)x;
}
/* The call table (slots.txt): one page of sockets, each holding the current address of one entry of one piece.
 * It never moves; a socket is rewritten with a single store when its piece is swapped. Every call into a piece
 * is handed the table as its last argument, so pieces can reach each other without holding addresses. */
static void *volatile *table;
JNIEXPORT jlong JNICALL Java_com_trough_hot_Pieces_table(JNIEnv *env, jclass c) {
    (void)env; (void)c;
    if (!table) { long m = sys(SYS_mmap, 0, 4096, P_READ | P_WRITE, M_PRIVATE | M_ANON, -1, 0); if (m < 0 && m > -4096) return 0; table = (void *volatile *)m; }
    return (jlong)(long)table;
}
JNIEXPORT jint JNICALL Java_com_trough_hot_Pieces_slot(JNIEnv *env, jclass c, jint index, jlong address) {
    (void)env; (void)c; if (!table || index < 0 || index >= 512 || !address) return -1;
    __atomic_store_n(&table[index], (void *)address, __ATOMIC_SEQ_CST); return 0;
}
/* Calls an entry of the shape (samples, count, argument, table) -> number, on 16-bit samples held in a byte array. */
JNIEXPORT jlong JNICALL Java_com_trough_hot_Pieces_callBlock(JNIEnv *env, jclass c, jlong entry, jbyteArray pcm, jint offset, jint count, jlong argument) {
    (void)c; if (!entry || !pcm || offset < 0 || count < 0) return 0;
    jsize n = (*env)->GetArrayLength(env, pcm); if ((long)offset + 2L * count > n) return 0;
    jbyte *data = (*env)->GetPrimitiveArrayCritical(env, pcm, 0); if (!data) return 0;
    long (*run)(const int16_t *, long, long, void *) = (long (*)(const int16_t *, long, long, void *))entry;
    long result = run((const int16_t *)(data + offset), count, argument, (void *)table);
    (*env)->ReleasePrimitiveArrayCritical(env, pcm, data, JNI_ABORT);
    return result;
}
/* Calls an entry of the shape (state, samples, count, argument, table) -> number. The state block is the host's:
 * the piece reads and updates it and keeps nothing of its own. samples may be absent (for migrate). */
JNIEXPORT jlong JNICALL Java_com_trough_hot_Pieces_callState(JNIEnv *env, jclass c, jlong entry, jbyteArray state, jbyteArray pcm, jint offset, jint count, jlong argument) {
    (void)c; if (!entry || !state || offset < 0 || count < 0) return -1;
    if ((*env)->GetArrayLength(env, state) < 64) return -1;
    if (pcm && (long)offset + 2L * count > (*env)->GetArrayLength(env, pcm)) return -1;
    if (!pcm && count != 0) return -1;
    jbyte *block = (*env)->GetPrimitiveArrayCritical(env, state, 0); if (!block) return -1;
    jbyte *data = pcm ? (*env)->GetPrimitiveArrayCritical(env, pcm, 0) : 0;
    long result = -1;
    if (!pcm || data) {
        long (*run)(void *, const int16_t *, long, long, void *) = (long (*)(void *, const int16_t *, long, long, void *))entry;
        result = run(block, data ? (const int16_t *)(data + offset) : 0, count, argument, (void *)table);
    }
    if (data) (*env)->ReleasePrimitiveArrayCritical(env, pcm, data, JNI_ABORT);
    (*env)->ReleasePrimitiveArrayCritical(env, state, block, 0);
    return result;
}
/* Calls an entry of the shape (block, numbers, count, argument, table) -> number, where the block is a large
 * piece of memory the host owns outside the Java heap (a picture, for the paint pieces): nothing is copied. */
JNIEXPORT jlong JNICALL Java_com_trough_hot_Pieces_callDirect(JNIEnv *env, jclass c, jlong entry, jobject block, jbyteArray numbers, jint count, jlong argument) {
    (void)c; if (!entry || !block || count < 0) return -1;
    void *memory = (*env)->GetDirectBufferAddress(env, block);
    if (!memory || (*env)->GetDirectBufferCapacity(env, block) < 64) return -1;
    if (numbers && 2L * count > (*env)->GetArrayLength(env, numbers)) return -1;
    if (!numbers && count != 0) return -1;
    jbyte *data = numbers ? (*env)->GetPrimitiveArrayCritical(env, numbers, 0) : 0;
    long result = -1;
    if (!numbers || data) {
        long (*run)(void *, const int16_t *, long, long, void *) = (long (*)(void *, const int16_t *, long, long, void *))entry;
        result = run(memory, (const int16_t *)data, count, argument, (void *)table);
    }
    if (data) (*env)->ReleasePrimitiveArrayCritical(env, numbers, data, JNI_ABORT);
    return result;
}
/* Handles (slots.txt): put a block of host-owned memory at handle 0-255, or empty the handle (block absent).
 * The library keeps its own reference to the buffer for as long as the handle points at it, and empties the
 * handle before letting go, so a piece can never be handed memory that has been given back. Returns 0, or -1. */
static jobject held[256];
JNIEXPORT jint JNICALL Java_com_trough_hot_Pieces_block(JNIEnv *env, jclass c, jint handle, jobject block) {
    (void)c; if (!table || handle < 0 || handle > 255) return -1;
    void *memory = 0; jobject keep = 0;
    if (block) {
        memory = (*env)->GetDirectBufferAddress(env, block);
        if (!memory || (*env)->GetDirectBufferCapacity(env, block) < 64) return -1;
        keep = (*env)->NewGlobalRef(env, block); if (!keep) return -1;
    }
    jobject old = held[handle];
    __atomic_store_n(&table[256 + handle], memory, __ATOMIC_SEQ_CST);
    held[handle] = keep;
    if (old) (*env)->DeleteGlobalRef(env, old);
    return 0;
}
