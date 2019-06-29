// WF_blinky.v
//
// The "Hello World" of Digital Logic!
// This example blinks the on-board user LED once a second.
//
// This Source Code is Public Domain.

module fpga_top(output reg WF_LED, input wire WF_CLK);
    reg [24:0] counter;

    // Blink LED every 1000 ms
    always @ (posedge WF_CLK) begin
        // Try using a different value here...
        // 8000000 will cause it to blink twice as fast!
        if (counter == 16000000) begin
            WF_LED   <= ~WF_LED;
            counter  <= 'b0;
        end else begin
            counter  <= counter + 'b1;
        end
    end
endmodule
