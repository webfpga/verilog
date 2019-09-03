//
// --------------------------------------------------------------------
// --------------------------------------------------------------------
// Cascadia Web Based FPGA Tools  Section
//
// IOs are set with comment directive @MAP_IO ioName ioPin
//
// @MAP_IO DOUT      10 // (internal FPGA pin = 28)
// @MAP_IO CLK_OUT   9  // (internal FPGA pin = 26)
// @MAP_IO LOAD      8  // (internal FPGA pin = 25)

// Clock is define with directive #CAS_XXX  clkName clkPeriod (12MHz)
// This builds the SDC file used for P&R and timing checks
// #CASS_CLK net CLK 83   //ns
// #CAS_CLK pin OSC_i/CLKHF 83.3    //ns   
//
// Device target board is done with directive #CAS_XXXXXX boardName
// #CAS_TARGET  SHASTAPLUS

// set top level module
// #CAS_NAME  WF_7seg_clock // top level module
// --------------------------------------------------------------------
//  #CAS_DESC  7 segment display used as a clock. Push buttom clears clock
//
//  This DEMO uses the internal HFOSC which isn't accurate enough for
//  a real clock. An external cystal is needed to gain the presion needed.
//

//           
// --------------------------------------------------------------------
//
// Revision History :

module fpga_top(

    output wire      CLK_OUT,
    output wire      DOUT,
    output wire      LOAD,
    input  wire      WF_CPU1,
    input  wire      WF_BUTTON
);

// define registers


   // CPU signal
   reg       cpu_in_d;      // delayed to create pulse
   wire      cpu_toggled;

   // stop switch control
   reg       timer_enable;
   reg       timer_reset;
   reg       once_half_sec;

   // timer digits  BCD
   reg [3:0] digit0;
   reg [3:0] digit1;
   reg [3:0] digit2;
   reg [3:0] digit3;

/////////////////////////////////////////////////////////////////////////
//
//  create clk from SB_HFOCS hard macro
// OSC enable
   wire      clk_en = 1'b1;
	

  SB_HFOSC OSC_i (
	    .CLKHFEN(clk_en),
	    .CLKHFPU(clk_en),
	    .CLKHF(clk));

    // set to 12MHz
   defparam OSC_i.CLKHF_DIV = "0b10";

        // include time base  10us
     WF_timer #(.COUNT(119), .EVERY_CLK(1'b1)) ten_usec(
           .clk(clk),
           .enable(1'b1),
           .timer_pulse(ten_us));

     // include time base  2ms
     WF_timer #(.COUNT(199)) two_msec(
           .clk(clk),
           .enable(ten_us),
           .timer_pulse(two_ms));

     // include time base  1 sec
     WF_timer #(.COUNT(499)) one_sec(
           .clk(clk),
           .enable(two_ms),
           .timer_pulse(one_second));

//
//  debounce switch in

    WF_switch_debounce switch_deb1 (
      .clk(clk),              // main clock
      .sample_en(ten_ms),     // pulse when to sample
      .switch_in(WF_BUTTON),  // async switch input
      .switch_out(switch_debounced),    // sync switch out, debounced
      .switch_pushed(switch_pushed),    // pulse when switch is pushed
      .switch_released()                // pulse when switch is released
     );

