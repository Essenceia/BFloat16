# BFloat16 hardware implementation 

Home to the shared bf16 hardware implementation and verification. 
These modules are designed with the objective on being included in 
future self-funded ASIC tapeouts, as such, area is the primary concerned
followed by permorance. Power is not a design prerogative. 
In order to save on logic cost, this hardware only supports 
subnormals so far as to round them to zero.

Supported operations : 
- addition/subtration
- multiplication

Usage assumptions:
- inputs are bf16 
- inputs are never subnormal or any flavor of NaN

Limitations implied by design choices: 
- no NaN support: since no addition or multipliation can produce a NaN if no input is NaN, there is no explicit NaN support
- no NaN signalling: corollary of above 
- subnormals: all produced subnormals will be clamped to 0




