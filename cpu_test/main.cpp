#include <stdfloat>
#include <iostream> 
#include <bitset> 
#include <cstring> 
#include <cmath> 

using namespace std; 

#if __STDCPP_BFLOAT16_T__ != 1
#error No support for bfloat16_t
#endif

void pretty_print(bfloat16_t x, string name){
	uint16_t tmp; 
	memcpy(&tmp, &x, sizeof(uint16_t));
	cout << name << ": 16'h" <<std::hex << tmp  << " - 16'b"<<  bitset<16>{tmp}  << " (" << scientific << x << ")" << endl; 
}

void pretty_print_triplet(bfloat16_t a, bfloat16_t b, bfloat16_t c){
	pretty_print(a, "a");
	pretty_print(b, "d");
	pretty_print(c, "c");
}

bfloat16_t set_bf16(uint16_t u){
	bfloat16_t r; 
	static_assert(sizeof(bfloat16_t) == sizeof(uint16_t));	
	memcpy(&r, &u, sizeof(bfloat16_t));
	return r;
}

void test_subnormal(){
	bfloat16_t a, b, c;
	a = set_bf16(0x1); // smallest subnormal 
	b = a;
	c = a + b; 
	
	cout << "Testing stdfloat subnormal support for bfloat16_t" << endl;
	if (c == 0e0bf16) cout << "No submormal support, rounded to 0" << endl;
	else cout << "Has subnormal support" << endl;

	pretty_print_triplet(a,b,c);
}

void test_inf(){
	bfloat16_t a,b,c; 

	a = INFINITY; 
	b = INFINITY; 	
	c = a - b;
	// inf - inf = nan ? 
	cout << "Testing inf NaN adder corner case" << endl;

	if(isnan(c)) cout << "PASS: inf - inf = nan - expected behavior" << endl; 
	else cout << "ERROR: unexpected behavior" << endl; 

	pretty_print_triplet(a,b,c);	
}

int main(){
	bfloat16_t a, b, c;

	a = 1e0bf16; 
	b = 1e0bf16; 
	c = a+b;
	pretty_print_triplet(a,b,c);

	test_subnormal();
	test_inf();

	return 0;
} 
