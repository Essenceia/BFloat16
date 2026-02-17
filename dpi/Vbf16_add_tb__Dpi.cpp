#include "svdpi.h"
#include "Vbf16_add_tb__Dpi.h" 
#include <stdfloat> 
#include <cstring> 
#include <cmath> 

short add(short x, short y){
	static_assert(sizeof(x) == sizeof(bfloat16_t));
	static_assert(sizeof(bfloat16_t) == sizeof(uint16_t));

	bfloat16_t a, b, c; 
	short r; 
	memcpy(&a, &x, sizeof(bfloat16_t));
	memcpy(&b, &y, sizeof(bfloat16_t));

	// hardware implementation doesn't support subnormals as inputs
	if(!isnormal(a)) a = 0e0bf16;
	if(!isnormal(b)) b = 0e0bf16;

	c = a + b; 
	
	// hardware implementation rounds subnormals to 0
	if(!isnormal(c)) c = 0e0bf16;

	memcpy(&r, &c, sizeof(bfloat16_t));
	return r;
}
 
