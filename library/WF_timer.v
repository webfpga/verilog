//////////////////////////////////////////////////////////////////////
//
// WF_timer
//
// General timer/counter  (up to 1023 counts)
// Will count when enable is true and clk occurs.
//
// outputs a 1 clock pulse when timer/counter completes.
//
// Use a parameter statement to set number of enabled clocks to count minus 1.
//
// Another parameter is provided when every clock (ie, always enabled) is
// needed to be counted. This usally is needed when his is the first counter
// in a counter divider chain.
//
// instantiation example:
//
//  // create 10us time base, 48MHz clock source.
//
//   WF_timer #(.COUNT(479), .EVERY_CLK(1'b1)) ten_usec(
//              .clk(clk),
//              .enable(1'b1),
//              .timer_pulse(ten_us));
//
//   // create 10ms time base 10ms
//
//   WF_timer #(.COUNT(999)) ten_msec(
//              .clk(clk),
//              .enable(ten_us),
//              .timer_pulse(ten_ms));
//
///////////////////////////////////////////////////////////////////////

   module WF_timer (
       input  wire clk,                    // main core clock
       input  wire enable,                 // count when enabled
       output reg  timer_pulse             // 1 clk pulse when completion event occurs
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

