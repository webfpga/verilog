//////////////////////////////////////////////////////////////////////
//
// 256x16 FPGA RAM, BRAM.
//
   module WF_bram256x16 (
     input wire         clk,
     input wire         wen,
     input wire         ren,
     input wire  [7:0]  waddr,
     input wire  [7:0]  raddr,
     input wire  [15:0] wdata,
//     output reg  [15:0] rdata
     output wire [15:0] rdata
     );

     // inferred BRAM, doesn't work, so use manual instantiation
/*
     reg [15:0] mem [0:63];

     always @(posedge clk)
       begin
         if (wen)
           mem[waddr] <= wdata;

         if (ren)
           rdata <= mem[raddr];
       end
*/

 SB_RAM256x16  SB_RAM256x16_inst (
                      .WDATA(wdata),
                      .MASK(16'b0),
                      .WADDR(waddr),
                      .WE(wen),
                      .WCLKE(1'b1),
                      .WCLK(clk),

                      .RDATA(rdata),
                      .RADDR(raddr),
                      .RE(1'b1),
                      .RCLKE(1'b1),
                      .RCLK(clk));
   endmodule

