/* 
  Bfloat16 multiplication 
  c = a*b

  a = { s_a, e_a, m_a }
  b = { s_b, e_b, m_b }
*/	
module bf16_mul #(
	localparam int E = 8,
	localparam int M = 7
)(
	input wire sa_i,
	input wire [E-1:0] ea_i,
	input wire [M-1:0] ma_i,

	input wire sb_i,
	input wire [E-1:0] eb_i,
	input wire [M-1:0] mb_i,


	output wire s_o,
	output wire [E-1:0] e_o,
	output wire [M-1:0] m_o
);

`ifdef FORMAL

always @(*) begin
	// xcheck
	sva_xcheck_i: assert( ~$isunknown({sa_i, ea_i, ma_i, sb_i, eb_i, mb_i});
	sva_xcheck_o: assert( ~$isunknown({s_o, e_o, m_o});
end

`endif
endmodule
endmodule
