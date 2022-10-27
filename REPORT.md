# Implementation of a hardware accelerator for the SM4 block cipher

Table of content

---

- [Implementation of a hardware accelerator for the SM4 block cipher](#implementation-of-a-hardware-accelerator-for-the-sm4-block-cipher)
- [Team Members](#team-members)
- [Introduction](#introduction)
- [Block and States diagram](#block-and-states-diagram)
- [VHDL Source files](#vhdl-source-files)
  * [[`Work` Files](/vhdl/crypto)](#--work--files---vhdl-crypto-)
    + [[Crypto](/vhdl/crypto/crypto.vhd)](#-crypto---vhdl-crypto-cryptovhd-)
    + [[Counter](/vhdl/crypto/counter.vhd)](#-counter---vhdl-crypto-countervhd-)
    + [[Key Expansion](/vhdl/crypto/key_expansion.vhd)](#-key-expansion---vhdl-crypto-key-expansionvhd-)
    + [[Round Funtion Engine](/vhdl/crypto/round_function_engine.vhd)](#-round-funtion-engine---vhdl-crypto-round-function-enginevhd-)
    + [[Xor Engine](/vhdl/crypto/xor_engine.vhd)](#-xor-engine---vhdl-crypto-xor-enginevhd-)
    + [[AXI Slave Controller](/vhdl/crypto/slave_axi_ctrl.vhd)](#-axi-slave-controller---vhdl-crypto-slave-axi-ctrlvhd-)
    + [[AXI Master Controller](/vhdl/crypto/master_axi_ctrl.vhd)](#-axi-master-controller---vhdl-crypto-master-axi-ctrlvhd-)
  * [[`SM4` and `common` Files](/vhdl/common)](#--sm4--and--common--files---vhdl-common-)
    + [[SM4 Package](/crypto/common/sm4_pkg.vhd)](#-sm4-package---crypto-common-sm4-pkgvhd-)
- [Design choices](#design-choices)
- [Validation](#validation)
- [Synthesis results](#synthesis-results)
- [Performance](#performance)
- [Software components](#software-components)
    + [[Crypto Sim](/vhdl/crypto/crypto_sim.vhd)](#-crypto-sim---vhdl-crypto-crypto-simvhd-)
    + [[AXI Memory Optimized](/vhdl/common/axi_memory_optimized.vhd)](#-axi-memory-optimized---vhdl-common-axi-memory-optimizedvhd-)
    + [[Text Generating Python Script](/Python/text_sample.py)](#-text-generating-python-script---python-text-samplepy-)
    + [[Shell Script for Automated Tests](/launch_sim.sh)](#-shell-script-for-automated-tests---launch-simsh-)

---

# Team Members 

Chloé Bon : Chloe.Bon@eurecom.fr\
Pierre Fournier : Pierre.Fournier@eurecom.fr\
Naïs Schietecatte : Nais.Schietecatte@eurecom.fr

# Introduction

In this project, we designed a hardware accelerator for the SM4 block cipher, using the AXI4 Lite communication protocol for IOs. 

"In computing, a cryptographic accelerator is a co-processor designed specifically to perform computationally intensive cryptographic operations, doing so far more efficiently than the general-purpose CPU."

# Block and States diagram

![Block diagram of `crypto`](/images/Diagram.png)

# VHDL Source files

## [`Work` Files](/vhdl/crypto)

### [Crypto](/vhdl/crypto/crypto.vhd)

This is the global file where everything is instantiated, it has a state machine with 4 states : {Idle, Starting, Busy, Ending}

![State diagram of `crypto`](/images/STATE_MACHINE_CRYPTO.PNG)

### [Counter](/vhdl/crypto/counter.vhd)

Simple clock counter, made during [Lab 6](https://gitlab.eurecom.fr/renaud.pacalet/ds/-/tree/Pierre.Fournier/vhdl/lab06).

### [Key Expansion](/vhdl/crypto/key_expansion.vhd)

Entity in charge of computing the round keys, each round key is computed once then stored in its own register for the whole encryption process.

![Key Expansion](/images/KEY_EXPENSION_ALGO.PNG)

### [Round Funtion Engine](/vhdl/crypto/round_function_engine.vhd)

Instantiated 8 times in [Crypto](/vhdl/crypto/crypto.vhd), each instance computes 4 rounds.
There are handshake signals to ensure the pipeline is working correctly.

"engine" because it has a small state machine with 5 states : {Reset, Round1, Round2, Round3, Round4} 
and handles handshake signals between each stage of the pipeline.

![Round Funtion Engine](/images/ROUND_FUNCTION.PNG)

![Round Funtion Engine](/images/STATE_MACHINE_ROUND_FUNCTION.PNG)

### [Xor Engine](/vhdl/crypto/xor_engine.vhd)

Entity in charge of the xor between the plaintext and the output of the cryptographic engine.

"engine" because it handles the handshake signals between the in and out of the AXI master controller and the cryptographic engine. 

![Xor Engine](/images/RESULT_HANDLING.PNG)

### [AXI Slave Controller](/vhdl/crypto/slave_axi_ctrl.vhd)

Slave controller of the AXI4 Lite interface between the CPU and the crypto accelerator.

![AXI Slave Controller](/images/AXI4_LITE_COMMUNICATION_LEFT.PNG)

### [AXI Master Controller](/vhdl/crypto/master_axi_ctrl.vhd)

Master controller of the AXI4 Lite interface between the memory and the crypto accelerator.

![AXI Master Controller](/images/AXI4_LITE_COMMUNICATION.PNG)

## [`SM4` and `common` Files](/vhdl/common)

### [SM4 Package](/crypto/common/sm4_pkg.vhd)

Self made package containing sboxes, the key expansion function, the round function and many other utilities for the project.

# Design choices

The objective was to optimize the maximum in terms of throughput and latency.

- Full Pipeline architecture only limited by the AXI4 Lite interface, needed only 4 clock cycles for each 128 bits word to encrypt.

- We compute each round key only onceand then store them in registers, it takes some space but the energy saved should be non negligeable.

- The AXI Master controller has no *explicit* state machine but has two counters for reading and to counters for writing.
For each of reading/writing, there is a first, big counter that counter the number of words that have been read/written.
Then there is a second counter, going from 0 to 3 that is used to cut the 128 bits words into 32 bits words and selecting which to send.

# Validation

For validating the encryption, we made a [Python script](/Python/text_sample.py) 
that generates a key, an input text and its reference output for testing.

For debugging, as we wanted to be efficient, we first wrote every file needed and first made a [Crypto Sim File](/vhdl/crypto/crypto_sim.vhd)
to test everything directly. If needed we would have written some more speficied parts that might've needed some more attention.
The debugging went well and having the Crypto Sim File only was sufficient.

# Synthesis results

```
+----------------------------+------+-------+-----------+-------+
|          Site Type         | Used | Fixed | Available | Util% |
+----------------------------+------+-------+-----------+-------+
| Slice LUTs                 | 4337 |     0 |     17600 | 24.64 |
|   LUT as Logic             | 4269 |     0 |     17600 | 24.26 |
|   LUT as Memory            |   68 |     0 |      6000 |  1.13 |
|     LUT as Distributed RAM |    0 |     0 |           |       |
|     LUT as Shift Register  |   68 |     0 |           |       |
| Slice Registers            | 4377 |     0 |     35200 | 12.43 |
|   Register as Flip Flop    | 4377 |     0 |     35200 | 12.43 |
|   Register as Latch        |    0 |     0 |     35200 |  0.00 |
| F7 Muxes                   |  583 |     0 |      8800 |  6.63 |
| F8 Muxes                   |  288 |     0 |      4400 |  6.55 |
+----------------------------+------+-------+-----------+-------+

Check Type        Corner  Lib Pin      Required(ns)  Actual(ns)  Slack(ns)  Location
Min Period        n/a     BUFG/I       2.155         4.000       1.845      BUFGCTRL_X0Y0
Low Pulse Width   Slow    SRLC32E/CLK  0.980         2.000       1.020      SLICE_X8Y43
High Pulse Width  Fast    SRL16E/CLK   0.980         2.000       1.020      SLICE_X8Y54    
```

# Performance

We could get the maximum AXI4 Lite throughput at 250MHz clock frenquency and we have 32bits/clock cycle so **the performance is 8Gb/s**

# Software components

### [Crypto Sim](/vhdl/crypto/crypto_sim.vhd)

This is the file that we used to simulate the crypto.

### [AXI Memory Optimized](/vhdl/common/axi_memory_optimized.vhd)

This is an optimized version of the [AXI Memory](/vhdl/common/axi_memory.vhd) that was given. 
It was used to test the maximum throughput of the crypto

### [Text Generating Python Script](/Python/text_sample.py)

This is a simple Python script that automatically generate a key, a plaintext of 128 words of 128 bits,
its encrypted version using the algorithm we implemented in crypto, and outputs everything into different files and different text formats
for convenient use when testing.

### [Shell Script for Automated Tests](/launch_sim.sh)

**Beware, this script is made for a specific setup check the file before using it!**

It is a simple shell script that generates random input data and reference using the python script, places every file in the place it should be
for the simultation, launches the simulations, checks the diffs between the crypto output and the reference 
and then launches gtkwave for debugging.
