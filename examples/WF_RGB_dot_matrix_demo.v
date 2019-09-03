// @MAP_IO RGB_DOUT    25 
// @MAP_IO RGB_CLK_OUT 26 
// @MAP_IO RGB_LOAD    27 

// #CAS_CLK pin OSC_i/CLKHF 83.3    //ns   

module fpga_top(
    output wire RGB_CLK_OUT,
    output wire RGB_DOUT,
    output wire RGB_LOAD,
    input  wire WF_BUTTON,
    input  wire WF_CPU1,
    input  wire WF_CPU2,
    input  wire WF_CPU3
);


   // input IO from CPU
   wire      cpuin_pa0_toggled;
   reg       cpuin_pa0_d;

   // ram write to demo display driver
   reg         updates;   // allow updates to memory only when not scanning
   reg [15:0]  ram_wr_pixels;
   reg [5:0]   ram_wr_addr;
   reg         ram_wr_en;
   wire [15:0]  ram_rd_pixels;
   wire [5:0]   ram_rd_addr;
   wire [4:0]  random_num;
   wire        colR;
   wire        colG;
   wire        colB;
   reg  [2:0]  cnt;

/////////////////////////////////////////////////////////////////////////
//
//  create clock for SB_HFOCS hard macro
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
      .sample_en(two_ms),     // pulse when to sample
      .switch_in(WF_BUTTON),  // async switch input
      .switch_out(),          // sync switch out, debounced
      .switch_pushed(switch_pushed),    // pulse when switch is pushed
      .switch_released()                // pulse when switch is released
     );


// detect CPU in toggling
//
   always @ (posedge clk)
       cpuin_pa0_d        <= WF_CPU1;

     assign cpuin_pa0_toggled = ~cpuin_pa0_d &&  WF_CPU1 ||
                                 cpuin_pa0_d && ~WF_CPU1;

