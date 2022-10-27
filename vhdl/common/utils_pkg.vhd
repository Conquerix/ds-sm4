-- MASTER-ONLY: DO NOT MODIFY THIS FILE
--
-- Copyright (C) Telecom Paris
-- Copyright (C) Renaud Pacalet (renaud.pacalet@telecom-paris.fr)
--
-- This file must be used under the terms of the CeCILL. This source
-- file is licensed as described in the file COPYING, which you should
-- have received as part of this distribution. The terms are also
-- available at:
-- http://www.cecill.info/licences/Licence_CeCILL_V1.1-US.txt
--

--
-- Utility package
--
-- Defines utility procedures for simulation.

library ieee;
use ieee.std_logic_1164.all;

package utils_pkg is

    -- return true if b is '0' or '1', else false
    function is_01(b: std_ulogic) return boolean;
    -- return true if all bits of b are '0' or '1', else false
    function is_01(b: std_ulogic_vector) return boolean;
    -- check that v equals '0' or '1'; if not prints an error message and finish the simulation. s is the name of the faulty variable or signal, used in the error message. If not empty pre (post) is printed before (after) the error message.
    procedure check_unknowns(v: in std_ulogic; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns);
    -- check that all elements of v equal '0' or '1'; if not prints an error message and finish the simulation. s is the name of the faulty variable or signal, used in the error message. If not empty pre (post) is printed before (after) the error message.
    procedure check_unknowns(v: in std_ulogic_vector; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns);
    -- print string to standard output
    procedure print(s: in string := "");
    -- return now if t < 0, else t
    impure function now_or_what(t: time) return time;
    -- check that c is true r; if not prints an error message and finish the simulation. If not empty pre (post) is printed before (after) the error message.
    procedure check_ref(c: in boolean; pre: in string := ""; post: in string := ""; t: in time := -1 ns);
    -- all check-ref procedures check that v equals r; if not prints an error message and finish the simulation. s is the name of the faulty variable or signal, used in the error message. If not empty pre (post) is printed before (after) the error message.
    procedure check_ref(v, r: in integer; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns);
    procedure check_ref(v, r: in bit; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns);
    procedure check_ref(v, r: in bit_vector; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns);
    procedure check_ref(v, r: in std_ulogic; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns);
    procedure check_ref(v, r: in std_ulogic_vector; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns);
    -- print a sucess message and finish the simulation.
    procedure pass;
    function ds_to_string(v: time) return string;
    function ds_to_string(v: integer) return string;
    function ds_to_string(v: bit) return string;
    function ds_to_string(v: bit_vector) return string;
    function ds_to_string(v: std_ulogic) return string;
    function ds_to_string(v: std_ulogic_vector) return string;

    -- the log2 function returns the log base 2 of its parameter. the rounding
    -- is toward zero (log2(2) = log2(3) = 1)
    -- precision RTL when the parameter is a static constant.
    function log2(v: positive) return natural;
    function log2_down(v: positive) return natural;
    function log2_up(v: positive) return natural;

end package utils_pkg;

use std.textio.all;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;

