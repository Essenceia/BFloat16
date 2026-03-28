`ifndef RAND_SEED
`define RAND_SEED 10
`endif

`ifndef TEST_RAND_ITER
`define TEST_RAND_ITER 10000
`endif

`default_nettype none
`timescale 1ns / 1ps

module booth_unsigned_mul_pipelined_tb;
localparam W = 8;
localparam MAX_VAL = $pow(2,W) - 1;

// x*y = res
logic [31:8]    a_unused, b_unused;
logic [W-1:0]   a,b; 
logic [2*W-1:0] res,exp;
logic clk = 1'b0;

task test_mul();

	for(int i=0; i < MAX_VAL; i++) begin
		for(int y=0; y < MAX_VAL; y++) begin
			{a_unused, a} = i;
			{b_unused, b} = y;
			exp = a * b;
			#10
			sva_match: assert(exp == res);
		end
	end	
endtask

always #5 clk <= !clk;

initial begin
	$dumpfile("wave/booth_unsigned_mul_pipelined_tb.vcd");
	$dumpvars(0, booth_unsigned_mul_pipelined_tb);
	#4	
	$urandom(`RAND_SEED);
	
	test_mul();

	$finish; 
end

booth_unsigned_mul_pipelined m_mul(
	.clk(clk),
	.data_i(a),
	.w_i(b),
	.res_o(res)
);

endmodule
