#include "Vbf16_add_tb__Dpi.h"
#include "Vbf16_add_tb.h"

#include <stdfloat> 
#include <cstring> 
#include <cmath> 
#include <iostream> 
#include <bitset> 

#include <cfenv>
#include <iomanip>

#define HW_NAN 0x7FFF

using namespace std; 

typedef struct {
	uint8_t mantissa: 7;
	uint8_t exponent: 8;
	uint8_t sign : 1; 
} __attribute__((packed)) bf16_u; 

// set rounding mode to RZ
void init_bf16(){
		fesetround(FE_TOWARDZERO);
}

bfloat16_t subnormal_to_zero(bfloat16_t x){
	if(!(isnormal(x) | isnan(x) | isinf(x))){
		bool pos = (x>0);
		cout << "rounding subnormal to "<< pos?"+":"-" <<"0.0 from " << scientific << x << " [normal:"<<
		isnormal(x) << ", nan:"<< isnan(x) << ", inf:"<< isinf(x) << "]" << endl;
		if (pos) x = 0e0bf16;
		else x = -0e0bf16; // because -0 is a thing I want to handle
	}
	return x;
};

bfloat16_t expected_hw_result(bfloat16_t x){
	x = subnormal_to_zero(x);
	if (isnan(x)){
		uint16_t nan = HW_NAN; 
		memcpy(&x, &nan, sizeof(bfloat16_t));
	}
	return x;
};


short bf16_add(short x, short y){
	static_assert(sizeof(x) == sizeof(bfloat16_t));

	bfloat16_t a, b, c; 
	short r; 
	memcpy(&a, &x, sizeof(bfloat16_t));
	memcpy(&b, &y, sizeof(bfloat16_t));

	// hardware implementation doesn't support subnormals as inputs
	a = subnormal_to_zero(a);	
	b = subnormal_to_zero(b);	

	c = a + b; 
	
	// hardware implementation rounds subnormals to 0 and set expected NaN
	c = expected_hw_result(c);	

	memcpy(&r, &c, sizeof(bfloat16_t));
	return r;
}

void bf16_pretty_print(short x){
	bfloat16_t f; 
	bf16_u u;
	memcpy(&f, &x, sizeof(bfloat16_t));
	static_assert(sizeof(bf16_u) == sizeof(bfloat16_t));
	memcpy(&u, &x, sizeof(bf16_u));

	cout << "16'h" <<std::hex << setfill('0') << setw(4) << x << 
	" | 16'b"<<  bitset<1>{u.sign} << "_" << bitset<8>{u.exponent} << "_" << bitset<7>{u.mantissa}
	<< " | " << scientific << f << endl; 
}
// reduce the call overhead by having a triple print
void bf16_pretty_print_triple(short x, short y, short z){
	bf16_pretty_print(x);
	bf16_pretty_print(y);
	bf16_pretty_print(z);
	cout << endl;
}
