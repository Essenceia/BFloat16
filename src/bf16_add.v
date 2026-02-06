/* 
  Bfloat16 addition
  c = a+b

  a = { s_a, e_a, m_a }
  b = { s_b, e_b, m_b }

*/
module bf16_add #(
	localparam E = 8,
	localparam M = 7
)
(
	input wire sa_i,
	input wire [E-1:0] ea_i,
	input wire [M-1:0] ma_i,

	input wire sb_i,
	input wire [E-1:0] eb_i,
	input wire [M-1:0] mb_i,


	output wire s_o,
	output wire [E-1:0] e_o,
	output wire [M-1:0] m_o,
);

/* Internally the addition is performed on 
   z = x + y
   with x >= to y
  this is the swapped version of a and b */

/* ----------------
   compare and swap 
   ---------------- */
//exponent
wire [E-1:0] ex, ey, exy_diff;
wire [M-1:0] mx, my;
wire [E-1:0] eab_diff, eba_diff;
wire         eab_diff_carry, eba_diff_carry;

assign {eab_diff_carry, eab_diff} = ea_i - eb_i;
assign {eba_diff_carry, eba_diff} = eb_i - ea_i;

assign exy_diff = ~eab_diff_carry? eab_diff ? eba_diff;
assign {ex, ey} = ~eab_diff_carry? {ea_i, eb_i} ? {eb_i, ea_i}; 
assign {mx, my} = ~eab_diff_carry? {ma_i, mb_i} ? {mb_i, ma_i}; 

/* --------
   far path  
   -------- */
// stupidly expensive shifter made a little cheaper by the fact we only need
// M+1 bits in the end and that the close path handles the 0 and 1 difference
// case
// exy_diff is strickly positive
wire [M-2:0] my_shift_lite;
wire [M:0]   my_shift;
wire         shift_underflow; 

