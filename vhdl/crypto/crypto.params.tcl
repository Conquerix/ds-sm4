#
# Copyright (C) Telecom Paris
# Copyright (C) Renaud Pacalet (renaud.pacalet@telecom-paris.fr)
#
# This file must be used under the terms of the CeCILL. This source
# file is licensed as described in the file COPYING, which you should
# have received as part of this distribution. The terms are also
# available at:
# http://www.cecill.info/licences/Licence_CeCILL_V1.1-US.txt
#

# edit the following assignments to set the target clock frequency, the list of
# VHDL source files and the IO ports

# target clock frequency (MHz)
set f_mhz 250

# list of design units: FILE LIBRARY (files relative to vhdl)
array set dus {
    common/axi_pkg.vhd                    common
    common/sm4_pkg.vhd                    sm4
    crypto/crypto.vhd                     work
    crypto/counter.vhd                    work
    crypto/key_expansion.vhd              work
    crypto/master_axi_ctrl.vhd            work
    crypto/slave_axi_ctrl.vhd             work
    crypto/round_function_engine.vhd      work
    crypto/xor_engine.vhd                 work
}

# list of external ports: NAME { PIN IO_STANDARD }
array set ios {
    sw[0]   {G15 LVCMOS33}
    sw[1]   {P15 LVCMOS33}
    sw[2]   {W13 LVCMOS33}
    sw[3]   {T16 LVCMOS33}
    btn[0]  {R18 LVCMOS33}
    btn[1]  {P16 LVCMOS33}
    btn[2]  {V16 LVCMOS33}
    btn[3]  {Y16 LVCMOS33}
    led[0]  {M14 LVCMOS33}
    led[1]  {M15 LVCMOS33}
    led[2]  {G14 LVCMOS33}
    led[3]  {D18 LVCMOS33}
}

# vim: set tabstop=4 softtabstop=4 shiftwidth=4 expandtab textwidth=0:
