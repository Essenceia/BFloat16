// BFloat16 Adder Testbench

`ifndef RAND_SEED
`define RAND_SEED 10
`endif

`define sva_check_bf16(sva_name, v, sign, exp,  man) \
	sva_check_bf16_sign_``sva_name: assert(v.s == sign); \
	sva_check_bf16_exponent_``sva_name: assert(v.e == exp); \
	sva_check_bf16_mantissa_``sva_name: assert(v.m == man);	
 
module bf16_add_tb;

typedef struct {
	logic s; // sign
	logic [7:0] e; // exponent
	logic [6:0] m; // mantissa (significant)
} bf16_t;

bf16_t a, b,c;

function set_bf16(logic sign, logic [7:0] exp, logic [6:0] man);
	bf16_t tmp; 
	tmp.s = sign; 
	tmp.e = exp; 
	tmp.m = man; 
	return tmp;
endfunction

task test_zero();

	//  0 + 0
	a = set_bf16(0, '0, '0);
	b = set_bf16(0, '0, '0);
	#10
	`sva_check_bf16(zero, c, 0, '0, '0);

	// 0 - 0 = +0 
	b = set_bf16(1, '0, '0);
	#10 
	`sva_check_bf16(zero_plus, c, 0, '0, '0);
	// 0 + 1
	b = set_bf16( 1, 8'h7f, '0);
	#10 
	`sva_check_bf16(_one_test0, c, 0, 8'h7f, '0);

	// -0 + 1
	a = set_bf16(1, '0, '0);
	#10 
	`sva_check_bf16(_one_test1,c, 0, 8'h7f, '0);

	$display("test_zero: PASS");
endtask 

initial begin
	$dumpfile("wave/bf16_add_tb.vcd");
	$dumpvars(0, bf16_add_tb);

	$urandom(`RAND_SEED);
	#10
	test_zero();
	
	$finish; 
end

bf16_add m_dut(
	.sa_i(a.s),
	.ea_i(a.e),
	.ma_i(a.m),

	.sb_i(b.s),
	.eb_i(b.e),
	.mb_i(b.m),

	.s_o(c.s),
	.e_o(c.e),
	.m_o(c.m)
);

endmodule
