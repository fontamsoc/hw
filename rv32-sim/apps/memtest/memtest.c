// SPDX-License-Identifier: GPL-2.0-only
// 20260914 (c) William Fonkou Tambe

#include <stdio.h>

#include <_os.h>

#define countof(A) (sizeof(A)/sizeof(A[0]))

#define PASS (1)
#define FAIL (0)

// Bytes to leave untested below the stack pointer sampled in main().
// test() and the printf()/fflush() it calls between its write and verify
// loops push their frames below that stack pointer using plain stores, which
// land in the data cache. An atomic on a word held in the data cache first
// writes that cache line back to memory, then does its read-modify-write in
// memory; so if those frames sat inside the tested range, the verify loop's
// atomic reads would write the frames over the pattern and report a mismatch
// that the memory did not cause. 1024 clears test()'s frame plus the
// newlib-nano printf() chain (about 300 bytes).
#define STACK_RESERVE 1024

// The heap break set by crt0.S at boot.
extern uintptr_t __heap_ptr;

#define current_sp() ({ \
  uintptr_t x; \
  __asm__ __volatile__ ("mv %0, sp\n" : "=r"(x)); \
  x; })

static uintptr_t patterns[] = {
     (uintptr_t)0x0000000000000000ULL
    ,(uintptr_t)0xffffffffffffffffULL
    ,(uintptr_t)0x5555555555555555ULL
    ,(uintptr_t)0xaaaaaaaaaaaaaaaaULL
    ,(uintptr_t)0x1111111111111111ULL
    ,(uintptr_t)0x2222222222222222ULL
    ,(uintptr_t)0x4444444444444444ULL
    ,(uintptr_t)0x8888888888888888ULL
    ,(uintptr_t)0x3333333333333333ULL
    ,(uintptr_t)0x6666666666666666ULL
    ,(uintptr_t)0x9999999999999999ULL
    ,(uintptr_t)0xccccccccccccccccULL
    ,(uintptr_t)0x7777777777777777ULL
    ,(uintptr_t)0xbbbbbbbbbbbbbbbbULL
    ,(uintptr_t)0xddddddddddddddddULL
    ,(uintptr_t)0xeeeeeeeeeeeeeeeeULL
    ,(uintptr_t)0x4D41524B43454843ULL /* CHECKRAM */
    ,(uintptr_t)0x21545345544D4152ULL /* RAMTEST! */
    ,(uintptr_t)0x53545345544D454DULL /* MEMTESTS */
};

// Atomic memory operations are used to bypass the data cache.
uintptr_t test (uintptr_t *start, uintptr_t *end, uintptr_t first, uintptr_t modulo) {
    for (uintptr_t *ptr = start; ptr < end; ++ptr) {
        uintptr_t pattern = patterns[first + ((ptr - start) % modulo)];
        _xchg(ptr, pattern) /* write *ptr */;
    }
    printf("⏳"); fflush(stdout);
    for (uintptr_t *ptr = start; ptr < end; ++ptr) {
        uintptr_t ptr_val = _atomic_add(ptr, 0) /* read *ptr */;
        uintptr_t pattern = patterns[first + ((ptr - start) % modulo)];
        if (ptr_val != pattern) {
            printf("\n❌ ERROR: mismatch at 0x%x! Expected 0x%x, got 0x%x\n",
                ptr, pattern, ptr_val);
            return FAIL;
        }
    }
    printf("👍"); fflush(stdout);
    return PASS;
}

void main () {

    printf("🚀 Starting memory tests ...\n");

    // Intentionally set after above printf() as newlib allocates stdout's
    // buffer on that call advancing __heap_ptr; correct alignment is assumed.
    uintptr_t *unused_heap_start = (void *)__heap_ptr;
    uintptr_t *unused_heap_end   = (void *)(current_sp() - STACK_RESERVE);

    if (unused_heap_end <= unused_heap_start) {
        printf("❌ ERROR: no unused heap available to test!\n");
        return;
    }

    _date_t start_time = _clkcycles();

    printf("👉 Test 1/2: writing and verifying sequence pattern ...\n");
    for (uintptr_t i = 0; i < countof(patterns); ++i) {
        if (test(unused_heap_start, unused_heap_end, i, 1) == FAIL)
            return;
    }

    printf("\n👉 Test 2/2: writing and verifying alternating pattern ... "); fflush(stdout);
    if (test(unused_heap_start, unused_heap_end, 0, countof(patterns)) == FAIL)
        return;

    _date_t end_time = _clkcycles();

    // Reduced to a word before printing to match printf() "%u".
    uintptr_t ms = (((end_time - start_time) * 1000) / _clkfreq());

    printf("\n✅ SUCCESS: all tests passed in %u ms!\n", ms);
}
