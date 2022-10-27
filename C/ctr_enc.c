/*
Copyright (C) Telecom Paris
Copyright (C) Renaud Pacalet (renaud.pacalet@telecom-paris.fr)

This file must be used under the terms of the CeCILL. This source
file is licensed as described in the file COPYING, which you should
have received as part of this distribution. The terms are also
available at:
http://www.cecill.info/licences/Licence_CeCILL_V1.1-US.txt
*/

#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <inttypes.h>
#include <stdlib.h>
#include "utils.h"

// Base address and size of registers area
#define REGS_ADDR 0x40000000
#define REGS_SIZE 0x1000
// Word offset of timer register in REGS area.
// Uncomment if you have a timer and check the word offset
// #define TIMER_OFF 8

// Base address and size of OCM
#define OCM_ADDR 0xfffc0000
#define OCM_SIZE 0x40000

// Registers
#define SBA (regs[0])
#define MBL (regs[1])
#define CTRL (regs[2])
#define STATUS (regs[3])
#define KEY (regs + 4)
#ifdef TIMER_OFF
#define TIMER (*timer)
#endif

// Hardare-accelerated encryption of input data file finame, with key file fkname
// Return 0 if no error, else 1
int hardware_encryption(const char * const fkname, const char * const finame);
// Software encryption of input data file finame, with key file fkname
// Return 0 if no error, else 1
int software_encryption(const char * const fkname, const char * const finame);

// Return 0 if no error, else 1
int main(int argc, char **argv)
{
    char *usage = "\
Usage: %s [OPTION] KEYFILE DATAFILE\n\
Use key in KEYFILE to encrypt DATAFILE.\n\n\
  -h                hardware encryption (software is the default)\n\n\
KEYFILE and DATAFILE are text files in hexadecimal form, 32 characters per line,\n\
that is one 128-bits block per line. The leftmost character in a line encodes\n\
the 4 leftmost bits of the block. Example:\n\
  DEADBEEF00112233445566778899AABB\n\
is the 128-bits block 1101_1110_1010...1011_1011. KEYFILE contains only one\n\
line, the secret key to use for encryption. DATAFILE contains the Initial Counter\n\
Block (ICB) followed by as many lines as blocks to encrypt. The encrypted input\n\
is sent to the standard output, in the same format as the input, preceded by the\n\
unmodified ICB.\n\n\
If the TIMER_OFF macro is defined and set to the word offset of a 4-bytes\n\
location in the registers area, its content is printed as an unsigned 32-bits\n\
integer at the end of a hardware-accelerated encryption.\n\
";

    // If wrong arguments or wrong number of arguments
    if ((argc == 4 && strcmp(argv[1], "-h")) || argc < 3 || argc > 4)
    {
        fprintf(stderr, usage, argv[0]);
        return 1;
    }
    if (argc == 4) // If 3 arguments (hardware acceleration)
    {
#ifndef __arm__
        fprintf(stderr, "Hardware encryption supported only on ARM platform\n");
        return 1;
#endif
        return hardware_encryption(argv[2], argv[3]);
    }
    else // Software encryption
    {
        return software_encryption(argv[1], argv[2]);
    }
}

int software_encryption(const char * const fkname, const char * const finame)
{
    blk_t key, cnt, pt, ct; // Key, counter, plain text, cipher text
    FILE *fk, *fi; // Key and input files
    int ret = 1; // Return status (0 = OK, 1 = error, 1 by default)

    fk = fopen(fkname, "r"); // Open key file
    if (fk == NULL) // If cannot open key file
    {
        fprintf(stderr, "%s: file not found\n", fkname);
        goto sw_end;
    }
    if (fscanf_block(fk, fkname, key)) // If cannot read key
    {
        goto sw_close_fk;
    }
    fi = fopen(finame, "r"); // Open input data file
    if (fi == NULL) // If cannot open input data file
    {
        fprintf(stderr, "%s: file not found\n", finame);
        goto sw_close_fk;
    }
    if (fscanf_block(fi, finame, cnt)) // If cannot read ICB
    {
        goto sw_close_fi;
    }
    printf_block(cnt); // Print ICB
    while (!(ret = fscanf_block(fi, finame, pt))) { // While there are block in input data file
        my_encrypt(ct, key, cnt, pt); // Encrypt
        printf_block(ct); // Print encrypted block
        increment_block(cnt); // Increment counter
    }
    // ret == 2 => end of file => OK
    ret = ret == 2 ? 0 : ret;

sw_close_fi:
    fclose(fi); // Close input data file
sw_close_fk:
    fclose(fk); // Close key file
sw_end:
    return ret;
}

