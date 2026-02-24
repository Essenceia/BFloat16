/*Copyright (c) 2026, Julia Desmazes. All rights reserved.

  This work is licensed under the Creative Commons Attribution-NonCommercial
  4.0 International License. 

  This code is provided "as is" without any express or implied warranties.
*/

// Placeholder module, actual mul will be inferred by yosys abc
module booth_unsigned_mul #(
	parameter W = 8
)(
	input wire [W-1:0] x_i,
	input wire [W-1:0] y_i,
	output wire [2*W-1:0] z_o
);

assign z_o = x_i * y_i; 
endmodule
