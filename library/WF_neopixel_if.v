
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
//
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

module neopixel_if(
    input  wire        clk,
    input  wire        ten_us,          // pulse every ten us
    output reg  [7:0]  ram_rd_addr,     // address of next pixel
    input  wire [23:0] ram_rd_data,     // neopixel data
    output reg         DOUT             // neopixel data out pin
);

 parameter NUM_OF_PIXELS = 8;

// set parameters based on  above table and clk frequenecy
  parameter [3:0] BIT1_HI = 10;
  parameter [3:0] BIT1_LO =  5;
  parameter [3:0] BIT0_HI =  5;
  parameter [3:0] BIT0_LO = 10;
  parameter [3:0] NEO_PERIOD = 15;
  parameter [3:0] NEO_RESET = 6;    // count in 10s of microseconds


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

