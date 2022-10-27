library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- key expansion when ecrypting uses a constant parameter CK which is calcuulated using the table below
-- CK_i = ( ck_i,0 ; ck_i,1 ; ck_i,2 ; ck_i,3 ) and ck_i,j = (4i+j) * 7 mod (256)
-- When simulating, we will have to decide if it better to stock the ck_i,j or to calculate them once at the begining (we will choose according to their respective performance)

package sm4_pkg is

    subtype sm4_w8_t   is std_ulogic_vector(7 downto 0);
    subtype sm4_w32_t  is std_ulogic_vector(31 downto 0);
    subtype sm4_w128_t is std_ulogic_vector(127 downto 0);

    type sm4_rk_array_t is array(0 to 31) of sm4_w32_t;

    type sm4_reducer_array_t is array(0 to 3) of sm4_w32_t;

    type sm4_interface_registers_array_t is array(0 to 8) of sm4_w32_t;

    type sm4_round_function_io_array_t is array(0 to 8) of sm4_w128_t;

    function ck_function (v: natural range 0 to 31) return sm4_w32_t;

    function sm4_sbox(v: sm4_w8_t) return sm4_w8_t;

    function sm4_tau(Y: sm4_w32_t) return sm4_w32_t;

    function sm4_L(B: sm4_w32_t) return sm4_w32_t;

    function sm4_L_prime(Z: sm4_w32_t) return sm4_w32_t;

    function round_function(input: sm4_w128_t; rk: sm4_w32_t) return sm4_w128_t;

    function key_exp_function(input: sm4_w128_t; CK: sm4_w32_t) return sm4_w128_t;

end package sm4_pkg;


package body sm4_pkg is

    type constantCK_t is array (natural range 0 to 31) of sm4_w32_t;

    constant constantCK_c: constantCK_t := (
        x"00070e15", x"1c232a31", x"383f464d", x"545b6269", x"70777e85", x"8c939aa1", x"a8afb6bd", x"c4cbd2d9", x"e0e7eef5", x"fc030a11", x"181f262d", x"343b4249",
        x"50575e65", x"6c737a81", x"888f969d", x"a4abb2b9", x"c0c7ced5", x"dce3eaf1", x"f8ff060d", x"141b2229", x"30373e45", x"4c535a61", x"686f767d", x"848b9299",
        x"a0a7aeb5", x"bcc3cad1", x"d8dfe6ed", x"f4fb0209", x"10171e25", x"2c333a41", x"484f565d", x"646b7279"
    );

    function ck_function(v: natural range 0 to 31) return sm4_w32_t is
    begin
        return  constantCK_c(v);
    end function ck_function;

    type sm4_sbox_t is array (natural range 0 to 255) of sm4_w8_t;

    constant sm4_sbox_c: sm4_sbox_t := (
        x"d6",x"90",x"e9",x"fe",x"cc",x"e1",x"3d",x"b7",x"16",x"b6",x"14",x"c2",x"28",x"fb",x"2c",x"05",
        x"2b",x"67",x"9a",x"76",x"2a",x"be",x"04",x"c3",x"aa",x"44",x"13",x"26",x"49",x"86",x"06",x"99",
        x"9c",x"42",x"50",x"f4",x"91",x"ef",x"98",x"7a",x"33",x"54",x"0b",x"43",x"ed",x"cf",x"ac",x"62",
        x"e4",x"b3",x"1c",x"a9",x"c9",x"08",x"e8",x"95",x"80",x"df",x"94",x"fa",x"75",x"8f",x"3f",x"a6",
        x"47",x"07",x"a7",x"fc",x"f3",x"73",x"17",x"ba",x"83",x"59",x"3c",x"19",x"e6",x"85",x"4f",x"a8",
        x"68",x"6b",x"81",x"b2",x"71",x"64",x"da",x"8b",x"f8",x"eb",x"0f",x"4b",x"70",x"56",x"9d",x"35",
        x"1e",x"24",x"0e",x"5e",x"63",x"58",x"d1",x"a2",x"25",x"22",x"7c",x"3b",x"01",x"21",x"78",x"87",
        x"d4",x"00",x"46",x"57",x"9f",x"d3",x"27",x"52",x"4c",x"36",x"02",x"e7",x"a0",x"c4",x"c8",x"9e",
        x"ea",x"bf",x"8a",x"d2",x"40",x"c7",x"38",x"b5",x"a3",x"f7",x"f2",x"ce",x"f9",x"61",x"15",x"a1",
        x"e0",x"ae",x"5d",x"a4",x"9b",x"34",x"1a",x"55",x"ad",x"93",x"32",x"30",x"f5",x"8c",x"b1",x"e3",
        x"1d",x"f6",x"e2",x"2e",x"82",x"66",x"ca",x"60",x"c0",x"29",x"23",x"ab",x"0d",x"53",x"4e",x"6f",
        x"d5",x"db",x"37",x"45",x"de",x"fd",x"8e",x"2f",x"03",x"ff",x"6a",x"72",x"6d",x"6c",x"5b",x"51",
        x"8d",x"1b",x"af",x"92",x"bb",x"dd",x"bc",x"7f",x"11",x"d9",x"5c",x"41",x"1f",x"10",x"5a",x"d8",
        x"0a",x"c1",x"31",x"88",x"a5",x"cd",x"7b",x"bd",x"2d",x"74",x"d0",x"12",x"b8",x"e5",x"b4",x"b0",
        x"89",x"69",x"97",x"4a",x"0c",x"96",x"77",x"7e",x"65",x"b9",x"f1",x"09",x"c5",x"6e",x"c6",x"84",
        x"18",x"f0",x"7d",x"ec",x"3a",x"dc",x"4d",x"20",x"79",x"ee",x"5f",x"3e",x"d7",x"cb",x"39",x"48"
    );

    function sm4_sbox(v: sm4_w8_t) return sm4_w8_t is
    begin
        return sm4_sbox_c(to_integer(v));
    end function sm4_sbox;

    function sm4_tau(Y: sm4_w32_t) return sm4_w32_t is
    begin
        return sm4_sbox(Y(31 downto 24)) & sm4_sbox(Y(23 downto 16)) & sm4_sbox(Y(15 downto 8)) & sm4_sbox(Y(7 downto 0));
    end function sm4_tau;

    function sm4_L(B: sm4_w32_t) return sm4_w32_t is
    begin
        return B xor (B(29 downto 0) & B(31 downto 30)) xor (B(21 downto 0) & B(31 downto 22)) xor (B(13 downto 0) & B(31 downto 14))  xor (B(7 downto 0) & B(31 downto 8));
    end function sm4_L;

    function sm4_L_prime(Z: sm4_w32_t) return sm4_w32_t is
    begin
        return Z xor (Z(18 downto 0) & Z(31 downto 19)) xor (Z(8 downto 0) & Z(31 downto 9));
    end function sm4_L_prime;

    function round_function(input: sm4_w128_t; rk: sm4_w32_t) return sm4_w128_t is
    begin
        return input(95 downto 0) & (input(127 downto 96) xor sm4_L(sm4_tau(input(95 downto 64) xor input(63 downto 32) xor input(31 downto 0) xor rk)));
    end function round_function;

    function key_exp_function(input: sm4_w128_t; CK: sm4_w32_t) return sm4_w128_t is
    begin
        return input(95 downto 0) & (input(127 downto 96) xor sm4_L_prime(sm4_tau(input(95 downto 64) xor input(63 downto 32) xor input(31 downto 0) xor CK)));
    end function key_exp_function;
end package body sm4_pkg;
