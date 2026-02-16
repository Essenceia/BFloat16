#include <stdfloat>
#include <iostream> 
#include <bitset> 
#include <cstring> 

using namespace std; 

#if __STDCPP_BFLOAT16_T__ != 1
#error No support for bfloat16_t
#endif

void pretty_print(bfloat16_t x, string name){
	uint16_t tmp; 
	memcpy(&tmp, &x, sizeof(uint16_t));
	cout << name << ": 16'h" <<std::hex << tmp  << " - 16'b"<<  bitset<16>{tmp}  << " (" << scientific << x << ")" << endl; 
}

int main(){
	bfloat16_t a, b, c;

	a = 1e0bf16; 
	b = 1e0bf16; 
	c = a+b;

	pretty_print(a, "a");
	pretty_print(b, "d");
	pretty_print(c, "c");

	return 0;
} 
