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

/* exponent addition */
localparam [E:0] B       = 9'd127; 
localparam [E:0] B_MIN_1 = 9'd126;

wire [E:0] eab; // ea + eb  
wire [E:0] eab_diff, eab_diff_min1;
wire       eab_diff_carry;
wire       eab_diff_min1_carry;
 
assign eab = ea_i + eb_i; 
assign {eab_diff_carry, eab_diff} = eab - B; 
assign {eab_diff_min1_carry, eab_diff_min1} = eab - B_MIN_1; 

// detect under/overflow, mul MSB is on critical path, so 
// detecting and correcting for overflow before normalization
wire eab_diff_overflow, eab_diff_uderflow; 
wire eab_diff_min1_overflow, eab_diff_min1_uderflow; 

assign eab_diff_overflow = eab_diff[E];
assign eab_diff_underflow = eab_diff_carry;
assign eab_diff_min1_overflow = eab_diff_min1_b[E];
assign eab_diff_min1_underflow = eab_diff_min1_b_carry;

wire [E-1:0] eab_diff_cor, eab_diff_min1_cor;
// on overflow round toward zero clamps at largest finite floating point number e = 8'FE
// using consecutive masking logic to save on a mux being mistakenly infered, exploiting the
// fact overflow and underflow are exclusive 
assign eab_diff_cor = {E{~eab_diff_underflow}} 
					& {{{E-1{eab_diff_overflow}} | eab_diff[E-1:1]}, ~eab_diff_overflow & eab_diff[0]};
assign eab_diff_min1_cor = {E{~eab_diff_min1_underflow}} 
					     & {{{E-1{eab_diff_min1_overflow}} | eab_min1_diff[E-1:1]}, ~eab_diff_min1_overflow & eab_min1_diff[0]};

/* significant multiplication */
wire [M:0] ma, mb; // include hidden bit
wire       a_nzero, b_nzero; 
wire [2*M:0] mz; // ma*mb =mz

// don't need to check mantissa since we don't support subnormal numbers
assign {a_nzero, b_nzero} = {|ea_i, |eb_i}; 
assign {ma, mb} = {{a_nzero, ma_i}, {b_nzero, mb_i}}; // hidden bit is 0 on 0.0

// can't reuse existing 8 bit booth radix-4 multiplier because it was 
// optimized for signed numbers, these are unsigned.
// will be using the yosys's abc synthesized radix4 booth multiplier
// for unsigned
booth_unsigned_mul #(.W(M+1)) m_mul
	.x_i(ma),
	.y_i(mb),
	.z_o(mz)
); 

// normalize 
wire [E-1:0] ez_norm;
wire         z_zero; // underflow
wire         z_max; // overflow
wire [M-1:0] mz_norm_lite;
wire [M-1:0] mz_lite; 

assign ez_norm = mz[M*2-1]? eab_diff_min1_cor: eab_diff_cor;
assign z_zero  = mz[M*2-1]? eab_diff_min1_underflow: eab_diff_underflow;
assign z_max   = mz[M*2-1]? eab_diff_min1_overflow: eab_diff_overflow;

assign mz_norm_lite = mz[M*2-1] ? mz[M*2-2:M-1] : mz[M*2-1:M];
assign mz_norm = mz & {M{~z_zero}} | {M{z_max}};

/* result */ 
assign s_o = sa_i ^ sb_i; 
assign e_o = ez_norm;
assign m_o = mz_norm; 

`ifdef FORMAL

always @(*) begin
	// xcheck
	sva_xcheck_i: assert( ~$isunknown({sa_i, ea_i, ma_i, sb_i, eb_i, mb_i});
	sva_xcheck_o: assert( ~$isunknown({s_o, e_o, m_o});

	// exponent overflow and underflow are mutually exclusive
	sva_exponent_overflow_underflow_diff_exclusive: assert( $onehot0({eab_diff_overflow, eab_diff_underflow});
	sva_exponent_overflow_underflow_diff_min1_exclusive: assert( $onehot0({eab_diff_min1_overflow, eab_diff_min1_underflow});
end

`endif
endmodule
endmodule
