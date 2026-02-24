/* Copyright (c) 2026, Julia Desmazes. All rights reserved.

  This work is licensed under the Creative Commons Attribution-NonCommercial
  4.0 International License. 

  This code is provided "as is" without any express or implied warranties.
*/

/* Collection of shared testbench utilitiaries, preventing code duplication */

`ifndef _TB_UTILS_SV
`define _TB_UTILS_SV

`ifdef VERILATOR
// DPI interface
import "DPI-C" function void init_bf16(); 
import "DPI-C" function shortint bf16_remap_input(input shortint x); 
import "DPI-C" function void bf16_pretty_print(input shortint x); 
import "DPI-C" function void bf16_pretty_print_triple(input shortint x, input shortint y, input shortint z); 
import "DPI-C" function shortint bf16_calculate_relative_error(input shortint x, input shortint y);
`endif

`define _sva_error_msg(name, exp, got) \
	$error("sva assert 'name' failed: \nexpected b%b\nreceived b%b\n", exp, got)

`ifdef VERILATOR
`define sva_check_bf16_ignore_nan_sign(sva_name, v, sign, exp,  man) \
	sva_check_bf16_sign_``sva_name    : assert((&v``_e & | v``_m) | (v``_s == sign)) else `_sva_error_msg(sva_check_bf16_sign_``sva_name,sign, (v``_s)); \
	sva_check_bf16_exponent_``sva_name: assert(v``_e == exp)  else `_sva_error_msg(sva_check_bf16_exponent_``sva_name, exp,  (v``_e)); \
	sva_check_bf16_mantissa_``sva_name: assert(v``_m == man)  else `_sva_error_msg(sva_check_bf16_mantissa_``sva_name, man,  (v``_m));
	
`define sva_check_bf16(sva_name, v, sign, exp,  man) \
	sva_check_bf16_sign_``sva_name    : assert(v``_s == sign) else `_sva_error_msg(sva_check_bf16_sign_``sva_name,sign, (v``_s)); \
	sva_check_bf16_exponent_``sva_name: assert(v``_e == exp)  else `_sva_error_msg(sva_check_bf16_exponent_``sva_name, exp,  (v``_e)); \
	sva_check_bf16_mantissa_``sva_name: assert(v``_m == man)  else `_sva_error_msg(sva_check_bf16_mantissa_``sva_name, man,  (v``_m));	
`else
`define sva_check_bf16(sva_name, v, sign, exp, man) \
	if (v``_s !== sign) `_sva_error_msg(sva_check_bf16_sign_``sva_name,    sign, (v``_s)); \
	if (v``_e !== exp)  `_sva_error_msg(sva_check_bf16_exponent_``sva_name, exp, (v``_e)); \
	if (v``_m !== man)  `_sva_error_msg(sva_check_bf16_mantissa_``sva_name, man, (v``_m));
`endif

// icarus verilog doesn't support structures, macro workaround
`define set_bf16(v, sign, exp, man) \
	v``_s = sign; \
	v``_e = exp; \
	v``_m = man; 

// generate a valid (not nan) integer number excluding inf
`define set_rand_bf16(v) \
	/* verilator lint_off WIDTHTRUNC */ \
	v``_s = $urandom_range(1,0); \
	v``_e = $urandom_range($rtoi($pow(2,E)-2), 0);\
	v``_m = $urandom_range($rtoi($pow(2,M)-1), 0);\
	/* verilator lint_on WIDTHTRUNC */

`endif // _TB_UTILS_SV

