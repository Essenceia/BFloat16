// BFloat16 Adder Testbench

`timescale 10 ns / 1 ns 

`ifndef RAND_SEED
`define RAND_SEED 10
`endif

`ifndef ITER
`define ITER 10
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

`define set_rand_bf16(v) \
	v``_s = $urandom_range(1,0); \
	v``_e = $urandom_range($rtoi($pow(2,E)-1), 0);\
	v``_m = $urandom_range($rtoi($pow(2,M)-1), 0);

module bf16_add_tb;

localparam E = 8;// exponent
localparam M = 7;// mantissa (signficant) 

logic a_s, b_s, c_s;
logic [E-1:0] a_e, b_e, c_e;
logic [M-1:0] a_m, b_m, c_m;

int unsigned seed;

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

// whatever the value sent next to a nan, the result if allways nan
task test_nan();
	logic nan_sign, rand_sign; 
	logic [M-1:0] nan_mantissa, rand_mantissa; 
	
	for(int i = 0; i < `ITER; i++) begin
		nan_sign = $urandom_range(1, 0);
		nan_mantissa = $urandom_range($rtoi($pow(2,M)-1), 1); 
		`set_bf16(a, nan_sign, {E{1'b1}}, nan_mantissa);
		for(int j=0; j < `ITER; j++) begin
			`set_rand_bf16(b)
			#10
			`sva_check_bf16(nan, c, nan_sign, {E{1'b1}}, {M{1'b1}});
				
		end
	end
	$display("test_nan: PASS");
endtask

initial begin
	$dumpfile("wave/bf16_add_tb.vcd");
	$dumpvars(0, bf16_add_tb);

	seed = `RAND_SEED;
	$urandom(seed);

	#10
	test_zero();
	#10 
	test_nan();
	
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