//
// use memory to store 8x8 pixel matrix colors.

   WF_bram256x16 dot_memory (
     .clk(clk),
     .wen(ram_wr_en),
     .ren(1'b1),
     .waddr({2'b0,ram_wr_addr}),
     .raddr({2'b0,ram_rd_addr}),
     .wdata(ram_wr_pixels),
     .rdata(ram_rd_pixels));

// bring in the RGB I/F
    WF_RGB_if RGB_if_inst(
     .clk(clk),
     .scan_en(two_ms),
     .scan_done(scan_done),
     .ram_rd_addr(ram_rd_addr),
     .ram_rd_pixels(ram_rd_pixels),
     .CLK_OUT(RGB_CLK_OUT),
     .LOAD(RGB_LOAD),
     .DOUT(RGB_DOUT)
     );

///////////////////////////////////////////////////////////////////

     // **************************************
     //  fill memory to test display.
     //
    
 // sync to the scan done sugnals to updates to memory
 // when scanning isn't being done.
 //
     always @ (posedge clk)
       if (two_ms)
         updates <= 1'b0;
       else if (scan_done)
           updates <= 1'b1;
         else if (~WF_CPU2)   // if doing random hen only
           updates <= 1'b0;    // update memory once every two ms

     always @ (posedge clk)
       if (updates)   // update when not scanning
        begin
            ram_wr_addr <= ram_wr_addr + 1;
            ram_wr_pixels <= {1'b0,4'b0,colR, 4'b0,colG,4'b0, colB}; 
//            ram_wr_pixels <= {1'b0,4'b0,1'b0, 4'b0,1'b1,4'b0,1'b0}; 
            ram_wr_en <= 1'b1;
        end
        else
            ram_wr_en <= 1'b0;

     always @ (posedge clk)
       if (switch_pushed || cpuin_pa0_toggled)
         cnt <= cnt + 1;


    // get random 5 bit number.
     WF_random_5 random5 (
           .clk(clk),
           .enable(two_ms),
    	   .data(random_num));

    assign colR = WF_CPU2 ? cnt[0] : random_num[0];
    assign colG = WF_CPU2 ? cnt[1] : random_num[1];
    assign colB = WF_CPU2 ? cnt[2] : random_num[2];

////////////////////////////////////////////////////////////////////////////

endmodule

////////////////////////////////////////////////////////////////////////////
//
// RGB I/F
// 
//////////////////////////////////////////////////////////////////////
//  RGB dot matrix display driver and logic
//
//  This code is written for a serial 8x8 3 color dot matrix display.
//  It is wired as follows:
//
//  8 row drivers enabled when high.  (ANODE)
//  3 - 8 column sinks, LED on when low. (CATHODE)
//  There are 3 row sinks, one for each color (red,green,blue).
//
//  Shift 32 bits of data per scan.
//      {row,colG,colR,colB}, each are 8 bits
//
//      MSB bit is shift first.
//  Need to generate a CLK, DOUT and LOAD signal.
//  DOUT is changed on falling edge of CLK. LOAD is pulsed high
//  after last CLK falling edge.
//////////////////////////////////////////////////////////////////////
//
  module WF_RGB_if(
	  input  clk,
          input  scan_en,   // start scan cycle, two_ms min
	  output scan_done, // can be used to sync updates

	  output [5:0]  ram_rd_addr,   // pixel memory addr
	  input  [15:0] ram_rd_pixels, // pixel data {1'b0,5'RED,5'GRN,5'BLUE}
	                           // currently no PWM, so LSB of each color 
	  output reg  CLK_OUT,  // send to IOs
	  output wire LOAD,
	  output wire DOUT
  );

  wire scan_done = dotclk_done;

// variables
  reg        phase_col;
  reg        phase_rd;
  reg [5:0]  dotclk_index;
  reg [2:0]  dotclk_index_d;
  reg        dotclk_en;      // during DOUT shifting
  reg        dotclk_en_d;    // delayed
  wire       dotclk_done;    // after falling edge of dotclk_en
  reg        dotclk_done_d; 
  reg        phase_row;      // on when row selects are being shifted out
  reg [7:0]  row;            // scan enables 
  reg [2:0]  row_addr;
  reg [23:0] data_next;      // these can be optimized, use only 8 bits
  reg [23:0] data_out; 

// scan rows every scan_en, so compete display is updated every 8 scan enables,
// 16ms, is the minimum scan o no see the flickering.

// row scanning 
     always @ (posedge clk)
       begin
         if (row == 8'h0)     // just came out of reset
           row <= 8'hfe;

         if (dotclk_done )
           row <= {row[6:0],row[7]};   // rotate the select bit
       end

////////////////////////////////////////////////////////////////////////////
//  Main logic controller. Starts when scan_en pulse is true.
//  read memory phase, 8 clocks to read pxiel RAM, one row, or 8 bytes.
//  start shifting data, 24 bits,
//  finally shift out row selects 8 bits.
//  end cycle
//

    always@ (posedge clk)   
      if (scan_en)      // start cycle
   //   if (WF_CPU3, ? one_second:scan_en)      // start cycle
        phase_rd <= 1'b1;
      else
        begin         
          if (dotclk_index == 15 && phase_rd)  // end of phase_rd
            begin
              phase_rd     <= 1'b0;
              phase_col    <= 1'b1;
              dotclk_index <= 0;
              dotclk_en    <= 1'b1;   // enable external clock
            end
          else 
	    if (phase_rd || phase_col || phase_row)
	      dotclk_index <= dotclk_index + 'b1;

          if (dotclk_index == 47)     // end of phase_col
            begin
              phase_col    <= 1'b0;
              phase_row    <= 1'b1;  // enable loading for row data
            end
          if (dotclk_index == 6'd63) // check for last bit
            begin
              dotclk_en    <= 1'b0;
              phase_row    <= 1'b0;  
            end
        end      

////////////////////////////////////////////////////////////////////////////

// lookup pixel from memory
//
// take row and convert to address.
   always @(*)                                                                
         case (row)  //synthesis parallel_case full_case 
             8'b1111_1110 : row_addr <= 3'h0;
             8'b1111_1101 : row_addr <= 3'h1;
             8'b1111_1011 : row_addr <= 3'h2;
             8'b1111_0111 : row_addr <= 3'h3;
             8'b1110_1111 : row_addr <= 3'h4;
             8'b1101_1111 : row_addr <= 3'h5;
             8'b1011_1111 : row_addr <= 3'h6;
             8'b0111_1111 : row_addr <= 3'h7;
         endcase                                                                

// get next row pixel data from memory
//  use pixel index to help construct ram addr.
    assign ram_rd_addr =  {row_addr,dotclk_index[2:0]};

    // below supports only 8 colors, need to add PWM to mix the colors
    always@ (posedge clk)   
      if (phase_row) // reading data while row sel is shifting
         begin
           dotclk_index_d <= dotclk_index[2:0];  // ram pipeline
     
           data_next[dotclk_index_d[2:0]]    <= ram_rd_pixels[0];   // blue
           data_next[dotclk_index_d[2:0]+16] <= ram_rd_pixels[5];   // green
           data_next[dotclk_index_d[2:0]+8]  <= ram_rd_pixels[10];  // red
       end


////////////////////////////////////////////////////////////////////////////
//
      // generate clock
     always @ (posedge clk)     // clock will be half core clock, 6MHz.
       if (dotclk_en)
         CLK_OUT <= ~CLK_OUT;
       else
         CLK_OUT <= 1'b0;   // make sure it at zero at idle

// send data out 32 clocks of data, { colG,colR,colB, row}
//
//  use 64 clocks, data will change on every other, so data changes on falling
//  edge out the output-ed clock
//
     always @ (posedge clk)
       if (dotclk_en )
         begin
           if (dotclk_index == 47)    // load pixel data for the row
             data_out <= {row, 16'b0};
           else 
             if (dotclk_index[0]) // only change on falling edge
             data_out <= {data_out[22:0],1'b0};  // shift data out
         end
       else            // load next data continueously until dotclk_en
         data_out <= data_next;

     always @ (posedge clk)
       begin
         dotclk_en_d   <= dotclk_en;   // delay so read data is ready
         dotclk_done_d <= dotclk_done; // delay to load new row after scan
       end   

     // send signals out
     assign LOAD = ~dotclk_en;
     assign DOUT = data_out[23];

     assign dotclk_done = ~dotclk_en && dotclk_en_d;  // create pulse

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
// 256x16 FPGA RAM, BRAM.
//
   module WF_bram256x16 (
     input wire         clk,
     input wire         wen,
     input wire         ren, 
     input wire  [7:0]  waddr, 
     input wire  [7:0]  raddr,
     input wire  [15:0] wdata,
//     output reg  [15:0] rdata
     output wire [15:0] rdata
     );

     // inferred BRAM, doesn't work, so use manual instantiation
/*
     reg [15:0] mem [0:63];

     always @(posedge clk)
       begin
         if (wen)
           mem[waddr] <= wdata;

         if (ren)
           rdata <= mem[raddr];
       end
*/

 SB_RAM256x16  SB_RAM256x16_inst (  
                      .WDATA(wdata),
                      .MASK(16'b0),
                      .WADDR(waddr),
                      .WE(wen),
                      .WCLKE(1'b1),
                      .WCLK(clk),

                      .RDATA(rdata),
                      .RADDR(raddr),                             
                      .RE(1'b1),
                      .RCLKE(1'b1),
                      .RCLK(clk));
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
