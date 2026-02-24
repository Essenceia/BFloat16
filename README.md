# BFloat16 hardware implementation 

Home to the shared bf16 hardware implementation and verification. 
These modules are designed with the objective on being included in 
future ASIC tapeouts, as such, area is the primary concerned
followed by performance. Power is not a design prerogative. 
In order to save on logic cost, this hardware doesn't support subnormals, 
uses rounded towards zero allowing it to also drop inf and NaN support. 

This implementation has **100% test coverage** of the valid input space. 

Supported operations : 
- addition/subtration
- multiplication
- round towards zero roudding

Usage assumptions:
- inputs are bf16 
- inputs are never subnormal
- input are never NaN or $\pm\infty$

Limitations implied by design choices: 
- subnormals: all produced subnormals will be clamped to 0
- no support for rounding modes apart from round to zero 

## BFloat16 

The bf16 is not defined as a IEEE-574 floating point format
in the same sense as its contemporaries: the half-precision (f16), single percision (f32),
and double precision (f64), are. 

This lack of standardisation makes its implementation more flexible to the
need of the underlying task. From a hardware designs perspective this also
allows the tradeoffs between supporting certain features present in the IEEE-574
floating point format, and their implementation costs, to be weighed. 

BFloat16 uses the following layout : 
```
[ sign (1 bit) | exponent (8 bits) | significant (7 bits) ]
```

## Releases 

`v1.0`: 
- bfloat16 adder :
    - dual path architecture
    - no subnormal support
    - nan/inf support

`v2.0`:
- bfloat16 adder :
    - dual path architecture
    - no subnormal support
    - no nan/inf support


## Testing 

This codebase supports using both the `verilator`(default) and `icarus verilog`
simulators, though the batch testing producing a full coverage of the 
input space is only available with the faster `verilator` simulator. 

Run all testbenches, including batch testing (recomend not dumping waves to not nuke your disk): 
```
make test wave=
```

Leading Zero Count testbench : 
```
make run_lzc
```

BFloat16 adder testbench (including batch testing): 
```
make run_bf16_add
```

BFloat16 multiplier testbench (including batch testing):
```
make run_bf16_mul
```

### Options

#### Waves

Waves are dumped by default, to disable the waves undefine the `wave` argument 
when building the testbench. This is recommended during batch testing as 
the full waves can occupy upwards of 1.6TB. 
```
make run_bf16_add wave=
```

#### Verbose logs

Verbose debug logs are disabled by default, invoking make with the `debug` argument 
enables it.
```
make run_bf16_add debug=1
```

#### Simulator 

To run the testbench with icarus verilog, invoke the testbench with the `SIM=I` argument
```
make run_lzc SIM=I
```


## Misc

Developement notes can be found [here](doc/notes.md). 

Given behavior of C++ `bfloat16_t` is implementation defined, the code in the `cpu_test` 
directory is used to identify local hardware's behavior. This code is portable and 
has been tested on both `x86_64` and `armv9`, to build and run: 
```
cd cpu_test
make run
```

## Release v1.0 vs v2.0 NaN/inf support

Initially the desire was to NOT add support for NaN, 
then due to an improper preconcived understanding in regards to the behavior of
round towards zero on overflows, proper support for NaN and $\infty$
was implemented and full tested. 

This belief was that an operations overflow could produce an $\infty$,
lead to conclude that since, $\pm \infty$ are limits, and there is no mathematically correct
solution $\pm \infty \times 0$ then `NaN` support was necessary. 

But, once I realized that according to the IEEE-574 prescription of round towards zero's
behavior on overflow implied reaching $\infty$ was impossible, it became possible to 
remove them. 
Given my usecase doesn't require NaN or $\infty$ support and my aim to optimize for area and performance I 
decided to remove support and the associated hardware for NaN and $\infty$ in the `v2.0` release. 

Given the validation was far enough along and some users may need NaN and $\infty$ support I 
decided finish testing and keep them, then package this as the `v1.0` release. 

## References 

- IEEE-754, IEEE Standard for Floating-Point Arithmetic
- Handbook of Floating-Point Arithmetic - Jean-Michel Muller • Nicolas Brunie, Florent de Dinechin, Claude-Pierre Jeannerod, Mioara Joldes, Vincent Lefèvre, Guillaume Melquiond, Nathalie Revol, Serge Torres

## License

This code is licensed under  Creative Commons Attribution-NonCommercial
4.0 International License, all rights belong to Julia Desmazes.
