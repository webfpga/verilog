// audio.v
//
// This example plays the tune of Star Wars through the Audio DAC.
// The Verilog source code in the file produces an I2S audio stream
// and outputs it on MCLK, LRCK, and SDATA. You can select whatever pins
// you woule like to use below, then wire those up to the DAC.
//
// @MAP_IO MCLK  1
// @MAP_IO LRCK  2
// @MAP_IO SDATA 4
//
// This Source Code is Public Domain.

module fpga_top (
    output reg  MCLK,    // master (audio codec) clock, our case is ~12MHz
    output reg  LRCK,    // Left/right clock, aka Frame Sync (FS)
    output reg  SCK,     // Serial clock, no needed MCLK/SCK is x512
    output wire SDATA,   // channel data LSB first.

    input  wire WF_CPU1,
    input  wire WF_BUTTON
);


  // i2s
   reg [31:0] shift_data;
   reg        sclk_d;
   reg [15:0] phase_acc;

   wire mclk_pulse;
   wire lrck_pulse;
   wire sclk_pulse;

   // tone sequencer
   reg [5:0] cnt1;
   reg [5:0] note;
   reg [3:0] melody;   // 16 notes
   reg [15:0] tone;
//////////////////////////////////////////////////////////////////////          


//  create clock for SB_HFOCS hard macro
    wire clk_en;
    assign clk_en = 1'b1;

//////////////////////////////////////////////////////////////////////          
//                                                                              
//  module time base  logic
//                                                                              
  SB_HFOSC OSC_i (
        .CLKHFEN(clk_en),
        .CLKHFPU(clk_en),
        .CLKHF(clk));

     // include time base  10us
     WF_timer #(.COUNT(479), .EVERY_CLK(1'b1)) ten_usec(
           .clk(clk),
           .enable(1'b1),
           .timer_pulse(ten_us));

     // include time base  10ms
     WF_timer #(.COUNT(999)) ten_msec(
           .clk(clk),
           .enable(ten_us),
           .timer_pulse(ten_ms));

     // include time base  1/4 sec
     WF_timer #(.COUNT(24)) quarter_sec(
           .clk(clk),
           .enable(ten_ms),
           .timer_pulse(quarter_second));

//  debounce switch in

    WF_switch_debounce switch_debounce_inst (
      .clk(clk),              // main clock
      .sample_en(ten_ms),     // pulse when to sample
      .switch_in(WF_BUTTON),  // async switch input
      .switch_out(),          // sync switch out, debounced
      .switch_pushed(switch_pushed),    // pulse when switch is pushed
      .switch_released()                // pulse when switch is released
     );

//////////////////////////////////////////////////////////////////////          
//                                                                              
//  create timing for i2s
//                                                                              
WF_i2s_pulses WF_i2s_pulses_inst(
              .clk(clk),
              .mclk_pulse(mclk_pulse),
              .lrck_pulse(lrck_pulse),
              .sclk_pulse(sclk_pulse));
//                                                                              
// generate output clock streams
//
  always @(posedge clk)
    begin
      sclk_d <= SCK && ~lrck_pulse; // skip first falling edge after LRCK

      if (mclk_pulse)
        MCLK <= ~MCLK;

      if (lrck_pulse)
        LRCK <= ~LRCK;

      if (sclk_pulse)
        SCK <= ~SCK;
      end

  assign sclk_fall = sclk_d && ~SCK;


//////////////////////////////////////////////////////////////////////          
//                                                                              
// sine wave table to form notes, can use a half table for higher
// resolution
//
reg     [7:0] sine [0:255];
initial $readmemh("/sine.hex", sine);


