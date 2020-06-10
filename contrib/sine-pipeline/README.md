This directory contains a Verilog module contributed by Dave Platt.
It can be use to generate a set of near-CD-quality audio sinewaves via
a process of table lookup and interpolation.  The design has been
successfully synthesized for the WebFPGA's ICE40 using a current
snapshot of the Icestorm toolchain, using nextpnr-ice40.

## Usage

The sinewave pipeline module is designed to let you evaluate sin(x).
Phase angle "x" is a 16-bit unsigned integer in the range of
[0,0xFFFF] representing the angle range of 0 to 2*pi radians.  Output
is a 16-bit signed value.  The pipeline accepts a new input phase
angle (and an "owner" identifier) on every clock cycle, and delivers
an output (and the corresponding owner identifier) on every clock
cycle.  Processing latency is on the order of 6 clock cycles.

The module uses one ICE40 Ultra Plus DSP block (a SB16_MAC block), and
a total of 12 block RAMs.

&copy; David Platt 2019, MIT LICENSED
