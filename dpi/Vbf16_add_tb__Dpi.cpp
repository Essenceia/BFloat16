#include "Vbf16_add_tb__Dpi.h"
#include "Vbf16_add_tb.h"

#include <stdfloat> 
#include <cstring> 
#include <cmath> 
#include <iostream> 
#include <bitset> 

#include <cfenv>
#include <iomanip>

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

short bf16_add(short x, short y){
	static_assert(sizeof(x) == sizeof(bfloat16_t));

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