//////////////////////////////////////////////////////////////////////          
//                                                                              
//  create  tones and notes.
//   sine frequency is calculated as follows:
//   fo  frequency out (our tone, middle C is 440Hz)
//   fc  sample frequency,   using 48KHz, which implies 12.288MHz for MCLK
//
// using the phase accumulator (PA) method to generate tones.
// This method adds a constant (M) on each sample time to an accumulator.
// The accumulator is a large adder, in which the most significant bits
// are used to address the sine lookup table.
//
// The equation is fo = (M * fc) /2^n, where n is the width of the PA.
//                                                                              
//  The larger n is, will allow a higher sine frequency. Nyquist tells us
//  we need at least 2x sampling, however higher sampling gives less noise.
//  The Nyquist can be calculated as 2^n/M, where M is the value for the
//  highest frequency desired. This result needs to be at least 2x, 5x to 10x 
//  is desired.
//
//  So two variables will increase the quality of the audio, n and number
//  of entries in the sine lookup table.
//
//  The highest note on a piano is ~4100Hz.
//  Given a PA of 16 bits, M is 5583. so 2^16/5583 is 11x,
//  If our sine LUT is 7 bits, then PA[15:9] is its address. Each M added
//  at 4100Hz, will change bits PA[11:0], from that you can see our sine
//  will skip about every four entries in the table. The note should be
//  ok given Nyquist.
//
//  If we increase PA size we can get more entries from the table. Also
//  if we increase the sine table to 10 bits of address, will also increase the
//  quality. If the table increases we must increase the PA width. These
//  increases do have of cost in FPGA resources.
//  
  always @(*)
      case (note[3:0])
          4'h0 : tone = 16'd356;    // 261.63 C(4)
          4'h1 : tone = 16'd378;    // 277.18 D(4) flat/C(4) sharp
          4'h2 : tone = 16'd401;    // 293.66 D(4)
          4'h3 : tone = 16'd424;    // 311.13 E(4) flat/D(4) sharp
          4'h4 : tone = 16'd450;    // 329.63 E(4)
          4'h5 : tone = 16'd476;    // 349.23 F(4)
          4'h6 : tone = 16'd505;    // 369.99 G(4) flat/F(4) sharp
          4'h7 : tone = 16'd534;    // 392.00 G(4)
          4'h8 : tone = 16'd566;    // 415.30 A(4) flat/G(4) sharp
          4'h9 : tone = 16'd599;    // 440.00 A(4)
          4'ha : tone = 16'd635;    // 466.16 B(4) flat/A(4) sharp
          4'hb : tone = 16'd674;    // 493.88 B(4)
          4'hc : tone = 16'd000;
      endcase

      parameter C  = 6'h0;
      parameter Df = 6'h1;
      parameter Cs = 6'h1;
      parameter D  = 6'h2;
      parameter Ef = 6'h3;
      parameter Ds = 6'h3;
      parameter E  = 6'h4;
      parameter F  = 6'h5;
      parameter Fs = 6'h6;
      parameter Gf = 6'h6;
      parameter G  = 6'h7;
      parameter Af = 6'h8;
      parameter Gs = 6'h8;
      parameter A  = 6'h9;
      parameter Bf = 6'ha;
      parameter As = 6'ha;
      parameter B  = 6'hb;
      parameter none = 4'hc;
      parameter OL = 6'b11_0000;  // octave lower
      parameter OH = 6'b10_0000;  // octave higher

  always @(*)
      case (melody[3:0])
      `ifdef CETK     // close encounters of the third kind
	      4'h0 : note = G;
	      4'h1 : note = A;
	      4'h2 : note = F;
	      4'h3 : note = F+OL;
	      4'h4 : note = C;
	      4'h5 : note = none;
	      4'h6 : note = none;
	      4'h7 : note = none;
	      4'h8 : note = Bf;
	      4'h9 : note = C;
	      4'ha : note = Af;
	      4'hb : note = Af+OL;
	      4'hc : note = Ef;
	      4'hd : note = none;
	      4'he : note = none;
	      4'hf : note = none;
      `else
	      4'h0 : note = G+OL;
	      4'h1 : note = none;
	      4'h2 : note = G+OL;
	      4'h3 : note = none;
	      4'h4 : note = G+OL;
	      4'h5 : note = C;
	      4'h6 : note = none;
	      4'h7 : note = none;
	      4'h8 : note = G;
	      4'h9 : note = none;
	      4'ha : note = none;
	      4'hb : note = none;
	      4'hc : note = F;
	      4'hd : note = E;
	      4'he : note = D;
	      4'hf : note = C+OH;
      `endif
      endcase
//  
/////////////////////////////////////////////////////////////////////          
//
//  pause melody when switch is pushed or WF_CPU1 is asserted
   always @ (posedge clk)                                                       
       if ((quarter_second && WF_CPU1) || switch_pushed)
           melody <= melody + 1;

//////////////////////////////////////////////////////////////////////          
//                                                                              
// SDATA output
//
    wire   [6:0] sinlut;
    assign sinlut = sine[phase_acc[15:8]];
//
  always @(posedge clk)
    if (lrck_pulse && LRCK)
      begin
        //phase_acc <= phase_acc + (cnt1[5] ? (cnt1[4] ? {1'b0,tone[15:1]} :{tone[14:0],1'b0})  : tone);  
        phase_acc <= phase_acc + (note[5] ? (note[4] ? {1'b0,tone[15:1]} :{tone[14:0],1'b0})  : tone);  
     //   phase_acc <= phase_acc + 16'd599;     // 440Hz
     //   phase_acc <= phase_acc + 24'd76900;     // 440Hz
     //   phase_acc <= phase_acc + 16'd1362;    // 1KHz
     //   phase_acc <= phase_acc + 16'd11362;    // 1KHz
       // shift_data <= {16'h0,sinlut[6],9'b0,sinlut[5:0]};
     //   shift_data <= {16'h0,sinlut[6:0],9'b0};   // good waveform, sign bit 15.
        shift_data <= {16'h0,sinlut[6],
                             sinlut[6] ? 1'b1:1'b0,
                             sinlut[6] ? 1'b1:1'b0,
                             sinlut[6] ? 1'b1:1'b0,
                             sinlut[6] ? 1'b1:1'b0,
                             sinlut[5:0],5'b0};   
      end
    else if (sclk_fall)
      shift_data <= {shift_data[30:0],1'b0};

  assign SDATA = shift_data[31];

endmodule

///////////////////////////////////////////////////////////////////////////

module WF_i2s_pulses(
    input clk,       //     Input Clock
    output reg mclk_pulse, //     Master Clock : 12.5 Mhz
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

//////////////////////////////////////////////////////////////////////
//
// timer
//
   module WF_timer (
       input  wire clk,
       input  wire enable,
       output reg  timer_pulse
   );

   parameter [9:0] COUNT = 499;
   parameter       EVERY_CLK = 1'b0;

    reg [9:0] counter;

    always @ (posedge clk)
        if (enable)
          begin
            if (counter == COUNT)
              begin
                timer_pulse <= 1'b1;
                counter     <= 'b0;
              end
           else
             begin
              counter     <= counter + 'b1;
              if (EVERY_CLK)  // case enable never goes low
               timer_pulse <= 1'b0;
             end

          end
        else
            timer_pulse <= 1'b0;

   endmodule

//////////////////////////////////////////////////////////////////////
//
// external switch debounced and synchronizer.
// active low when pushed.
//
   module WF_switch_debounce (
     input  wire clk,              // main clock
     input  wire sample_en,        // pulse when to sample
     input  wire switch_in,        // async switch input
     output reg  switch_out,       // sync switch out, debounced
     output wire switch_pushed,    // pulse when switch is pushed
     output wire switch_released); // pulse when switch is released

     reg  [2:0] switch;
     reg        switch_out_d;
//
     always @ (posedge clk)
       begin
         if ( sample_en)
           switch <= { switch[1:0],switch_in };

         if (switch == 3'b000)
           switch_out <= 1'b1;
         else if (switch == 3'b111)
           switch_out <= 1'b0;
     
         switch_out_d <= switch_out;
       end

     assign switch_pushed   = ~switch_out &&  switch_out_d;
     assign switch_released =  switch_out && ~switch_out_d;

   endmodule

