# webfpga/verilog

This repository contains the Verilog examples and WebFPGA Standard Module
Library hosted at [webfpga.io](https://webfpga.io).

## Directory Structure

`examples/` holds several sub-directories for each example category. Each
example category begins with a two-digit prefix that indicates its overall order
in the scheme of learning progression. Within each category, each individual
example is placed in it's own sub-sub-directory.

`library/` contains several WebFPGA-specific modules that are compatible with
the WebFPGA board and physical modules. In here, there are simple to instantiate
modules handle:
* communication with the on-board Neopixel
* input button debouncing
* seven-segment display control
* LED matrix display control
