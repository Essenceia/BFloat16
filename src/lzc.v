/* Tree Leading Zero Count 
 * 
 * This implementation works with the assumption that the 
 * input data width is a power of 2
 *
 * This monstrosity is getting its own tb 
 */ 
/* First level of the tree */
module lzc_leaf (
	input wire [1:0] pair_i,
	output wire [1:0] cnt_o
);

assign cnt_o[1] = ~pair_i[1] & ~pair_i[0]; // pair == 00
assign cnt_o[0] = ~pair_i[1] & pair_i[0]; // pair == 01
endmodule; 

/* Inner tree levels */ 
module lzc_inner #(
	parameter W = 2
)(

	input wire [W-1:0] left_i,
	input wire [W-1:0] right_i,

	output wire [W:0]  next_o
);
wire lmsb, rmsb; 

assign lmsb = left_i[W-1];
assign rmsb = right_i[W-1];

// this is where the magic happens
assign next_o = ~lmsb ? { 1'b0, left_i } : 
				 rmsb ? { 1'b1, {W{1'b0}}}:
						{ 1'b1, right_i};
endmodule

module lzc #(
	parameter  W = 4,
	localparam I_W = $clog2(W+1)
	)(
	input wire  [W-1:0]   data_i,
	output wire [I_W-1:0] cnt_o
	);

// first level, convert every leaf to there leading zero count
wire [W-1:0] leaf_lzc;
genvar i;
generate 
	for(i = 0; i < W/2 ; i = i+i)begin : g_leaf_lzc
		lzc_leaf m_leaf_lzc( 
			.pair_i(data_i[2*i+1:2*i]),
			.cnt_o(leaf_lzc[2*i+1:2*i])
		);
	end
endgenerate

wire [W-1:0] lzc_inner[I_W-2:0];
assign lzc_inner[0] = leaf_lzc;
// inner levels 
genvar j;
generate
	for(i=2; i < I_W ; i= i+1)begin: g_inner_lzc_lvl
		for(j=0; j < $clog2(W)-2; j = j + 1)begin: g_inner_lzc_span
		// left/right is a pair of 2*i bits
		lzc_inner #(.W(i))
		m_inner_lzc (
			.left_i (lzc_inner[i-2][2*i*(j+1)+:i]),
			.right_i(lzc_inner[i-2][2*i*j+:i]),
			.next_o (lzc_inner[i-1][(i+1)*j+:i+1])
		);
		end
	end
endgenerate

assign cnt_o = lzc_inner[I_W-2][I_W-1:0];
endmodule


