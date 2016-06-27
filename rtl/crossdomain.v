module crossdomain (
    input clkA,   // we actually don't need clkA in that example, but it is here for completeness as we'll need it in further examples
    input inA,
    input clkB,
    output outB
);

// We use a two-stages shift-register to synchronize SignalIn_clkA to the clkB clock domain
reg [1:0] SyncA_clkB;
always @(posedge clkB) SyncA_clkB[0] <= inA;   // notice that we use clkB
always @(posedge clkB) SyncA_clkB[1] <= SyncA_clkB[0];   // notice that we use clkB

assign outB = SyncA_clkB[1];  // new signal synchronized to (=ready to be used in) clkB domain
endmodule