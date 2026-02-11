/* 
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
wire [E-1:0] ex, exy_diff;
wire [M-1:0] mx, my;
wire [E-1:0] eab_diff, eba_diff;
wire         eab_diff_carry, eba_diff_carry;

assign {eab_diff_carry, eab_diff} = ea_i - eb_i;
assign {eba_diff_carry, eba_diff} = eb_i - ea_i;

assign exy_diff = ~eab_diff_carry? eab_diff: eba_diff;
assign ex       = ~eab_diff_carry? ea_i: eb_i; 
assign {mx, my} = ~eab_diff_carry? {ma_i, mb_i}: {mb_i, ma_i}; 

/* --------
   far path  
   -------- */
// stupidly expensive shifter made a little cheaper by the fact we only need
// p+1 bits since we are doing a round to zero, we can discard the sticky bit
logic [M+1:0] my_shift;

always_comb begin
	case(exy_diff)
		'd0: my_shift = {1'b1, my, 1'b0};
		'd1: my_shift = {1'b1, 1'b0, my};
		'd2: my_shift = {1'b1, 2'b0, my[M-1:1]};
		'd3: my_shift = {1'b1, 3'b0, my[M-1:2]};
		'd4: my_shift = {1'b1, 4'b0, my[M-1:3]};
		'd5: my_shift = {1'b1, 5'b0, my[M-1:4]};
		'd6: my_shift = {1'b1, 6'b0, my[M-1:5]};
		'd7: my_shift = {1'b1, 7'b0, my[6]};
		default: my_shift = {1'b1, 8'b0}; // 8+, sel is only on bottom 3 bits of exy_diff, else clamp to 0 
	endcase
end


// operation can be either positive or negative: m_r = m_x +/- m_y
// since we won't be doing the common rouding post normalization to save on
// the need to have a W+E wide adder, our addition will be done on p+1 bits
// unlike the p bits commonly found in the litterature
wire op_sub;
wire [M+1:0] mr;
wire [M+1:0] my_shift_neg;
wire mr_carry;
assign op_sub = sa_i ^ sb_i; 
assign my_shift_neg  = {M+2{op_sub}} ^ my_shift;
assign {mr_carry, mr} = {1'b1, mx, 1'b0} // 9
					  + my_shift_neg
                      + {{M+1{1'b0}}, op_sub}; // 9

// normalize: 2 bit shifter
// if addition: division by 2 might be needed 
// if substraction: multiplication by 2 might be needed

/* verilator lint_off UNUSEDSIGNAL */ 
logic [M+1:0] mr_prenorm;
/* verilator lint_on UNUSEDSIGNAL */ 

logic [M-1:0] mr_norm;// removing hidden 1 and extra lsb
logic [E-1:0] er_norm;
/* verilator lint_off UNUSEDSIGNAL */
logic         er_norm_carry; // TODO overload identification ? 
/* verilator lint_on UNUSEDSIGNAL */

// a little ugly but useing a case to give more flexibility for optimization
always_comb begin
	casez({mr_carry, mr[M+1]})
		2'b00: begin // divide by 2
			{er_norm_carry, er_norm} = ex - {{E-1{1'b0}},1'b1};
			mr_prenorm = {mr[M:0], 1'b0}; // left shift 1, inject round bit
		end
		2'b1?: begin // multiply by 2 
			{er_norm_carry, er_norm} = ex + {{E-1{1'b0}},1'b1};
			mr_prenorm = {1'b0, mr[M+1:1]}; // right shit 1
		end
		2'b01: begin // default
			er_norm_carry = 1'b0;
			er_norm = ex;
			mr_prenorm = mr;
		end
	endcase
end
assign mr_norm = mr_prenorm[M:1];

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
logic [M+1:0] mz_cp_norm; //partially unused signal [8] and [0] unused 
/* verilator lint_on UNUSEDSIGNAL */

always_comb begin
	case(zero_cnt) 
		'd0: mz_cp_norm = mxy_cp_abs_diff; // no cancellation 
		'd1: mz_cp_norm = {mxy_cp_abs_diff[M:0], 1'b0}; 
		'd2: mz_cp_norm = {mxy_cp_abs_diff[M-1:0], 2'b0}; 
		'd3: mz_cp_norm = {mxy_cp_abs_diff[M-2:0], 3'b0}; 
		'd4: mz_cp_norm = {mxy_cp_abs_diff[M-3:0], 4'b0}; 
		'd5: mz_cp_norm = {mxy_cp_abs_diff[M-4:0], 5'b0}; 
		'd6: mz_cp_norm = {mxy_cp_abs_diff[M-5:0], 6'b0}; 
		'd7: mz_cp_norm = {mxy_cp_abs_diff[M-6:0], 7'b0}; 
		'd8: mz_cp_norm = {1'b1, 8'b0}; //only 1 left 
		default: mz_cp_norm = {1'b1,{M+1{1'b0}}}; // full cancellation, nothing is left, made the same as the 8 case
												   // could fuse 8 and default case to have mux sel be done
												   // only on bottom 3 bits ?
	endcase
end

// normalize exponent
wire [E-1:0] ex_lzc_cp_diff;
/* verilator lint_off UNUSEDSIGNAL */
wire         ex_lxc_cp_diff_carry; // TODO: overflow detection
/* verilator lint_on UNUSEDSIGNAL */
wire         ez_min_inf;
wire [E-1:0] ez_cp_norm;

assign {ex_lzc_cp_diff_carry, ex_lzc_cp_diff} = ex - {{E-LZC_W{1'b0}}, zero_cnt}; 
assign ez_min_inf = ex_lzc_cp_diff_carry;// detect undexflow, going to - e_min

assign ez_cp_norm = {E{ez_min_inf}} & ex_lzc_cp_diff; 

/* ---------------------------------
 * select between close and far path
 * --------------------------------- */
wire fp_sel; 
assign fp_sel = ~(~|exy_diff[E-1:1] & op_sub); //  exy_diff < 2 && cancellation 


// TODO: handling corner cases : 
//  - round subnormals to 0 
//  - +/i inf

// return
assign s_o = 1'b0;// TODO
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
