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

