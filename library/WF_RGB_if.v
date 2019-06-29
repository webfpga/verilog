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


