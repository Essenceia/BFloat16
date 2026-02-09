// Leading Zero Count Testbench 

module lzc_tb; 
localparam W = 12; 
localparam CNT_W = $clog2(W);

wire [W-1:0] data;
wire [CNT_W-1:0] cnt;


// simple test, send thermometers 
task check_thermo();
	data = {W{1'b1}};
	#10
	assert(cnt == 'd0);
	for(int i=1; i < W; i++) begin
		data = {{i{1'b0}}, {W-i{1'b1}}};
		#10 
		assert(cnt == i);
	end
	data = {W{1'b0}};
	#10 
	assert(cnt == W);
endtask

initial begin
	$dumpfile("wave/lzc_tb.vcd");
	$dumpvars(0, lzc_tb);
	
	check_termo();

	$finish; 
end

lzc #(.W(W)) m_dut(
	.data_i(data),
	.cnt_o(cnt)
);

endmodule 
