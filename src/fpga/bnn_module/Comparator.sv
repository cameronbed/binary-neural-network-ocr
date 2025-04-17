/*
    Comparator module, 
    compares the outputs from the FC layer to decide the final classification output
    the inputs should be in the form of Q8.8 fixed-point array
*/

module Comparator#(
    parameter int IC = 10,
    parameter int OUTPUT_BIT = $clog2(IC+1) // num of bits to enumerate each class
)(
    input logic signed [15:0] in [0:IC-1],
    output [OUTPUT_BIT-1:0] out
);
    logic signed [15:0] max;
    logic [OUTPUT_BIT-1:0] max_ind;
    always_comb begin
        max = in[0];
        max_ind = 0;
        for (int ic=1; ic<IC; ic=ic+1) begin
            if (in[ic] > max) begin
                max = in[ic];
                max_ind = ic[OUTPUT_BIT-1:0];
            end
        end
    end
    assign out = max_ind;       // return the index with largest value

endmodule

