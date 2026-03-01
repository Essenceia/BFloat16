/* Wide mux : count leading zero's */ 
module wide_mux #(
	localparam W = 8,
	localparam IDX_W = $clog2(W+1)
)(
	input wire [W-1:0] data_i, 
	output wire [IDX_W-1:0] lzc_o
);

wire [W-1:0] data_rev;
genvar i; 
generate
	for(i = 0; i < W; i=i+1) begin: gen_data_reverse
		assign data_rev[i] = data_i[W-1-i];
	end
endgenerate

wire [W-1:0] data_p1;
wire         data_p1_carry_unused; 
wire [W-1:0] x1; 

assign {data_p1_carry_unused, data_p1} = data_i + 8'd1; 
assign x1 = (data_rev & ~data_p1);

assign lzc_o[3] = ~|data_i;//data_i == 8'd0
assign lzc_o[0] = |(x1 & 8'haa);
assign lzc_o[1] = |(x1 & 8'hcc);
assign lzc_o[2] = |(x1 & 8'hf0};
endmodule
