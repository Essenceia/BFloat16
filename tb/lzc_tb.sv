// Leading Zero Count Testbench 

`ifndef RAND_SEED
`define RAND_SEED 10
`endif

`ifndef TEST_RAND_ITER
`define TEST_RAND_ITER 100
`endif


module lzc_tb; 
localparam W = 16; 
localparam CNT_W = $clog2(W+1);
localparam int MAX_DATA_V = $rtoi($pow(2, W) - 1);

logic [W-1:0] data;
logic [CNT_W-1:0] cnt;


// simple test, send thermometers 
task test_thermo();
	int tmp;
	data = {W{1'b1}};
	#10
	sva_thermo_0: assert(cnt == 'd0);
	for(int i=1; i < W; i++) begin
		tmp = $rtoi($pow(2,i));
		/* verilator lint_off WIDTHTRUNC */
		data = tmp - 1;
		/* verilator lint_on WIDTHTRUNC */
		#10 
		/* verilator lint_off WIDTHEXPAND */
		sva_thermo_var: assert(cnt == W-i);
		/* verilator lint_on WIDTHEXPAND */
	end
	data = {W{1'b0}};
	#10 
	sva_thermo_max: assert(cnt == W);
	$display("test_thermo: PASS"); 
endtask

// randomized test, input vector isn't guarantied to be a thermo
task test_rand(int iter);
	int exp_lzc;
	logic [32-W-1:0] data_unused;
	for(int i = 0; i < iter; i++) begin
		{data_unused, data} = $urandom_range(MAX_DATA_V, 0);
		// cnt the number of leading zeros
		exp_lzc = 0;
		for(int j = 0; j < W && ~data[W-1-j]; j++) begin
				exp_lzc++;
		end
		#10
		sva_rand: assert(exp_lzc[CNT_W-1:0] == cnt);
	end
	$display("test_rand: PASS"); 
	
endtask


initial begin
	$dumpfile("wave/lzc_tb.vcd");
	$dumpvars(0, lzc_tb);

	$urandom(`RAND_SEED);
	
	test_thermo();

	test_rand(`TEST_RAND_ITER);

	$finish; 
end

lzc #(.W(W)) m_dut(
	.data_i(data),
	.cnt_o(cnt)
);

endmodule 
