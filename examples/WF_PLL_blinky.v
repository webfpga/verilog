//// For clocking use the internal HFOSC.
// #CAS_CLK pin OSC_i/CLKHF 83   //ns
//
module fpga_top (
      output reg  WF_LED
);
// Internal HFOSC runs ~48Mhz. Use a PLL to reduce to 16MHzi (pll min).
// Use counter to count to 1 second.
// Breaking the counter into smaller stages will allow it to time
// at a higher frequenecy. But for DEMO keep it simple.

// 1/16,000,000, 62.5ns period. Count to 16 million for one second.
// Spec is to toggle 1/2 second, on for 1/2, then off or 1/2 second.
// So need to count to 8 Million. Need a 23 bit counter.
   reg [22:0] counter;
   
   always @ (posedge clk)
     if (counter == 8000000)
       begin
         WF_LED      <= ~WF_LED;
         counter  <= 'b0;
       end
     else
       begin
         counter  <= counter + 'b1;
       end
 
 //  create clock for SB_HFOCS hard macro
    wire clk_en;
    wire clkout_osc;
    assign clk_en = 1'b1;

  SB_HFOSC OSC_i (
        .CLKHFEN(clk_en),
        .CLKHFPU(clk_en),
        .CLKHF(clkout_osc));

    pll_48in_16out pll_i (
        .REFERENCECLK(clkout_osc),
        .PLLOUTCORE(),
        .PLLOUTGLOBAL(clk),
        .RESET(1'b1));   // simuations only

   endmodule

/////////////////////////////////////////////////////////////////////////
// PLL 
//   input range 10-133 MHz
//   output range 16-275 MHz   (global buffer max is 185MHz)
//   PLL VCO must be in 533 to 1066 MHz range.
//   Phase detector range is 10-133 MHz.
//
//   // simple use equation
//   VCO    = (INPUT/(DIVR+1))*(DIVF+1)
//   PLLOUT = VCO/(2^DIVQ)
//
//   PLLOUT = (INPUT*(DIVF+1))/((2^DIVQ)x(DIVR+1))
//
//
//   example 48 in, 16 out, DIVF=63, DIVR=2, DIVQ=6
//   VCO    = 48/3*64 = 1024MHz
//   PLLOUT = 1024/(2^6) =  16 MHz
//
module pll_48in_16out(REFERENCECLK,
                          PLLOUTCORE,
                          PLLOUTGLOBAL,
                          RESET);

input REFERENCECLK;
input RESET;    /* To initialize the simulation properly, the RESET signal (Active Low) must be asserted at the beginning of the simulation */
output PLLOUTCORE;
output PLLOUTGLOBAL;

SB_PLL40_CORE pll_48in_16out_inst(.REFERENCECLK(REFERENCECLK),
                                      .PLLOUTCORE(PLLOUTCORE),
                                      .PLLOUTGLOBAL(PLLOUTGLOBAL),
                                      .EXTFEEDBACK(),
                                      .DYNAMICDELAY(),
                                      .RESETB(RESET),
                                      .BYPASS(1'b0),
                                      .LATCHINPUTVALUE(),
                                      .LOCK(),
                                      .SDI(),
                                      .SDO(),
                                      .SCLK());

//\\ Fin=48, Fout=16;
defparam pll_48in_16out_inst.DIVR = 4'b0010;
defparam pll_48in_16out_inst.DIVF = 7'b0111111;
defparam pll_48in_16out_inst.DIVQ = 3'b110;
// filter value is set based on the above parameters, add description TODO
defparam pll_48in_16out_inst.FILTER_RANGE = 3'b001;
defparam pll_48in_16out_inst.FEEDBACK_PATH = "SIMPLE";
defparam pll_48in_16out_inst.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
defparam pll_48in_16out_inst.FDA_FEEDBACK = 4'b0000;
defparam pll_48in_16out_inst.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
defparam pll_48in_16out_inst.FDA_RELATIVE = 4'b0000;
defparam pll_48in_16out_inst.SHIFTREG_DIV_MODE = 2'b00;
defparam pll_48in_16out_inst.PLLOUT_SELECT = "GENCLK";
defparam pll_48in_16out_inst.ENABLE_ICEGATE = 1'b0;

endmodule
// comment on last line
//

