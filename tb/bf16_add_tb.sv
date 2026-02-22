// BFloat16 Adder Testbench

`timescale 10 ns / 1 ns 

`ifndef RAND_SEED
`define RAND_SEED 10
`endif

`ifndef ITER
`define ITER 10
`endif

`ifdef VERILATOR
// DPI interface
import "DPI-C" function void init_bf16(); 
import "DPI-C" function shortint bf16_add(input shortint x, input shortint y);
import "DPI-C" function shortint bf16_subnormal_to_zero(input shortint x); 
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
	#1
	`sva_check_bf16(zero, c, 1'b0, 8'h00, 7'h00);

	// 0 - 0 = +0 
	`set_bf16(b, 1'b1, 8'h00, 7'h00);
	#1 
	`sva_check_bf16(zero_plus, c, 1'b0, 8'h00, 7'h00);
	
	// 0 + 1
	`set_bf16(b, 1'b0, 8'h7f, 7'h00);
	#1 
	`sva_check_bf16(one_test0, c, 1'b0, 8'h7f, 7'h00);

	// -0 + 1
	`set_bf16(a, 1'b1, 8'h00, 7'h00);
	#1 
	`sva_check_bf16(one_test1,c, 1'b0, 8'h7f, 7'h00);

	// -0 - 1
	`set_bf16(b, 1'b1, 8'h7f, 7'h00);
	#1 
	`sva_check_bf16(min_one_test0, c, 1'b1, 8'h7f, 7'h00);
	
	// 0 - 1
	`set_bf16(a, 1'b0, 8'h00, 7'h00);
	#1 
	`sva_check_bf16(min_one_test1,c, 1'b1, 8'h7f, 7'h00);

	$display("test_zero: PASS");
endtask 

// whatever the value sent next to a nan, the result if allways nan
task test_nan();
	logic nan_sign; 
	logic [M-1:0] nan_mantissa;
	
	for(int i = 0; i < `ITER; i++) begin
		/* verilator lint_off WIDTHTRUNC */
		nan_sign = $urandom_range(1, 0);
		nan_mantissa = $urandom_range($rtoi($pow(2,M)-1), 1); 
		/* verilator lint_on WIDTHTRUNC */
		`set_bf16(a, nan_sign, {E{1'b1}}, nan_mantissa);
		for(int j=0; j < `ITER; j++) begin
			`set_rand_bf16(b)
			#1
			`sva_check_bf16(nan, c, nan_sign, {E{1'b1}}, {M{1'b1}});
				
		end
	end
	// +nan - nan  = +/-nan
	`set_bf16(a, 1'b0, 8'hFF, 7'h01);
    `set_bf16(b, 1'b1, 8'hFF, 7'h03);
	#1
	`sva_check_bf16(diff_nan, c, 1'b1, 8'hFF, 7'hFF);	

	$display("test_nan: PASS");
endtask

// test inf
task test_inf();
	logic inf_sign; 
	
	// + inf - inf  = -nan
	`set_bf16(a, 1'b0, 8'hFF, 7'h00);
    `set_bf16(b, 1'b1, 8'hFF, 7'h00);
	#1
	`sva_check_bf16(inf_nan, c, 1'b1, 8'hFF, 7'hFF);

	// + inf + 0 = +inf
	`set_bf16(a, 1'b0, 8'hFF, 7'h00);
    `set_bf16(b, 1'b0, 8'h00, 7'h00);
	#1
	`sva_check_bf16(inf_plus_zero, c, 1'b0, 8'hFF, 7'h00);


	// +/- inf + rand = inf
	for(int i = 0; i < `ITER; i++) begin
		/* verilator lint_off WIDTHTRUNC */
		inf_sign = $urandom_range(1, 0);
		/* verilator lint_on WIDTHTRUNC */
		`set_bf16(a, inf_sign, {E{1'b1}}, 7'h00);
		for(int j=0; j < `ITER; j++) begin
			`set_rand_bf16(b)
			#1
			`sva_check_bf16(inf_rand, c, inf_sign, {E{1'b1}}, {M{1'b0}});
				
		end
	end
	$display("test_inf: PASS");
endtask

// DPI is verilator only 
`ifdef VERILATOR
task test_dpi();
	shortint x, y, r; 
	// 1 + 1 
	`set_bf16(a, 1'b0, 8'h7F, 7'h00);
	`set_bf16(b, 1'b0, 8'h7F, 7'h00);

	x = {a_s, a_e, a_m};
	y = {b_s, b_e, b_m};

	// call dpi 
	r = bf16_add(x,y);
	bf16_pretty_print_triple(x,y,r);
endtask 


task test_batch(shortint start_x, shortint start_y);
	shortint x,y,r; 
	longint cnt; 
	shortint got;
	logic [15:0] a, b, c;
	shortint pass; 

	y = start_y;

	cnt = 0;
	for(shortint i = start_x; i < 16'hffff; i++) begin
		for(shortint j = (i == start_x)? start_y : 0; j < 16'hffff; j++) begin
			// sanitize inputs
			x = bf16_subnormal_to_zero(i); 
			y = bf16_subnormal_to_zero(j);
		
			r = bf16_add(x, y);
			a = x; 
			b = y; 
			c = r; 
			`set_bf16(a, a[15], a[14:7], a[6:0]);
			`set_bf16(b, b[15], b[14:7], b[6:0]);
			#1
`ifdef DEBUG
			$display("%d:", cnt);
			bf16_pretty_print_triple(i,y,r);
`endif
			got = { c_s, c_e, c_m };;
			pass = bf16_calculate_relative_error(r, got);	
			if (pass == 0) begin
				if (got != r) begin // pass will missfire on corner cases due to float unordering, kepping this behavior to not miss corner cases
					$display("Possible error detected at iteration %d (missfire on NaN sign)", cnt);
					bf16_pretty_print_triple(i, y, r);
					`sva_check_bf16_ignore_nan_sign(batch_test, c, c[15], c[14:7], c[6:0]);
				end
			end
			cnt = cnt + 1;
`ifndef DEBUG
			// log progress
			if (cnt % 1000000 == 0) begin
				$display("cnt: %d", cnt);
				bf16_pretty_print_triple(i,y,r);
			end
`endif
		end
	end
	$display("test_batch: PASS");
endtask 
`endif


initial begin
	$dumpfile("wave/bf16_add_tb.vcd");
	$dumpvars(0, bf16_add_tb);

	seed = `RAND_SEED;
	$urandom(seed);

	#1
	test_zero();
	#1 
	test_nan();
	#1
	test_inf();

`ifdef VERILATOR
	init_bf16();
	`ifdef DEBUG	
	#1
	test_dpi();
	`endif
	#1
	test_batch(0,0);
`endif

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
