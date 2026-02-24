/* Copyright (c) 2026, Julia Desmazes. All rights reserved.

  This work is licensed under the Creative Commons Attribution-NonCommercial
  4.0 International License. 

  This code is provided "as is" without any express or implied warranties.
*/
#include "Vbf16_mul_tb__Dpi.h"
#include "Vbf16_mul_tb.h"

// include litterally includes the raw code, preventing
// code duplication between the add and mul tb's
#include "dpi_custom_utils.cpp"

short bf16_mul(short x, short y){
	static_assert(sizeof(x) == sizeof(bfloat16_t));

	bfloat16_t a, b, c; 
	short r; 
	memcpy(&a, &x, sizeof(bfloat16_t));
	memcpy(&b, &y, sizeof(bfloat16_t));

	// input should not be subnormal
	assert((IS_SUBNORMAL(a)|| isnan(a) || isinf(a)) == false && "Unexpected subnormal/inf/nan input on a");
	assert((IS_SUBNORMAL(b)|| isnan(b) || isinf(b)) == false && "Unexpected subnormal/inf/nan input on b");

	c = a * b; 
	
	// hardware implementation rounds subnormals to 0 and set expected NaN
	c = expected_hw_result(c);	

	memcpy(&r, &c, sizeof(bfloat16_t));
	return r;
}

