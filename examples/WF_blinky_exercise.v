// WF_blinky_exercise.v
//
// The "Hello World" of Digital Logic!
// This example blinks the on-board user LED once a second.

module fpga_top(output reg WF_LED, input WF_CLK, input WF_BUTTON);
    reg  [24:0] counter;
    wire        switch_pushed;
    wire        switch_released;
    reg         switch_debounced_d;
    reg  [3:0]  blink_cnt;

    // Blink LED every 1000 ms
    always @ (posedge WF_CLK) begin
        // Try using a different value here...
        // 8000000 will cause it to blink twice as fast!
//        if (counter == ( {blink_cnt, 2'b11, 20'h42400} )) begin
       if (counter == ( {blink_cnt, 20'h42400} )) begin    
            WF_LED   <= ~WF_LED;
            counter  <= 'b0;
        end else begin
            counter  <= counter + 'b1;
        end
    end
    
    
    // create event flags/pulse
  always @ (posedge WF_CLK)
    switch_debounced_d <= switch_debounced;  // create 1 clock delayed signal
    
 
  assign switch_pushed   = ~switch_debounced &&  switch_debounced_d;
  assign switch_released =  switch_debounced && ~switch_debounced_d;

  always @ (posedge WF_CLK)
     if (blink_cnt == 0)
       blink_cnt <= 4'b0001;
     else
        if (switch_pushed)
      //blink_cnt <= blink_cnt +1;
         blink_cnt <= { blink_cnt[2:0],blink_cnt[3]}; // rotate a one

//  debounce switch in
    WF_switch_debounce switch_deb1 (
      .clk(WF_CLK),              // main clock
      .sample_en(ten_ms),     // pulse when to sample
      .switch_in(WF_BUTTON),  // async switch input
      .switch_out(switch_debounced),    // sync switch out, debounced
      .switch_pushed(),                 // pulse when switch is pushed
      .switch_released() );             // pulse when switch is rel
      
      
    WF_timer #(.COUNT(159), .EVERY_CLK(1'b1)) ten_usec(
        .clk(WF_CLK),
        .enable(1'b1),
        .timer_pulse(ten_us));

   // include time base  10ms
    WF_timer #(.COUNT(999)) ten_msec(
        .clk(WF_CLK),
        .enable(ten_us),
        .timer_pulse(ten_ms));

endmodule







// ************ modules ***************************************//      
      
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
           switch_out <= 1'b0;
         else if (switch == 3'b111)
           switch_out <= 1'b1;

         switch_out_d <= switch_out;
       end

     assign switch_pushed   = ~switch_out &&  switch_out_d;
     assign switch_released =  switch_out && ~switch_out_d;

   endmodule