// include 4 digit 7 segment interface module
//
     WF_BL_7seg_if WF_BL_7seg_if (
	.clk(clk),
	.scan_enable(two_ms),   // should be >60Hz, 2 ms or better
	                        // 5 calls for one 1 cycle
				// 60Hz == 16.67ms -> /5 -> 3.33ms

	.digit0(digit0),    // BCD digits, 0 is LSD
	.digit1(digit1),
	.digit2(digit2),
	.digit3(digit3),
	.colon(2'b00),      // 00 colon, 01 decpoint, 11 none

	.CLK_OUT(CLK_OUT),
	.LOAD(LOAD),
	.DOUT(DOUT)
);

////////////////////////////////////////////////////////////////////////////
//  DEMO uses the webfpga Blue 7 segment 4 digit board
//
// This will be a clock show 2 digits of second, followed by a colon
// then two digits of minutes.
// Pressing the user push botton or push the webfpga BNT1 will reset the clock.
//
////////////////////////////////////////////////////////////////////////////
//
     // detect CPU signal changing
   always @ (posedge clk)
       cpu_in_d <= WF_CPU1;

    assign cpu_toggled = (cpu_in_d && ~WF_CPU1) || (~cpu_in_d && WF_CPU1);


////////////////////////////////////////////////////////////////////////////
// create clock, counts seconds and minutes.
//
    always @ (posedge clk)
      begin
        if (switch_debounced==0 || cpu_toggled)
          begin
            digit3 <= 4'h0;  
            digit2 <= 4'h0;  
            digit1 <= 4'h0;  
            digit0 <= 4'h0;  
          end
        else
          begin
            if (one_second)
              begin
                if (digit0 == 4'h9)
	          begin
	            digit0 <= 4'h0;
                      if (digit1 == 4'h5)
	              begin
	                digit1 <= 4'h0;
	  	          if (digit2 == 4'h9)
		            begin
		              digit2 <= 4'h0;
		              if (digit3 == 4'h5)
		                begin
		                  digit3 <= 4'h0;
  		                end
		              else
                                digit3 <= digit3 + 4'h1;
	  	            end
		          else
                            digit2 <= digit2 + 4'h1;
	              end
	            else
                      digit1 <= digit1 + 4'h1;
                  end
	        else
	          digit0 <= digit0 + 4'h1;
              end  // one second
          end //else
      end   //always


 endmodule

////////////////////////////////////////////////////////////////////////////


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
	input scan_enable,   // should be >60Hz, 2 ms or better

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
   reg       clk_en;   // during DOUT shifting
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

         if (clk_en && seg_index == 5'd31) // rotate at end of cycle
	   digit <= {digit[3:0],digit[4]};   // rotate the select bit
       end

// shift register bit counter
     always @ (posedge clk)
       begin
         if (scan_enable)
           begin
             clk_en      <= 1'b1;
             seg_index   <= 5'b0;
           end

         if (clk_en)
           begin
	     if (seg_index == 5'd31)   // check for last bit
               clk_en <= 1'b0;

	     seg_index <= seg_index + 5'h1;
           end

       end   // always clk enable


// send data out, shift register 
     always @ (posedge clk)
       if (clk_en )
         begin
           if (seg_index[0]) // only change on falling edge
	     begin
	       if(seg_index == 5'd15) // mid way, send digit enables
                 data_out <= {digit[4],3'b000,digit[3:0]};
               else
                 data_out <= {data_out[6:0],1'b0};
             end
         end
       else
         data_out<= (digit[4]) ? {6'h0,colon} : segments; // load for next cycle

// create external outputs to drive the board
     assign LOAD = ~clk_en;
     assign DOUT = data_out[7];
     // generate clock
     always @ (posedge clk)
       if (clk_en)
         CLK_OUT <= ~CLK_OUT;
       else
         CLK_OUT <= 1'b0;   // make sure it at zero at idle


////////////////////////////////////////////////////////////////////////////
     // encode current digit into segment data
  //   
   always @(*)    // pre-load one digit ahead
      case (digit[4:0])   // synthesis parallel_case
        5'h1 : current_digit = digit0;
        5'h2 : current_digit = digit1;
        5'h4 : current_digit = digit2;
        default: current_digit = digit3;   // 5'h8 case
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
           switch_out <= 1'b0;
         else if (switch == 3'b111)
           switch_out <= 1'b1;

         switch_out_d <= switch_out;
       end

     assign switch_pushed   = ~switch_out &&  switch_out_d;
     assign switch_released =  switch_out && ~switch_out_d;

   endmodule

