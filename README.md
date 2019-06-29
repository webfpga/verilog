# webfpga/verilog

This repository contains the Verilog examples and WebFPGA Standard Module
Library hosted at [beta.webfpga.io](https://beta.webfpga.io).

## Directory Structure

**Note: This structure has not been put into place yet. This current
example directory is unsorted and unorganizaed.**

`examples/` holds several sub-directories for each example category. Each
example category begins with a two-digit prefix that indicates its overall
order in the learning progression. Within each category, each individual
example is placed in it's own sub-sub-directory.

```console
├── examples
│   ├── 00-Basics
│   │   └── blinky
│   ├── 01-User-Input
│   │   ├── button
│   │   └── debounce
│   ├── 02-LED
│   │   └── neopixel
│   ├── 03-Seven-Segment
│   │   ├── clock
│   │   ├── counter
│   │   └── stopwatch
│   ├── 04-WebUSB-Communication
│   │   ├── neopixel-control
│   │   └── simple
│   ├── 05-Serial
│   │   ├── I2C
│   │   ├── SPI
│   │   └── UART
│   └── 06-Clocks
│       └── simple

...
```

`library/` contains several WebFPGA-specific modules that are compatible with
the WebFPGA board and physical modules. In here, there are simple to instantiate
modules handle:
* communication with the on-board Neopixel
* input button debouncing
* seven-segment display control
* LED matrix display control

```console
├── library
│   ├── webfpga_debounce.v
│   ├── webfpga_neopixel.v
│   └── webfpga_seven_segment.v

...
```

## Versioning

The live version of the website [https://beta.webfpga.io](beta.webfpga.io) tracks the
latest release. Changes here will not be reflected until a new release has
been cut.

## Contribution

Public contribution is always appreciated! Submit any issues or pull requests
and we will be sure to get through them as quickly as possible.

&copy; Auburn Ventures 2019, MIT LICENSED
