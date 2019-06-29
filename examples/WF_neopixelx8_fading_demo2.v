// #CAS_CLK pin OSC_i/CLKHF 83.3    //ns   
// @MAP_IO DOUT 0

module fpga_top(
    output wire DOUT,
    input  wire WF_CPU1,
    input  wire WF_BUTTON
);

// OSC enable
   wire      clk_en = 1'b1;

   reg  [23:0] pixel0;  
   reg  [23:0] pixel1;
   reg  [23:0] pixel2;
   reg  [23:0] pixel3;
   reg  [23:0] pixel4;
   reg  [23:0] pixel5;
   reg  [23:0] pixel6;
   reg  [23:0] pixel7;	
   reg  [23:0] np_pixels;
   wire [ 7:0] ram_rd_addr;

      // CPU signal
   reg       cpu_in_d;      // delayed to create pulse
   wire      cpu_toggled;

/////////////////////////////////////////////////////////////////////////
//
// instaiate modules
//
//  create clock for SB_HFOCS hard macro

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

     // include time base   five ms
     WF_timer #(.COUNT(499)) five_msec(
           .clk(clk),
           .enable(ten_us),
           .timer_pulse(five_ms));

//  debounce switch in
    WF_switch_debounce switch_deb1 (
      .clk(clk),              // main clock
      .sample_en(five_ms),     // pulse when to sample
      .switch_in(WF_BUTTON),  // async switch input
      .switch_out(),          // sync switch out, debounced
      .switch_pushed(switch_pushed),    // pulse when switch is pushed
      .switch_released()                // pulse when switch is released
     );

     // neopixel I/F
    WF_neopixel_if #(     // parameters for on board neopixel
	   .NUM_OF_PIXELS(8))
    neopixel_inst(
           .clk(clk),                 // currently parameters based on 12MHz
           .ten_us(ten_us),           // only used for reset timer
           .ram_rd_addr(ram_rd_addr),
           .ram_rd_data(np_pixels),   // neopxiel data
           .DOUT(DOUT));              // neopxiel data out pin


