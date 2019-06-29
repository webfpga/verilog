//////////////////////////////////////////////////////////////////////
//
// external switch debounced and synchronizer.
// active low when pushed.
//
// instantiation example:
//
// WF_switch_debounce switch_debounce_inst (
//    .clk(clk),              // main clock
//    .sample_en(ten_ms),     // pulse when to sample
//    .switch_in(WF_BUTTON),  // async switch input
//    .switch_out(),          // sync switch out, debounced 
//    .switch_pushed(switch_pushed),    // pulse when switch is pushed
//    .switch_released()                // pulse when switch is released
//   );
//
   module WF_switch_debounce (
     input  wire clk,              // main clock
     input  wire sample_en,        // pulse when to sample, something like 10ms or so
     input  wire switch_in,        // async switch input
     output reg  switch_out,       // sync switch out, debounced
     output wire switch_pushed,    // pulse when switch is pushed
     output wire switch_released   // pulse when switch is released
     );


     reg  [2:0] switch;    // use a shift reigter to debounce, fastest and least logic
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

