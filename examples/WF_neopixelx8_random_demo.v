// #CAS_CLK pin OSC_i/CLKHF 83.3    //ns   
// @MAP_IO DOUT 0

module fpga_top(
    output wire      DOUT,
    input  wire      WF_CPU1,
    input  wire      WF_BUTTON
);

// OSC enable
   wire      clk_en = 1'b1;
	
// Dual port Memory for 16 bit color.   5/5/5  RGB
   reg [15:0] pixel_mem[7:0];
   wire [7:0] ram_rd_addr;
   wire [23:0] np_pixels;
   reg [2:0] mem_cnt;
   wire [15:0] pixel;
   wire [4:0] rnd_pixels;
   reg  [2:0] cnt;


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

     // include time base   demo ms
     WF_timer #(.COUNT(999)) demo_msec(
           .clk(clk),
           .enable(ten_us),
           .timer_pulse(demo_ms));

    // create 32 bit sequence for some low randomness
    WF_random_5 rnd5 (
         .clk(clk),
         .enable(1'b1),
         .data(rnd_pixels));

     // neopixel I/F
    WF_neopixel_if neopixel_inst(
           .clk(clk),
           .ten_us(ten_us),
           .ram_rd_addr(ram_rd_addr),    // address of next pixel
           .ram_rd_data(np_pixels),      // neopxiel data
           .DOUT(DOUT));                 // neopxiel data out pin

// Memory used by WF_neopixel_if.
//
  // instead of using 8/8/8 using 5/5/5 format, must expand for noepixel.
  // example turns of highest power bit to save of the 5v supply.
  // This can be removed if array is powered by a non USB power supply.
  //
  assign pixel = pixel_mem[ram_rd_addr];
  assign np_pixels = {2'b0,pixel[14:10],1'b0,2'b0,pixel[9:5],1'b0,2'b0,pixel[4:0],1'b0};

//
//  debounce switch in
    WF_switch_debounce switch_deb1 (
      .clk(clk),              // main clock
      .sample_en(demo_ms),     // pulse when to sample
      .switch_in(WF_BUTTON),  // async switch input
      .switch_out(),          // sync switch out, debounced
      .switch_pushed(switch_pushed),    // pulse when switch is pushed
      .switch_released()                // pulse when switch is released
     );


//////////////////////////////////////////////////////////////////              
  // CPU inputs and Switch logic
// detect CPU signal changing
   always @ (posedge clk)
      cpu_in_d <= WF_CPU1;

    assign cpu_toggled = (cpu_in_d && ~WF_CPU1) || (~cpu_in_d && WF_CPU1);

   always @ (posedge clk)
     if (cpu_toggled || switch_pushed)
       cnt <= cnt +1;

//////////////////////////////////////////////////////////////////              
//  Create colors to DEMO above bit logic.                                      
//////////////////////////////////////////////////////////////////
// create colors in pixel registers.
//
   wire [4:0] colR,colG,colB;

   always @(posedge clk)
     if(demo_ms)   
       begin
  //       pixel_mem[{5'b0,mem_cnt}] <= {1'b0,rnd_pixels & {5{cnt[0]}},rnd_pixels & {5{cnt[1]}},rnd_pixels & {5{cnt[2]}} };
         pixel_mem[{5'b0,mem_cnt}] <= {1'b0,colB & {5{rnd_pixels[3]}},colR & {5{rnd_pixels[4]}},colG & {5{rnd_pixels[2]}} };
         mem_cnt <= mem_cnt +1 ;
     end
      
//     assign colR = 0; 
//     assign colG = 0; 
//     assign colB = 8'hff; // 8'h80 is lowest brightness

     assign colR = rnd_pixels[1:0];
     assign colG = rnd_pixels[3:2];
     assign colB = rnd_pixels[4:3];

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

module WF_neopixel_if(
    input  wire        clk,    
    input  wire        ten_us,          // pulse every ten us
    output reg  [7:0]  ram_rd_addr,     // address of next pixel
    input  wire [23:0] ram_rd_data,     // neopixel data
    output reg         DOUT             // neopixel data out pin
);

 parameter NUM_OF_PIXELS = 8;

// set parameters based on  above table and clk frequenecy
//   BIT1_HI nad BIT0_HI cannot be the same.
  parameter [3:0] BIT1_HI = 10;                                                 
  parameter [3:0] BIT1_LO =  5;                                                 
  parameter [3:0] BIT0_HI =  5;                                                 
  parameter [3:0] BIT0_LO = 10;                                                 
  parameter [3:0] NEO_PERIOD = 15; 
  parameter [2:0] NEO_RESET = 6;    // count in 10s of microseconds


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
    reg [2:0]   reset_cnt;              // count number 10us pulses

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
// pseudo random sequence
// 5 bit output.
// pattern repeats every 32 counts
//
   module WF_random_5 (
     input  wire      clk,
     input  wire      enable,
     output reg [4:0] data
   );

   wire [4:0] data_next;

   // unrolled equations
   assign data_next[4] = data[4]^data[1];
   assign data_next[3] = data[3]^data[0];
   assign data_next[2] = data[2]^data_next[4];
   assign data_next[1] = data[1]^data_next[3];
   assign data_next[0] = data[0]^data_next[2];

   always @(posedge clk)
     if (enable)
       if(data == 0)  // just out of reset, or all zeros case
         data <= 5'h1f;
       else
         data <= data_next;

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

