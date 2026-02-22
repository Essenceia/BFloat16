#include <stdfloat>
#include <iostream> 
#include <bitset> 
#include <cstring> 
#include <cmath> 
#include <cfenv>
#include <iomanip>

using namespace std; 

#if __STDCPP_BFLOAT16_T__ != 1
#error No support for bfloat16_t
#endif

typedef struct {
	uint8_t mantissa: 7;
	uint8_t exponent: 8;
	uint8_t sign : 1; 
} __attribute__((packed)) bf16_u; 


typedef struct {
	uint64_t mantissa: 52;
	uint16_t exponent: 11;
	uint8_t  sign : 1; 
} __attribute__((packed)) f64_u; 

void pretty_print_f64(float64_t x, string name){
	uint64_t tmp; 
	f64_u u;
	memcpy(&tmp, &x, sizeof(uint64_t));
	static_assert(sizeof(f64_u) == sizeof(float64_t));
	memcpy(&u, &x, sizeof(f64_u));

	cout << "64'h" <<std::hex << setfill('0') << setw(16) << tmp << 
	" | 64'b"<<  bitset<1>{u.sign} << "_" << bitset<11>{u.exponent} << "_" << bitset<52>{u.mantissa}
	<< " | " << scientific << x << endl; 
}

void pretty_print(bfloat16_t x, string name){
	uint16_t tmp; 
	bf16_u u;
	memcpy(&tmp, &x, sizeof(uint16_t));
	static_assert(sizeof(bf16_u) == sizeof(bfloat16_t));
	memcpy(&u, &x, sizeof(bf16_u));

	cout << "16'h" <<std::hex << setfill('0') << setw(4) << tmp << 
	" | 16'b"<<  bitset<1>{u.sign} << "_" << bitset<8>{u.exponent} << "_" << bitset<7>{u.mantissa}
	<< " | " << scientific << x << endl; 
}


void pretty_print_triplet(bfloat16_t a, bfloat16_t b, bfloat16_t c){
	pretty_print(a, "a");
	pretty_print(b, "d");
	pretty_print(c, "c");
}

void pretty_print_triplet_f64(float64_t a, float64_t b, float64_t c){
	pretty_print_f64(a, "a");
	pretty_print_f64(b, "b");
	pretty_print_f64(c, "c");
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

	b = 1.175494e-38bf16;
	c = a + b; 
	cout << "Testing inf + N corner case" << endl;
	if (isinf(c))cout << "PASS: inf + N = inf" << endl;
	else cout << "ERROR: unexpected behavior" << endl;
	pretty_print_triplet(a,b,c);	
}

void test_f32_bf16_conversion_behavior(){
	bfloat16_t a,b,c;
	uint16_t hb = 0x84ff;
	a = set_bf16((uint16_t)0x0080);
	cout << "Testing impact of f32 -> bf16 conversion on mantissa " << endl; 
	for(int i = 0; i < 4; i++){	
		b = set_bf16(hb);
		c = a + b; 
		pretty_print_triplet(a,b,c);
		cout << endl;
		hb++;
	}
}

void test_corner_case(){
	bfloat16_t a, b, c; 
	float64_t fa, fb, fc;
 
	a = set_bf16((uint16_t)0x7b80);
	b = set_bf16((uint16_t)0x7f7f);
	c = a+b;	
	pretty_print_triplet(a,b,c);
	
	// bf16 -> f64 implicit conversion
	fa = a; 
	fb = b; 
	fc = fa+fb; 
	cout << "f64" << endl;
	pretty_print_triplet_f64(fa,fb,fc);
}

int main(){
	fesetround(FE_TOWARDZERO);
	
	bfloat16_t a, b, c;

	a = 1e0bf16; 
	b = 1e0bf16; 
	c = a+b;
	pretty_print_triplet(a,b,c);

	test_subnormal();
	test_inf();

	test_f32_bf16_conversion_behavior();

	test_corner_case(); 
	fesetround(FE_UPWARD);
	test_corner_case(); 

	return 0;
} 