int hardware_encryption(const char * const fkname, const char * const finame)
{
    int i, n, fm; // Index, block counter, file descriptor for dev-mem
    int ret = 1; // Return status (0 = OK, 1 = error, 1 by default)
    FILE *fk, *fi; // Key and input files
    uint32_t status; // Content of status register
    uint32_t *regs, *ocm, *timer; // Pointers to registers, On-Chip Memory and timer

    fm = open("/dev/mem", O_RDWR | O_SYNC); // Open dev-mem character device
    if(fm == -1) // If cannot open dev-mem
    {
        fprintf(stderr, "Failed to open /dev/mem\n");
        goto hw_end;
    }
    regs = (uint32_t *)(mmap(NULL, REGS_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fm, REGS_ADDR)); // Map registers area
    if(regs == (void *) -1) // If cannot map
    {
        fprintf(stderr, "Failed to map registers\n");
        goto hw_close_fm;
    }
#ifdef TIMER_OFF
    timer = regs + TIMER_OFF; // Timer address
#endif
    ocm = (uint32_t *)(mmap(NULL, OCM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fm, OCM_ADDR)); // Map OCM area
    if(ocm == (void *) -1) // If cannot map
    {
        fprintf(stderr, "Failed to map On-Chip Memory\n");
        goto hw_unmap_regs;
    }
    fk = fopen(fkname, "r"); // Open key file
    if (fk == NULL) // If cannot open key file
    {
        fprintf(stderr, "%s: file not found\n", fkname);
        goto hw_unmap_ocm;
    }
    if (fscanf_block(fk, fkname, KEY)) // If cannot read key
    {
        goto hw_close_fk;
    }
    fi = fopen(finame, "r"); // Open input data file
    if (fi == NULL) // If cannot open input data file
    {
        fprintf(stderr, "%s: file not found\n", finame);
        goto hw_close_fk;
    }
    if (fscanf_block(fi, finame, ocm)) // If cannot read ICB
    {
        goto hw_close_fi;
    }
    ret = 0; // No error, maybe?
    n = 1; // On block read (ICB)
    // While there are block in input data file and OCM not full
    while ((!fscanf_block(fi, finame, ocm + n * 4)) && (n < OCM_SIZE / 16)) {
        n += 1;
    }
    SBA = OCM_ADDR; // Store Starting Byte Address of input message in SBA register
    MBL = n * 16; // Store Message Byte Length in MBL register
    CTRL = 2; // Configure control register (interrupt disabled, chip enabled, soft reset disabled
    fprintf(stderr, "Starting encryption, STATUS=%08X\n", STATUS);
    STATUS = 0; // Start encryption by writing in status register
    while (1)
    {
        status = STATUS;
        if (status & 2)
        {
            break;
        }
        usleep(1000);
    }
    fprintf(stderr, "Ending encryption, STATUS=%08X\n", status);
#ifdef TIMER_OFF
    fprintf(stderr, "Timer=%" PRIu32 "\n", TIMER);
#endif
    for (i = 0; i < n; i++)
    {
        printf_block(ocm + i * 4);
    }

hw_close_fi:
    fclose(fi);
hw_close_fk:
    fclose(fk);
hw_unmap_ocm:
    if(munmap(ocm, OCM_SIZE) == -1) // If cannot unmap
    {
        fprintf(stderr, "Failed to unmap OCM\n");
        ret = 1;
    }
hw_unmap_regs:
    if(munmap(regs, REGS_SIZE) == -1) // If cannot unmap
    {
        fprintf(stderr, "Failed to unmap registers\n");
        ret = 1;
    }
hw_close_fm:
    close(fm); // Close dev-mem character device
hw_end:
    return ret;
}

// vim: set tabstop=4 softtabstop=4 shiftwidth=4 expandtab textwidth=0:
