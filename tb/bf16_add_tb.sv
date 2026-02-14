// BFloat16 Adder Testbench

`timescale 10 ns / 1 ns 

`ifndef RAND_SEED
`define RAND_SEED 10
`endif

`define _sva_error_msg(name, exp, got) \
	$error("sva assert 'name' failed: \nexpected b%b\nreceived b%b\n", exp, got)

`ifdef VERILATOR
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

`define set_bf16(v, sign, exp, man) \
	v``_s = sign; \
	v``_e = exp; \
	v``_m = man; 

module bf16_add_tb;

logic a_s, b_s, c_s;
logic [7:0] a_e, b_e, c_e;
logic [6:0] a_m, b_m, c_m;

task test_zero();
	//  0 + 0
	`set_bf16(a, 1'b0, 8'h00, 7'h00);
    `set_bf16(b, 1'b0, 8'h00, 7'h00);
	#10
	`sva_check_bf16(zero, c, 1'b0, 8'h00, 7'h00);

	// 0 - 0 = +0 
	`set_bf16(b, 1'b1, 8'h00, 7'h00);
	#10 
	`sva_check_bf16(zero_plus, c, 1'b0, 8'h00, 7'h00);
	
	// 0 + 1
	`set_bf16(b, 1'b0, 8'h7f, 7'h00);
	#10 
	`sva_check_bf16(one_test0, c, 1'b0, 8'h7f, 7'h00);

	// -0 + 1
	`set_bf16(a, 1'b1, 8'h00, 7'h00);
	#10 
	`sva_check_bf16(one_test1,c, 1'b0, 8'h7f, 7'h00);

	// -0 - 1
	`set_bf16(b, 1'b1, 8'h7f, 7'h00);
	#10 
	`sva_check_bf16(min_one_test0, c, 1'b1, 8'h7f, 7'h00);
	
	// 0 - 1
	`set_bf16(a, 1'b0, 8'h00, 7'h00);
	#10 
	`sva_check_bf16(min_one_test1,c, 1'b1, 8'h7f, 7'h00);


	$display("test_zero: PASS");
endtask 

initial begin
	$dumpfile("wave/bf16_add_tb.vcd");
	$dumpvars(0, bf16_add_tb);

	//$urandom(`RAND_SEED);
	#10
	test_zero();
	
	$finish; 
end

bf16_add m_dut(
	.sa_i(a_s),
	.ea_i(a_e),
	.ma_i(a_m),

	.sb_i(b_s),
	.eb_i(b_e),
	.mb_i(b_m),

	.s_o(c_s),
	.e_o(c_e),
	.m_o(c_m)
);

endmodule
