#include "Vbf16_add_tb__Dpi.h"
#include "Vbf16_add_tb.h"

#include <stdfloat> 
#include <cstring> 
#include <cmath> 
#include <iostream> 
#include <bitset> 

using namespace std; 

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
	memcpy(&f, &x, sizeof(bfloat16_t));
	cout << "16'h" <<std::hex << x << " - 16'b"<<  bitset<16>{x} << " (" << scientific << f << ")" << endl; 
}
// reduce the call overhead by having a triple print
void bf16_pretty_print_triple(short x, short y, short z){
	bf16_pretty_print(x);
	bf16_pretty_print(y);
	bf16_pretty_print(z);
}
