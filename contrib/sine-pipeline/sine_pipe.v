// Pipeline to calculate sines.  Phase runs from 16h0000 to 16hFFFF
// for the full phase circle.  Owner is a 3-bit field identifying the
// input; it's passed along through the pipeline and with the output.

// This is a rather long pipeline, coded for clarity at the expense of
// latency. It can certainly be compressed to fewer steps, but this
// may come at the expense of complicating the logic in one or more
// steps and reducing the maximum allowable clock speed.

module sine_pipe (
		  input wire 	    clk,
		  input wire [3:0]  owner,
		  input wire [15:0] phase,
		  output reg [3:0]  owner_out,
		  output reg signed [15:0] sin_out
		  );

   // Load the sine value lookup tables.  We store 16 bits for
   // each primary sample, and 8 bits to store the delta between this
   // sample and the next.
   reg signed [15:0] 			   sine_integer [0:2047];
   initial $readmemh("sine_integer.hex", sine_integer);
   reg signed [7:0] 			   sine_fract [0:2047];
   initial $readmemh("sine_fract.hex", sine_fract);

   // Latch the inputs

   reg [3:0] 			    owner_0;
   reg [15:0] 			    phase_0;
   
   always @(posedge clk) begin
      owner_0 <= owner;
      phase_0 <= phase;
   end

   // Split the phase into negate, reverse, and subphase sections
   
   reg [3:0] 			    owner_1;
   reg 				    negate_1;
   reg 				    reverse_1;
   reg [13:0] 			    subphase_1;
   
   always @(posedge clk) begin
      owner_1 <= owner_0;
      negate_1 <= phase_0[15];
      reverse_1 <= phase_0[14];
      subphase_1 <= phase_0[13:0];
   end

   // Reverse the direction of the in-quadrant phase if necessary

   reg [3:0] 			    owner_2;
   reg 				    negate_2;
   reg [13:0] 			    subphase_2;

   always @(posedge clk) begin
      owner_2 <= owner_1;
      negate_2 <= negate_1;
      subphase_2 <= reverse_1 ? ~subphase_1 : subphase_1;
   end

   // Do the table lookups.  Don't need the reversal
   // information after this.  Also, generate the
   // multiplier for the interpolation.

   reg [3:0] 			    owner_3;
   reg 				    negate_3;
   reg signed [15:0] 		    integer_3;
   reg [15:0] 			    fract_3;
   reg [15:0] 			    interp_3;

   always @(posedge clk) begin
      owner_3 <= owner_2;
      negate_3 <= negate_2;
      integer_3 <= sine_integer[subphase_2[13:3]];
      fract_3 <= {8'b0, sine_fract[subphase_2[13:3]]};
      interp_3 <= {subphase_2[2:0], 13'b0000000000};
   end

   // Multiply-and-add.
 			    
   reg [3:0] 			    owner_4;
   reg 				    negate_4;
   wire signed [31:0] 		    product_4;

   always @(posedge clk) begin
      owner_4 <= owner_3;
      negate_4 <= negate_3;
   end

   // Instantiate an SB16_MAC block which does a 16x16 multiply and
   // accumulate.  This is equivalent to
   //
   //   product_4 <= fract_3 * interp_3 + {integer_3, 16'h0000}
   //
   // It's done here with an explicit instantiation, because yosys
   // does not currently seem to know how to infer a full multiply-
   // and-add into an SB16_MAC - it will infer an unsigned multiply
   // but uses logic cells for the subsequent add.
   SB_MAC16 #(
	      .A_REG('b1),
              .A_SIGNED('b0),
              .BOTADDSUB_CARRYSELECT('b00),
              .BOTADDSUB_LOWERINPUT('b10),
              .BOTADDSUB_UPPERINPUT('b1),
              .BOTOUTPUT_SELECT('b00),
              .BOT_8x8_MULT_REG('b0),
              .B_REG('b1),
              .B_SIGNED('b0),
              .C_REG('b1),
              .D_REG('b1),
              .MODE_8x8('b0),
              .NEG_TRIGGER('b0),
              .PIPELINE_16x16_MULT_REG1('b0),
              .PIPELINE_16x16_MULT_REG2('b0),
              .TOPADDSUB_CARRYSELECT('b11),
              .TOPADDSUB_LOWERINPUT('b10),
              .TOPADDSUB_UPPERINPUT('b1),
              .TOPOUTPUT_SELECT('b00),
              .TOP_8x8_MULT_REG('b0)) mac (
					 .A(fract_3),
					 .ACCUMCI(1'b0),
					 .ADDSUBBOT(1'b0),
					 .ADDSUBTOP(1'b0),
					 .AHOLD(1'b0),
					 .B(interp_3),
					 .BHOLD(1'b0),
					 .C(integer_3),
					 .CE(1'b1),
					 .CHOLD(1'b0),
					 .CI(1'b0),
					 .CLK(clk ),
					 .D(16'h0000),
					 .DHOLD(1'b0),
					 .IRSTBOT(1'b0),
					 .IRSTTOP(1'b0),
					 .O(product_4),
					 .OHOLDBOT(1'b0),
					 .OHOLDTOP(1'b0),
					 .OLOADBOT(1'b0),
					 .OLOADTOP(1'b0),
					 .ORSTBOT(1'b0),
					 .ORSTTOP(1'b0),
					 .SIGNEXTIN(1'b0)
					 );

   // Truncate the product to 16 bits, and negate if necessary.

   reg [3:0] 			    owner_5;
   reg signed [15:0] 		    product_5;

   always @(posedge clk) begin
      owner_5 <= owner_4;
      product_5 <= negate_4? -product_4[31:16] : product_4[31:16];
   end

   // Output the results
		   
   always @(posedge clk) begin
      owner_out <= owner_5;
      sin_out <= product_5;
   end

endmodule // sine_pipe

