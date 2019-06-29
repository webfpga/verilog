///////////////////////////////////////////////////////////////////////////
// 
// Moudle: WF_i2s_pulses
//
// Create pulse stream to control timing for i2s signalling.
//
// Parameters allow for adjusting the module for different sampling rates
// and core clock rate.
//
//   instantiation example:
//
//
////  create timing for i2s
//
// i2s_pulses i2s_pulses_inst(
//            .clk(clk),                  // core clock
//            .mclk_pulse(mclk_pulse),    // codec clock, typical in MHz
//            .lrck_pulse(lrck_pulse),    // Frame sync aka, left/right
//            .sclk_pulse(sclk_pulse));   // not always needed, see data
//                                        // sheets
//
// defaults to ~12MHz MCLK, 48KHz sampling, requiring 48MHz core clock
module WF_i2s_pulses(
    input clk,       //     Input Clock
    output reg mclk_pulse, // Master Clock : ~12 Mhz
    output reg lrck_pulse, // Left-Right Clock : 48 Khz
    output reg sclk_pulse  // data shift clk
);

// this module takes the main clock and generates
// pulses to indicate when that signal should toggle.
// The main clock must be at least 4x of desired MCLK.
// MCLK should be very close to one of the following:
//  8.192, 12.2880, 16.384MHz for 32kHz sampling.
//  11.296, 16.9344, 22.5792MHz for 44.1kHz sampling.
//  12.2880, 18.4320, 24.5760MHz for 48kHz sampling.

// counters
reg [7:0] mclk_cnt;
reg [9:0] lrck_cnt;
reg [7:0] sclk_cnt;

// counter thresholds
parameter MCLK_MAX = 1;     // input is 48MHz, master is 12MHz,
parameter LRCK_MAX = 511;   // ratio LR to MCLK is 512
parameter SCLK_MAX = 7;

// mclk
  always @(posedge clk)
    // increment counter
    if (mclk_cnt < MCLK_MAX)
      begin
        mclk_pulse <= 0;
        mclk_cnt   <= mclk_cnt + 1;
      end
    else
      begin
        mclk_pulse <= 1;
        mclk_cnt   <= 0;
      end

  always @(posedge clk)
    if (lrck_cnt < LRCK_MAX)
      begin
        lrck_cnt <= lrck_cnt + 1;
        lrck_pulse <= 0;
      end
    else
      begin
        lrck_pulse <= 1;
        lrck_cnt <= 0;
      end

// sclk
  always @(posedge clk)
    if (sclk_cnt < SCLK_MAX)
      begin
        sclk_pulse <= 0;
        sclk_cnt <= sclk_cnt + 1;
      end
    else
      begin
        sclk_pulse <= 1;
        sclk_cnt <= 0;
      end

endmodule

