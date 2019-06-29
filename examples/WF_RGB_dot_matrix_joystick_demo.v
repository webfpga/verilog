// --------------------------------------------------------------------
// Cascadia Web Based FPGA Tools  Section
//
// IOs are set with comment directive #CAS_XX ioName ioPin
// #CAS_IO RGB_DOUT 4
// #CAS_IO RGB_CLK_OUT 9
// #CAS_IO RGB_LOAD 6
//
// #CAS_IO SIO_MST_OUT_SLV_IN 47
// #CAS_IO SIO_CLK_OUT 44
// #CAS_IO SIO_LOAD 37
// #CAS_IO SIO_MST_IN_SLV_OUT 46

// This builds the SDC file used for P&R and timing checks
// #CASS_CLK net CLK 83   //ns
// #CAS_CLK pin OSC_i/CLKHF 83.3    //ns   
//
// Device target board is done with directive #CAS_XXXXXX boardName
// #CAS_TARGET  SHASTAPLUS

// set top level module
// #CAS_NAME  WF_RGB_dot_matrix  // top level module
// --------------------------------------------------------------------
//  #CAS_DESC  8x8 RGB serial dot matrix driver. 
//
// @MAP_IO RGB_DOUT    24
// @MAP_IO RGB_CLK_OUT 25
// @MAP_IO RGB_LOAD    26
//
// @MAP_IO SIO_MST_OUT_SLV_IN 19
// @MAP_IO SIO_CLK_OUT        17 
// @MAP_IO SIO_LOAD           15
// @MAP_IO SIO_MST_IN_SLV_OUT 18 


//           
// --------------------------------------------------------------------
//
// Revision History :

