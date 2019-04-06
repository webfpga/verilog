/*
* webfpga_debounce.v
*
* Simple input signal debouching.
*
*       clk  -> on each posedge, we sample the input state
* in_signal  -> signal to sample
* out_signal -> debounced output
*
* out_signal will only pull high when in_signal has maintained its
* state for 3 samples.
*/

module webfpga_debounce(input clk, input in_signal, output out_signal);
    reg [2:0] state;
    reg output_signal;

    always @(posedge clk) begin
        state[0] <= state[1];
        state[1] <= state[2];
        state[2] <= in_btn; 

        case (state)
            3'b000:  output_signal <= 0;
            3'b111:  output_signal <= 1;
            default: output_signal <= output_signal;
        endcase
    end
endmodule
