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

## Finally found the bfloat16 spec ? 

Have I finally found the bf16 spec? Nobody seems to aggree on what the 
expected behavior of bf16 is expected to be ... nope ... just points to ieee 754 ... 


