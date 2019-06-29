//////////////////////////////////////////////////////////////////////
//  7 segment display driver and logic
//
//  This code can be adapted to various wiring schemes of 7 segment
//  displays.
//
//  THis code is written for a serial 4 digit 7 segment display.
//  DIS_4x7SEG_BLUE_RA.
//
//  It is wired as follows:
//
//  5 digit drivers enabled when high. (4 digits, time colon)
//  8 segment sinks, LED on when low.
//
//  Shift 16 bits of data per scan.
//      {{1'b0,gg,ff,ee,dd,cc,bb,aa}, {digit[4],3'b000,digit[3:0]}}
//         digit[4] is the driver for the time colon.
//
//      MSB bit is shift first.
//  Need to generate a CLK, DOUT and LOAD signal.
//  DOUT is changed on falling edge of CLK. LOAD is pulsed high
//  after last CLK falling edge.
//
//////////////////////////////////////////////////////////////////////

module WF_BL_7seg_if (

        input clk,
        input scan_enable,   // should be >60Hz, ~2 ms or better
                         // 5 calls for one 1 cycle
                             // 60Hz == 16.67ms -> /5 -> 3.33ms

        input [3:0] digit0,    // BCD digits, 0 is LSD
        input [3:0] digit1,
        input [3:0] digit2,
        input [3:0] digit3,
    input [1:0] colon,   // 00 colon, 01 decpoint, 11 none

        output reg CLK_OUT,
        output     LOAD,
        output     DOUT
);

   reg [4:0] digit;    // rotating bit for which digit is being scanned
                       // scan enables (4 digits, one colon)
   reg       clk7_en;   // during DOUT shifting
   reg [4:0] seg_index;
   reg [3:0] current_digit;
   reg [7:0] segments;
   reg [7:0] data_out; // segment data to be shifted

////////////////////////////////////////////////////////////////////////////
// send data out 16 clocks of data, { digits[3:0],3'b000,DIGDP, seg[7:0]}
// scan digits every scan_enable,
// 4 digits, and colon digit.
//

// digit scaning
     always @ (posedge clk)
       begin
         if (digit == 5'h0)     // just came out of reset
           digit <= 5'h01;

         if (scan_enable)
           digit <= {digit[3:0],digit[4]};   // rotate the select bit
       end

// shift register bit counter
     always @ (posedge clk)
       begin
         if (scan_enable)
           begin
             clk7_en     <= 1'b1;
             seg_index   <= 5'b0;
           end

         if (clk7_en)
           if (seg_index == 5'd31)   // check for last bit
             clk7_en <= 1'b0;
           else
             seg_index <= seg_index + 5'h1;

       end   // always clk enable


// send data out, shift register
     always @ (posedge clk)
       if (clk7_en )
         begin
           if (seg_index[0]) // only change on falling edge
             data_out <= {data_out[6:0],1'b0};
           if (seg_index == 5'd16)
             data_out <= {digit[4],3'b000,digit[3:0]};
           end
       else    // pipelined, digit 4 coming up for ?
         data_out<= (digit[3]) ? {6'h0,2'b01} : segments;     // time colons

// create external outputs to drive the board
     assign LOAD = ~clk7_en;
     assign DOUT = data_out[7];
     // generate clock
     always @ (posedge clk)
       if (clk7_en)
         CLK_OUT <= ~CLK_OUT;
       else
         CLK_OUT <= 1'b0;   // make sure it at zero at idle


////////////////////////////////////////////////////////////////////////////
     // encode current digit into segment data
  //
   always @(*)    // pre-load one digit ahead
      case (digit[4:0])   // synthesis parallel_case
        5'h10: current_digit = digit0;
        5'h1 : current_digit = digit1;
        5'h2 : current_digit = digit2;
        5'h4 : current_digit = digit3;
     endcase
//
//         aaaa
//       ff    bb
//       ff    bb
//       ff    bb
//         gggg
//       ee    cc
//       ee    cc
//       ee    cc
//         dddd
//
//         time colons:  top dot: seg aa
//         time colons:  bot dot: seg bb
//
//        shift order is  {ee,  dd,  ff,  aa,     gg,  bb,  DP,cc}
//        note: DP does exist on this display, it has its own DIGDP
//

////////////////////////////////////////////////////////////////////////////
//active low turns on segment LED
   always @(*)
      case (current_digit)// DP   g    f    e    d    c    b    a
        4'h0 : segments = {1'b1,1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0};
        4'h1 : segments = {1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b0,1'b1};
        4'h2 : segments = {1'b1,1'b0,1'b1,1'b0,1'b0,1'b1,1'b0,1'b0};
        4'h3 : segments = {1'b1,1'b0,1'b1,1'b1,1'b0,1'b0,1'b0,1'b0};
        4'h4 : segments = {1'b1,1'b0,1'b0,1'b1,1'b1,1'b0,1'b0,1'b1};
        4'h5 : segments = {1'b1,1'b0,1'b0,1'b1,1'b0,1'b0,1'b1,1'b0};
        4'h6 : segments = {1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b1,1'b1};
        4'h7 : segments = {1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b0,1'b0};
        4'h8 : segments = {1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0};
        4'h9 : segments = {1'b1,1'b0,1'b0,1'b1,1'b1,1'b0,1'b0,1'b0};
        4'ha : segments = {1'b1,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,1'b0};
        4'hb : segments = {1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b1,1'b1};
        4'hc : segments = {1'b1,1'b0,1'b1,1'b0,1'b0,1'b1,1'b1,1'b1};
        4'hd : segments = {1'b1,1'b0,1'b1,1'b0,1'b0,1'b0,1'b0,1'b1};
        4'he : segments = {1'b1,1'b0,1'b0,1'b0,1'b0,1'b1,1'b1,1'b0};
        4'hf : segments = {1'b1,1'b0,1'b0,1'b0,1'b1,1'b1,1'b1,1'b0};
     endcase

endmodule


