// @MAP_IO LED 31

module fpga_top(
    output reg  LED
);

// Internal HFOSC runs ~48Mhz. Use counter to count to 1 second.
// Breaking the counter into smaller stages will allow it to time
// at a higher frequenecy. But for DEMO keep it simple.

// 1/48,000,000, 20.833ns. period. Count to 48 million for one second.
// Spec is to toggle 1/2 second, on for 1/2, then off or 1/2 second.
// So need to count to 24 Million. Need a 25 bit counter.
   reg [24:0] counter;
   
   always @ (posedge clk)
     if (counter == 2400000)
       begin
         LED      <= ~LED;
         counter  <= 'b0;
       end
     else
       begin
         counter  <= counter + 'b1;
       end
           

 //  create clock for SB_HFOCS hard macro
    wire clk_en;
    assign clk_en = 1'b1;

  SB_HFOSC OSC_i (
        .CLKHFEN(clk_en),
        .CLKHFPU(clk_en),
        .CLKHF(clk));

   endmodule