package body utils_pkg is

    function is_01(b: std_ulogic) return boolean is
    begin
        return (b = '0') or (b = '1');
    end function is_01;

    function is_01(b: std_ulogic_vector) return boolean is
    begin
        for i in b'range loop
            if not is_01(b(i)) then
                return false;
            end if;
        end loop;
        return true;
    end function is_01;

    impure function now_or_what(t: time) return time is
    begin
        if t < 0 ns then
            return now;
        else
            return t;
        end if;
    end function now_or_what;

    procedure check_unknowns(v: in std_ulogic; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns) is
    begin
        if not is_01(v) then
            if pre'length > 0 then
                print(pre);
            end if;
            print("NON REGRESSION TEST FAILED - " & ds_to_string(now_or_what(t)));
            print("  INVALID " & s & " VALUE: " & ds_to_string(v));
            if post'length > 0 then
                print(post);
            end if;
            finish;
        end if;
    end procedure check_unknowns;

    procedure check_unknowns(v: in std_ulogic_vector; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns) is
    begin
        if not is_01(v) then
            if pre'length > 0 then
                print(pre);
            end if;
            print("NON REGRESSION TEST FAILED - " & ds_to_string(now_or_what(t)));
            print("  INVALID " & s & " VALUE: " & ds_to_string(v));
            if post'length > 0 then
                print(post);
            end if;
            finish;
        end if;
    end procedure check_unknowns;

    procedure print(s: in string := "") is
        variable l: line;
    begin
        write(l, s);
        writeline(output, l);
    end procedure print;

    procedure check_ref(c: in boolean; pre: in string := ""; post: in string := ""; t: in time := -1 ns) is
    begin
        if not c then
            if pre'length > 0 then
                print(pre);
            end if;
            print("NON REGRESSION TEST FAILED - " & ds_to_string(now_or_what(t)));
            if post'length > 0 then
                print(post);
            end if;
            finish;
        end if;
    end procedure check_ref;

    procedure check_ref(v, r: in integer; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns) is
    begin
        if v /= r then
            if pre'length > 0 then
                print(pre);
            end if;
            print("NON REGRESSION TEST FAILED - " & ds_to_string(now_or_what(t)));
            print("  EXPECTED " & s & "=" & ds_to_string(r));
            print("       GOT " & s & "=" & ds_to_string(v));
            if post'length > 0 then
                print(post);
            end if;
            finish;
        end if;
    end procedure check_ref;

    procedure check_ref(v, r: in bit; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns) is
    begin
        if v /= r then
            if pre'length > 0 then
                print(pre);
            end if;
            print("NON REGRESSION TEST FAILED - " & ds_to_string(now_or_what(t)));
            print("  EXPECTED " & s & "=" & ds_to_string(r));
            print("       GOT " & s & "=" & ds_to_string(v));
            if post'length > 0 then
                print(post);
            end if;
            finish;
        end if;
    end procedure check_ref;

    procedure check_ref(v, r: in bit_vector; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns) is
        constant lv: bit_vector(v'length - 1 downto 0) := v;
        constant lr: bit_vector(r'length - 1 downto 0) := r;
    begin
        for i in v'length - 1 downto 0 loop
            if lv(i) /= lr(i) then
                if pre'length > 0 then
                    print(pre);
                end if;
                print("NON REGRESSION TEST FAILED - " & ds_to_string(now_or_what(t)));
                print("  EXPECTED " & s & "=" & ds_to_string(r));
                print("       GOT " & s & "=" & ds_to_string(v));
                if post'length > 0 then
                    print(post);
                end if;
                finish;
            end if;
        end loop;
    end procedure check_ref;

    procedure check_ref(v, r: in std_ulogic; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns) is
    begin
        if r /= '-' and v /= r then
            if pre'length > 0 then
                print(pre);
            end if;
            print("NON REGRESSION TEST FAILED - " & ds_to_string(now_or_what(t)));
            print("  EXPECTED " & s & "=" & ds_to_string(r));
            print("       GOT " & s & "=" & ds_to_string(v));
            if post'length > 0 then
                print(post);
            end if;
            finish;
        end if;
    end procedure check_ref;

    procedure check_ref(v, r: in std_ulogic_vector; s: in string; pre: in string := ""; post: in string := ""; t: in time := -1 ns) is
        variable l: line;
        constant lv: std_ulogic_vector(v'length - 1 downto 0) := v;
        constant lr: std_ulogic_vector(r'length - 1 downto 0) := r;
    begin
        for i in v'length - 1 downto 0 loop
            if lr(i) /= '-' and lv(i) /= lr(i) then
                if pre'length > 0 then
                    print(pre);
                end if;
                print("NON REGRESSION TEST FAILED - " & ds_to_string(now_or_what(t)));
                print("  EXPECTED " & s & "=" & ds_to_string(r));
                print("       GOT " & s & "=" & ds_to_string(v));
                if post'length > 0 then
                    print(post);
                end if;
                finish;
            end if;
        end loop;
    end procedure check_ref;

    procedure pass is
        variable l: line;
    begin
        print("NON REGRESSION TEST PASSED - " & ds_to_string(now));
        finish;
    end procedure pass;

    function log2(v: positive) return natural is
        variable res: natural;
    begin
        if v = 1 then
            res := 0;
        else
            res := 1 + log2(v / 2);
        end if;
        return res;
    end function log2;

    function log2_down(v: positive) return natural is
    begin
        return log2(v);
    end function log2_down;

    function log2_up(v: positive) return natural is
        variable res: natural;
    begin
        if v = 1 then
            res := 0;
        else
            res := 1 + log2_up((v + 1) / 2);
        end if;
        return res;
    end function log2_up;

    function ds_to_string(v: time) return string is
    begin
        return v'subtype'image(v);
    end function ds_to_string;

    function ds_to_string(v: integer) return string is
    begin
        return v'subtype'image(v);
    end function ds_to_string;

    function ds_to_string(v: bit) return string is
    begin
        return v'subtype'image(v);
    end function ds_to_string;

    function ds_to_string(v: bit_vector) return string is
    constant n: natural := v'length;
    constant vv: bit_vector(n - 1 downto 0) := v;
    variable s: string(1 to 3);
    begin
        if n = 0 then
            return "";
        elsif n = 1 then
            s := bit'image(vv(0));
            return s(2 to 2);
        else
            return ds_to_string(vv(n - 1 downto n / 2)) & ds_to_string(vv(n / 2 - 1 downto 0));
        end if;
    end function ds_to_string;

    function ds_to_string(v: std_ulogic) return string is
    begin
        return v'subtype'image(v);
    end function ds_to_string;

    function ds_to_string(v: std_ulogic_vector) return string is
    constant n: natural := v'length;
    constant vv: std_ulogic_vector(n - 1 downto 0) := v;
    variable s: string(1 to 3);
    begin
        if n = 0 then
            return "";
        elsif n = 1 then
            s := std_ulogic'image(vv(0));
            return s(2 to 2);
        else
            return ds_to_string(vv(n - 1 downto n / 2)) & ds_to_string(vv(n / 2 - 1 downto 0));
        end if;
    end function ds_to_string;

end package body utils_pkg;

-- vim: set tabstop=4 softtabstop=4 shiftwidth=4 expandtab textwidth=0:
