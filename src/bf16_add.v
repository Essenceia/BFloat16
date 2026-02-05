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


	output wire sa_i,
	output wire [E-1:0] ea_i,
	output wire [M-1:0] ma_i,
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

endmodule