//////////////////////////////////////////////////////////////////              
//  Create colors to DEMO above bit logic.                                      
//////////////////////////////////////////////////////////////////
// create colors in the pixel registers.
//
//  DEMO showing fading and mxing of colors
//
//  pixel0 green fading
//  pixel1 red fading
//  pixel2 blue fading
//  pixel3 CPU controlled
//  pixel4 red and blue mixed fading 
//  pixel5 red and green mixed fading 
//  pixel6 all colors mixing  (positive)
//  pixel7 all colors mixing  (negative)
//
  reg [1:0] cnt;
  reg [6:0] cnt2;
  reg [2:0] cnt3;
  reg       updn;
  reg       updn_d;
  reg [2:0] ph;

  // bit reverse, since LSB is most bright
  wire [6:0] cnt2_G = {cnt2[0],cnt2[1],cnt2[2],cnt2[3],cnt2[4],cnt2[5],cnt2[6]};
  wire [6:0] cnt2_R = {cnt2[0],cnt2[1],cnt2[2],cnt2[3],cnt2[4],cnt2[5],cnt2[6]};
  wire [6:0] cnt2_B = {cnt2[0],cnt2[1],cnt2[2],cnt2[3],cnt2[4],cnt2[5],cnt2[6]};


   always @(posedge clk)
     begin
       if (five_ms)
         begin
           cnt <= cnt + 'h01;   // every 40ms change the color
           if (cnt == 0)
             begin
               if (cnt2 ==  127)
	         begin
                   cnt2 <= 126;
                   updn <= ~updn;   // phasing, so mixed colors blend well
	           if (ph==5) ph <= 0; else ph <= ph + 1;
	         end
	       else if (cnt2 == 1 && updn ==1)  // down counting
	         begin
                   cnt2 <= 1;
                   updn <= ~updn;
	           if (ph==5) ph <= 0; else ph <= ph + 1;
	         end
	       else if (updn==0)
                 cnt2 <= cnt2 + 7'b1;
	       else
                 cnt2 <= cnt2 - 7'b1;
	   end   // cnt == 0
         end  // five_ms

	 // use above updown couner values and assign to different pixels
	 //  pure color fading
	 //  NOTE: all fading colors are at 1/2 power, can go full if not USB powered
         pixel0[23:0] <= {8'b0,8'b0,cnt2_G,1'b0};
         pixel1[23:0] <= {8'b0,cnt2_R,1'b0,8'b0};
         pixel2[23:0] <= {cnt2_B,1'b0,8'b0,8'b0};
         // CPU controlled
         pixel3[0]  <= ~cnt3[0];
         pixel3[8]  <= ~cnt3[1];
         pixel3[16] <= ~cnt3[2];
         // mixed colors  (2 colors)
         pixel4[23:0] <= {cnt2_B,1'b0, ~cnt2_R,1'b0,8'b0};
         pixel5[23:0] <= {8'b0, ~cnt2_R,1'b0,cnt2_G,1'b0};
         // all three mixed
	 if (ph==0) // pixel 6 and 7 mix all colors
           pixel6[23:0] <= {8'h80,        ~cnt2_R,1'b0,   cnt2_G,1'b0};
         if (ph==1)
           pixel6[23:0] <= {~cnt2_B, 1'b0, 8'h80,         cnt2_G,1'b0};
         if (ph==2)
           pixel6[23:0] <= {~cnt2_B, 1'b0,  cnt2_R,1'b0,   8'h80};
         if (ph==3)
           pixel6[23:0] <= {8'h80,         cnt2_R,1'b0,   ~cnt2_G,1'b0};
         if (ph==4)
           pixel6[23:0] <= {cnt2_B,1'b0,   8'h80,         ~cnt2_G,1'b0};
         if (ph==5)
           pixel6[23:0] <= {cnt2_B,1'b0,  ~cnt2_R,1'b0,    8'h80};
         pixel7[23:0] <= 
		    {~pixel6[23:17],1'b0,~pixel6[15:9],1'b0,~pixel6[7:1],1'b0};
   
         updn_d <= updn; 
     end  // always

///////////////////////////////////////////////////////////////////////////
// mux for the pixels channels
//
   always @(*)
      case (ram_rd_addr)
        3'h0 : np_pixels = pixel0;
        3'h1 : np_pixels = pixel1;
        3'h2 : np_pixels = pixel2;
        3'h3 : np_pixels = pixel3;
        3'h4 : np_pixels = pixel4;
        3'h5 : np_pixels = pixel5;
        3'h6 : np_pixels = pixel6;
        3'h7 : np_pixels = pixel7;
     endcase
///////////////////////////////////////////////////////////////////////////
//
//       // detect CPU signal changing
   always @ (posedge clk)
       cpu_in_d <= WF_CPU1;

    assign cpu_toggled = (cpu_in_d && ~WF_CPU1) || (~cpu_in_d && WF_CPU1);

     always @(posedge clk)
       if (cpu_toggled || switch_pushed)  
          cnt3 <= cnt3 + 3'b1;

endmodule

///////////////////////////////////////////////////////////////////////////
// Addressable RGB LEDs.
//
// This module is coded for 1 to 255 LEDs in a chain or array.
//
// These "neopixels" use a signal control signals to send data to conrol
// upto 16.7M colors per LED. Upto 1000 LEDs can be placed in a chain(array).
// Each LED needs 24bits for its color, it then strips the used data and 
// forwards the remaining serial stream to the downstream LEDs. This repeats
// until all the LEDs get their color data.
//
// Each bit has the following timing for either a logical zero or one
// in the data stream. Once all the serial data is sent a reset period is
// required before sending new data to the LEDs array.
//
// The table detials how many clocks the specific vender of the LEDs 
// requires for a bit0, bit1 and total period. Also listed is the reset 
// period. The values are parameterized and must be calculated based on
// the connected clock rate.
//
///////////////////////////////////////////////////////////////////////////
// create pulses for bit0 and bit1 switching to low state.
// sync on np_sof signal.
//0
// one bit stream is:
//  
//    |                             |
//    |-------------                -----------
//    |             |               |
//    |<- hi time ->|< lo time    ->|
//    |             |               |
//    |              ----------------
//    |                             |
//    |<-         bit time        ->|
//
//    first bit out is the mosb for color intentsity.
//    GREEN followed by RED followed by BLUE. (this may vary by vender)
//
//  table values are in ns and +/- tolerances, ex: 800/150 is 800+/-150ns
//
//            period   |   1 hi  |   0 hi  |   1 lo  |   0 lo  |  reset 
//==========================================================================
// WS2812B  1250/600   | 800/150 | 400/150 | 450/150 | 850/150 | >50 us
// SK6805   1250/600   | 600/150 | 600/150 | 300/150 | 900/150 | >80 us


// this device has 12 MHz, so 83.333ns period.
// Table for number clocks and acutal time given that number of clocks

//            period   |   1 hi  |   0 hi  |   1 lo  |   0 lo  |  reset 
//==========================================================================
// WS2812B  15/1250    | 10/833  |  5/417  |  5/417  | 10/833  | >600 clks
// SK6805   15/1250    |  7/583  |  8/666  |  4/333  | 11/916  | >961 clks
//
// I have seen clone boards with stated WS2812B but they are not. This
// may results in different RGB ordering or even timing numbers.

module WF_neopixel_if(
    input  wire        clk,    
    input  wire        ten_us,          // pulse every ten us
    output reg  [7:0]  ram_rd_addr,     // address of next pixel
    input  wire [23:0] ram_rd_data,     // neopixel data
    output reg         DOUT             // neopixel data out pin
);

  parameter NUM_OF_PIXELS = 8;
  parameter [3:0] BIT1_HI = 10;                                                 
  parameter [3:0] BIT1_LO =  5;                                                 
  parameter [3:0] BIT0_HI =  5;                                                 
  parameter [3:0] BIT0_LO = 10;                                                 
  parameter [3:0] NEO_PERIOD = 15; 
  parameter [3:0] NEO_RESET = 6;    // count in 10s of microseconds
// set parameters based on  above table and clk frequenecy


    reg [23:0]  shift_pixels;
    reg [4:0]   pixel_bit_cnt;
    reg         np_eof;                 // end of frame
    wire        np_sof;                 // start of frame
    reg [3:0]   np_clk_cnt;
    reg         tog_bit0;               // pulse to indicate toggle output
    reg         tog_bit1;
    reg         pixel_bit_end;          // pulse at end of bit time
    wire        phase;                  // when phase==0 reset, ==1 shift
    reg         phase_d;
    reg         phase_tmp;
    reg [3:0]   reset_cnt;              // count number 10us pulses

// use above parameters to create signals to conrol shifting of data
//  pulses when to toggle bit based on whether bit is zero or one
//  pulse to indicate end of bit time.
   always @(posedge clk)
     begin
       if (np_sof)
         begin
           np_clk_cnt <= 4'b1;  // advance one cnt due to dout starting early
	                        // for first transfer.
         end
       else if (phase == 1'b1)
         begin
           if (np_clk_cnt == NEO_PERIOD - 4'h1)
             begin
               np_clk_cnt     <= 4'b0;
               pixel_bit_end  <= 1'b1;
             end
           else
             np_clk_cnt <= np_clk_cnt + 4'b1;

           if (np_clk_cnt == BIT0_HI - 4'h1)
             tog_bit0 <= 1'b1;    // pulse to change dout for bit being 0
           else
             tog_bit0 <= 1'b0;

           if (np_clk_cnt == BIT1_HI - 4'h1)    
             tog_bit1 <= 1'b1;    // pulse to change dout for bit being 1
           else
             tog_bit1 <= 1'b0;

           if (pixel_bit_end) pixel_bit_end <= 1'b0; // create pulse
         end
     end

 // data stream shift register.
   always @(posedge clk)
     begin 
       if (phase==0) // neopixel reset
         begin
           if (np_sof)
             begin
               DOUT      <= 1'b1;  // every bit starts at logic 1
               ram_rd_addr<= 8'b1;  // advance pointer 
             end
           else
             begin
               DOUT         <= 1'b0;
               shift_pixels <= ram_rd_data;
               pixel_bit_cnt<= 5'b0;  // 24 bits per pixel
               ram_rd_addr  <= 8'b0;  //256 pxiels
               np_eof       <= 1'b0;  // clear singal to create pulse
             end
         end  // if phase==0
       else
         begin       // neopixel data TX phase
           if (( shift_pixels[0] && tog_bit1) ||
               (~shift_pixels[0] && tog_bit0) )
             DOUT <= 1'b0;
//       at end of bit time, shift the pixels or load new 24 bits
           if (pixel_bit_end)
             if (pixel_bit_cnt != 23)
               begin
                 DOUT          <= 1'b1;
                 shift_pixels  <= {1'b0,shift_pixels[23:1]};
                 pixel_bit_cnt <= pixel_bit_cnt + 1'b1;
               end
             else
	       if ( ram_rd_addr != NUM_OF_PIXELS) // last one was sent
                 begin
                   DOUT          <= 1'b1;
                   shift_pixels  <= ram_rd_data;
                   pixel_bit_cnt <= 1'b0;
                   ram_rd_addr   <= ram_rd_addr + 8'b1;  //  pixels 
                 end
	       else
	         begin     // start reset cycle
                   np_eof <= 1'b1;
                   DOUT   <= 1'b0; 
	         end
         end  // phase == 1
     end    // always


//  reset counter  -pause after complete data stream of string of LEDs 
   always @(posedge clk)
     begin
       if (phase_tmp == 0)
	 begin
           if (ten_us)
             begin
               if (reset_cnt == NEO_RESET)
                 begin
                   phase_tmp <= 1'b1;  // start data frame
                   reset_cnt <= 'd0; // clear reset count readying it for next use
                 end
               else
                 reset_cnt <= reset_cnt + 'd1;
             end	 
         end

      if (np_eof)           // once last data is sent start reset again
        phase_tmp <= 1'b0;

// create delays for SOF
      phase_d <= phase_tmp;

    end

    assign np_sof =  ~phase_d && phase_tmp; 
    assign phase = phase_d;

endmodule
// 
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

//////////////////////////////////////////////////////////////////////
//   ROM holding rainbow colors.  ROM will be made out of a BRAM.
//
module WF_neo_fading_rom ( rd_data, rd_addr,clk);
  output [15:0]  rd_data;
  input   [7:0]  rd_addr;
  input          clk;

  wire [15:0] rd_data1;
  wire [15:0] rd_data;

  // bit reverse ROM data for LSB being brightest.
  assign rd_data = {rd_data1[15],
                    rd_data1[10],rd_data1[11],rd_data1[12],rd_data1[13],rd_data1[14],
                    rd_data1[5],rd_data1[6],rd_data1[7],rd_data1[8],rd_data1[9],
                    rd_data1[0],rd_data1[1],rd_data1[2],rd_data1[3],rd_data1[4]};

                 SB_RAM256x16  ram ( .WDATA(16'b0),
                               .MASK(16'b0),
                               .WADDR(8'b0),
                               .WE(1'b0),
                               .WCLKE(1'b0),
                               .WCLK(1'b0),
                               .RDATA(rd_data1),
                               .RADDR(rd_addr),
                               .RE(1'b1),
                               .RCLKE(1'b1),
                               .RCLK(clk));

defparam ram.INIT_0 = 256'b0001011101000000000101110100000000010011010000000001001101100000000100110110000000001111011000000000111110000000000011111000000000001011101000000000101110100000000001111010000000000111110000000000011111000000000000111100000000000011111000000000001111100000;
defparam ram.INIT_1 = 256'b0010111010000000001011101000000000101010100000000010101010100000001010101010000000100110101000000010011011000000001001101100000000100010111000000010001011100000000111101110000000011111000000000001111100000000000110110000000000011011001000000001101100100000;
defparam ram.INIT_2 = 256'b0100010111000000010001011100000001000001110000000100000111100000010000011110000000111101111000000011111000000000001111100000000000111010001000000011101000100000001101100010000000110110010000000011011001000000001100100100000000110010011000000011001001100000;
defparam ram.INIT_3 = 256'b0101110100000000010111010000000001011001000000000101100100100000010110010010000001010101001000000101010101000000010101010100000001010001011000000101000101100000010011010110000001001101100000000100110110000000010010011000000001001001101000000100100110100000;
defparam ram.INIT_4 = 256'b0111010001000000011101000100000001110000010000000111000001100000011100000110000001101100011000000110110010000000011011001000000001101000101000000110100010100000011001001010000001100100110000000110010011000000011000001100000001100000111000000110000011100000;
defparam ram.INIT_5 = 256'b0110110000000011011100000000001101110000000000110111010000000010011101000000001001110100000000010111100000000001011110000000000101111000000000000111110000000000011111000000000001111100000000000111110000000000011110000000000001111000001000000111100000100000;
defparam ram.INIT_6 = 256'b0101010000001001010110000000100101011000000010010101110000001000010111000000100001011100000001110110000000000111011000000000011101100000000001100110010000000110011001000000011001101000000001010110100000000101011010000000010001101100000001000110110000000100;
defparam ram.INIT_7 = 256'b0011110000001111010000000000111101000000000011110100010000001110010001000000111001000100000011010100100000001101010010000000110101001000000011000100110000001100010011000000110001010000000010110101000000001011010100000000101001010100000010100101010000001010;
defparam ram.INIT_8 = 256'b0010010000010101001010000001010100101000000101010010110000010100001011000001010000101100000100110011000000010011001100000001001100110000000100100011010000010010001101000001001000111000000100010011100000010001001110000001000000111100000100000011110000010000;
defparam ram.INIT_9 = 256'b0000110000011011000100000001101100010000000110110001010000011010000101000001101000010100000110010001100000011001000110000001100100011000000110000001110000011000000111000001100000100000000101110010000000010111001000000001011000100100000101100010010000010110;
defparam ram.INIT_A = 256'b0000000000111101000000000011111000000000001111100000000000011110000000000001111100000000000111110000000000011111000000000001111100000000000111100000010000011110000001000001111000001000000111010000100000011101000010000001110000001100000111000000110000011100;
defparam ram.INIT_B = 256'b0000000011110111000000001111100000000000111110000000000011011000000000001101100100000000110110010000000010111010000000001011101000000000100110100000000010011011000000001001101100000000011110110000000001111100000000000111110000000000010111010000000001011101;
defparam ram.INIT_C = 256'b0000000110110001000000011011001000000001101100100000000110010010000000011001001100000001100100110000000101110100000000010111010000000001010101000000000101010101000000010101010100000001001101010000000100110110000000010011011000000001000101110000000100010111;
defparam ram.INIT_D = 256'b0000001001101011000000100110110000000010011011000000001001001100000000100100110100000010010011010000001000101110000000100010111000000010000011100000001000001111000000100000111100000001111011110000000111110000000000011111000000000001110100010000000111010001;
defparam ram.INIT_E = 256'b0000001100100101000000110010011000000011001001100000001100000110000000110000011100000011000001110000001011101000000000101110100000000010110010000000001011001001000000101100100100000010101010010000001010101010000000101010101000000010100010110000001010001011;
defparam ram.INIT_F = 256'b0000001111100000000000111110000000000011111000000000001111000000000000111100000100000011110000010000001110100010000000111010001000000011100000100000001110000011000000111000001100000011011000110000001101100100000000110110010000000011010001010000001101000101;


  endmodule

