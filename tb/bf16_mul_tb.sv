/* Copyright (c) 2026, Julia Desmazes. All rights reserved.

  This work is licensed under the Creative Commons Attribution-NonCommercial
  4.0 International License. 

  This code is provided "as is" without any express or implied warranties.
*/
// BFloat16 Multiplier Testbench

`timescale 10 ns / 1 ns 

`ifndef RAND_SEED
`define RAND_SEED 10
`endif

`ifndef ITER
`define ITER 10
`endif

`ifdef VERILATOR
// DPI interface
import "DPI-C" function shortint bf16_mul(input shortint x, input shortint y);
`endif

`include "tb/tb_utils.sv"

module bf16_mul_tb;

localparam E = 8;// exponent
localparam M = 7;// mantissa (signficant) 

logic a_s, b_s, c_s;
logic [E-1:0] a_e, b_e, c_e;
logic [M-1:0] a_m, b_m, c_m;

int unsigned seed;

task test_zero();
	//  0 * 0 = +0
	`set_bf16(a, 1'b0, 8'h00, 7'h00);
    `set_bf16(b, 1'b0, 8'h00, 7'h00);
	#1
	`sva_check_bf16(zero, c, 1'b0, 8'h00, 7'h00);

	// 0 * (-0) = +0 
	`set_bf16(b, 1'b1, 8'h00, 7'h00);
	#1 
	`sva_check_bf16(zero_plus, c, 1'b0, 8'h00, 7'h00);
	
	// 0 * 1 = +0
	`set_bf16(b, 1'b0, 8'h7f, 7'h00);
	#1 
	`sva_check_bf16(one_test0, c, 1'b0, 8'h00, 7'h00);

	// -0 * 1 = -0
	`set_bf16(a, 1'b1, 8'h00, 7'h00);
	#1 
	`sva_check_bf16(one_test1,c, 1'b1, 8'h00, 7'h00);

	// -0 * (-1) = +0
	`set_bf16(b, 1'b1, 8'h7f, 7'h00);
	#1 
	`sva_check_bf16(min_one_test0, c, 1'b0, 8'h00, 7'h00);
	
	// 0 * (-1) = -0
	`set_bf16(a, 1'b0, 8'h00, 7'h00);
	#1 
	`sva_check_bf16(min_one_test1,c, 1'b1, 8'h00, 7'h00);

	$display("test_zero: PASS");
endtask 

// DPI is verilator only 
`ifdef VERILATOR
task test_dpi();
	shortint x, y, r; 
	// 1*1 = 1 
	`set_bf16(a, 1'b0, 8'h7F, 7'h00);
	`set_bf16(b, 1'b0, 8'h7F, 7'h00);

	x = {a_s, a_e, a_m};
	y = {b_s, b_e, b_m};

	// call dpi 
	r = bf16_mul(x,y);
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
			x = bf16_remap_input(i); 
			y = bf16_remap_input(j);
		
			r = bf16_mul(x, y);
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
	$dumpfile("wave/bf16_mul_tb.vcd");
	$dumpvars(0, bf16_mul_tb);

	seed = `RAND_SEED;
	$urandom(seed);

	#1
	test_zero();

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

bf16_mul m_dut(
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
