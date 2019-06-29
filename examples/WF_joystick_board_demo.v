// --------------------------------------------------------------------
// Cascadia Web Based FPGA Tools  Section
//
// IOs are set with comment directive #CAS_XX ioName ioPin
// #CAS_IO MST_OUT_SLV_IN 47
// #CAS_IO CLK_OUT 44
// #CAS_IO LOAD 37
// #CAS_IO SWITCH_IN 42
// #CAS_IO CPU_IN 11
// #CAS_IO MST_IN_SLV_OUT 46 
// #CAS_IO DTEST 27
//
// @MAP_IO MST_OUT_SLV_IN 19 // (original fpga pin = 47)
// @MAP_IO CLK_OUT        17 // (original fpga pin = 44)
// @MAP_IO LOAD           15 // (original fpga pin = 37)
// @MAP_IO MST_IN_SLV_OUT 18 // (original fpga pin = 46)
// @MAP_IO DTEST          11 // (original fpga pin = 27)

// Clock is define with directive #CAS_XXX  clkName clkPeriod (12MHz)
// This builds the SDC file used for P&R and timing checks
// #CASS_CLK net CLK 83   //ns
// #CAS_CLK pin OSC_i/CLKHF 83.3    //ns   
//
// Device target board is done with directive #CAS_XXXXXX boardName
// #CAS_TARGET  SHASTAPLUS

// set top level module
// #CAS_NAME  WF_joystick_board_demo // top level module
// --------------------------------------------------------------------
//  #CAS_DESC  7 segment display used as a timer. Push buttom stops timer,
//  then, restarts. Hold push button in for ~1sec resets timer.
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
    output wire      MST_OUT_SLV_IN,
    input  wire      MST_IN_SLV_OUT,
    output wire      LOAD,
    input  wire      WF_CPU1,
    input  wire      WF_BUTTON
);


// demo logic
// define registers
    reg [11:0] reds; 
    reg [11:0] greens; 
    reg        count83ms_pulse;
    reg [7:0]  seconds;
    reg [3:0]  count12;
    reg        count12_pulse;

    reg [11:0] circle_red;
    reg [11:0] circle_grn;
    reg [7:0]  slide_grn;
    reg [7:0]  slide_red;
    
   reg [5:0] count83ms;

   wire [7:0] slides;
   wire [4:0] joystick;

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

    // include joystick board
     WF_joystick_board joystick_inst (
             .clk(clk),
             .scan_enable(two_ms), // better than 60Hz, so 2ms min.
     // LEDs
             .slide_leds_red(slide_red),
             .slide_leds_green(slide_grn),
             .status_leds_red(4'b1010),
             .status_leds_blue(4'b0101),
             .circle_leds_red(circle_red),
             .circle_leds_green(circle_grn),
     // switches
             .slide_switches(slides),
             .joystick_switches(joystick), // [0]=N,[4]=W,[1]=E,[2]=S,[3]=Push
     // header IOs
             .header_outputs(slides),  // reflect slide switches on header 
             .header_inputs(),
     // extrenal IOs
             .LOAD(LOAD),
             .CLK_OUT(CLK_OUT),
             .MST_OUT_SLV_IN(MST_OUT_SLV_IN),
             .MST_IN_SLV_OUT(MST_IN_SLV_OUT) 
     );



////////////////////////////////////////////////////////////////////////////

// DEMO for switches and LEDs
//  create reset function
//
   reg  [1:0] resets;
   always @ (posedge clk)
       if (resets == 2'b0)     // just came out of reset
         resets <= 2'b01;
        else
         resets <= {resets[0],resets[1]};   // rotate the select bit

    wire second_mode = ~slides[2];

// create a ring led display that cycles once a second 
    always @ (posedge clk)
      if (resets==2'b0)     // still in reset
        begin
          reds   <= 12'hFFF;     // set all reds   (lite them)
          greens <= 12'h001;     // clear all greens except top one 
        end
      else
        if (count83ms_pulse) // 1/12 second
          greens <= second_mode ? {greens[10:0],1'b1} :
                                  {greens[10:0],greens[11]};
        else 
          if (count12_pulse && second_mode)
            greens <= 12'h001;
 // clear other LED when green is on.
   wire [11:0] reds_wire = reds & ~greens;

  
// create 1/12 second enable
    always @ (posedge clk)
      if (two_ms && ~joystick[3])  // freeze if joystick center pushed
        count83ms <=count83ms + 'b1;
      else
        if (count83ms ==  42) // 83)
          begin
            count83ms <= 0;
            count83ms_pulse <= 1;
          end
        else
          count83ms_pulse <= 0;
           
 //  count every 12 pulses for a second, advance the switch LEDs
    always @ (posedge clk)
      if  (count83ms_pulse && ~joystick[2])
        count12 <= count12 + 'b1;
      else
        if (count12 == 12)
          begin
            count12 <= 'b0;
            count12_pulse <= 1'b1;
          end
        else
          count12_pulse <= 1'b0;
          
 // count seconds  - for binary reqpresentation of seconds on slide LEDs
    always @ (posedge clk)
      if (count12_pulse)
        seconds  <= seconds + 'b1;
        
          
    wire [1:0] mux_ctl = {slides[7],slides[0]};
       
    always @ (posedge clk)
      begin
        // circle LEDs
        circle_red[11:0]  <= ~mux_ctl[0] ? greens      : reds_wire;
        circle_grn[11:0]  <= ~mux_ctl[0] ? reds_wire   : greens;
        // switch LEDs, bit reverse so binary count right to left
        slide_grn[7:0 ] <= mux_ctl[1] ? 
                       {seconds[0],seconds[1],seconds[2],seconds[3],
                        seconds[4],seconds[5],seconds[6],seconds[7]} : 8'h00;
        slide_red[7:0 ] <= mux_ctl[1] ? 8'h00 :
                       {seconds[0],seconds[1],seconds[2],seconds[3],
                        seconds[4],seconds[5],seconds[6],seconds[7]};
        end

endmodule

// IPs

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
         
