// Leading Zero Count Testbench 

module lzc_tb; 
localparam W = 16; 
localparam CNT_W = $clog2(W+1);

logic [W-1:0] data;
logic [CNT_W-1:0] cnt;


// simple test, send thermometers 
task check_thermo();
	int tmp;
	data = {W{1'b1}};
	#10
	assert(cnt == 'd0);
	for(int i=1; i < W; i++) begin
		tmp = $rtoi($pow(2,i));
		/* verilator lint_off WIDTHTRUNC */
		data = tmp - 1;
		/* verilator lint_on WIDTHTRUNC */
		#10 
		/* verilator lint_off WIDTHEXPAND */
		assert(cnt == W-i);
		/* verilator lint_on WIDTHEXPAND */
	end
	data = {W{1'b0}};
	#10 
	assert(cnt == W);
endtask

initial begin
	$dumpfile("wave/lzc_tb.vcd");
	$dumpvars(0, lzc_tb);
	
	check_thermo();

	$finish; 
end

lzc #(.W(W)) m_dut(
	.data_i(data),
	.cnt_o(cnt)
);

endmodule 