module fpga_top (

    output wire      RGB_CLK_OUT,
    output wire      RGB_DOUT,
    output wire      RGB_LOAD,
    // SIO IOs
    output wire      SIO_CLK_OUT,
    output wire      SIO_MST_OUT_SLV_IN,
    input  wire      SIO_MST_IN_SLV_OUT,
    output wire      SIO_LOAD
);

   wire [15:0]  ram_rd_pixels;
   wire [5:0]   ram_rd_addr;
   reg  [2:0]  cnt;

   // joystick
   wire [4:0] joystick;

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
     WF_timer #(.COUNT(099)) two_msec(   
           .clk(clk),
           .enable(ten_us),
           .timer_pulse(two_ms));

     // include time base  1 sec
     WF_timer #(.COUNT(499)) one_sec( 
           .clk(clk),
           .enable(two_ms),
           .timer_pulse(one_second));


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

         // include joystick board
     WF_joystick_board joystick_inst (
             .clk(clk),
             .scan_enable(two_ms), // better than 60Hz, so 2ms min.
     // LEDs
             .slide_leds_red(8'h0),
             .slide_leds_green(8'h0),
             .status_leds_red(4'b1010),
             .status_leds_blue(4'b0101),
         //    .circle_leds_red(12'h0),
             .circle_leds_red({2'b0,joystick[4],2'b0,joystick[2],2'b0,joystick[1],2'b0,joystick[0]}),
             .circle_leds_green(12'h0),
     // switches
             .slide_switches(),
             .joystick_switches(joystick), // [0]=N,[4]=W,[1]=E,[2]=S,[3]=Push
     // header IOs
             .header_outputs(8'h0),  // 
             .header_inputs(),
     // extrenal IOs
             .LOAD(SIO_LOAD),
             .CLK_OUT(SIO_CLK_OUT),
             .MST_OUT_SLV_IN(SIO_MST_OUT_SLV_IN),
             .MST_IN_SLV_OUT(SIO_MST_IN_SLV_OUT)
     );


///////////////////////////////////////////////////////////////////

 //  Demo a dot moving on the do matrix controlled by the joystick switch
 
  reg [4:0] joystick_d;
  reg [5:0] dot;


  // capture joystick and detect when pushed
     always @ (posedge clk)
       joystick_d <= joystick;

     assign center_pushed = joystick[3] && !joystick_d[3];
     assign north_pushed  = joystick[0] && !joystick_d[0];
     assign south_pushed  = joystick[2] && !joystick_d[2];
     assign east_pushed   = joystick[1] && !joystick_d[1];
     assign west_pushed   = joystick[4] && !joystick_d[4];


     always @ (posedge clk)
       if (center_pushed || (cnt == 0))   // like a reset to center the dot again
	 begin                            // and make the color not black
           dot <= 28;
           if (cnt == 0) 
             cnt <= 1;
           else
	     cnt <= cnt + 1;
	 end
       else
	 begin    
	   // north case
	   if (north_pushed)
	     if (dot[5:3] == 3'b000)     // at top edge
               begin
	         if (cnt == 7) cnt <= 1; // change color
		 else cnt <= cnt +1;
	       end
             else 
	      dot <= dot  - 8;

	   // south case
	   if (south_pushed)
	     if (dot[5:3]  == 3'b111)    // at bottom edge
               begin
	         if (cnt == 7) cnt <= 1; // change color
		 else cnt <= cnt +1;
	       end
             else 
	      dot <= dot  + 8;

	   // east case
	   if (east_pushed)
	     if (dot[2:0] == 3'b111)     // at right edge
               begin
	         if (cnt == 7) cnt <= 1; // change color
		 else cnt <= cnt +1;
	       end
             else 
	      dot <= dot  + 1;

	   // west case
	   if (west_pushed)
	     if (dot[2:0] == 3'b000)     // at left edge
               begin
	         if (cnt == 7) cnt <= 1; // change color
		 else cnt <= cnt +1;
	       end
             else 
	      dot <= dot  - 1;
         end

     assign ram_rd_pixels = (dot == ram_rd_addr) ? 16'h0 : { 1'b0,4'b0,cnt[0], 4'b0,cnt[1],4'b0, cnt[2]}; 


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
   //   if (CPUIN_PA3 ? one_second:scan_en)      // start cycle
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
      if (phase_rd) // reading data while row sel is shifting
        begin
         data_next[dotclk_index[2:0]]    <= ram_rd_pixels[0];   // blue
         data_next[dotclk_index[2:0]+16] <= ram_rd_pixels[5];   // green
         data_next[dotclk_index[2:0]+8]  <= ram_rd_pixels[10];  // red
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

///////////////////////////////////////////////////////////////////////////
//
// joystick board
//
//
// The joystick board has a serial intreface to access the switch states,
// control the LED states, sample the 8 header inputs and control 8 header
// outputs. The serial stream is SPI like and is 24 bits long.
//
// sent data:  {header outputs[7:0], led columns[5:0],2'b0,led rows[7:0]}
// recv'd data:{header inputs[7:0], slide_sitches[7:0],3'b0,joystick[4:0]}
//
// The 48 leds are in column/row form and need to be scanned. At least
// at 60Hz or better than 2ms. 6 columns and 8 rows.
//  mapping to be added here
//
//  Switches are not scanned but are in the serial stream.
////////////////////////////////////////////////////////////////////////////
//

      module WF_joystick_board (
     input        clk,
     input        scan_enable,
     // LEDs
     input [7:0]  slide_leds_red,      // active high LEDs, 1=lite
     input [7:0]  slide_leds_green,    // active high LEDs, 1=lite
     input [3:0]  status_leds_red,     // active high LEDs, 1=lite
     input [3:0]  status_leds_blue,    // active high LEDs, 1=lite
     input [11:0] circle_leds_red,     // active high LEDs, 1=lite
     input [11:0] circle_leds_green,   // active high LEDs, 1=lite
     // switches
     output reg  [7:0] slide_switches,  //  slide up == 1
     output reg  [4:0] joystick_switches, // [0]=N,[4]=W,[1]=E,[2]=S,[3]=Push
     // extra IOs
     input       [7:0] header_outputs,
     output reg  [7:0] header_inputs,

     // extrenal IOs
     output       LOAD,
     output reg   CLK_OUT,
     output       MST_OUT_SLV_IN,
     input        MST_IN_SLV_OUT
     );

// define variables
   reg [5:0] columns;   // scan enables for each column

   reg       shiftclk_en;   // during DOUT shifting
   reg [5:0] dataout_index;

   reg [7:0]  current_row;
   reg [15:0] data_out; //  output shift register
   reg [23:0] data_in;  //  input switch register
   reg  [4:0] joystick;

   // capture pulse for sampling switches
   reg        shiftclk_en_d;
   wire       load_clk;

////////////////////////////////////////////////////////////////////////////
   // mappings of switches, header bits and LEDs
    always @ (posedge clk)
      if (load_clk)
       begin
        header_inputs[7:0]     <= data_in[23:16];
        joystick_switches[4:0] <= ~data_in[4:0];
        slide_switches[7:0]    <= ~data_in[15:8];  //slide up == 1
       end

////////////////////////////////////////////////////////////////////////////
// column initialization and rotation.
//
   always @ (posedge clk)
     begin
       if (columns == 6'h0)     // just came out of reset
         columns <= 6'h01;

       if (scan_enable)
         columns <= {columns[4:0],columns[5]};   // rotate the select bit
     end

////////////////////////////////////////////////////////////////////////////
// send data out 24 clocks of data, {Outputs[7:0], columns[5:0],2'b0, rows[7:0]}
//
//
   // control logic for 24 bit shift register
   always @ (posedge clk)
     begin
       if (scan_enable)
         begin
           shiftclk_en     <= 1'b1;
           dataout_index   <= 6'b0;// two of our clocks for each serial clk
         end
       else
         begin
           if (shiftclk_en)
             begin
               if (dataout_index == 6'd47)   // check for last bit
                 shiftclk_en <= 1'b0;
               else
                 dataout_index <= dataout_index + 6'h1;
             end
         end
   end   // always

   // send data out and capture switch data
   always @ (posedge clk)
     if (shiftclk_en )
       begin
         if (dataout_index[0]) // only change on falling edge
           begin
             data_out <= {data_out[14:0],1'b0}; // shift data
           end

        // capture input data on DIN
         else   // rising edge capture - data will change for next cycle on
                 // the board, we have the earliest clock.
            data_in <= {data_in[22:0],MST_IN_SLV_OUT};

         if (dataout_index == 5'd31) // header outputs are last byte sent
           data_out <= {header_outputs,8'h00};

       end
     else
         data_out<= { current_row[7:0],2'b0,columns}; // load up LEDs
                                                      // when not shifting


    // capture switch data for next sampling cycle
    always @ (posedge clk)
      shiftclk_en_d <= shiftclk_en;   // create pulse

    assign load_clk = shiftclk_en_d && ~shiftclk_en;

////////////////////////////////////////////////////////////////////////////
// MAP leds to rows and columns
//active low turns on LED
   always @(*)
      case (columns)  // synthesis parallel_case
        6'd1 : current_row = ~slide_leds_red[7:0];
        6'd2 : current_row = ~slide_leds_green[7:0];
        6'd4 : current_row = ~circle_leds_red[7:0];
        6'd8 : current_row = ~circle_leds_green[7:0];
        6'd16: current_row = ~{status_leds_red[3:0],circle_leds_red[11:8]};
        default:
         current_row = ~{status_leds_blue[3:0],circle_leds_green[11:8]};
      endcase

////////////////////////////////////////////////////////////////////////////
// create external IOs
   assign LOAD = ~shiftclk_en;

// generate clock
   always @ (posedge clk)
     if (shiftclk_en)
       CLK_OUT <= ~CLK_OUT;
     else
       begin
         if (load_clk)
           CLK_OUT <= 1'b1;   // capture for switches
         else
           CLK_OUT <= 1'b0;   // make sure it at zero at idle
       end

   assign MST_OUT_SLV_IN = data_out[15];

endmodule

