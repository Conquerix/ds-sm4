#include <stdio.h>
#include <inttypes.h>
#include <stdlib.h>
#include "utils.h"

int fscanf_block(FILE *f, const char * const fname, blk_t b) {
    int i;

    if (feof(f)) // If end of file
    {
        return 2;
    }
    for (i = 3; i >= 0; i--) {
        if(fscanf(f, "%08" SCNx32 " ", b + i) != 1) { // If read error
            fprintf(stderr, "%s: invalid format\n", fname);
            return 1;
        }
    }
    return 0;
}

void printf_block(const blk_t b) {
    int i;

    for (i = 3; i >= 0; i--) {
        printf("%08X", b[i]);
    }
    printf("\n");
}

void my_encrypt(blk_t ct, const blk_t k, const blk_t cnt, const blk_t pt) {
    int i;

    for(i = 0; i < 4; i++) {
        ct[i] = pt[i] ^ k[i] ^ cnt[i];
    }
}

void increment_block(blk_t b) {
    int i;

    b[0] += UINT32_C(1);
}

// vim: set tabstop=4 softtabstop=4 shiftwidth=4 expandtab textwidth=0:
