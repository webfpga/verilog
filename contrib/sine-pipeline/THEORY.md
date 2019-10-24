## Overview

I have a project underway which uses the WebFPGA to generate high-
quality audio test signals and create an FM broadcast stereo
"composite" signal, convert this to analog (with an outboard DAC of
some sort) and drive this into an RF modulator circuit.  The eventual
goal is to create a high-quality FM-tuner alignment signal generator.

This project requires creating multiple sine waves at the same time,
with fine control of frequency and phase and amplitude.  My goal was
for these to be of CD quality (16-bit linear PCM), or as close to it
as possible given the FPGA's somewhat limited resources.  I considered
using the CORDIC algorithm but decided it would require too much
computation per sinewave.  Actually trying to calculate sin(A) via a
Taylor series was even worse.  Instead, a classic lookup-table
approach seemed superior, but space in the FPGA for the table is
definitely an issue.

## Lookup-table approximations

A sine wave is highly symmetrical - one can store data to represent
1/4 of the wave, and can then generate the other 3/4 of the waveform
by what amounts to a process of reflection.  This means that if I
wanted to allow for a full 16-bit representation of the phase of the
wave (2^16 different angles), I'd need to store data for the 2^14
points in the first quadrant... and for "CD quality" I'd need to store
16 bits per point.  This can't be done in the ICE40 Ultra Plus logic
cells (there are far too few).  The Ultra Plus has several single-port
RAMs which are large enough for this much data, but unfortunately they
cannot be pre-loaded as part of the FPGA configuration - it would be
necessary to load them separately by having the FPGA read data from an
external SPI flash.  This was more complex than I wanted to undertake.

So, the only viable storage area for the sin(x) data is the relatively
small dual-port BRAMs... and these can be preloaded as part of the
FPGA configuration and used as ROMs.

Each BRAM can be configured as a 256-element array of 16-bit
registers... so, one BRAM can hold 2^8 values.  That means I'd need 64
BRAMs to hold 2^14 values, and that's more than twice what the FPGA
has available.  So, a brute-force approach won't work.

What will work is some use of linear interpolation.  If I were to use
a single BRAM holding 256 entries (1/64 of the total number of points)
I could then interpolate between these values to create the other
63/64th of the points.  This should result in a fairly good
approximation of a sinewave... and experimentation showed that it does.
Not CD-quality, but not bad.

For better quality, I could use two, or four, or 8 BRAMs, holding
accurate values for 512, 1024, or 2048 points respectively.  This
would require less interpolation and would reduce the distortion of
the approximated sinewave.

## This implementation

This implementation stores accurate 16-bit values for 2048 points per
quadrant (8 BRAMs), and also stores an 8-bit "difference" between each
point and the next, to save time and logic during computation (4
BRAMs).  This requres an 8:1 interpolation, and results in an average
error of roughly 1/2 bit in the 16-bit result... pretty close to CD
quality,

This approach could be extended even further - e.g. using 16 BRAMs to
hold 4096 points per quadrant, and another 4 B BRAMs to hold 4096
4-bit "difference" values.  This would use 20 BRAMs and would reduce
the average error even further.

Yosys is able to infer the use of BRAMs for register arrays of this
sort, even if multiple BRAMs are needed, and so it's not necessary to
explicitly instantiate the SB16 BRAM blocks in the Verilog code.

## Pipelining and resources

The sine-calculating module was designed to be able to handle a
multiplicity of independent sine-wave lookups, while minimizing
resource use.  It uses the BRAMs I've mentioned, some standard
registers, and one of the Ultra Plus DMA blocks (the SB16_MAC
multiply-and-accumulate tile).  

It's designed as a processing pipeline.  You shovel phase angles in,
and (several clocks later) the corresponding sinewave value comes out.
Along with each angle in, the caller provides a 4-bit "owner" tag
which passes through the pipeline, and is presented at the output
along with the sinewave output value.  It accepts one phase angle (and
owner tag) per clock, and delivers one sinewave output (and its owner
tag) per clock.

It has a fairly deep pipeline, with simple processing at each
step... this helps keep the logic clean and fast.  The price for this
is latency - there's about a six-clock delay between the time that a
phase angle goes in, and the time that the sin(x) value comes out.  It
could probably be done in 2-3 clock cycles with a more compressed
pipeline, but the added logic might reduce the maximum clock frequency
at which it could run.

## What it doesn't do.

All this module does is the "phase angle, to sine" lookup and
computation... it's just a fancy table lookup.  It doesn't advance the
phase angle from one lookup to the next.  That's the caller's
responsibility.

## How it can be used

In my own application, I'm using it to do the sin(x) lookups for ten
different signals - six audio test signals, a 38 kHz FM-stereo
subcarrier, the 19 kHz stereo "pilot tone", and an I/Q modulator
drive.  It's being driven by the same clock that drives the I2S
bit-clock, which means I have 32 clocks per audio sample... plenty for
10 signals and a 6-cycle pipeline delay.  It could easily handle 20
signals per audio sample (might need to increase the owner registers
to 5 bits, of course).

You could also use it to compute a single sinewave "as fast as
possible" (one new value per clock) and ignore the owner registers
entirely.

&copy; David Platt 2019, MIT LICENSED
