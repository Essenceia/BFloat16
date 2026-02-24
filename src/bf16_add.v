/* Copyright (c) 2026, Julia Desmazes. All rights reserved.

  This work is licensed under the Creative Commons Attribution-NonCommercial
  4.0 International License. 

  This code is provided "as is" without any express or implied warranties.

 
  Bfloat16 addition
  c = a+b

  a = { s_a, e_a, m_a }
  b = { s_b, e_b, m_b }

*/
module bf16_add #(
	localparam int E = 8,
	localparam int M = 7
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
	output wire [M-1:0] m_o
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
wire         sx, sy_unused;
wire [E-1:0] eab_diff, eba_diff;
wire         eab_diff_carry, eba_diff_carry;

assign {eab_diff_carry, eab_diff} = ea_i - eb_i;
assign {eba_diff_carry, eba_diff} = eb_i - ea_i;

assign exy_diff = ~eab_diff_carry ? eab_diff: eba_diff;
assign {ex, ey} = ~eab_diff_carry ? {ea_i, eb_i}: {eb_i, ea_i}; 
assign {mx, my} = ~eab_diff_carry ? {ma_i, mb_i}: {mb_i, ma_i}; 
assign {sx, sy_unused} = ~eab_diff_carry ? {sa_i, sb_i}: {sb_i, sa_i};

// equality check, parallel check to determine close path sign for special 
// case where N - N / -N + N = +0
wire mab_eq, exy_eq, xy_eq;
assign mab_eq = ma_i == mb_i; // if they are equal, we don't care about swap
assign exy_eq = ~eab_diff_carry & ~eba_diff_carry; // 1 = equal, 0 = not equal 
assign xy_eq  = mab_eq & exy_eq; 

// identify corner cases : 
// +/- zero 
wire x_nzero, y_nzero;
assign {x_nzero, y_nzero }  = {|ex, |ey};

/* --------
   far path  
   -------- */
// stupidly expensive shifter made a little cheaper by the fact we only need
// p+1 bits since we are doing a round to zero, we can discard the sticky bit
logic [M+1:0] my_shift;

