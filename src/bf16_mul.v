/* Copyright (c) 2026, Julia Desmazes. All rights reserved.

  This work is licensed under the Creative Commons Attribution-NonCommercial
  4.0 International License. 

  This code is provided "as is" without any express or implied warranties.


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
wire       a_nzero, b_nzero; 
wire       ab_zero; 
 
assign eab = ea_i + eb_i; 
assign {eab_diff_carry, eab_diff} = eab - B; 
assign {eab_diff_min1_carry, eab_diff_min1} = eab - B_MIN_1; 

// don't need to check mantissa since we don't support subnormal numbers
assign {a_nzero, b_nzero} = {|ea_i, |eb_i}; 
assign ab_zero = ~a_nzero | ~b_nzero;

// detect under/overflow, mul MSB is on critical path, so 
// detecting and correcting for overflow before normalization
wire eab_diff_overflow, eab_diff_underflow; 
wire eab_diff_min1_overflow, eab_diff_min1_underflow;
wire eab_diff_min1_clamp_max, eab_diff_clamp_max;
wire eab_diff_zero, eab_diff_min1_zero; 

assign eab_diff_overflow      = eab_diff[E] & ~eab_diff_carry;
assign eab_diff_min1_overflow = eab_diff_min1[E] & ~eab_diff_min1_carry;
assign eab_diff_underflow = eab_diff_carry | ab_zero;
assign eab_diff_min1_underflow = eab_diff_min1_carry | ab_zero;

// test when diff results in zero, before diff correction for better perf 
assign eab_diff_zero = ~|eab_diff[E:0] | eab_diff_underflow;
assign eab_diff_min1_zero = ~|eab_diff_min1[E:0] | eab_diff_min1_underflow;

// test when exponent has reached max, revent it from reaching inf
assign eab_diff_min1_clamp_max = &eab_diff_min1[E-1:1];
assign eab_diff_clamp_max = &eab_diff[E-1:1];

wire [E-1:0] eab_diff_cor, eab_diff_min1_cor;
// on overflow round toward zero clamps at largest finite floating point number e = 8'FE
// using consecutive masking logic to save on a mux being mistakenly infered, exploiting the
// fact overflow and underflow are exclusive 
assign eab_diff_cor = {E{~eab_diff_underflow}} 
					& {{{E-1{eab_diff_overflow | eab_diff_clamp_max}} | eab_diff[E-1:1]}, ~(eab_diff_overflow | eab_diff_clamp_max) & eab_diff[0]};
assign eab_diff_min1_cor = {E{~eab_diff_min1_underflow}} 
					     & {{{E-1{eab_diff_min1_overflow | eab_diff_min1_clamp_max}} | eab_diff_min1[E-1:1]}, ~(eab_diff_min1_overflow | eab_diff_min1_clamp_max) & eab_diff_min1[0]};

/* significant multiplication */
localparam int P2 = 2*(M+1); // double the size of the precision p=m+1 (hidden bit) 
 
wire [M:0] ma, mb; // include hidden bit
wire [P2-1:0] mz; // ma*mb =mz


assign {ma, mb} = {{a_nzero, ma_i}, {b_nzero, mb_i}}; // hidden bit is 0 on 0.0

// can't reuse existing 8 bit booth radix-4 multiplier because it was 
// optimized for signed numbers, these are unsigned.
// will be using the yosys's abc synthesized radix4 booth multiplier
// for unsigned
booth_unsigned_mul #(.W(M+1)) m_mul(
	.x_i(ma),
	.y_i(mb),
	.z_o(mz)
); 

// normalize 
wire [E-1:0] ez_norm;
wire         z_zero; // underflow
wire         z_max; // overflow
wire [M-1:0] mz_norm_lite;
wire [M-1:0] mz_norm; 
wire         mz_msb; 

assign mz_msb  = mz[P2-1];
assign ez_norm = mz_msb? eab_diff_min1_cor: eab_diff_cor;
assign z_zero  = mz_msb? eab_diff_min1_zero: eab_diff_zero;
assign z_max   = mz_msb? eab_diff_min1_overflow: eab_diff_overflow;

assign mz_norm_lite = mz_msb ? mz[P2-2-:M] : mz[P2-3-:M];
assign mz_norm = mz_norm_lite & {M{~z_zero}} | {M{z_max}};

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
