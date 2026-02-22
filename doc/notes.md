## Missing hardware support for bfloat16

Looking at the dissably of the test program we can 
see that gcc handling the bfloat16 addition by using the
soft floating point function replacements (`__extendbfsf2`,
`__truncsfbf2` + wrapper code ). 

This is indicative that my current hardware either doesn't have
hardware support for bf16 or that the support isn't being 
advertised to the compiler. Given I havn't been able to find
any indication that my CPU had any support for bf16, it seem to be 
the latter: 

```asm
4	int main(){
   0x0000000000001119 <+0>:	push   %rbp
   0x000000000000111a <+1>:	mov    %rsp,%rbp
   0x000000000000111d <+4>:	sub    $0x20,%rsp

5		bfloat16_t a, b, c;
6	
7		a = 1.0;
   0x0000000000001121 <+8>:	movzwl 0xee4(%rip),%eax        # 0x200c
   0x0000000000001128 <+15>:	mov    %ax,-0x6(%rbp)

8		b = 1.0;
   0x000000000000112c <+19>:	movzwl 0xed9(%rip),%eax        # 0x200c
   0x0000000000001133 <+26>:	mov    %ax,-0x4(%rbp)

9		c = a+b;
   0x0000000000001137 <+30>:	pinsrw $0x0,-0x6(%rbp),%xmm0
   0x000000000000113d <+36>:	call   0x1180 <__extendbfsf2>
   0x0000000000001142 <+41>:	movss  %xmm0,-0x14(%rbp)
   0x0000000000001147 <+46>:	pinsrw $0x0,-0x4(%rbp),%xmm0
   0x000000000000114d <+52>:	call   0x1180 <__extendbfsf2>
   0x0000000000001152 <+57>:	movaps %xmm0,%xmm1
   0x0000000000001155 <+60>:	addss  -0x14(%rbp),%xmm1
   0x000000000000115a <+65>:	movd   %xmm1,%eax
   0x000000000000115e <+69>:	movd   %eax,%xmm0
   0x0000000000001162 <+73>:	call   0x1250 <__truncsfbf2>
   0x0000000000001167 <+78>:	movd   %xmm0,%eax
   0x000000000000116b <+82>:	mov    %ax,-0x2(%rbp)

10	
11		return 0;
   0x000000000000116f <+86>:	mov    $0x0,%eax

12	}
   0x0000000000001174 <+91>:	leave
   0x0000000000001175 <+92>:	ret
```
Based on this assembly, the expected behavior for the bfloat16_t would be 
similar to a clamped down float32_t. 

## Finally found the bfloat16 spec ? 

Have I finally found the bf16 spec? Nobody seems to aggree on what the 
expected behavior of bf16 is expected to be ... nope ... just points to ieee 754 ... 


## Probing the standard library soft `bfloat16_t` implementation 

Added some testing in the program that lives under `cpu_test` used to 
independantly probe the behavior of the `bfloat16_t`. 

Confirmed behavior: 
- has subnormal support
- has NaN support
- has inf support

In order to use this as a golden model for the hardware, I will 
need to manually clamp subnormals to 0. To this end, I can probably use 
the `cmath` standard `isnormal` wrapper.

## Betrayed by C++

Quote from the C++ 2022 published proposal on "Extended floating-point types and standard names" : 
```
7.2. Supported formats

We propose aliases for the following layouts:

    [IEEE-754-2008] binary16 - IEEE 16-bit.
    [IEEE-754-2008] binary32 - IEEE 32-bit.
    [IEEE-754-2008] binary64 - IEEE 64-bit.
    [IEEE-754-2008] binary128 - IEEE 128-bit.
    bfloat16, which is binary32 with 16 bits of precision truncated; see [bfloat16]. <-- !
```
Essentially, this means `bfloat16_t` will be calculated using a `float32_t` (refered to as binary32 in the IEEE spec) 
and then truncated down. 
The problem with this approach is that, `float32_t` has a much larger internal precision $p$ when compared 
with `bfloat16_t` : 
- `float32_t` $p = 24$ 
- `bfloat16_t` $p = 8$

In practice, this means that, if I want my hw to correctly match the golden model, as specificed by 
the C++ standard library, I will need to support $p = 24$, which directly translates to a much 
widder significant shift + adder path on the adder far path ... and that is in no universe the outcome 
I am intrested in. 

source: https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2022/p1467r9.html#alias-formats

### Within 1 ulp 

Given the c++ standard's libraries implementation of `bfloat16_t` of using a `float32_t` under the hood 
I cannot cleanly match the results of my golden model to the expected RTL output. 
This is because `float32_t` has $p=24$ bits on internal precision, while `bloat16_t` has 8 bits, given the
same input values, if the difference in exponent between these inputs if within range $]p_{bfloat16}; p_{float32}[$
I might observe a rounding difference. 
Due to the nature of the underlying cause of this rounding difference, this will occure indenependantly 
of the rounding mode. 
Another property of this difference is that is will be contained within a margin of the next 
consequtive floating point number.

To help simplify the following section, let me define $ulp(x)$ as the "unit of last place", 
or more formally : 

> $ulp(x)$ is the gap between the two floating-point numbers nearest to $x$, even if $x$ is one of them
~ William Kahan, 1960. 

As such, my relative error between my golden model's `bfloat16_t` and my implementation will be at most 
of $1 ulp(x)$. 

$ulp(x)$ is defined as : 
```math 
ulp(x) = 2^{-p+1} 
```

For my `bfloat16` implementation with $p=8$ we thus have $ulp(x) = 2^{-7}$. 

Note: The relative error calculation is as follows : 
```math 

error(x) = \frac{x_{model} - x_{hw}}{x_{model}}
``` 

## Round to zero, infinity condition 

Let us consider the following calculation performed using round to zero using 
`bfloat16_t` and, since `float32_t` has the same max representable magnitude, 
also `float32_t. Both will produce the same result: 
```
3.389531e+38 + 1.329227e+36 = 3.389531e+38
```
On it's face this result looks wrong, but is actually absolutely correct
when considering the expected behavior of floating point math!


The IEEE-754 spec defines the overflow behavior per rounding mode. 
When an overflow occurs, the result depends on the rounding direction attribute. 

For round to zero, I cite : 
> roundTowardZero, the result shall be the format’s floating-point number closest to and no greater in magnitude than the infinitely precise result.

In plain english, for round to zero, the result will not be $\pm\infty$ but $\pm$ the largest representable number, 
since $\infty$ has infinit magnitude. 

Now, looking back at our example, here are the binary representation of our values : 
```
a + b = c
a: 16'h7b80 | 16'b0_11110111_0000000 | 1.329227e+36
b: 16'h7f7f | 16'b0_11111110_1111111 | 3.389531e+38
c: 16'h7f7f | 16'b0_11111110_1111111 | 3.389531e+38
```
We can see that `3.389531e+38` is actually already the largest representable number so 
for any $y, y /geq 0$ using `bfloat16_t$ then $y +3.389531e+38 = 3.389531e+38$.

### Impact on NaN and inf

This realization that operations will never overflow to $infty$ forces me to re-evaluate the
need to add support for inf and NaN to the hardware, given these can now, never get
produced as long as they are not feed as inputs. 

The current plan is to finish a v1 with the support for inf and NaN and then remove them
in a v2.

## License

Copyright (c) 2026, Julia Desmazes. All rights reserved.

This work is licensed under the Creative Commons Attribution-NonCommercial
4.0 International License. 
 