always @(*) begin
	case(exy_diff[2:0])
		2: my_shift_lite = {1'b1, my[M-1:2];
		3: my_shift_lite = {1'b0, 1'b1, my[M-1:3];
		4: my_shift_lite = {2'b0, 1'b1, my[M-1:4];
		5: my_shift_lite = {3'b0, 1'b1, my[M-1:5];
		6: my_shift_lite = {4'b0, 1'b1, my[6];
		7: my_shift_lite = {5'b0, 1'b1};
		default: my_shift_lite = {M-1{1'bX}};// handled by close path, don't care, letting the optimization do what it wants
	endcase
end

// detect if we have shifted more than the entire significant's worth, shift
// > 7 
assign shift_underflow = |exy_diff[E-1:3];
assign my_shift = shift_underflow ? {M{1'b0}} : {1'b0, my_shift_lite};


// operation can be either positive or negative: m_r = m_x +/- m_y 
wire op_sub; 
wire [M+1:0] mr;
wire mr_carry;
assign op_sub = sa_i ^ sb_i; 
assign {my_carry, mr} = {1'b1,mx} + ({M+1{op_sub}}^my_shift) + op_sub;

// normalize: 2 bit shifter
// if addition: division by 2 might be needed 
// if substraction: multiplication by 2 might be needed 
wire [M:0] mr_norm;
wire [E-1:0] er_norm;
wire         er_norm_carry;

// a little ugly but useing a case to give more flexibility for optimization
always @(*) begin
	case(mr[M+1:M])
		2'b00: begin // divide by 2
			{er_norm_carry, er_norm} = er - {{E-2{1'b0}},1'b1};
			mr_norm = {m_r[M-1:0], 1'b0}; // should I have kept the guard bit to inject it here?
		begin
		2'b1X: begin // multiply by 2 
			{er_norm_carry, er_norm} = er + {{E-2{1'b0}},1'b1};
			mr_norm = {1'b0, m_r[M+1:1]}; 
		begin
		default: begin
			er_norm_carry = 1'b0;
			er_norm = ex;
			mr_norm = mr[M:0];
		end
	endcase
end
			 
/* ---------
 * close path 
 * ---------- */

// 1 bit shift
wire exy_eq; 
wire [M+1:0] my_cp_shifted; // p+1 width, including hidden 1
wire [M+1:0] mx_cp; 

assign exy_eq = ~eab_diff_carry & ~eba_diff_carry; // 1 = equal, 0 = not equal 
assign my_cp_shifted = exy_eq ? {1'b1, my, 1'b0} : 
								{1'b0, 1'b1, my}; // div 2, e_x - e_y = 1, e_x - e_y > 1 will be handed by far path  
assign mx_cp = { 1'b1, mx, 1'b0};

// absolute difference between significants 
wire [M+1:0] mxy_cp_abs_diff;
wire [M+1:0] mxy_cp_diff, myx_cp_diff;
wire         mxy_cp_diff_carry, myx_cp_diff_carry;

assign {mxy_cp_diff_carry, mxy_cp_diff} = mx_cp - my_cp; 
assign {myx_cp_diff_carry, myx_cp_diff} = my_cp - mx_cp; 

assign mxy_cp_abs_diff = mxy_cp_diff_carry ? myx_cp_diff: // m_y - m_x
											 mxy_cp_diff; // m_x - m_y

// Leading zero count LZC 
localparam LZC_W = $clog2(M+2);
wire [LZC_W-1:0] zero_cnt;

// TODO 

// variable shift : renormalization 
// using case again for synth
wire [M+1:0] mz_cp_norm; 

always_comb @(*) begin
	case(msb_one_idx) begin
		'd0: mz_cp_norm = mxy_cp_abs_diff; // no cancellation 
		'd1: mz_cp_norm = {mxy_cp_abs_diff[M:0], 1'b0}; 
		'd2: mz_cp_norm = {mxy_cp_abs_diff[M-1:0], 2'b0}; 
		'd3: mz_cp_norm = {mxy_cp_abs_diff[M-2:0], 3'b0}; 
		'd4: mz_cp_norm = {mxy_cp_abs_diff[M-3:0], 4'b0}; 
		'd5: mz_cp_norm = {mxy_cp_abs_diff[M-4:0], 5'b0}; 
		'd6: mz_cp_norm = {mxy_cp_abs_diff[M-5:0], 6'b0}; 
		'd7: mz_cp_norm = {mxy_cp_abs_diff[M-6:0], 7'b0}; 
		'd8: mz_cp_norm = {1'b1, 8'b0}; //only 1 left 
		'd9: mz_cp_norm = {1'b1, {M+1{1'b0}}}; // full cancellation, nothing is left
end

// normalize exponent
wire [E-1:0] ex_lzc_cp_diff;
wire         ex_lxc_cp_diff_carry; 
wire         ez_min_inf;
wire [E-1:0] ez_cp_norm;

assign {ex_lzc_cp_diff_carry, ex_lzc_cp_diff} = ex - {{E-LZC_W{1'b0}}, msb_one_idx}; 
assign ez_min_inf = ex_lzc_cp_diff_carry;// detect undexflow, going to - e_min

assign ez_cp_norm = {E{ez_min_inf}} & ex_lzc_cp_diff; 

/* ---------------------------------
 * select between close and far path
 * --------------------------------- */
wire fp_sel; 
assign fp_sel = |exy_diff[E-1:1]; // diff > 1 


// TODO: handling corner cases : 
//  - round subnormals to 0 
//  - +/i inf

// return
assign s_o = // TODO
assign e_o = fp_sel ? er_norm : ez_cp_norm;
assign m_o = fp_sel ? mr_norm[M-1:0]: mz_cp_norm[M:1];

`ifdef FORMAL

always_comb begin
	// xcheck
	sva_xcheck_i: assert( ~$isunknown({sa_i, ea_i, ma_i, sb_i, eb_i, mb_i});
	sva_xcheck_o: assert( ~$isunknown({s_o, e_o, m_o});

	// assertions 
	sva_swap_geq_exp: assert(mx >= my);
end

`endif
endmodule