// if y is 0 correct hidden bit to prevent wrong exponent correction
always @(*) begin
	case(exy_diff)
		'd0: my_shift = {y_nzero, my, 1'b0};
		'd1: my_shift = {1'b0, y_nzero, my};
		'd2: my_shift = {2'b0, y_nzero, my[M-1:1]};
		'd3: my_shift = {3'b0, y_nzero, my[M-1:2]};
		'd4: my_shift = {4'b0, y_nzero, my[M-1:3]};
		'd5: my_shift = {5'b0, y_nzero, my[M-1:4]};
		'd6: my_shift = {6'b0, y_nzero, my[M-1:5]};
		'd7: my_shift = {7'b0, y_nzero, my[M-1]};
		'd8: my_shift = {8'b0, y_nzero};
		default: my_shift = {9'b0}; // 9+, full shift out due to insuficient precision p = 8 
	endcase
end

// operation can be either positive or negative: m_r = m_x +/- m_y
// since we won't be doing the common rouding post normalization to save on
// the need to have a W+E wide adder, our addition will be done on p+1 bits
// unlike the p bits commonly found in the literature
wire op_sub;
wire [M+1:0] mr;
wire [M+1:0] my_shift_neg_comp;
wire [M+1:0] my_shift_neg;
wire         my_shift_neg_carry_unused;

wire mr_carry;

wire [M+1:0] mx_expanded; 
assign mx_expanded = {1'b1, mx, 1'b0};

assign op_sub = sa_i ^ sb_i; 
assign my_shift_neg_comp  = {M+2{op_sub & y_nzero}} ^ my_shift;
assign {my_shift_neg_carry_unused, my_shift_neg } = my_shift_neg_comp + 
                      							  + {{M+1{1'b0}}, op_sub & y_nzero}; // 9
assign {mr_carry, mr} = mx_expanded
					  + my_shift_neg;

// rounds to zero: clamps to largest finite number in case of overflow to
// +/- inf
logic rz_max; 
assign rz_max = {{E-1{1'b1}}, 1'b0} == ex; 

// normalize: 2 bit shifter
// if addition: division by 2 might be needed 
// if substraction: multiplication by 2 might be needed

logic [M-1:0] mr_norm;// removing hidden 1 and extra lsb
logic [E-1:0] er_norm;
/* verilator lint_off UNUSEDSIGNAL */
logic         er_norm_carry; // overflow will be prevented by rz_max logic
/* verilator lint_on UNUSEDSIGNAL */

// a little ugly but useing a case to give more flexibility for optimization
always @(*) begin
	casez({mr_carry & ~op_sub, mr[M+1]})
		2'b00: begin // divide by 2
			{er_norm_carry, er_norm} = ex - {{E-1{1'b0}},1'b1};
			//mr_prenorm = {mr[M:0], 1'b0}; // left shift 1, inject round bit
			mr_norm = mr[M-1:0]; // left shift 1, inject round bit
		end
		2'b1?: begin // multiply by 2 
			{er_norm_carry, er_norm} = ex + {{E-1{1'b0}}, ~rz_max};
			mr_norm = rz_max ? {M{1'b1}}: mr[M+1:2]; // right shit 1
		end
		2'b01: begin // default
			er_norm_carry = 1'b0;
			er_norm = ex;
			mr_norm = mr[M:1]; // removed hidden 1 and sticky 
		end
	endcase
end

/* ---------
 * close path 
 * ---------- */

// 1 bit shift
wire [M+1:0] my_cp_shifted; // p+1 width, including hidden 1
wire [M+1:0] mx_cp; 

assign my_cp_shifted = exy_eq ? {y_nzero, my, 1'b0} : 
								{1'b0, y_nzero, my}; // div 2, e_x - e_y = 1, e_x - e_y > 1 will be handed by far path  
assign mx_cp = { 1'b1, mx, 1'b0};

// absolute difference between significants 
wire [M+1:0] mxy_cp_abs_diff;
wire [M+1:0] mxy_cp_diff, myx_cp_diff;
wire         mxy_cp_diff_carry;
wire         myx_cp_diff_carry_unused;

assign {mxy_cp_diff_carry, mxy_cp_diff} = mx_cp - my_cp_shifted; 
assign {myx_cp_diff_carry_unused, myx_cp_diff} = my_cp_shifted - mx_cp; 

assign mxy_cp_abs_diff = mxy_cp_diff_carry ? myx_cp_diff: // m_y - m_x
											 mxy_cp_diff; // m_x - m_y

// Leading zero count LZC 
localparam int LZC_W = $clog2(M+3);
localparam int LZC_V_W = $rtoi($pow(2, $clog2(M+2)));
wire [LZC_W-1:0] zero_cnt;
wire             zero_cnt_unused;
wire [LZC_V_W-1:0] lzc_data;

assign lzc_data = { mxy_cp_abs_diff, {LZC_V_W-(M+2){1'b1}}};

lzc #(.W(LZC_V_W)) m_lzc (
	.data_i(lzc_data),	
	.cnt_o({zero_cnt_unused, zero_cnt})
);

// variable shift : renormalization 
// using case again for synth
/* verilator lint_off UNUSEDSIGNAL */
logic [M+1:0] mz_cp_norm_lite; //partially unused signal [8] and [0] unused 
/* verilator lint_on UNUSEDSIGNAL */

always @(*) begin
	case(zero_cnt) 
		'd0: mz_cp_norm_lite = mxy_cp_abs_diff; // no cancellation 
		'd1: mz_cp_norm_lite = {mxy_cp_abs_diff[M:0], 1'b0}; 
		'd2: mz_cp_norm_lite = {mxy_cp_abs_diff[M-1:0], 2'b0}; 
		'd3: mz_cp_norm_lite = {mxy_cp_abs_diff[M-2:0], 3'b0}; 
		'd4: mz_cp_norm_lite = {mxy_cp_abs_diff[M-3:0], 4'b0}; 
		'd5: mz_cp_norm_lite = {mxy_cp_abs_diff[M-4:0], 5'b0}; 
		'd6: mz_cp_norm_lite = {mxy_cp_abs_diff[M-5:0], 6'b0}; 
		'd7: mz_cp_norm_lite = {mxy_cp_abs_diff[M-6:0], 7'b0}; 
		'd8: mz_cp_norm_lite = {1'b1, 8'b0}; //only 1 left 
		default: mz_cp_norm_lite = {1'b1,{M+1{1'b0}}}; // full cancellation, nothing is left
	endcase
end

// normalize exponent
wire [E-1:0] ex_lzc_cp_diff;
wire         ex_lzc_cp_diff_carry; // TODO: overflow detection
wire         ez_cp_underflow;
wire [E-1:0] ez_cp_norm;

assign {ex_lzc_cp_diff_carry, ex_lzc_cp_diff} = ex - {{E-LZC_W{1'b0}}, zero_cnt}; 
assign ez_cp_underflow = ex_lzc_cp_diff_carry;// detect undexflow, going to 0

assign ez_cp_norm = {E{~ez_cp_underflow & ~xy_eq}} & ex_lzc_cp_diff; 

// denomral round to 0: mantissa correction 
logic [M-1:0] mz_cp_norm;
assign mz_cp_norm = {M{~(exy_eq | ~|ez_cp_norm) }} & mz_cp_norm_lite[M:1];

/* ---------------------------------
 * select between close and far path
 * --------------------------------- */
wire fp_sel; 
assign fp_sel = ~(~|exy_diff[E-1:1] & op_sub); //  exy_diff < 2 && cancellation 

// special case
// - 0 +/- 0, return +0
// observation: when x is 0, then y is 0 since ex >= ey and we have no
// subnormals
wire sc_sel; // special case select
wire [E-1:0] er_sc;
wire [M-1:0] mr_sc; 

assign sc_sel = ~x_nzero; 
assign er_sc = {E{1'b0}};
assign mr_sc = {M{1'b0}};

// return
assign s_o = fp_sel ? sx : (sx ^ mxy_cp_diff_carry) & ~xy_eq;// sign is allways + for -N + N/ N - N, convention to help equality comparison
assign e_o = sc_sel ? er_sc : fp_sel ? er_norm : ez_cp_norm;
assign m_o = sc_sel ? mr_sc : fp_sel ? mr_norm: mz_cp_norm;

`ifdef FORMAL

always @(*) begin
	// xcheck
	sva_xcheck_i: assert( ~$isunknown({sa_i, ea_i, ma_i, sb_i, eb_i, mb_i});
	sva_xcheck_o: assert( ~$isunknown({s_o, e_o, m_o});

	// assertions
	// validate swap working, covers 0 assumptions (x == 0 => y == 0) 
	sva_swap_geq_exp: assert(ex >= ey);
end

`endif
endmodule
