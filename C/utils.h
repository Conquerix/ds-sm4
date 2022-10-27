#ifndef __UTILS_H__

#define __UTILS_H__

#include <stdio.h>
#include <inttypes.h>
#include <stdlib.h>

// Block type: 128 bits as 4 32-bits unsigned integers; index 0 is LSB, index 3 is MSB
typedef uint32_t blk_t[4];

// Read block b from file f (file name fname)
// Return 0 if OK, 1 if error, 2 if end of file
int fscanf_block(FILE *f, const char * const fname, blk_t b);
// Print block b to standard output
void printf_block(const blk_t b);
// Encrypt block pt with key k and counter value cnt, store encrypted block in ct
void my_encrypt(blk_t ct, const blk_t k, const blk_t cnt, const blk_t pt);
// Increment 32 LSB of b, wrap around 2^32
void increment_block(blk_t b);

#endif

// vim: set tabstop=4 softtabstop=4 shiftwidth=4 expandtab textwidth=0:
