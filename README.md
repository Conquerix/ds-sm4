<!--
MASTER-ONLY: DO NOT MODIFY THIS FILE

Copyright (C) Telecom Paris
Copyright (C) Renaud Pacalet (renaud.pacalet@telecom-paris.fr)

This file must be used under the terms of the CeCILL. This source
file is licensed as described in the file COPYING, which you should
have received as part of this distribution. The terms are also
available at:
http://www.cecill.info/licences/Licence_CeCILL_V1.1-US.txt
-->

The final project of the DigitalSystems course

---

- [Evaluation](#evaluation)
- [Functional specifications](#functional-specifications)
  * [Notations](#notations)
  * [Encryption / decryption](#encryption---decryption)
  * [The `s0_axi` 32-bits AXI4 lite slave interface](#the--s0-axi--32-bits-axi4-lite-slave-interface)
  * [The `m0_axi` 32-bits AXI4 lite master interface](#the--m0-axi--32-bits-axi4-lite-master-interface)
- [Interface specifications](#interface-specifications)
- [Performance specifications](#performance-specifications)
- [Functional validation](#functional-validation)
- [Logic synthesis](#logic-synthesis)
- [Test on the Zybo](#test-on-the-zybo)
  * [Testing with `devmem`](#testing-with--devmem-)
    + [Store an input message somewhere in memory](#store-an-input-message-somewhere-in-memory)
    + [Pass the parameters to `crypto`](#pass-the-parameters-to--crypto-)
    + [Launch the encryption](#launch-the-encryption)
    + [Wait until the encryption finishes](#wait-until-the-encryption-finishes)
    + [Read the result](#read-the-result)
    + [Power off](#power-off)
  * [Testing with a simple C application](#testing-with-a-simple-c-application)
    + [Compile the test application for your host PC and test it](#compile-the-test-application-for-your-host-pc-and-test-it)
    + [Cross-compile the test application for the Zybo](#cross-compile-the-test-application-for-the-zybo)
    + [Generate test data files](#generate-test-data-files)
    + [Run the test application on the Zybo](#run-the-test-application-on-the-zybo)
    + [Power off](#power-off-1)
    + [Adding a hardware timer for performance measurements](#adding-a-hardware-timer-for-performance-measurements)

---

The goal of the project is to implement `crypto`, a hardware accelerator for the SM4 block cipher, which specifications can be found in [/doc/crypto.pdf](/doc/crypto.pdf).
The `crypto` hardware accelerator is used to encrypt an input message stored in the external Double Data Rate (DDR) memory.
The encrypted message is stored back in the external DDR memory, overwriting the original message.
SM4 supports various parameter values but `crypto` implements only the following:

| Key length | Block length | Rounds | Round keys | Round key length |
| :----      | :----        | :----  | :----      | :----            |
| 128        | 128          | 32     | 32         | 32               |


# Evaluation

The project accounts for 50% of the final grade.
All members of the group will get the same grade.
It will be evaluated based on your source code and your report which you will write in markdown format in the `/REPORT.md` file.
Do not neglect the report, it will have a significant weight.
Keep it short but complete:

- Provide block diagrams with a clear identification of the registers and of the combinatorial parts; name the registers, explain what the combinatorial parts do.
- Provide state diagrams and detailed explanations for your state machines.
- Explain what each VHDL source file contains and what its role is in the global picture.
- Detail and motivate your design choices (partitioning, scheduling of operations...)
- Explain how you validated each part.
- Comment your synthesis results (maximum clock frequency, resource usage...)
- Provide an overview of the performance of your cryptographic accelerator (e.g., in Mb/s).
- Document the companion software components you developed (drivers, scripts, libraries...)
- Provide a user documentation showing how to use your cryptographic accelerator and its companion software components.
- ...

Smart engineers optimize their work by reusing what can reasonably be reused.
Smart reuse of existing resources is thus encouraged and will be rewarded if and only if:

- You cite the original source, explain why you decided to use it, what you changed, why and how.
- It is **not** parts of the work of other groups, even after obfuscation, renaming of user identifiers...
  Plagiarism will be penalized.
  
About VHDL code that you may find on Internet: be careful, my experience shows that most of it was written by students like you, not by experts.
A significant proportion does not work at all and contains basic errors showing that the authors did not really understand digital hardware design and/or the VHDL language.
Another significant proportion is written at a disappointing low level (e.g., one entity/architecture pair for any 2 inputs multiplexer).
Sometimes the VHDL code you find was generated automatically from gate-level entry GUI tools, automatically translated into VHDL from another language, or from a netlist obtained after logic synthesis.
So, before reusing such code, please look at it carefully and ask yourself if it's really worth reusing.

A validated VHDL design with its simulation environment is of much higher value than a not validated VHDL design without a simulation environment.
So, if you can, try to also design simulation environments and to validate what you did by simulation.

# Functional specifications

`crypto` communicates with its environment with a 32-bits AXI4 lite slave interface `s0_axi` and a 32-bits AXI4 lite master interface `m0_axi`.
It receives parameters and commands from `s0_axi`.
The environment also uses `s0_axi` to read status information about `crypto`.
`crypto` reads the input message and writes the encrypted message through `m0_axi` (it is what is called a Direct Memory Access (DMA) capable peripheral).

![`crypto` in its environment](/images/crypto_in_environment-fig.png)  
_`crypto` in its environment_

## Notations

- |A|: length of bit string A in bits.
- A[i]: i-th bit of bit string A; by convention A[0] is the rightmost bit; A[|A|-1] is the leftmost bit.
- When A represents an integer A[0] is also the Least Significant Bit (LSB) and A[|A|-1] is the Most Significant Bit (MSB).
- A || B: concatenation of bit strings A and B.
- ⊕: exclusive OR.
- A ⊕ B: bitwise exclusive OR of bit strings A and B where |A| = |B|.
- A[i ... j]: bit slice of bit string A: A[i ... j] = A[i] A[i - 1] ... A[j].
- K: secret key; |K| = 128.
- SM4(K,B): encryption of block B with secret key K where |B| = 128.
- ICB: Initial Counter Block (public); |ICB| = 128.
- P: input message to encrypt; ICB is the first 128-bits block of P.
- C: encrypted message; |C| = |P|; ICB is the first 128-bits block of C.

## Encryption / decryption

The length of the message P to encrypt is a multiple of the block length: |P| = n * 128.
The ICB value is not secret (only the secret key is).
It is the first block of the input message and of the encrypted message.
It is not encrypted and is left unmodified, at the same memory location, after encryption.
The mode of operation implemented by `crypto` is the counter mode: a 128-bits counter, CNT, is initialized with ICB and repeatedly encrypted.
After each encryption of CNT its 32 LSB, considered as an unsigned integer, is incremented by one modulo $`2^{32}`$.
If we denote CNTi the i-th value of CNT, we have:

```math
CNT_1 = ICB;\ \forall\ i > 1,\ CNT_i = ICB[127 ... 32]\ ||\ (CNT_{i-1}[31 ... 0] + 1 \mod 2^{32})
```

Each block of the encrypted message, except the first one which is ICB, is the exclusive OR of the encrypted counter and the corresponding block of the input message. If we denote Pi the i-th block of P and Ci the i-th block of C, we have:

```math
P = P_0 || P_1 || ... || P_{n-1};\ C = C_0 || C_1 || ... || C_{n-1}
```

```math
P_0 = C_0 = ICB;\ \forall\ i \ge 1,\ C_i = SM4(K, CNT_i) \oplus P_i
```

A nice property of this counter mode is that decryption is exactly the same as encryption, with the same secret key and the same ICB.
So, encrypting twice without modifying the parameters produces the original input message.
A drawback is that the same CNT value shall never be used to encrypt more than one block with the same secret key, else the security is compromised.
But this can be easily guaranteed by limiting the length of the input messages to $`2^{32} \times 128`$ bits, that is $`2^{36}`$ bytes (64 GB) and by always using a fresh value for the 96 MSB of ICB to encrypt a new message.
The first constraint is not a problem because 64 GB is much more than our 1GB addressable memory space.
The second can be achieved by, for instance, always incrementing the 96 MSB of ICB after an input message has been encrypted.

## The `s0_axi` 32-bits AXI4 lite slave interface

The `s0_axi` 32-bits AXI4 lite slave interface is used by the environment to access the interface registers of `crypto`.
The address buses are 12-bits wide (the minimum supported by Xilinx tools).
The corresponding 4kB address space is the following (addresses are byte offsets from the base address of `crypto`):

| Name   | Byte offset | Byte length | Description                           |
| :----  | :----       | :----       | :----                                 |
| SBA    | 0           | 4           | Starting Byte Address, multiple of 16 |
| MBL    | 4           | 4           | Message Byte Length, multiple of 16   |
| CTRL   | 8           | 4           | ConTRoL register                      |
| STATUS | 12          | 4           | STATUS register                       |
| K      | 16          | 16          | secret Key                            |
| -      | 32          | 4064        | unmapped                              |

You can add more interface registers in the unmapped region if you wish (debugging, timer for performance measurements...)
CPU read or write accesses to unmapped addresses shall receive a DECERR response.
All CPU accesses are considered word-aligned: the 2 LSB of the read and write addresses are ignored; reading at addresses 0, 1, 2 or 3 returns the same 32 bits word.

SBA is the byte address of the first byte of the input (and output) message, that is the first byte of ICB; it is aligned on a 128-bits (16 bytes) boundary.
MBL is the byte length of the  input (and output) message, including ICB; it is also be a multiple of 16.
To guarantee that SBA and MBL are multiples of 16 their four LSB are hard-wired to zero: they always read as zeros and writing them has no effect.
The layout of K is little endian: K[7 ... 0] is stored at byte offset 16 and K[127 ... 120] is stored at byte offset 31.
But remember that the ARM processor is also little endian; when reading a 32-bits word (4 bytes) at address 16 we have:

```math
s0\_axi\_rdata = K[31 ... 0]
```

When reading a 32-bits word at address 20 we have:

```math
s0\_axi\_rdata = K[63 ... 32]
```

The 32-bits CTRL register is represented on the following figure:

![The CTRL control register](/images/ctrl-fig.png)  
_The CTRL control register_

- RST is an active high ReSeT; when RST is high `crypto` is entirely reset, except of course its `s0_axi` interface and its interface registers (else it would be impossible to recover from a soft reset).
- CE is a Chip Enable flag; when CE is low (and RST is low) `crypto` is entirely frozen, all registers keep their current value, except of course its `s0_axi` interface and its interface registers (else it would be impossible to recover from a chip disable).
- IE is an Interrupt Enable flag; when IE is high, and a message encryption ends, `crypto` raises its IRQ output for one clock period; when IE is low IRQ is maintained low, even at the end of a message encryption.

Writing the other bits has no effect; they read as zero.

The 32-bits STATUS register is represented on the following figure:

![The STATUS status register](/images/status-fig.png)  
_The STATUS status register_

- BSY is a BuSY flag; when a message encryption is ongoing BSY is high, else, when `crypto` is idle, BSY is low.
- IRQ is an Interrupt ReQuest flag; when a message encryption ends, even if it is because an error was encountered, IRQ is set to one.
- ERR is an ERRor flag; when an AXI4 read/write error is encountered on `m0_axi` during an encryption, the processing ends immediately (after the ongoing transactions on `s0_axi` and `m0_axi` are properly terminated according the AXI4 protocol) and the ERR flag is set to one.
- CAUSE is a 3-bits error code indicating the cause of an error:

  | Code  | Description                      |
  | :---- | :----                            |
  | 000   | No error (reset value)           |
  | 010   | Read slave error (AXI4 SLVERR)   |
  | 011   | Read decode error (AXI4 DECERR)  |
  | 110   | Write slave error (AXI4 SLVERR)  |
  | 111   | Write decode error (AXI4 DECERR) |
  | Other | Reserved                         |

When STATUS is read the current value of IRQ and ERR are returned as part of the read word, after which IRQ and ERR are set to zero.
When STATUS is written the written value is ignored; if `crypto` is idle (BSY is low) this write operation is considered as a start encryption command, else it is ignored.

**Important**: SBA, MBL and K are valid only when the STATUS register is written to start a new message encryption.
The cryptographic engine shall not rely on them past the start command because the environment can modify them any time to prepare for the next message encryption.
When a start encryption command is detected (and `crypto` is not busy) the content of SBA, MBL and K must thus be copied inside the cryptographic engine, before the next write request on `s0_axi` is served, and it is these copies that must be used during the current message encryption.

## The `m0_axi` 32-bits AXI4 lite master interface

The `m0_axi` 32-bits AXI4 lite master interface is used by `crypto` to read the input message and to write the encrypted message from/to memory.
The address buses are 32-bits wide, that is a total address space of 4GB.
The input message and the encrypted message are stored somewhere in this address space in little endian order: if x is the starting byte address of the memory region to encrypt, ICB[7 ... 0] is stored at address x, ICB[127 ... 120] at address x + 15, P1[7 ... 0] at address x + 16...
Again, as the ARM processor is also little endian, when reading a 32-bits word (4 bytes) at address x we have:

```math
m0\_axi\_rdata = ICB[31 ... 0]
```

When reading a 32-bits word at address x + 4 we have:

```math
m0\_axi\_rdata = ICB[63 ... 32]
```

And when reading a 32-bits word at address x + 16 we have:

```math
m0\_axi\_rdata = P1[31 ... 0]
```

# Interface specifications

The interface of `crypto` is the following:

| Name             | Type                             | Direction | Description                                                |
| :----            | :----                            | :----     | :----                                                      |
| `aclk`           | `std_ulogic`                     | in        | master clock                                               |
| `aresetn`        | `std_ulogic`                     | in        | **synchronous** active **low** reset                       |
| `s0_axi_araddr`  | `std_ulogic_vector(11 downto 0)` | in        | read address from CPU (12 bits = 4kB)                      |
| `s0_axi_arvalid` | `std_ulogic`                     | in        | read address valid from CPU                                |
| `s0_axi_arready` | `std_ulogic`                     | out       | read address acknowledge to CPU                            |
| `s0_axi_awaddr`  | `std_ulogic_vector(11 downto 0)` | in        | write address from CPU (12 bits = 4kB)                     |
| `s0_axi_awvalid` | `std_ulogic`                     | in        | write address valid flag from CPU                          |
| `s0_axi_awready` | `std_ulogic`                     | out       | write address acknowledge to CPU                           |
| `s0_axi_wdata`   | `std_ulogic_vector(31 downto 0)` | in        | write data from CPU                                        |
| `s0_axi_wstrb`   | `std_ulogic_vector(3 downto 0)`  | in        | write byte enables from CPU                                |
| `s0_axi_wvalid`  | `std_ulogic`                     | in        | write data and byte enables valid from CPU                 |
| `s0_axi_wready`  | `std_ulogic`                     | out       | write data and byte enables acknowledge to CPU             |
| `s0_axi_rdata`   | `std_ulogic_vector(31 downto 0)` | out       | read data response to CPU                                  |
| `s0_axi_rresp`   | `std_ulogic_vector(1 downto 0)`  | out       | read status response (OKAY, SLVERR or DECERR) to CPU       |
| `s0_axi_rvalid`  | `std_ulogic`                     | out       | read data and status response valid flag to CPU            |
| `s0_axi_rready`  | `std_ulogic`                     | in        | read response acknowledge from CPU                         |
| `s0_axi_bresp`   | `std_ulogic_vector(1 downto 0)`  | out       | write status response (OKAY, SLVERR or DECERR) to CPU      |
| `s0_axi_bvalid`  | `std_ulogic`                     | out       | write status response valid to CPU                         |
| `s0_axi_bready`  | `std_ulogic`                     | in        | write response acknowledge from CPU                        |
| `m0_axi_araddr`  | `std_ulogic_vector(31 downto 0)` | out       | read address to memory (32 bits = 4GB)                     |
| `m0_axi_arvalid` | `std_ulogic`                     | out       | read address valid to memory                               |
| `m0_axi_arready` | `std_ulogic`                     | in        | read address acknowledge from memory                       |
| `m0_axi_awaddr`  | `std_ulogic_vector(31 downto 0)` | out       | write address to memory (32 bits = 4GB)                    |
| `m0_axi_awvalid` | `std_ulogic`                     | out       | write address valid flag to memory                         |
| `m0_axi_awready` | `std_ulogic`                     | in        | write address acknowledge from memory                      |
| `m0_axi_wdata`   | `std_ulogic_vector(31 downto 0)` | out       | write data to memory                                       |
| `m0_axi_wstrb`   | `std_ulogic_vector(3 downto 0)`  | out       | write byte enables to memory                               |
| `m0_axi_wvalid`  | `std_ulogic`                     | out       | write data and byte enables valid to memory                |
| `m0_axi_wready`  | `std_ulogic`                     | in        | write data and byte enables acknowledge from memory        |
| `m0_axi_rdata`   | `std_ulogic_vector(31 downto 0)` | in        | read data response from memory                             |
| `m0_axi_rresp`   | `std_ulogic_vector(1 downto 0)`  | in        | read status response (OKAY, SLVERR or DECERR) from memory  |
| `m0_axi_rvalid`  | `std_ulogic`                     | in        | read data and status response valid flag from memory       |
| `m0_axi_rready`  | `std_ulogic`                     | out       | read response acknowledge to memory                        |
| `m0_axi_bresp`   | `std_ulogic_vector(1 downto 0)`  | in        | write status response (OKAY, SLVERR or DECERR) from memory |
| `m0_axi_bvalid`  | `std_ulogic`                     | in        | write status response valid from memory                    |
| `m0_axi_bready`  | `std_ulogic`                     | out       | write response acknowledge to memory                       |
| `irq`            | `std_ulogic`                     | out       | interrupt request to CPU                                   |
| `sw`             | `std_ulogic_vector(3 downto 0)`  | in        | wired to the four user slide switches                      |
| `btn`            | `std_ulogic_vector(3 downto 0)`  | in        | wired to the four user press buttons                       |
| `led`            | `std_ulogic_vector(3 downto 0)`  | out       | wired to the four user LEDs                                |

The slide switches, press buttons and LEDs have no specified role, use them as you wish (debugging...)
The entity declaration is already coded in `/vhdl/crypto/crypto.vhd`.
Please do not modify this entity declaration.

# Performance specifications

Try to implement the most powerful accelerator you can (multiple encryption rounds per clock cycle, pipelining, other types of parallel architcetures...)
Remember that the performance also depends on the clock frequency: computing twice more in a twice longer clock period does not change the processing power.
The performance on the `s0_axi` slave interface is not critical but things are different on the `m0_axi` master interface where the accesses shall be optimized in order to not slow down the encryption.
Read and write operations shall probably be parallel, read and write requests shall probably not be delayed while waiting for responses...

Note that with a 32-bits wide `m0_axi` interface, even if it is very optimized, reading or writing a block takes at least 4 clock cycles.
When targeting the maximum performance for your hardware accelerator do not try to go below 4 clock cycles per counter encryption, it would be a waste.

And remember that the resources in the FPGA fabric are limited.
Before designing a super-sophisticated deeply pipelined architecture check that it fits...

# Functional validation

In order to validate your design by simulation you will need:

- A simulation environment; design one.
- A reference to compare with; design one.

The easiest way to get a reference is probably to develop a software implementation of your block cipher (or use an existing one) in any language you like (C, python, java...)
Developing your own software is probably a nice way to really understand all details of the algorithm, and to get access to intermediate values, a very useful aspect for debugging.
Suggestion: design it such that it takes 2 parameters, the name of a text file containing the secret key in hexadecimal plus the name of a text file containing the input message (including ICB), and writes the output on the standard output.
Example where ICB = a1e4050cece528c0d28b4c155baa32fd and secret key is 62ce6d8b32b0af9657ad36b5e0ff8d88:

```bash
$ printf '62ce6d8b32b0af9657ad36b5e0ff8d88\n' > key.txt
$ head -n3 in.txt
a1e4050cece528c0d28b4c155baa32fd
d07c4fdc90afa9d22df43d5d7000cb23
eb7b17c5b316433a15c1d5784362f92a
$ ./my-crypto key.txt in.txt
a1e4050cece528c0d28b4c155baa32fd
...
...
```

Validate your software implementation against known test vectors for your block cipher.
If the specification document does not contain test vectors search Internet for test vectors or another reference implementation to compare with.

Once you are confident that your software implementation is correct, generate some random input and encrypt it:

```bash
$ hexdump -vn16 -e '4/4 "%08x" 1 "\n"' /dev/urandom > test1.key.txt
$ cat test1.key.txt
d3d04261647a792c1329a7382d355758
$ hexdump -vn1024 -e '4/4 "%08x" 1 "\n"' /dev/urandom > test1.in.txt
$ ./my-crypto test1.key.txt test1.in.txt > test1.out.txt
$ ls
test1.in.txt  test1.key.txt  test1.out.txt
```

Use these input and output data files in your simulation environment to verify that your `crypto` module works:

```vhdl
use std.textio.all;
...
    subtype w128_t is std_ulogic_vector(127 downto 0);
...
    process
        variable l: line;
        file f_key: text;
        file f_in: text;
        file f_out: text;
        variable k, icb, p, c, ref_c: w128_t;
    begin
        file_open(f_key, "test1.key.txt", read_mode);
        file_open(f_in, "test1.in.txt", read_mode);
        file_open(f_out, "test1.out.txt", read_mode);
        readline(f_key, l);
        hread(l, k);
        readline(f_in, l);
        hread(l, icb);
        readline(f_out, l);
        hread(l, icb);
        while not (endfile(f_in) or endfile(f_out)) loop
            readline(f_in, l);
            hread(l, p);
            readline(f_out, l);
            hread(l, ref_c);
            ... -- wait until encrypted block is written back to memory
            ... -- and capture it in variable c
            assert c = ref_c report "ENCRYPTION ERROR" severity error;
            ...
        end loop;
    end process;
```

If the language you selected for your software implementation is... VHDL, then you can also integrate your reference encryption function to your simulation environment, instead of using input and output reference text files:

```vhdl
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library common;
use common.rnd_pkg.all;
...
    subtype w128_t is std_ulogic_vector(127 downto 0);
...
    process
        variable rg: rnd_generator;
        variable k, icb, cnt, p, c, ref_c: w128_t;
    begin
        k   := rg.get_std_ulogic_vector(128);
        icb := rg.get_std_ulogic_vector(128);
        cnt := icb;
        for i in 1 to 1000 loop
            p := rg.get_std_ulogic_vector(128);
            ref_c := my_crypto(k, cnt, p);
            ... -- wait until encrypted block is written back to memory
            ... -- and capture it in variable c
            assert c = ref_c report "ENCRYPTION ERROR" severity error;
            ...
            cnt := cnt(127 downto 32) + (cnt(31 downto 0) + 1);
            ...
        end loop;
    end process;
```

Note that even in this case it can be useful to generate reference text files anyway such that they can also be used for the post-synthesis tests on the Zybo.
See the `std.textio` VHDL package and its `hwrite` and `writeline` procedures.

# Logic synthesis

You will now synthesize your design with the Vivado tool by Xilinx to map it in the programmable logic part of the Zynq core of the Zybo.
The clock (`aclk`) and the system reset (`aresetn`) will come from the microprocessor part of the Zynq core (the Processing System or PS).
The `sw`, `btn` and `led` input/outputs, will be wired to the user slide switches, press buttons and LEDs of the Zybo board.

The `vhdl/crypto/crypto.syn.tcl` and `vhdl/crypto/crypto.params.tcl` TCL scripts will automate the synthesis and the `vhdl/crypto/boot.bif` file will tell the Xilinx tools what to do with the synthesis result.
Before you can use the synthesis scripts, you will have to edit `crypto.params.tcl`.

1. Specify your target clock frequency with the `f_mhz` variable; example if you would like to run your design at 175 MHz:

   ```tcl
   set f_mhz 175
   ```

   Remember that this clock frequency is only a target; it could be that the synthesis tool cannot reach it; check the timing report and adjust your target clock frequency if you were too aggressive.
   Remember also that the PS cannot generate any clock frequency; the actual clock frequency will be the closest achievable not larger than your target clock frequency.

2. Add the VHDL source files that must be synthesized (not the simulation only files) and the name of the library they must be compiled in with the `dus` array; see the `axi_pkg` and `crypto` examples in `crypto.params.tcl` for the exact syntax.

3. Add information about the primary inputs and outputs (I/O), as we did for the labs, in the `ios` array.
   See figure 14, page 22/26 of the [Zybo reference manual], for the list of primary inputs and outputs; the signaling standard is the same for the 12 I/O: `LVCMOS33`.
   Example for `sw[0]`:

   ```tcl
   array set ios {
     sw[0] { G15 LVCMOS33 }
     ...
   ```

Cross-check your findings with your teammates.
If everything looks fine, synthesize:

```bash
$ ds=/some/where/ds
$ prj=/some/where/ds-sm4
$ syn=/tmp/$USER/ds-sm4/syn
$ mkdir -p "$syn"
$ cd "$syn"
$ vivado -mode batch -source "$prj/vhdl/crypto/crypto.syn.tcl" -notrace
```

All log messages are printed on the standard output and stored in the `vivado.log` log file.
If there are errors during the synthesis of your design it is this `vivado.log` file that probably contains the most valuable error messages.

A resource utilization report is available in `crypto.utilization.rpt`.
Open it and look at the first table of the `Slice Logic` section.
Check that the percentage of each resource that your design uses is "_reasonable_" (more than 80% can lead to place and route problems).
Check also that you do not have any unwanted "_Register as Latch_".
In tables 3 (memory) and 4 (DSP) check that you do not use any of these resources (unless you used some on purpose but this is unlikely for this project).
A hierarchical resource utilization report is available in `crypto.utilization.hierarchical.rpt`.
Open it and look at the first table of the `Utilization by Hierarchy` section.
Ignore the parts that have been added by Vivado to implement the AXI4 routing infrastructure and look at the parts under `crypto`.
Check that you have the expected number of one-bit registers (Flip Flops or FFs).
Check also that the other resources ("_LUT as Logic_", "_LUT as Memory_") are about in line with the complexity of your design.

A timing report is available in `crypto.timing.rpt`.
Open it and check that you do not have critical warnings or errors in the first sections.
Then, check that "_All user specified timing constraints are met_".
Look also at the first of the "_Max Delay Paths_" and try to understand where it starts from, where it ends and how long it is.

The main synthesis result is in `crypto.bit`.
It is a binary file called a *bitstream* that is used by the Zynq core to configure the programmable logic.

If there were no synthesis errors or serious warnings, if the resource utilization and timing reports look OK, you can now use the `bootgen` utility to pack the bitstream with the first (`fsbl.elf`) and second (`u-boot.elf`) stage software boot loaders that we already used in the labs and that can be found in `$ds/software`:

```bash
$ cd "$syn"
$ cp "$ds/software/fsbl.elf" .
$ cp "$ds/software/u-boot.elf" .
$ bootgen -w -image "$prj/vhdl/crypto/boot.bif" -o boot.bin 
```

The result is a *boot image*: `boot.bin`.

# Test on the Zybo

Mount the micro SD card on a computer and define a shell variable that points to it:

```bash
$ SDCARD=<path-to-mounted-sd-card>
```

If your micro SD card does not yet contain the software components of the DigitalSystems reference design, prepare it:

```bash
$ cd "$ds/software"
$ cp uImage devicetree.dtb uramdisk.image.gz "$SDCARD"
```

Copy the new boot image to the micro SD card:

```bash
$ cp "$syn/boot.bin" "$SDCARD"
$ sync
```

Unmount the micro SD card, eject it, plug it on the Zybo, power on the Zybo, launch your serial communication program (e.g. `picocom`) and attach it to the serial device that corresponds to the Zybo board (which you will first have to find).
Example under macOS with `picocom` if the device is `/dev/cu.usbserial-210279A42E221`:

```bash
$ picocom -b115200 /dev/cu.usbserial-210279A42E221
...
Welcome to DS (c) Telecom Paris
ds login: root
root@ds>
```

Example under GNU/Linux with `picocom` if the device is `/dev/ttyUSB1`:

```bash
$ picocom -b115200 /dev/ttyUSB1
...
Welcome to DS (c) Telecom Paris
ds login: root
root@ds>
```

You are now connected as the `root` user under the GNU/Linux OS that runs on the Zynq core of the Zybo board.
The default shell is `bash`.

In order to encrypt a message you will need to 1) store it somewhere in memory, 2) pass the parameters (Starting Byte Address, Message Byte Length, control flags, secret key) to your design, 3) launch the encryption, 4) wait until it finishes, and 5) read the result from memory.

For simple testing you can use the `devmem` utility.
For more advanced testing you will have to design a Linux driver and/or a C library and application (see below for a starting point C application).

## Testing with `devmem`

Let us see how to test your `crypto` design with `devmem`.

### Store an input message somewhere in memory

In the following we use a shell variable with uppercase name for the base addresses of a `crypto` interface register (e.g., `SBA` for the base address of the Starting Byte Address register), and a lowercase name for its content (e.g., `sba` for the content of the Starting Byte Address register).

The first thing to understand is that you cannot write some data to encrypt anywhere is the 4GB memory space.
Most of it is unmapped or mapped to non-memory devices, but even the parts that are mapped to memory cannot be used without precautions: if you modify a memory region that is currently in use by the Linux kernel, one of the many software services or a user application you could just crash the platform.
Fortunately there is a 256 kB memory region that corresponds to an On-Chip Memory (OCM) and that, by default, is not used by any software after the boot sequence completes (it is indeed used during the boot sequence).
This OCM is located in the `[0xfffc0000 ... 0xffffffff]` address range.
So, to install a 5-blocks (including ICB) all-zero message at the beginning of the OCM:

```bash
root@ds> devmem 0xfffc0000 32 0
root@ds> devmem 0xfffc0004 32 0
...
root@ds> devmem 0xfffc004c 32 0
```

Or, a bit more elegant (`nbl` for Number of BLocks and `mbl` for Message Byte Length):

```bash
root@ds> sba=0xfffc0000; nbl=5; mbl="$(( nbl * 16 ))"
root@ds> for (( i = 0; i < nbl * 4; i++ )); do
           devmem $(( sba + 4 * i )) 32 0
         done
root@ds>
```

Read back to check:

```bash
root@ds> for (( i = 0; i < nbl * 4; i++ )); do
           devmem $(( sba + 4 * i ))
         done
0x00000000
0x00000000
...
0x00000000
root@ds>
```

### Pass the parameters to `crypto`

For the next step you need to know at which physical address the `crypto` interface registers are mapped.
The `s0_axi` AXI4 lite slave interface is mapped at physical address `0x40000000` (see the `set_property offset` command of the `crypto.syn.tcl` synthesis script).
So, the `SBA` register is at address `0x40000000`, the `MBL` register is at `0x40000004`, etc.
Let us write their values (with a all-zero secret key):

```bash
root@ds> SBA=0x40000000; MBL=0x40000004; CTRL=0x40000008
root@ds> STATUS=0x4000000c; KEY=0x40000010
root@ds> devmem "$SBA" 32 "$sba"
root@ds> devmem "$MBL" 32 "$mbl"
root@ds> for (( i = 0; i < 4; i++ )); do
           devmem $(( KEY + 4 * i )) 32 0
         done
root@ds>
```

Let us also configure the `CTRL` register (no soft reset, chip enable, interrupt disabled):

```bash
root@ds> devmem "$CTRL" 32 2
```

Read back to check:

```bash
root@ds> for (( i = 0; i < 8; i++ )); do
           devmem $(( SBA + 4 * i ))
         done
0x00000000
0x00000050
0x00000002
0x00000000
0x00000000
0x00000000
0x00000000
0x00000000
root@ds>
```
### Launch the encryption

To launch the encryption just write any value in the `STATUS` register (`0x4000000c`).
Let us read it first to check that there is no on-going encryption:

```bash
root@ds> devmem "$STATUS"
0x00000000
root@ds>
```

Go!

```bash
root@ds> devmem "$STATUS" 32 0
root@ds>
```

### Wait until the encryption finishes

Just read the `STATUS` register and look at bit 0 (`BSY` or BuSY flag) and bit 1 (`IRQ` or Interrupt ReQuest flag):

```bash
[root@ds]> devmem "$STATUS"
0x00000002
root@ds>
```

`BSY` is clear and `IRQ` is set, meaning that the encryption completed.
The encryption is so fast that it was finished before you could type the next command.
Note that this read operation also clears `IRQ`; if you read `STATUS` again:

```bash
[root@ds]> devmem "$STATUS"
0x00000000
root@ds>
```

Note also that in this example there was no detected error (the `ERR` and `CAUSE` fields were clear).

### Read the result

(and check that it is correct)

```bash
root@ds> for (( i = 0; i < nbl * 4; i++ )); do
           devmem $(( sba + 4 * i ))
         done
0x00000000
0xF57FF04F
...
0xE5912100
root@ds>
```

### Power off

When you are done with your experiments, cleanly shut down the Zybo (do not forget to unmount the SD card if you mounted it):

```bash
root@ds> cd
root@ds> umount /media/sdcard
root@ds> poweroff
...
Requesting system poweroff
reboot: System halted
```

You can now safely power off the board.

## Testing with a simple C application

All operations that can be done manually on the command line could more conveniently be done by a piece of software.
The `C` directory contains such an application (`ctr_enc` for counter-mode encryption), coded in C, plus a `Makefile` to automate the compilation.

### Compile the test application for your host PC and test it

```bash
$ cd /some/where/ds-sm4/C
$ make ctr_enc
...
$ ./ctr_enc
Usage: ./ctr_enc [OPTION] KEYFILE DATAFILE
Use key in KEYFILE to encrypt DATAFILE.

  -h                hardware encryption (software is the default)

KEYFILE and DATAFILE are text files in hexadecimal form, 32 characters per line,
that is one 128-bits block per line. The leftmost character in a line encodes
the 4 leftmost bits of the block. Example:
  DEADBEEF00112233445566778899AABB
is the 128-bits block 1101_1110_1010...1011_1011. KEYFILE contains only one
line, the secret key to use for encryption. DATAFILE contains the Initial Counter
Block (ICB) followed by as many lines as blocks to encrypt. The encrypted input
is sent to the standard output, in the same format as the input, preceded by the
unmodified ICB.

If the TIMER_OFF macro is defined and set to the word offset of a 4-bytes
location in the registers area, its content is printed as an unsigned 32-bits
integer at the end of a hardware-accelerated encryption.

$ ./ctr_enc -h key.txt in.txt
Hardware encryption supported only on ARM platform
```

Of course you cannot use the hardware-accelerated implementation (`-h` option) on your host PC.

The test application can also use a pure software implementation of SM4, instead of the hardware-accelerated implementation.
But the provided one is not a real software implementation of SM4, it is a dummy block cipher that simply computes the bit-wise exclusive or of the secret key, the counter and the block of the input message.
To replace it by yours, just edit `utils.c` and replace the dummy `my_encrypt` function definition by your own C implementation.
When executing the application if you do not pass the `-h` option it uses the software implementation.
This should thus work on your host PC as well as on the Zybo (but of course it will be much slower on the Zybo than the hardware-accelerated version).

### Cross-compile the test application for the Zybo

To use the test application on the Zybo you will have to cross-compile it on a EURECOM desktop computer with the `arm-linux-gnueabihf-gcc` cross-compiler that comes with Vivado:

```bash
$ export PATH=/packages/LabSoC/Xilinx/bin
$ cd /some/where/ds-sm4/C
$ make ctr_enc ARM=1
./ctr_enc
-bash: ./ctr_enc: cannot execute binary file: Exec format error
```

The error message is normal, we tried to run an executable compiled for ARM on a x86-64 PC...

### Generate test data files

- Create a text file containing the secret key to use for encryption, in hexadecimal, on one single line (32 characters); example:

   ```bash
   $ cat key.txt
   64CB809C2C112B9970E32293253B1447
   ```

- Create a text file containing the input message to encrypt, in hexadecimal, one 128-bits block (32 characters) per line, starting with the ICB; example:

   ```bash
   $ cat in.txt
   1F1C6B65565D0688C58B607B6092214F
   10AC2F51B7FF50EEA2718EBB8BB6B112
   D8E31FA6E6DCD5403BC1ED003AF79909
   ...
   ```

- Use your software reference implementation of SM4 to also create a text file containing the expected output message, in hexadecimal, one 128-bits block (32 characters) per line, starting with the ICB; example:

   ```bash
   $ cat ref.txt
   1F1C6B65565D0688C58B607B6092214F
   6B7BC4A8CDB37DFF1719CC53CE1F841A
   A334F45F9C90F8518EA9AFE87F5EAC1E
   ...
   ```

### Run the test application on the Zybo

Mount the SD card on your PC, copy the generated `ctr_enc` executable and the 3 text files on the SD card:

```bash
$ cp ctr_enc key.txt in.txt ref.txt /path/to/sdcard
```

Unmount the SD card, plug it in the Zybo, power on, launch your terminal emulator and run the application with the `-h` option (for hardware acceleration):

```bash
$ picocom -b115200 /dev/ttyUSB1
...
Welcome to DS (c) Telecom Paris
ds login: root
root@ds> cd /media/sdcard
root@ds> ls
boot.bin             devicetree.dtb      key.txt
ctr_enc              in.txt              ref.txt
uImage               uramdisk.image.gz
root@ds> ./ctr_enc -h key.txt in.txt > out.txt
Starting encryption, STATUS=00000000
Ending encryption, STATUS=00000002
```

The result is in `out.txt`.
Compare with the reference:

```bash
root@ds> diff out.txt ref.txt
```

### Power off

When you are done with your experiments, cleanly shut down the Zybo (do not forget to unmount the SD card):

```bash
root@ds> cd
root@ds> umount /media/sdcard
root@ds> poweroff
...
Requesting system poweroff
reboot: System halted
```

You can now safely power off the board.

### Adding a hardware timer for performance measurements

A nice way to estimate the performance is to add a hardware timer to your design, for instance a 32-bits counter that is reset when an encryption starts and increments at the clock rate as long as `crypto` is busy.
If you implemented such a 32-bits timer in your hardware `crypto` design and added it to the interface registers accessible from the `s0_axi` AXI4 slave interface, you can tell the test application at compile time such that it prints the timer value at the end of the encryption.
Example if your timer is the next 32-bits register after the secret key (byte offset 32, word offset 8 from the base address of the `s0_axi` AXI4 slave interface):

```bash
$ make ctr_enc ARM=1 TIMER_OFF=8
```

And then:

```bash
$ picocom -b115200 /dev/ttyUSB1
...
Welcome to DS (c) Telecom Paris
ds login: root
root@ds> cd /media/sdcard
root@ds> ./ctr_enc -h key.txt in.txt > out.txt
Starting encryption, STATUS=00000000
Ending encryption, STATUS=00000002
Timer=81920
```

[Zybo reference manual]: /doc/data/zybo_rm.pdf

<!-- vim: set tabstop=4 softtabstop=4 shiftwidth=4 expandtab textwidth=0: -->
